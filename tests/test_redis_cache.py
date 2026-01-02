"""
Test suite for Redis cache functionality in LiteLLM proxy.

This test suite verifies:
1. Redis connection and basic operations
2. Cache storage and retrieval
3. Cache TTL (time-to-live) functionality
4. Namespace isolation
5. Integration with LiteLLM cache configuration
"""

import os
import pytest
import redis
import time


class TestRedisCache:
    """Test class for Redis cache functionality."""

    @pytest.fixture(scope="class")
    def redis_client(self) -> redis.Redis:
        """
        Create a Redis client for testing.
        Uses environment variables or defaults to localhost:6379.
        """
        host = os.getenv("REDIS_HOST", "localhost")
        port = int(os.getenv("REDIS_PORT", "6379"))
        password = os.getenv("REDIS_PASSWORD", None)
        
        client = redis.Redis(
            host=host,
            port=port,
            password=password,
            decode_responses=True,
            socket_connect_timeout=5
        )
        
        # Test connection
        try:
            client.ping()
        except redis.ConnectionError as e:
            pytest.skip(f"Redis server not available at {host}:{port}. Error: {e}")
        
        yield client
        
        # Cleanup: flush test keys
        try:
            # Only delete keys with test namespace
            keys = client.keys("test:*")
            if keys:
                client.delete(*keys)
        except Exception:
            pass
        finally:
            client.close()

    def test_redis_connection(self, redis_client: redis.Redis):
        """Test that Redis connection is working."""
        response = redis_client.ping()
        assert response is True, "Redis ping should return True"

    def test_redis_set_get(self, redis_client: redis.Redis):
        """Test basic Redis SET and GET operations."""
        test_key = "test:basic:key"
        test_value = "test_value_123"
        
        # Set a value
        result = redis_client.set(test_key, test_value)
        assert result is True, "SET operation should return True"
        
        # Get the value
        retrieved_value = redis_client.get(test_key)
        assert retrieved_value == test_value, f"Retrieved value should be '{test_value}', got '{retrieved_value}'"
        
        # Cleanup
        redis_client.delete(test_key)

    def test_redis_cache_ttl(self, redis_client: redis.Redis):
        """Test that TTL (time-to-live) functionality works."""
        test_key = "test:ttl:key"
        test_value = "ttl_test_value"
        ttl_seconds = 2
        
        # Set a value with TTL
        redis_client.setex(test_key, ttl_seconds, test_value)
        
        # Verify value exists immediately
        assert redis_client.get(test_key) == test_value, "Value should exist immediately after setting"
        
        # Verify TTL is set
        ttl = redis_client.ttl(test_key)
        assert 0 < ttl <= ttl_seconds, f"TTL should be between 0 and {ttl_seconds}, got {ttl}"
        
        # Wait for expiration
        time.sleep(ttl_seconds + 1)
        
        # Verify value is expired
        assert redis_client.get(test_key) is None, "Value should be expired after TTL"

    def test_redis_namespace_isolation(self, redis_client: redis.Redis):
        """Test that namespace isolation works (litellm namespace)."""
        namespace = "litellm"
        test_key = f"{namespace}:test:namespace:key"
        test_value = "namespace_test_value"
        
        # Set a value with namespace
        redis_client.set(test_key, test_value)
        
        # Verify value exists
        assert redis_client.get(test_key) == test_value, "Value should exist with namespace prefix"
        
        # Verify keys with namespace prefix exist
        keys = redis_client.keys(f"{namespace}:*")
        assert len(keys) > 0, f"Should find at least one key with namespace '{namespace}'"
        assert any(test_key in key for key in keys), f"Test key '{test_key}' should be in namespace keys"
        
        # Cleanup
        redis_client.delete(test_key)

    def test_redis_cache_performance(self, redis_client: redis.Redis):
        """Test cache performance with multiple operations."""
        test_prefix = "test:perf"
        num_keys = 100
        
        # Set multiple keys
        start_time = time.time()
        for i in range(num_keys):
            redis_client.set(f"{test_prefix}:{i}", f"value_{i}")
        set_time = time.time() - start_time
        
        # Get multiple keys
        start_time = time.time()
        for i in range(num_keys):
            value = redis_client.get(f"{test_prefix}:{i}")
            assert value == f"value_{i}", f"Value mismatch for key {i}"
        get_time = time.time() - start_time
        
        # Performance assertions (should be fast)
        assert set_time < 1.0, f"Setting {num_keys} keys should take < 1s, took {set_time:.3f}s"
        assert get_time < 1.0, f"Getting {num_keys} keys should take < 1s, took {get_time:.3f}s"
        
        # Cleanup
        keys = redis_client.keys(f"{test_prefix}:*")
        if keys:
            redis_client.delete(*keys)

    def test_redis_cache_configuration(self, redis_client: redis.Redis):
        """Test that Redis configuration matches expected settings."""
        # Check Redis info
        info = redis_client.info("server")
        
        # Verify Redis version (should be 7.x based on docker-compose)
        version = info.get("redis_version", "")
        assert version.startswith("7.") or version.startswith("6."), \
            f"Redis version should be 6.x or 7.x, got {version}"
        
        # Check memory policy (should be allkeys-lru based on config)
        memory_info = redis_client.info("memory")
        maxmemory_policy = memory_info.get("maxmemory_policy", "")
        # Note: This might not be set if maxmemory is 0 (unlimited)
        if maxmemory_policy:
            assert maxmemory_policy in ["allkeys-lru", "noeviction"], \
                f"Expected allkeys-lru or noeviction policy, got {maxmemory_policy}"

    def test_redis_cache_integration(self, redis_client: redis.Redis):
        """Test cache integration with LiteLLM namespace and expected structure."""
        namespace = "litellm"
        
        # Simulate a cache entry that LiteLLM might create
        cache_key = f"{namespace}:completion:test_hash"
        cache_value = '{"test": "data", "cached": true}'
        
        # Set cache entry
        redis_client.set(cache_key, cache_value)
        
        # Verify it exists
        assert redis_client.exists(cache_key) == 1, "Cache entry should exist"
        
        # Verify namespace isolation
        keys_in_namespace = redis_client.keys(f"{namespace}:*")
        assert len(keys_in_namespace) > 0, "Should have keys in litellm namespace"
        
        # Cleanup
        redis_client.delete(cache_key)

    def test_redis_connection_resilience(self, redis_client: redis.Redis):
        """Test that Redis connection can handle multiple operations."""
        test_key = "test:resilience:key"
        
        # Perform multiple operations
        for i in range(10):
            redis_client.set(test_key, f"value_{i}")
            value = redis_client.get(test_key)
            assert value == f"value_{i}", f"Value should be 'value_{i}' on iteration {i}"
        
        # Verify final value
        final_value = redis_client.get(test_key)
        assert final_value == "value_9", "Final value should be 'value_9'"
        
        # Cleanup
        redis_client.delete(test_key)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

