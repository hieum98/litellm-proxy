#!/bin/bash
#SBATCH --job-name=litellm-proxy-direct
#SBATCH --output=logs/litellm-proxy_%j.out
#SBATCH --error=logs/litellm-proxy_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=128G
#SBATCH --partition=memorylong,gpulong

# ================================================
# LiteLLM Proxy Direct Startup Script (No Docker)
# Features: Retry Mechanisms, Caching, Load Balancing
# ================================================

set -e  # Exit on error

# Create logs directory if it doesn't exist
mkdir -p logs

echo "=========================================="
echo "Starting LiteLLM Proxy Server (Direct)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Date: $(date)"
echo "=========================================="

# Change to the project directory
SCRIPT_DIR=/home/hieum/uonlp/litellm-proxy
cd $SCRIPT_DIR

# Activate conda environment
source /home/hieum/uonlp/miniconda3/etc/profile.d/conda.sh
conda activate litellm-proxy

# Install redis-server if not already installed
if ! command -v redis-server &> /dev/null; then
    echo "redis-server could not be found, installing..."
    conda install -c conda-forge redis-server -y
fi

# Install dependencies
echo "Installing/updating dependencies..."
uv pip install --upgrade pip
uv pip install 'litellm[proxy]' redis

# Load environment variables from .env file
if [ -f ".env" ]; then
    echo "Loading environment variables..."
    set -a  # automatically export all variables
    source .env
    set +a
else
    echo "Warning: .env file not found!"
    echo "Please create a .env file with required API keys and configuration."
    exit 1
fi

# Set required environment variables if not already set
export REDIS_HOST=${REDIS_HOST:-localhost}
export REDIS_PORT=${REDIS_PORT:-6379}

# ================================================
# Start Redis for caching
# ================================================

# Create data directories
mkdir -p $HOME/redis

echo "Starting Redis for caching..."
# Check if Redis is already running on the specified port
if ! lsof -i :${REDIS_PORT} > /dev/null 2>&1; then
    # Start Redis with config file and override specific settings via command line
    # Command line arguments take precedence over config file settings
    cd $HOME/redis
    
    if [ ! -z "$REDIS_PASSWORD" ]; then
        redis-server $SCRIPT_DIR/redis.conf \
            --port ${REDIS_PORT} \
            --dir $HOME/redis \
            --pidfile $HOME/redis/redis.pid \
            --logfile $HOME/redis/redis.log \
            --requirepass $REDIS_PASSWORD
    else
        redis-server $SCRIPT_DIR/redis.conf \
            --port ${REDIS_PORT} \
            --dir $HOME/redis \
            --pidfile $HOME/redis/redis.pid \
            --logfile $HOME/redis/redis.log
    fi
    # Wait for Redis to start
    sleep 2
    echo "Redis started successfully"
else
    echo "Redis is already running on port ${REDIS_PORT}"
fi

echo "Starting LiteLLM proxy server..."
echo "Config: config.yaml"
echo "Port: 4000"
echo "Workers: 32"
echo ""

cd $SCRIPT_DIR
# Start the LiteLLM proxy
litellm --config config.yaml \
    --port 4000 \
    --num_workers 32

# Cleanup on exit
cleanup() {
    echo ""
    echo "=========================================="
    echo "Shutting down LiteLLM Proxy"
    echo "Date: $(date)"
    echo "=========================================="
    
    # Kill litellm process
    pkill -f litellm || true
    
    # Stop Redis
    if [ -f "$HOME/redis/redis.pid" ]; then
        echo "Stopping Redis..."
        if [ ! -z "$REDIS_PASSWORD" ]; then
            redis-cli -p ${REDIS_PORT} -a ${REDIS_PASSWORD} shutdown || true
        else
            redis-cli -p ${REDIS_PORT} shutdown || true
        fi
        rm -f $HOME/redis/redis.pid
    fi
    
    deactivate || true
}

trap cleanup EXIT SIGTERM SIGINT
