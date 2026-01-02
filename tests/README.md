# Redis Cache Tests

This directory contains tests for verifying Redis cache functionality in the LiteLLM proxy.

## Running Tests

### Prerequisites

1. Ensure Redis is running and accessible
2. Install test dependencies:
   ```bash
   pip install pytest redis
   ```

### Basic Test Execution

```bash
# Run all tests
pytest tests/

# Run with verbose output
pytest tests/ -v

# Run a specific test file
pytest tests/test_redis_cache.py

# Run a specific test
pytest tests/test_redis_cache.py::TestRedisCache::test_redis_connection
```

### Environment Variables

Tests use the following environment variables (with defaults):

- `REDIS_HOST` (default: `localhost`)
- `REDIS_PORT` (default: `6379`)
- `REDIS_PASSWORD` (default: `None`)

You can set these in your environment or create a `.env` file:

```bash
export REDIS_HOST=localhost
export REDIS_PORT=6379
export REDIS_PASSWORD=your_password
```

### Test Coverage

The test suite covers:

1. **Connection Tests**: Verify Redis connection is working
2. **Basic Operations**: Test SET/GET operations
3. **TTL Functionality**: Verify cache expiration works
4. **Namespace Isolation**: Test that `litellm` namespace works correctly
5. **Performance**: Verify cache operations are fast
6. **Configuration**: Check Redis server configuration
7. **Integration**: Test cache structure expected by LiteLLM
8. **Resilience**: Test connection stability

### Expected Results

All tests should pass if:
- Redis server is running and accessible
- Redis configuration matches the project settings
- Network connectivity is available

If Redis is not available, tests will be skipped automatically.

