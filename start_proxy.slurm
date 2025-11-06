#!/bin/bash
#SBATCH --job-name=litellm-proxy
#SBATCH --output=logs/litellm-proxy_%j.out
#SBATCH --error=logs/litellm-proxy_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=256G
#SBATCH --partition=memorylong

# ================================================
# LiteLLM Proxy Startup Script (Simplified)
# Features: Retry Mechanisms, Caching, Load Balancing
# ================================================

set -e  # Exit on error

# Create logs directory if it doesn't exist
mkdir -p logs

echo "=========================================="
echo "Starting LiteLLM Proxy Server"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURM_NODELIST"
echo "Date: $(date)"
echo "=========================================="

# Change to the project directory
cd /home/hieum/uonlp/litellm-proxy

# Load required modules (adjust based on your HPC environment)
# Uncomment and modify as needed:
# module load docker/latest

echo "Starting services with Docker Compose..."
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to start..."
sleep 30

# Check service status
echo "Checking service status..."
docker-compose ps

# Show logs
echo "Showing initial logs..."
docker-compose logs --tail=50 litellm-1

# Keep the job running and monitor logs
echo "Proxy server is running. Monitoring logs..."
docker-compose logs -f

# ================================================
# Cleanup on exit
# ================================================
cleanup() {
    echo ""
    echo "=========================================="
    echo "Shutting down LiteLLM Proxy"
    echo "Date: $(date)"
    echo "=========================================="
    
    docker-compose down
}

trap cleanup EXIT SIGTERM SIGINT

# Keep the job running
wait
