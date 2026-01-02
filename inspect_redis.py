#!/usr/bin/env python3
"""
Redis Inspection Tool for LiteLLM Proxy
Provides detailed inspection of cached data in Redis
"""

import os
import sys
import json
import redis
from typing import Dict, Any, Optional
from datetime import datetime, timedelta

def load_env_file():
    """Load environment variables from .env file"""
    env_file = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_file):
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

def connect_redis() -> redis.Redis:
    """Connect to Redis using environment variables"""
    load_env_file()
    
    host = os.environ.get('REDIS_HOST', 'localhost')
    port = int(os.environ.get('REDIS_PORT', 6379))
    password = os.environ.get('REDIS_PASSWORD')
    namespace = os.environ.get('REDIS_NAMESPACE', 'litellm')
    
    try:
        r = redis.Redis(
            host=host,
            port=port,
            password=password if password else None,
            decode_responses=True,
            socket_connect_timeout=5
        )
        # Test connection
        r.ping()
        return r, namespace
    except redis.ConnectionError as e:
        print(f"Error: Cannot connect to Redis at {host}:{port}")
        print(f"Details: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error connecting to Redis: {e}")
        sys.exit(1)

def format_bytes(size: int) -> str:
    """Format bytes to human-readable format"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if size < 1024.0:
            return f"{size:.2f} {unit}"
        size /= 1024.0
    return f"{size:.2f} TB"

def format_ttl(ttl: int) -> str:
    """Format TTL to human-readable format"""
    if ttl == -1:
        return "No expiration"
    elif ttl == -2:
        return "Key does not exist"
    else:
        delta = timedelta(seconds=ttl)
        hours = delta.total_seconds() / 3600
        return f"{ttl} seconds ({hours:.2f} hours)"

def inspect_key(r: redis.Redis, key: str, namespace: str):
    """Inspect a specific key in detail"""
    full_key = f"{namespace}:{key}" if not key.startswith(namespace) else key
    
    if not r.exists(full_key):
        print(f"Key '{full_key}' does not exist")
        return
    
    key_type = r.type(full_key)
    ttl = r.ttl(full_key)
    
    print(f"\n{'='*60}")
    print(f"Key: {full_key}")
    print(f"Type: {key_type}")
    print(f"TTL: {format_ttl(ttl)}")
    
    if key_type == 'string':
        value = r.get(full_key)
        try:
            # Try to parse as JSON
            parsed = json.loads(value)
            print(f"Value (JSON):")
            print(json.dumps(parsed, indent=2))
        except:
            print(f"Value (raw, first 500 chars):")
            print(value[:500])
            if len(value) > 500:
                print(f"... ({len(value) - 500} more characters)")
        print(f"Size: {format_bytes(len(value.encode('utf-8')))}")
    
    elif key_type == 'hash':
        fields = r.hgetall(full_key)
        print(f"Hash fields ({len(fields)}):")
        for field, value in list(fields.items())[:10]:
            try:
                parsed = json.loads(value)
                print(f"  {field}: {json.dumps(parsed, indent=4)}")
            except:
                print(f"  {field}: {value[:200]}")
        if len(fields) > 10:
            print(f"  ... and {len(fields) - 10} more fields")
    
    elif key_type == 'list':
        length = r.llen(full_key)
        print(f"List length: {length}")
        items = r.lrange(full_key, 0, 4)
        print("First 5 items:")
        for i, item in enumerate(items):
            try:
                parsed = json.loads(item)
                print(f"  [{i}]: {json.dumps(parsed, indent=4)}")
            except:
                print(f"  [{i}]: {item[:200]}")
    
    elif key_type == 'set':
        members = r.smembers(full_key)
        print(f"Set members ({len(members)}):")
        for member in list(members)[:10]:
            print(f"  - {member}")
        if len(members) > 10:
            print(f"  ... and {len(members) - 10} more members")

def main():
    """Main inspection function"""
    r, namespace = connect_redis()
    
    print("="*60)
    print("Redis Inspection for LiteLLM Proxy")
    print("="*60)
    print(f"Host: {r.connection_pool.connection_kwargs['host']}")
    print(f"Port: {r.connection_pool.connection_kwargs['port']}")
    print(f"Namespace: {namespace}")
    print("="*60)
    print()
    
    # Get all keys with namespace
    pattern = f"{namespace}:*"
    keys = r.keys(pattern)
    
    print(f"Found {len(keys)} keys with namespace '{namespace}'")
    print()
    
    if len(keys) == 0:
        print("No cached data found.")
        return
    
    # Group keys by prefix
    key_groups: Dict[str, list] = {}
    for key in keys:
        # Remove namespace prefix
        key_without_ns = key.replace(f"{namespace}:", "", 1)
        # Get the first part (usually the type)
        parts = key_without_ns.split(":", 1)
        prefix = parts[0] if len(parts) > 0 else "unknown"
        if prefix not in key_groups:
            key_groups[prefix] = []
        key_groups[prefix].append(key)
    
    print("Keys by type:")
    for prefix, group_keys in sorted(key_groups.items()):
        print(f"  {prefix}: {len(group_keys)} keys")
    print()
    
    # Show sample keys
    print("Sample keys (first 10):")
    for i, key in enumerate(keys[:10], 1):
        key_type = r.type(key)
        ttl = r.ttl(key)
        size = r.memory_usage(key) if hasattr(r, 'memory_usage') else 0
        print(f"  {i}. {key}")
        print(f"     Type: {key_type}, TTL: {format_ttl(ttl)}")
        if size:
            print(f"     Size: {format_bytes(size)}")
    if len(keys) > 10:
        print(f"  ... and {len(keys) - 10} more keys")
    print()
    
    # Memory statistics
    info = r.info('memory')
    print("Memory Statistics:")
    print(f"  Used memory: {format_bytes(info.get('used_memory', 0))}")
    print(f"  Peak memory: {format_bytes(info.get('used_memory_peak', 0))}")
    if 'maxmemory' in info and info['maxmemory'] > 0:
        print(f"  Max memory: {format_bytes(info['maxmemory'])}")
        used_pct = (info.get('used_memory', 0) / info['maxmemory']) * 100
        print(f"  Usage: {used_pct:.2f}%")
    print()
    
    # Cache statistics
    stats = r.info('stats')
    hits = stats.get('keyspace_hits', 0)
    misses = stats.get('keyspace_misses', 0)
    total = hits + misses
    hit_rate = (hits / total * 100) if total > 0 else 0
    
    print("Cache Statistics:")
    print(f"  Cache hits: {hits:,}")
    print(f"  Cache misses: {misses:,}")
    print(f"  Hit rate: {hit_rate:.2f}%")
    print(f"  Total commands: {stats.get('total_commands_processed', 0):,}")
    print()
    
    # Interactive mode
    if len(sys.argv) > 1:
        key_to_inspect = sys.argv[1]
        inspect_key(r, key_to_inspect, namespace)
    else:
        print("="*60)
        print("Usage:")
        print(f"  {sys.argv[0]}                    # Show overview")
        print(f"  {sys.argv[0]} <key_name>         # Inspect specific key")
        print()
        print("Examples:")
        print(f"  {sys.argv[0]} completion:abc123   # Inspect a completion cache key")
        print(f"  {sys.argv[0]} embedding:xyz789  # Inspect an embedding cache key")
        print()
        print("To see all keys, use:")
        print(f"  redis-cli -h {r.connection_pool.connection_kwargs['host']} -p {r.connection_pool.connection_kwargs['port']} KEYS '{namespace}:*'")

if __name__ == '__main__':
    main()

