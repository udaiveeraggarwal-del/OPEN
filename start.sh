#!/bin/sh
set -e

: "${OPENCLAW_GATEWAY_TOKEN:?Set OPENCLAW_GATEWAY_TOKEN in Railway Variables before startup}"

mkdir -p /root/.openclaw
mkdir -p /root/.openclaw/workspace

# Configure Git inside the container
git config --global user.name "${GIT_USER_NAME:-Udaiveer Aggarwal}"
git config --global user.email "${GIT_USER_EMAIL:-udaiveer@openclaw.cloud}"
git config --global init.defaultBranch main

# If a Git repository URL is provided for the workspace, initialize or clone it
cd /root/.openclaw/workspace
if [ -n "$WORKSPACE_REPO_URL" ]; then
  if [ ! -d ".git" ]; then
    echo "Cloning workspace repository from $WORKSPACE_REPO_URL..."
    git clone "$WORKSPACE_REPO_URL" . || git init
  fi
elif [ ! -d ".git" ]; then
  echo "Initializing local Git repository for workspace tracking..."
  git init
fi

# Generate openclaw.json with environment variables
cat <<EOF > /root/.openclaw/openclaw.json
{
  "env": {
    "vars": {
      "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}",
      "GITHUB_TOKEN": "${GITHUB_TOKEN}"
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
    "entries": {
      "memory-core": {"enabled": true},
      "openrouter": {"enabled": true},
      "telegram": {"enabled": true}
    }
  },
  "tools": {"swarm": true},
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "auth": {
      "mode": "token",
      "token": "${OPENCLAW_GATEWAY_TOKEN}"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "open",
      "allowFrom": ["*"],
      "groupPolicy": "open",
      "groupAllowFrom": ["*"]
    }
  }
}
EOF

PORT="${PORT:-18789}"
echo "Starting OpenClaw Gateway on port $PORT (bind: lan)..."
exec openclaw gateway --port "$PORT" --bind lan --allow-unconfigured
