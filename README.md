# LiteLLM Proxy Server

A production-ready LiteLLM proxy deployment with enterprise features for managing multiple LLM providers with retry mechanisms, caching, and load balancing.

## 🌟 Key Features

- **🔄 Intelligent Retry Mechanisms**: Automatic retries with error-specific policies and cooldown management
- **⚡ Redis Caching**: Shared cache across instances for performance and cost optimization  
- **⚖️ Load Balancing**: Multiple proxy instances behind Nginx with health checks
- **🎯 Model Fallbacks**: Automatic fallback to alternative models on failure
- **🔌 Multi-Provider Support**: OpenAI, Anthropic, Google, and local models
- **🖥️ HPC Ready**: SLURM integration for cluster deployments

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [Core Features](#core-features)
- [Configuration](#configuration)
- [API Usage](#api-usage)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose (for local deployment)
- Redis instance
- API keys for your LLM providers

### 1-Minute Setup

```bash
# 1. Clone or navigate to project directory
cd litellm-proxy

# 2. Create .env file with your API keys
cat > .env << 'EOF'
# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_secure_redis_password

# LLM Provider API Keys
OPENAI_API_KEY=sk-your-openai-key
OPENAI_API_KEY_BACKUP=sk-your-backup-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
GOOGLE_API_KEY=your-google-api-key
EOF

# 3. Start all services
docker-compose up -d

# 4. Test the proxy
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Health Check

```bash
# Check all services
curl http://localhost/health

# Expected response: {"status":"healthy"}
```

---

## 🖥️ Deployment Options

### Option 1: Docker Compose (Recommended)

Best for local development and small-scale deployments.

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f litellm-1

# Stop services
docker-compose down
```

**Services included:**

- Redis (caching layer)
- LiteLLM Proxy Instance 1 (port 4000)
- LiteLLM Proxy Instance 2 (port 4001)
- Nginx Load Balancer (port 80)

### Option 2: SLURM (HPC Clusters)

For deployment on high-performance computing clusters.

#### Using the Management Script

```bash
# Start the proxy with Docker
./manage_proxy.sh start

# Or start without Docker (direct installation)
./manage_proxy.sh start-direct

# Check status
./manage_proxy.sh status

# View logs
./manage_proxy.sh logs

# Stop the proxy
./manage_proxy.sh stop

# Restart the proxy
./manage_proxy.sh restart
```

#### Manual SLURM Job Submission

```bash
# Submit job with Docker Compose
sbatch start_proxy.slurm

# Submit job without Docker (direct Python)
sbatch start_proxy_direct.slurm

# Check job status
squeue -u $USER

# Cancel job
scancel <JOB_ID>

# View logs
tail -f logs/litellm-proxy_<JOB_ID>.out
```

#### Accessing the Proxy on HPC

```bash
# Find the compute node
NODE=$(squeue -j <JOB_ID> -h -o "%N")

# Test the proxy
curl http://$NODE:4000/health

# Port forwarding (if node not directly accessible)
ssh -L 4000:$NODE:4000 username@cluster-login
# Then access at http://localhost:4000
```

#### Customizing SLURM Resources

Edit `start_proxy.slurm` or `start_proxy_direct.slurm`:

```bash
#SBATCH --time=48:00:00          # Job time limit
#SBATCH --cpus-per-task=16       # Number of CPUs
#SBATCH --mem=256G               # Memory allocation
#SBATCH --partition=memorylong   # SLURM partition
```

---

## 🎯 Core Features

### 1. 🔄 Intelligent Retry Mechanisms

Automatic retry with configurable policies for different error types.

**Configuration** (`config.yaml`):

```yaml
router_settings:
  # Basic retry configuration
  num_retries: 3
  retry_after: 5          # Wait 5 seconds before retry
  
  # Deployment health management
  allowed_fails: 3        # Failures before cooldown
  cooldown_time: 30       # Cooldown period in seconds
  
  # Error-specific retry policies
  retry_policy:
    TimeoutErrorRetries: 3
    RateLimitErrorRetries: 3
    InternalServerErrorRetries: 2
    ServiceUnavailableErrorRetries: 2
    BadRequestErrorRetries: 0
    AuthenticationErrorRetries: 0
  
  # Error-specific cooldown policies
  allowed_fails_policy:
    RateLimitErrorAllowedFails: 100
    TimeoutErrorAllowedFails: 50
    InternalServerErrorAllowedFails: 50
```

**How it works:**

- Automatically retries failed requests based on error type
- Different retry counts for different error types
- Cooldown period after multiple failures to prevent cascading failures
- Error-specific allowed failures before triggering cooldown
- Prevents overwhelming failing providers

**Model-level retries:**

```yaml
model_list:
  - model_name: gpt-4o
    litellm_params:
      max_retries: 2      # Model-specific retry limit
```

### 2. ⚡ Redis Caching

Redis-based caching for improved performance and cost reduction.

**Configuration** (`config.yaml`):

```yaml
litellm_settings:
  cache: true

cache_params:
  type: redis
  host: os.environ/REDIS_HOST
  port: os.environ/REDIS_PORT
  ssl: false
  ttl: 36000              # Cache for 10 hours
  namespace: "litellm"
  supported_call_types:
    - completion
    - acompletion
    - embedding
    - aembedding
```

**How it works:**

- Caches responses for identical requests
- Reduces API calls and costs
- Shared cache across multiple proxy instances
- Configurable TTL (10 hours by default)
- Supports both sync and async operations

**Docker setup** (`docker-compose.yml`):

```yaml
services:
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass your_password --maxmemory 2gb --maxmemory-policy allkeys-lru
```

**Cache benefits:**

- **Performance**: Sub-millisecond response times for cached requests
- **Cost savings**: Reduces API calls to expensive LLM providers
- **Consistency**: Same input always returns same cached output within TTL

### 3. ⚖️ Load Balancing

Multiple LiteLLM proxy instances behind Nginx load balancer.

**Nginx Configuration** (`nginx.conf`):

```nginx
upstream litellm_backend {
    least_conn;  # Use least connections strategy
    server litellm-1:4000 max_fails=3 fail_timeout=30s;
    server litellm-2:4000 max_fails=3 fail_timeout=30s;
    keepalive 64;
}
```

**Router Configuration** (`config.yaml`):

```yaml
router_settings:
  # Routing strategy for load balancing
  routing_strategy: simple-shuffle
  
  # Model-level load balancing (multiple API keys)
  fallbacks:
    - gpt-4o:
        - claude-3-5-sonnet
    - claude-3-5-sonnet:
        - gemini-2.0-flash
  
  # Context window fallbacks
  context_window_fallbacks:
    - gemini-2.0-flash: gpt-4o
    - claude-3-5-sonnet: gpt-4o
```

**How it works:**

- Nginx distributes requests across multiple LiteLLM instances
- Least-connections algorithm for optimal distribution
- Automatic failover if an instance fails
- Model-level fallbacks for redundancy
- Shared Redis state for coordination
- Context window-based automatic model upgrades

**Routing strategies:**

- `simple-shuffle`: Random distribution (default)
- `least-busy`: Route to least busy instance
- `usage-based-routing`: Based on usage metrics
- `latency-based-routing`: Route to lowest latency provider

---

## 📦 Configuration

### config.yaml

Main configuration file with all features.

**Structure:**

```yaml
# 1. Model definitions
model_list:
  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY
      timeout: 120
      max_retries: 2

# 2. LiteLLM settings
litellm_settings:
  set_verbose: false
  json_logs: true
  request_timeout: 600
  drop_params: true
  cache: true

# 3. Router settings (retry + load balancing)
router_settings:
  routing_strategy: simple-shuffle
  num_retries: 3
  retry_after: 5
  timeout: 120
  allowed_fails: 3
  cooldown_time: 30
  enable_pre_call_check: true
  retry_policy: {...}
  fallbacks: {...}

# 4. Cache configuration
cache_params:
  type: redis
  host: os.environ/REDIS_HOST
  port: os.environ/REDIS_PORT
  ttl: 36000
```

### docker-compose.yml

Defines the service stack:

- **redis**: Caching layer with 2GB memory limit
- **litellm-1**: Primary proxy instance (port 4000)
- **litellm-2**: Secondary proxy instance (port 4001)
- **nginx**: Load balancer (port 80)

All services include health checks and auto-restart policies.

### .env

Environment variables (create this file):

```bash
# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_secure_redis_password

# LLM Provider API Keys
OPENAI_API_KEY=sk-your-openai-key
OPENAI_API_KEY_BACKUP=sk-your-backup-openai-key
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key
GOOGLE_API_KEY=your-google-api-key
```

### nginx.conf

Load balancer configuration with:

- Streaming support (HTTP/1.1 with chunked transfer)
- Health checks
- Timeout configurations for long-running requests
- Connection keepalive for performance

---

## 🚀 API Usage

### Python (OpenAI SDK)

```python
import openai

client = openai.OpenAI(
    api_key="not-needed",  # No authentication required
    base_url="http://localhost/v1"
)

# Basic chat completion
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "Hello!"}
    ]
)

print(response.choices[0].message.content)

# Streaming
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Tell me a story"}],
    stream=True
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")

# Embeddings
response = client.embeddings.create(
    model="text-embedding-3-small",
    input="Hello world"
)

print(response.data[0].embedding)
```

### cURL

```bash
# Basic request
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'

# Streaming request
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Tell me a story"}],
    "stream": true
  }'

# Embeddings
curl -X POST 'http://localhost/v1/embeddings' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "text-embedding-3-small",
    "input": "Hello world"
  }'
```

### LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="gpt-4o",
    openai_api_key="not-needed",
    openai_api_base="http://localhost/v1"
)

response = llm.invoke("Hello!")
print(response.content)
```

### Testing Features

**Test Retry Mechanism:**

The proxy automatically retries on failures. Check logs to see retry attempts:

```bash
docker-compose logs litellm-1 | grep -i retry
```

**Test Caching:**

Identical requests will be cached:

```bash
# First request - hits the API (slower)
time curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"What is 2+2?"}]}'

