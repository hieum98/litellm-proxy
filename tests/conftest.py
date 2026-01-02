"""
Pytest configuration and shared fixtures for Redis cache tests.
"""

import os
import pytest


def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "redis: mark test as requiring Redis connection"
    )


@pytest.fixture(scope="session")
def redis_config():
    """Provide Redis configuration from environment or defaults."""
    return {
        "host": os.getenv("REDIS_HOST", "localhost"),
        "port": int(os.getenv("REDIS_PORT", "6379")),
        "password": os.getenv("REDIS_PASSWORD", None),
    }

