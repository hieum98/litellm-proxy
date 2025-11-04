# LiteLLM Proxy - Quick Reference Guide

## 🚀 Essential Commands

### Start/Stop Proxy

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f litellm-1

# Restart a service
docker-compose restart litellm-1

# Check service status
docker-compose ps
```

### Health Checks

```bash
# Basic health check
curl http://localhost/health

# Liveness check (for Kubernetes)
curl http://localhost/health/liveliness

# Readiness check
curl http://localhost/health/readiness

# Check specific service
curl -H "Authorization: Bearer sk-1234" \
  http://localhost/health/services?service=langfuse
```

---

## 🔑 API Key Management

### Create Keys

```bash
# Basic key
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{"models": ["gpt-4o"]}'

# Key with budget and limits
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gpt-4o", "claude-3-5-sonnet"],
    "max_budget": 100,
    "budget_duration": "30d",
    "tpm_limit": 100000,
    "rpm_limit": 1000,
    "duration": "90d",
    "metadata": {"team": "engineering"}
  }'

# Team-based key
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "team_id": "team-uuid-here",
    "models": ["gpt-4o"]
  }'
```

### Manage Keys

```bash
# Get key information
curl -X GET 'http://localhost/key/info?key=sk-your-key' \
  -H 'Authorization: Bearer sk-1234'

# Update key
curl -X POST 'http://localhost/key/update' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "key": "sk-your-key",
    "max_budget": 200
  }'

# Delete key
curl -X POST 'http://localhost/key/delete' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{"keys": ["sk-your-key"]}'

# Block/Unblock key
curl -X POST 'http://localhost/key/block' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{"key": "sk-your-key"}'

curl -X POST 'http://localhost/key/unblock' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{"key": "sk-your-key"}'
```

---

## 👥 User Management

```bash
# Create user
curl -X POST 'http://localhost/user/new' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "john@company.com",
    "user_email": "john@company.com",
    "max_budget": 50,
    "budget_duration": "30d",
    "user_role": "internal_user"
  }'

# Get user info
curl -X GET 'http://localhost/user/info?user_id=john@company.com' \
  -H 'Authorization: Bearer sk-1234'

# Update user
curl -X POST 'http://localhost/user/update' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "john@company.com",
    "max_budget": 100
  }'

# Delete user
curl -X POST 'http://localhost/user/delete' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{"user_ids": ["john@company.com"]}'
```

---

## 👫 Team Management

```bash
# Create team
curl -X POST 'http://localhost/team/new' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "team_alias": "engineering",
    "max_budget": 1000,
    "budget_duration": "30d",
    "tpm_limit": 1000000,
    "rpm_limit": 10000,
    "models": ["gpt-4o", "claude-3-5-sonnet"]
  }'

# Get team info
curl -X GET 'http://localhost/team/info?team_id=team-uuid' \
  -H 'Authorization: Bearer sk-1234'

# Add member to team
curl -X POST 'http://localhost/team/member_add' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "team_id": "team-uuid",
    "member": {
      "role": "user",
      "user_id": "john@company.com"
    },
    "max_budget_in_team": 50
  }'

# Update team
curl -X POST 'http://localhost/team/update' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "team_id": "team-uuid",
    "max_budget": 2000
  }'
```

---

## 💬 Making LLM Requests

### Python (OpenAI SDK)

```python
import openai

client = openai.OpenAI(
    api_key="sk-your-virtual-key",
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

# With metadata
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello!"}],
    extra_body={
        "metadata": {
            "user_id": "user-123",
            "session_id": "session-456"
        }
    }
)
```

### cURL

```bash
# Basic request
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Authorization: Bearer sk-your-key' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'

# With metadata
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Authorization: Bearer sk-your-key' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello!"}],
    "metadata": {
      "user_id": "user-123",
      "session_id": "session-456"
    }
  }'

# Streaming
curl -X POST 'http://localhost/v1/chat/completions' \
  -H 'Authorization: Bearer sk-your-key' \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Tell me a story"}],
    "stream": true
  }'
```

### LangChain

```python
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="gpt-4o",
    openai_api_key="sk-your-virtual-key",
    openai_api_base="http://localhost/v1"
)

response = llm.invoke("Hello!")
print(response.content)
```

---

## 📊 Monitoring & Analytics

### Check Spend

```bash
# Key spend
curl -X GET 'http://localhost/key/info?key=sk-your-key' \
  -H 'Authorization: Bearer sk-1234'

# User spend
curl -X GET 'http://localhost/user/info?user_id=john@company.com' \
  -H 'Authorization: Bearer sk-1234'

# Team spend
curl -X GET 'http://localhost/team/info?team_id=team-uuid' \
  -H 'Authorization: Bearer sk-1234'

# Global spend (last 30 days)
curl -X GET 'http://localhost/global/spend?start_date=2024-01-01&end_date=2024-01-31' \
  -H 'Authorization: Bearer sk-1234'
```

### View Metrics

```bash
# Prometheus metrics
curl http://localhost:4000/metrics

# Access Prometheus UI
open http://localhost:9090

# Access Grafana
open http://localhost:3000
```

### Cache Management

```bash
# Check cache health
curl -X GET 'http://localhost/cache/ping' \
  -H 'Authorization: Bearer sk-1234'