# Second identical request - served from cache (much faster!)
time curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"What is 2+2?"}]}'
```

**Test Load Balancing:**

Send multiple requests and check distribution:

```bash
# Send 100 requests
for i in {1..100}; do
  curl -X POST 'http://localhost/v1/chat/completions' \
    -H 'Content-Type: application/json' \
    -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hi '$i'"}]}' &
done
wait

# Check distribution between instances
docker-compose logs litellm-1 | grep -c "POST /v1/chat/completions"
docker-compose logs litellm-2 | grep -c "POST /v1/chat/completions"
```

---

## 📁 Project Structure

```text
litellm-proxy/
├── config.yaml              # Main configuration file
├── docker-compose.yml       # Docker services definition
├── nginx.conf              # Load balancer configuration
├── redis.conf              # Redis configuration
├── manage_proxy.sh         # SLURM management script
├── start_proxy.slurm       # SLURM job script (with Docker)
├── start_proxy_direct.slurm # SLURM job script (without Docker)
├── .env                    # Environment variables (create this)
├── .gitignore             # Git ignore patterns
├── README.md              # This file
├── quickref.md            # Quick reference guide
└── logs/                  # Log files directory
```

### Key Files

| File | Purpose |
|------|---------|
| `config.yaml` | Model definitions, retry policies, caching, routing |
| `docker-compose.yml` | Docker services (Redis, LiteLLM instances, Nginx) |
| `nginx.conf` | Load balancer with streaming support |
| `.env` | API keys and environment variables |
| `manage_proxy.sh` | Helper script for SLURM deployment |
| `start_proxy.slurm` | SLURM job script with Docker |
| `start_proxy_direct.slurm` | SLURM job script without Docker |

---

## 🔧 Troubleshooting

### Check Service Status

```bash
# All services
docker-compose ps

