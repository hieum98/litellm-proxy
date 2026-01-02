#!/bin/bash
# ================================================
# Redis Inspection Script for LiteLLM Proxy
# ================================================

# Load environment variables if .env exists
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Set defaults
REDIS_HOST=${REDIS_HOST:-localhost}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_NAMESPACE=${REDIS_NAMESPACE:-litellm}

# Build redis-cli command
REDIS_CMD="redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT}"
if [ ! -z "$REDIS_PASSWORD" ]; then
    REDIS_CMD="${REDIS_CMD} -a ${REDIS_PASSWORD}"
fi

echo "=========================================="
echo "Redis Inspection for LiteLLM Proxy"
echo "=========================================="
echo "Host: ${REDIS_HOST}"
echo "Port: ${REDIS_PORT}"
echo "Namespace: ${REDIS_NAMESPACE}"
echo "=========================================="
echo ""

# Test connection
echo "1. Testing Redis connection..."
if $REDIS_CMD PING > /dev/null 2>&1; then
    echo "   ✓ Redis is connected"
else
    echo "   ✗ Cannot connect to Redis"
    echo "   Make sure Redis is running and credentials are correct"
    exit 1
fi
echo ""

# Get all keys with litellm namespace
echo "2. Listing all cache keys (${REDIS_NAMESPACE}:*):"
KEYS=$($REDIS_CMD KEYS "${REDIS_NAMESPACE}:*" 2>/dev/null)
if [ -z "$KEYS" ]; then
    echo "   No keys found with namespace '${REDIS_NAMESPACE}'"
else
    KEY_COUNT=$(echo "$KEYS" | wc -l)
    echo "   Found $KEY_COUNT keys:"
    echo "$KEYS" | head -20
    if [ "$KEY_COUNT" -gt 20 ]; then
        echo "   ... and $((KEY_COUNT - 20)) more keys"
    fi
fi
echo ""

# Get key count
echo "3. Key statistics:"
TOTAL_KEYS=$($REDIS_CMD DBSIZE 2>/dev/null)
LITELLM_KEYS=$($REDIS_CMD --raw KEYS "${REDIS_NAMESPACE}:*" 2>/dev/null | wc -l)
echo "   Total keys in Redis: $TOTAL_KEYS"
echo "   Keys with '${REDIS_NAMESPACE}' namespace: $LITELLM_KEYS"
echo ""

# Memory usage
echo "4. Memory usage:"
$REDIS_CMD INFO memory 2>/dev/null | grep -E "used_memory_human|used_memory_peak_human|maxmemory_human" | sed 's/^/   /'
echo ""

# Cache statistics
echo "5. Cache statistics:"
$REDIS_CMD INFO stats 2>/dev/null | grep -E "keyspace_hits|keyspace_misses|total_commands_processed" | sed 's/^/   /'
echo ""

# Show sample key details
echo "6. Sample key inspection (first 3 keys):"
SAMPLE_KEYS=$($REDIS_CMD KEYS "${REDIS_NAMESPACE}:*" 2>/dev/null | head -3)
if [ ! -z "$SAMPLE_KEYS" ]; then
    for KEY in $SAMPLE_KEYS; do
        echo ""
        echo "   Key: $KEY"
        KEY_TYPE=$($REDIS_CMD TYPE "$KEY" 2>/dev/null)
        echo "   Type: $KEY_TYPE"
        TTL=$($REDIS_CMD TTL "$KEY" 2>/dev/null)
        if [ "$TTL" -eq -1 ]; then
            echo "   TTL: No expiration"
        elif [ "$TTL" -eq -2 ]; then
            echo "   TTL: Key does not exist"
        else
            echo "   TTL: ${TTL} seconds ($(($TTL / 3600)) hours remaining)"
        fi
        
        if [ "$KEY_TYPE" = "string" ]; then
            VALUE=$($REDIS_CMD GET "$KEY" 2>/dev/null)
            VALUE_LENGTH=${#VALUE}
            echo "   Value length: $VALUE_LENGTH bytes"
            echo "   Value preview: ${VALUE:0:200}..."
        elif [ "$KEY_TYPE" = "hash" ]; then
            FIELDS=$($REDIS_CMD HLEN "$KEY" 2>/dev/null)
            echo "   Hash fields: $FIELDS"
            echo "   Sample fields:"
            $REDIS_CMD HKEYS "$KEY" 2>/dev/null | head -5 | sed 's/^/     - /'
        elif [ "$KEY_TYPE" = "list" ]; then
            LENGTH=$($REDIS_CMD LLEN "$KEY" 2>/dev/null)
            echo "   List length: $LENGTH"
        elif [ "$KEY_TYPE" = "set" ]; then
            CARD=$($REDIS_CMD SCARD "$KEY" 2>/dev/null)
            echo "   Set cardinality: $CARD"
        fi
    done
else
    echo "   No keys to inspect"
fi
echo ""

echo "=========================================="
echo "Useful commands:"
echo "=========================================="
echo ""
echo "Connect to Redis CLI:"
if [ ! -z "$REDIS_PASSWORD" ]; then
    echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} -a \$REDIS_PASSWORD"
else
    echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT}"
fi
echo ""
echo "List all keys:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} KEYS '${REDIS_NAMESPACE}:*'"
echo ""
echo "Get a specific key:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} GET '<key_name>'"
echo ""
echo "Check key TTL:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} TTL '<key_name>'"
echo ""
echo "Get key type:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} TYPE '<key_name>'"
echo ""
echo "Monitor Redis commands in real-time:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} MONITOR"
echo ""
echo "Clear all cache (WARNING: deletes all data!):"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} FLUSHALL"
echo ""
echo "Clear only LiteLLM cache:"
echo "  redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} --scan --pattern '${REDIS_NAMESPACE}:*' | xargs redis-cli -h ${REDIS_HOST} -p ${REDIS_PORT} DEL"
echo ""

