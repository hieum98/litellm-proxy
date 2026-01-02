# Redis Inspection Guide for LiteLLM Proxy

This guide shows you how to inspect what Redis is storing for the LiteLLM proxy cache.

## Quick Start

### Using the Inspection Scripts

1. **Bash script** (quick overview):
   ```bash
   ./inspect_redis.sh
   ```

2. **Python script** (detailed inspection):
   ```bash
   python inspect_redis.py              # Overview
   python inspect_redis.py <key_name>   # Inspect specific key
   ```

## Manual Redis CLI Commands

### Connect to Redis

Based on your configuration, Redis is running on:
- **Host**: `localhost` (or value from `REDIS_HOST` env var)
- **Port**: `6379` (or value from `REDIS_PORT` env var)
- **Namespace**: `litellm` (all cache keys are prefixed with `litellm:`)

**Connect with password** (if `REDIS_PASSWORD` is set):
```bash
redis-cli -h localhost -p 6379 -a $REDIS_PASSWORD
```

**Connect without password**:
```bash
redis-cli -h localhost -p 6379
```

### Basic Inspection Commands

#### 1. List All Cache Keys
```bash
# List all keys with litellm namespace
redis-cli KEYS "litellm:*"

# Count keys
redis-cli --raw KEYS "litellm:*" | wc -l
```

#### 2. Inspect a Specific Key
```bash
# Get key type
redis-cli TYPE "litellm:completion:abc123"

# Get key value (for string type)
redis-cli GET "litellm:completion:abc123"

# Get key TTL (time to live)
redis-cli TTL "litellm:completion:abc123"

# Get memory usage (Redis 4.0+)
redis-cli MEMORY USAGE "litellm:completion:abc123"
```

#### 3. Get Key Information
```bash
# Check if key exists
redis-cli EXISTS "litellm:completion:abc123"

# Get all information about a key
redis-cli --raw OBJECT ENCODING "litellm:completion:abc123"
redis-cli --raw OBJECT IDLETIME "litellm:completion:abc123"
```

### Statistics and Monitoring

#### Memory Usage
```bash
# Overall memory statistics
redis-cli INFO memory

# Key memory usage
redis-cli INFO memory | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human"
```

#### Cache Performance
```bash
# Cache hit/miss statistics
redis-cli INFO stats | grep -E "keyspace_hits|keyspace_misses"

# Calculate hit rate
redis-cli INFO stats | grep keyspace_hits
redis-cli INFO stats | grep keyspace_misses
```

#### Database Size
```bash
# Total number of keys
redis-cli DBSIZE

# Number of keys with litellm namespace
redis-cli --raw KEYS "litellm:*" | wc -l
```

### Real-time Monitoring

#### Monitor All Commands
```bash
# Watch all Redis commands in real-time
redis-cli MONITOR
```

#### Monitor Specific Patterns
```bash
# Watch for specific key patterns (using redis-cli with --scan)
redis-cli --scan --pattern "litellm:*"
```

### Understanding LiteLLM Cache Keys

LiteLLM stores cache entries with the following structure:
- **Namespace**: `litellm:` (configured in `config.yaml`)
- **Key format**: `litellm:<type>:<hash>`
  - `completion`: Chat completion responses
  - `embedding`: Embedding vectors
  - `acompletion`: Async completion responses
  - `aembedding`: Async embedding responses

#### Example Keys
```
litellm:completion:abc123def456...
litellm:embedding:xyz789uvw012...
```

### Viewing Cached Data

#### View Completion Cache
```bash
# Get a completion cache entry
redis-cli GET "litellm:completion:<hash>"

# Pretty print JSON (if jq is available)
redis-cli GET "litellm:completion:<hash>" | jq .
```

#### View Embedding Cache
```bash
# Get an embedding cache entry
redis-cli GET "litellm:embedding:<hash>"

# Note: Embeddings are typically stored as JSON arrays
```

### Cache Management