# Specific service logs
docker-compose logs litellm-1
docker-compose logs redis
docker-compose logs nginx

# Follow logs in real-time
docker-compose logs -f litellm-1
```

### Redis Issues

```bash
# Connect to Redis
docker-compose exec redis redis-cli -a your_password

# Check connection
docker-compose exec redis redis-cli -a your_password PING

# Check cache keys
docker-compose exec redis redis-cli -a your_password KEYS "*"

# Check memory usage
docker-compose exec redis redis-cli -a your_password INFO memory

# Check cache statistics
docker-compose exec redis redis-cli -a your_password INFO stats

# Clear cache (if needed)
docker-compose exec redis redis-cli -a your_password FLUSHALL
```

### Load Balancer Issues

```bash
# Check Nginx status
docker-compose ps nginx

# Check Nginx logs
docker-compose logs nginx

# Test direct connections (bypass load balancer)
curl http://localhost:4000/health  # litellm-1
curl http://localhost:4001/health  # litellm-2

# Test through load balancer
curl http://localhost/health

# Check upstream distribution
docker-compose logs nginx | grep upstream
```

### Performance Issues

```bash
# Check cache hit rate
docker-compose exec redis redis-cli -a your_password INFO stats | grep keyspace

# Monitor request distribution
docker-compose logs nginx | grep upstream