# Clear cache (if needed)
curl -X POST 'http://localhost/cache/clear' \
  -H 'Authorization: Bearer sk-1234'
```

---

## 🔧 Configuration Updates

### Add Model via API

```bash
curl -X POST 'http://localhost/model/new' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "model_name": "gpt-4-turbo",
    "litellm_params": {
      "model": "openai/gpt-4-turbo",
      "api_key": "os.environ/OPENAI_API_KEY"
    }
  }'
```

### List All Models

```bash
curl -X GET 'http://localhost/v1/models' \
  -H 'Authorization: Bearer sk-1234'
```

### Update Router Settings

```bash
# Restart needed after config.yaml changes
docker-compose restart litellm-1 litellm-2
```

---

## 🚨 Troubleshooting

### Check Logs

```bash
# All logs
docker-compose logs

# Specific service
docker-compose logs litellm-1
docker-compose logs postgres
docker-compose logs redis

# Follow logs
docker-compose logs -f litellm-1

# Last 100 lines
docker-compose logs --tail=100 litellm-1
```

### Database Issues

```bash
# Connect to database
docker-compose exec postgres psql -U litellm -d litellm

# Check tables
docker-compose exec postgres psql -U litellm -d litellm -c "\dt"

# Check connections
docker-compose exec postgres psql -U litellm -d litellm -c "SELECT * FROM pg_stat_activity;"
```

### Redis Issues

```bash
# Connect to Redis
docker-compose exec redis redis-cli -a your-redis-password

# Check keys
docker-compose exec redis redis-cli -a your-redis-password KEYS "*"

# Check memory
docker-compose exec redis redis-cli -a your-redis-password INFO memory

# Flush cache (careful!)
docker-compose exec redis redis-cli -a your-redis-password FLUSHALL
```

### Restart Services

```bash
# Restart specific service
docker-compose restart litellm-1

# Restart all services
docker-compose restart

# Recreate services (if config changed)
docker-compose up -d --force-recreate
```

---

## 📈 Budget Management

### Set Budgets

```bash
# Key budget
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gpt-4o"],
    "max_budget": 100,
    "budget_duration": "30d"
  }'

# User budget
curl -X POST 'http://localhost/user/new' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "john@company.com",
    "max_budget": 50,
    "budget_duration": "7d"
  }'

# Team budget
curl -X POST 'http://localhost/team/new' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "team_alias": "engineering",
    "max_budget": 1000,
    "budget_duration": "30d"
  }'
```

### Reset Budgets

Budgets auto-reset based on `budget_duration`. Manual reset:

```bash
curl -X POST 'http://localhost/user/update' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "john@company.com",
    "spend": 0
  }'
```

---

## 🎯 Rate Limiting

```bash
# Set rate limits on key
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "models": ["gpt-4o"],
    "tpm_limit": 100000,
    "rpm_limit": 1000,
    "max_parallel_requests": 10
  }'

# Model-specific rate limits
curl -X POST 'http://localhost/key/generate' \
  -H 'Authorization: Bearer sk-1234' \
  -H 'Content-Type: application/json' \
  -d '{
    "model_rpm_limit": {"gpt-4o": 100},
    "model_tpm_limit": {"gpt-4o": 50000}
  }'
```

---

## 🔐 Security Best Practices

1. **Change default passwords** in `.env`:
   ```bash
   LITELLM_MASTER_KEY=sk-your-very-secure-key
   UI_PASSWORD=strong-password-here
   POSTGRES_PASSWORD=postgres-strong-password
   REDIS_PASSWORD=redis-strong-password
   ```

2. **Use environment variables** for API keys (never hardcode)

3. **Enable HTTPS** in production (uncomment SSL section in nginx.conf)

4. **Set up IP whitelisting** if needed

5. **Regularly rotate** virtual keys

6. **Monitor** failed authentication attempts

7. **Use SSO** for Admin UI in production

8. **Backup database** regularly:
   ```bash
   docker-compose exec postgres pg_dump -U litellm litellm > backup.sql
   ```

---

## 📝 Quick Reference: Key Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/chat/completions` | POST | Chat completions |
| `/v1/completions` | POST | Text completions |
| `/v1/embeddings` | POST | Generate embeddings |
| `/v1/models` | GET | List available models |
| `/key/generate` | POST | Create virtual key |
| `/key/info` | GET | Get key information |
| `/key/update` | POST | Update key |
| `/key/delete` | POST | Delete key |
| `/user/new` | POST | Create user |
| `/user/info` | GET | Get user info |
| `/team/new` | POST | Create team |
| `/team/info` | GET | Get team info |
| `/health` | GET | Health check |
| `/health/liveliness` | GET | Liveness probe |
| `/health/readiness` | GET | Readiness probe |
| `/metrics` | GET | Prometheus metrics |
| `/ui` | GET | Admin UI |

---

## 🆘 Support & Resources

- **Documentation**: https://docs.litellm.ai/
- **GitHub**: https://github.com/BerriAI/litellm
- **Discord**: https://discord.com/invite/wuPM9dRgDw
- **Langfuse Docs**: https://langfuse.com/docs

---

**Quick Tip**: Save this guide as `QUICKREF.md` in your project directory for easy access!
