#!/bin/sh
set -e

echo "=== OpenClaw 24/7 Cloud Engine Starting ==="

# Gateway security token
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-cbc5fcfa43305654e0d5339c2808e04b38172f142b41d991}"

mkdir -p /root/.openclaw
mkdir -p /root/.openclaw/workspace

# Configure Git inside cloud container
git config --global user.name "${GIT_USER_NAME:-Udaiveer Aggarwal}"
git config --global user.email "${GIT_USER_EMAIL:-udaiveer@openclaw.cloud}"
git config --global init.defaultBranch main

cd /root/.openclaw/workspace

# Resolve Private GitHub Repo URL if GITHUB_TOKEN & PRIVATE_REPO are provided
TARGET_REPO_URL="$PRIVATE_REPO_URL"
if [ -z "$TARGET_REPO_URL" ] && [ -n "$GITHUB_TOKEN" ] && [ -n "$PRIVATE_REPO" ]; then
  # Format: https://TOKEN@github.com/USERNAME/REPONAME.git
  TARGET_REPO_URL="https://${GITHUB_TOKEN}@github.com/${PRIVATE_REPO}.git"
fi

if [ -n "$TARGET_REPO_URL" ]; then
  echo "Connecting workspace to private GitHub repository..."
  if [ ! -d ".git" ]; then
    git clone "$TARGET_REPO_URL" . || (git init && git remote add origin "$TARGET_REPO_URL")
  else
    git remote set-url origin "$TARGET_REPO_URL" || true
  fi
  git branch -M main || true
elif [ ! -d ".git" ]; then
  echo "Initializing local Git repository inside cloud container..."
  git init
  git branch -M main || true
fi

# ==============================================================================
# AUTONOMOUS BACKGROUND AUTO-SYNC DAEMON
# Runs continuously every 20 seconds. Any file created, modified, or deleted by
# OpenClaw is automatically committed and pushed to the private GitHub repo.
# ZERO manual commands required from the user!
# ==============================================================================
(
  echo "[Auto-Sync Daemon] Started monitoring /root/.openclaw/workspace..."
  while true; do
    sleep 20
    if [ -d "/root/.openclaw/workspace/.git" ]; then
      cd /root/.openclaw/workspace
      # Check if any changes exist
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "[Auto-Sync] Changes detected! Saving and pushing to GitHub..."
        git add -A
        git commit -m "Auto-save: $(date -u +'%Y-%m-%d %H:%M:%S UTC')" || true
        if git remote get-url origin >/dev/null 2>&1; then
          git push origin main 2>&1 || echo "[Auto-Sync] Remote push pending (verify repo permissions)"
        fi
      fi
    fi
  done
) &

# Generate OpenClaw Configuration
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
          "openrouter/nvidia/nemotron-3.5-lightning:free"
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
      "memory-core": { "enabled": true },
      "openrouter": { "enabled": true },
      "telegram": { "enabled": true }
    }
  },
  "tools": { "swarm": true },
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
echo "Starting OpenClaw Gateway on port $PORT (LAN bind for web browser)..."
exec openclaw gateway --port "$PORT" --bind lan --allow-unconfigured