# Check for failed requests
docker-compose logs litellm-1 | grep -i error
docker-compose logs litellm-2 | grep -i error

# Check for retry attempts
docker-compose logs litellm-1 | grep -i retry
```

### Restart Services

```bash
# Restart specific service
docker-compose restart litellm-1

# Restart all services
docker-compose restart

# Recreate services (after config changes)
docker-compose up -d --force-recreate

# Full reset (removes volumes - WARNING: data loss!)
docker-compose down -v
docker-compose up -d
```

### Configuration Issues

After editing `config.yaml`:

```bash
# Restart LiteLLM instances to apply changes
docker-compose restart litellm-1 litellm-2

# View logs to check for errors
docker-compose logs -f litellm-1
```

### SLURM Issues

```bash
# Check job status
squeue -u $USER

# Check specific job
squeue -j <JOB_ID>

# View job details
scontrol show job <JOB_ID>

# Check node allocation
squeue -j <JOB_ID> -o "%N"

# Cancel stuck job
scancel <JOB_ID>

# View job logs
tail -f logs/litellm-proxy_<JOB_ID>.out
tail -f logs/litellm-proxy_<JOB_ID>.err
```

---

## 🏗️ Architecture

```text
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    Nginx    │ ◄── Load Balancing
                    │   (Port 80) │
                    └──────┬──────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼──────┐             ┌───────▼──────┐
     │  LiteLLM-1  │             │  LiteLLM-2   │
     │  (Port 4000)│             │  (Port 4001) │
     └──────┬──────┘             └───────┬──────┘
            │                             │
            └──────────────┬──────────────┘
                           │
                    ┌──────▼──────┐
                    │    Redis    │ ◄── Caching
                    │  (Port 6379)│
                    └─────────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼──────┐             ┌───────▼──────┐
     │   OpenAI    │             │  Anthropic   │
     │     API     │             │     API      │
     └─────────────┘             └──────────────┘
          (with retry)                (with retry)
```

**Request Flow:**

1. Client sends request to Nginx (port 80)
2. Nginx load balances to litellm-1 or litellm-2
3. LiteLLM checks Redis cache
4. If cache miss, sends to provider API with retry mechanism
5. Response cached in Redis and returned to client
6. On failure, automatic retry or fallback to alternative model

---

## 📊 Available Models

Current configuration includes:

| Model | Provider | Type | Features |
|-------|----------|------|----------|
| `Qwen3-0.6B` | Local (SGLang) | Chat | Local inference |
| `gpt-4o` | OpenAI | Chat | Primary + backup keys |
| `claude-3-5-sonnet` | Anthropic | Chat | Fallback model |
| `gemini-2.0-flash` | Google | Chat | Fallback model |
| `text-embedding-3-small` | OpenAI | Embedding | Vector embeddings |

All models include:

- Retry mechanisms
- Timeout configurations
- Fallback options

---

## 📚 Additional Resources

- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Quick Reference Guide](./quickref.md) - Fast lookup for common commands
- [Redis Caching Guide](https://docs.litellm.ai/docs/caching)
- [Load Balancing Guide](https://docs.litellm.ai/docs/routing)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)

---

## 🆘 Support

For issues and questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review logs: `docker-compose logs -f`
3. Consult [LiteLLM Docs](https://docs.litellm.ai/)
4. Open an issue on [GitHub](https://github.com/BerriAI/litellm/issues)

---

## 📝 License

This project configuration is based on [LiteLLM](https://github.com/BerriAI/litellm) which is licensed under MIT.

---

**Status**: ✅ Production Ready

Configured for enterprise deployment with retry mechanisms, caching, and load balancing.
