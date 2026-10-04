#!/bin/sh
set -e

mkdir -p /root/.openclaw

cat <<EOF > /root/.openclaw/openclaw.json
{
  "env": {
    "vars": {
      "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/root/.openclaw/workspace",
      "model": {
        "primary": "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free",
        "fallbacks": [
          "openrouter/poolside/laguna-s-2.1:free",
          "openrouter/nvidia/nemotron-3.5-lightning:free",
          "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
          "openrouter/cohere/north-mini-code:free"
        ]
      },
      "models": {
        "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free": {}
      },
      "thinkingDefault": "high"
    },
    "entries": {
      "main": {
        "name": "main",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/main/agent",
        "model": "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free"
      }
    }
  },
  "plugins": {
    
        "allow": ["openrouter", "telegram", "memory-core"],
        "entries": {
      "openrouter": {
        "enabled": true
      },
      "telegram": {
        "enabled": true
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN:-cbc5fcfa43305654e0d5339c2808e04b38172f142b41d991}"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "open",
      "allowFrom": [
        "*"
      ],
      "groupPolicy": "open",
      "groupAllowFrom": [
        "*"
      ]
    }
  }
}
EOF

PORT="${PORT:-18789}"
echo "Starting OpenClaw Gateway on port $PORT..."
exec openclaw gateway --port "$PORT"
