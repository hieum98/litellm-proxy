#!/bin/bash

# ================================================
# LiteLLM Proxy SLURM Management Script (Simplified)
# Features: Retry Mechanisms, Caching, Load Balancing
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

show_help() {
    echo "Usage: $0 {start|start-direct|stop|status|logs|restart}"
    echo ""
    echo "Commands:"
    echo "  start        Start the proxy with Docker Compose (recommended)"
    echo "  start-direct Start without Docker (direct Python installation)"
    echo "  stop         Stop the running proxy server"
    echo "  status       Show status of the SLURM job"
    echo "  logs         Show logs from the latest job"
    echo "  restart      Restart the proxy server"
    echo ""
    echo "Features:"
    echo "  - Retry Mechanisms: Automatic retry with configurable policies"
    echo "  - Caching: Redis-based caching for improved performance"
    echo "  - Load Balancing: Multiple proxy instances with Nginx"
    echo ""
}

start_proxy() {
    echo -e "${GREEN}Starting LiteLLM Proxy with Docker Compose...${NC}"
    echo "Features: Retry mechanisms, Redis caching, Load balancing"
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error: .env file not found!${NC}"
        echo "Please create .env file with required configuration:"
        echo ""
        echo "REDIS_PASSWORD=your_redis_password"
        echo "OPENAI_API_KEY=your_openai_key"
        echo "OPENAI_API_KEY_BACKUP=your_backup_key"
        echo "ANTHROPIC_API_KEY=your_anthropic_key"
        echo "GOOGLE_API_KEY=your_google_key"
        exit 1
    fi
    
    # Create logs directory
    mkdir -p logs
    
    # Submit SLURM job
    JOB_ID=$(sbatch --parsable start_proxy.slurm)
    echo -e "${GREEN}Job submitted successfully!${NC}"
    echo "Job ID: $JOB_ID"
    echo "Monitor with: squeue -j $JOB_ID"
    echo "View logs: tail -f logs/litellm-proxy_${JOB_ID}.out"
}

start_direct() {
    echo -e "${GREEN}Starting LiteLLM Proxy directly (no Docker)...${NC}"
    echo "Features: Retry mechanisms, Redis caching"
    echo "Note: Load balancing requires Docker setup"
    
    # Check if .env file exists
    if [ ! -f ".env" ]; then
        echo -e "${RED}Error: .env file not found!${NC}"
        echo "Please create .env file with required configuration."
        exit 1
    fi
    
    # Create logs directory
    mkdir -p logs
    
    # Submit SLURM job
    JOB_ID=$(sbatch --parsable start_proxy_direct.slurm)
    echo -e "${GREEN}Job submitted successfully!${NC}"
    echo "Job ID: $JOB_ID"
    echo "Monitor with: squeue -j $JOB_ID"
    echo "View logs: tail -f logs/litellm-proxy_${JOB_ID}.out"
}

stop_proxy() {
    echo -e "${YELLOW}Stopping LiteLLM Proxy...${NC}"
    
    # Find running job
    JOB_IDS=$(squeue -u $USER -n litellm-proxy -h -o "%i" 2>/dev/null)
    
    if [ -z "$JOB_IDS" ]; then
        JOB_IDS=$(squeue -u $USER -n litellm-proxy-direct -h -o "%i" 2>/dev/null)
    fi
    
    if [ -z "$JOB_IDS" ]; then
        echo -e "${YELLOW}No running LiteLLM proxy jobs found.${NC}"
        return
    fi
    
    # Cancel all found jobs
    for JOB_ID in $JOB_IDS; do
        echo "Cancelling job $JOB_ID..."
        scancel $JOB_ID
    done
    
    echo -e "${GREEN}Proxy server stopped.${NC}"
}

show_status() {
    echo -e "${GREEN}Checking LiteLLM Proxy status...${NC}"
    echo ""
    
    # Check for running jobs
    echo "=== SLURM Jobs ==="
    squeue -u $USER -n litellm-proxy,litellm-proxy-direct -o "%.18i %.20j %.8u %.10T %.10M %.6D %R" 2>/dev/null || echo "No jobs found."
    echo ""
    
    # Check Docker containers if available
    if command -v docker &> /dev/null; then
        echo "=== Docker Containers ==="
        docker ps --filter "name=litellm" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not available or no containers running."
    fi
    
    echo ""
}

show_logs() {
    echo -e "${GREEN}Showing recent logs...${NC}"
    
    # Find the most recent log file
    LATEST_LOG=$(ls -t logs/litellm-proxy_*.out 2>/dev/null | head -n1)
    
    if [ -z "$LATEST_LOG" ]; then
        echo -e "${RED}No log files found in logs/ directory.${NC}"
        exit 1
    fi
    
    echo "Latest log: $LATEST_LOG"
    echo "Press Ctrl+C to exit log viewing"
    echo "----------------------------------------"
    tail -f "$LATEST_LOG"
}

restart_proxy() {
    echo -e "${YELLOW}Restarting LiteLLM Proxy...${NC}"
    stop_proxy
    sleep 3
    start_proxy
}

# Main command handler
case "${1:-}" in
    start)
        start_proxy
        ;;
    start-direct)
        start_direct
        ;;
    stop)
        stop_proxy
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    restart)
        restart_proxy
        ;;
    *)
        show_help
        exit 1
        ;;
esac
