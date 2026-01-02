#!/bin/bash
# Script to run Redis cache tests

set -e

echo "=========================================="
echo "Running Redis Cache Tests"
echo "=========================================="

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "pytest not found. Installing test dependencies..."
    pip install -r requirements-test.txt
fi

# Load environment variables if .env exists
if [ -f ".env" ]; then
    echo "Loading environment variables from .env..."
    set -a
    source .env
    set +a
fi

# Set defaults if not set
export REDIS_HOST=${REDIS_HOST:-localhost}
export REDIS_PORT=${REDIS_PORT:-6379}

echo "Redis Configuration:"
echo "  Host: $REDIS_HOST"
echo "  Port: $REDIS_PORT"
echo ""

# Run tests
pytest tests/ -v "$@"

echo ""
echo "=========================================="
echo "Tests completed"
echo "=========================================="

