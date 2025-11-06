# LiteLLM Proxy - Quick Reference Guide

Fast lookup for common commands and operations.

## 🚀 Essential Commands

### Docker Compose

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f litellm-1

# Restart services
docker-compose restart

# Check service status
docker-compose ps

# Recreate services (after config changes)
docker-compose up -d --force-recreate
```

### SLURM (HPC Clusters)

```bash
# Start the proxy with Docker
./manage_proxy.sh start

# Start without Docker (direct installation)
./manage_proxy.sh start-direct

# Stop the proxy
./manage_proxy.sh stop

# Check status
./manage_proxy.sh status

# View logs
./manage_proxy.sh logs

# Restart
./manage_proxy.sh restart
```

### SLURM Manual Operations

```bash
# Submit job with Docker
sbatch start_proxy.slurm

# Submit job without Docker
sbatch start_proxy_direct.slurm

# Check your jobs
squeue -u $USER

# Cancel job
scancel <JOB_ID>

# View logs
tail -f logs/litellm-proxy_<JOB_ID>.out
tail -f logs/litellm-proxy_<JOB_ID>.err
```

### SLURM Access & Testing

```bash
# Get node hostname
NODE=$(squeue -j <JOB_ID> -h -o "%N")

# Health check
curl http://$NODE:4000/health

# Test API
curl -X POST "http://$NODE:4000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"Hi"}]}'

# Port forwarding (if node not accessible)
ssh -L 4000:$NODE:4000 username@cluster-login
# Then access at http://localhost:4000
```

---

## 💬 Making API Requests

### Python (OpenAI SDK)

```python
import openai

client = openai.OpenAI(
    api_key="not-needed",
    base_url="http://localhost/v1"
)

# Chat completion
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

---

## 🎯 Testing Core Features

### Test Retry Mechanism

```bash
# Check logs for retry attempts
docker-compose logs litellm-1 | grep -i retry

# The proxy automatically retries on failures
```

### Test Caching

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

### Test Load Balancing

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

## 🔍 Health Checks

```bash
# Basic health check
curl http://localhost/health

# Direct to instances
curl http://localhost:4000/health  # litellm-1
curl http://localhost:4001/health  # litellm-2
```

---

## 🚨 Troubleshooting

### Check Logs

```bash
# All logs
docker-compose logs

# Specific service
docker-compose logs litellm-1
docker-compose logs redis
docker-compose logs nginx

# Follow logs
docker-compose logs -f litellm-1

# Last 100 lines
docker-compose logs --tail=100 litellm-1
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

# Flush cache (careful!)
docker-compose exec redis redis-cli -a your_password FLUSHALL
```

### Load Balancer Issues

```bash
# Check Nginx status
docker-compose ps nginx

# Check Nginx logs
docker-compose logs nginx

# Test direct connections
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

# Recreate services (if config changed)
docker-compose up -d --force-recreate

# Full reset (WARNING: removes volumes and data!)
docker-compose down -v
docker-compose up -d
```

---

## 🔧 Configuration Updates

### After Editing config.yaml

```bash
# Restart LiteLLM instances to apply changes
docker-compose restart litellm-1 litellm-2

# View logs to check for errors
docker-compose logs -f litellm-1
```

### Add Model via Config

Edit `config.yaml`:

```yaml
model_list:
  - model_name: new-model
    litellm_params:
      model: provider/model-name
      api_key: os.environ/YOUR_API_KEY
      timeout: 120
      max_retries: 2
```

Then restart:

```bash
docker-compose restart litellm-1 litellm-2
```

---

## 📊 Available Models

Current configuration:

| Model | Provider | Type |
|-------|----------|------|
| `Qwen3-0.6B` | Local (SGLang) | Chat |
| `gpt-4o` | OpenAI | Chat |
| `claude-3-5-sonnet` | Anthropic | Chat |
| `gemini-2.0-flash` | Google | Chat |
| `text-embedding-3-small` | OpenAI | Embedding |

List all models:

```bash
curl http://localhost/v1/models
```

---

## 🔄 Key Configuration Settings

### Retry Settings (config.yaml)

```yaml
router_settings:
  num_retries: 3
  retry_after: 5
  allowed_fails: 3
  cooldown_time: 30
  
  retry_policy:
    TimeoutErrorRetries: 3
    RateLimitErrorRetries: 3
    InternalServerErrorRetries: 2
```

### Cache Settings (config.yaml)

```yaml
litellm_settings:
  cache: true

cache_params:
  type: redis
  host: os.environ/REDIS_HOST
  port: os.environ/REDIS_PORT
  ttl: 36000  # 10 hours
```

### Load Balancing (config.yaml)

```yaml
router_settings:
  routing_strategy: simple-shuffle
  
  fallbacks:
    - gpt-4o:
        - claude-3-5-sonnet
    - claude-3-5-sonnet:
        - gemini-2.0-flash
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `config.yaml` | Model definitions, retry policies, caching, routing |
| `docker-compose.yml` | Docker services definition |
| `nginx.conf` | Load balancer configuration |
| `.env` | API keys and environment variables |
| `manage_proxy.sh` | SLURM management script |
| `start_proxy.slurm` | SLURM job script (with Docker) |
| `start_proxy_direct.slurm` | SLURM job script (without Docker) |

---

## 🆘 Quick Reference: Common Issues

| Issue | Solution |
|-------|----------|
| Services won't start | Check `.env` file exists and has correct values |
| Redis connection failed | Verify `REDIS_PASSWORD` in `.env` matches config |
| Cache not working | Check Redis is running: `docker-compose ps redis` |
| Load balancer not distributing | Check both litellm instances are healthy |
| Config changes not applied | Restart services: `docker-compose restart litellm-1 litellm-2` |
| SLURM job not running | Check: `squeue -u $USER` and logs in `logs/` directory |

---

## 📚 Additional Resources

- [Full Documentation](./README.md)
- [LiteLLM Docs](https://docs.litellm.ai/)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)

---

**Quick Tip**: Bookmark this page for fast reference during deployment and troubleshooting!