#### Check TTL (Time To Live)
```bash
# Check remaining time for a key
redis-cli TTL "litellm:completion:abc123"

# Returns:
# -1 = No expiration
# -2 = Key doesn't exist
# >0 = Seconds until expiration
```

#### Clear Cache

**⚠️ WARNING: These commands will delete data!**

```bash
# Clear ALL Redis data (including non-LiteLLM keys)
redis-cli FLUSHALL

# Clear only LiteLLM cache (safer)
redis-cli --scan --pattern "litellm:*" | xargs redis-cli DEL

# Or using eval (more efficient for large datasets)
redis-cli EVAL "local keys = redis.call('keys', 'litellm:*'); for i=1,#keys do redis.call('del', keys[i]) end; return #keys" 0
```

#### Delete Specific Key
```bash
redis-cli DEL "litellm:completion:abc123"
```

### Advanced Inspection

#### Scan Keys (More Efficient for Large Datasets)
```bash
# Scan keys in batches (better for production)
redis-cli --scan --pattern "litellm:*" | head -20

# Count keys using scan
redis-cli --scan --pattern "litellm:*" | wc -l
```

#### Get All Information About Redis
```bash
# Full Redis information
redis-cli INFO

# Specific sections
redis-cli INFO server
redis-cli INFO clients
redis-cli INFO memory
redis-cli INFO stats
redis-cli INFO keyspace
```

### Troubleshooting

#### Connection Issues
```bash
# Test connection
redis-cli PING
# Should return: PONG

# Check if Redis is running
ps aux | grep redis-server
netstat -tlnp | grep 6379
```

#### Check Redis Configuration
```bash
# View current configuration
redis-cli CONFIG GET "*"

# Check specific settings
redis-cli CONFIG GET maxmemory
redis-cli CONFIG GET maxmemory-policy
```

#### Check Redis Logs
```bash
# If Redis was started with logfile (check your startup script)
tail -f ~/redis/redis.log
```

## Using the Provided Scripts

### `inspect_redis.sh`
A bash script that provides a quick overview:
- Tests Redis connection
- Lists all cache keys
- Shows key statistics
- Displays memory usage
- Shows cache performance metrics
- Provides sample key inspection

**Usage:**
```bash
./inspect_redis.sh
```

### `inspect_redis.py`
A Python script for detailed inspection:
- Detailed key information
- JSON parsing and pretty printing
- Memory statistics
- Cache hit rate calculation
- Interactive key inspection

**Usage:**
```bash
# Overview
python inspect_redis.py

# Inspect specific key
python inspect_redis.py completion:abc123
python inspect_redis.py embedding:xyz789
```

## Environment Variables

The scripts automatically load from `.env` file or use these defaults:
- `REDIS_HOST`: localhost
- `REDIS_PORT`: 6379
- `REDIS_PASSWORD`: (optional)
- `REDIS_NAMESPACE`: litellm

## Cache Configuration

Your cache is configured in `config.yaml`:
```yaml
cache_params:
  type: redis
  host: os.environ/REDIS_HOST
  port: os.environ/REDIS_PORT
  ttl: 36000  # 10 hours
  namespace: "litellm"
```

This means:
- Cache entries expire after 10 hours (36000 seconds)
- All keys are prefixed with `litellm:`
- Cache supports: completion, acompletion, embedding, aembedding

## Tips

1. **Use SCAN instead of KEYS** for production environments (KEYS blocks Redis)
2. **Monitor memory usage** regularly to prevent OOM errors
3. **Check cache hit rates** to optimize TTL settings
4. **Use the Python script** for detailed JSON inspection
5. **Set up monitoring** for cache performance metrics

## Example Workflow

```bash
# 1. Quick check
./inspect_redis.sh

# 2. Get a specific key to inspect
redis-cli KEYS "litellm:completion:*" | head -1

# 3. Inspect that key in detail
python inspect_redis.py <key_from_step_2>

# 4. Monitor real-time activity
redis-cli MONITOR
```

