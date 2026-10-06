#!/bin/sh
set -e

echo "=== OpenClaw 24/7 Cloud Engine Starting ==="

# Gateway security token
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-cbc5fcfa43305654e0d5339c2808e04b38172f142b41d991}"
PRIVATE_REPO="${PRIVATE_REPO:-udaiveeraggarwal-del/OPENCLAW-CLOUD-}"

# Determine user home directory safely for root or non-root environments
OPENCLAW_HOME="${HOME:-/root}"
OPENCLAW_DIR="${OPENCLAW_HOME}/.openclaw"
WORKSPACE_DIR="${OPENCLAW_DIR}/workspace"

mkdir -p "$OPENCLAW_DIR"
mkdir -p "$WORKSPACE_DIR"

# Ensure node_modules/.bin is on PATH
export PATH="./node_modules/.bin:$PATH"

# Resolve openclaw executable
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_CMD="openclaw"
elif [ -f "./node_modules/.bin/openclaw" ]; then
  OPENCLAW_CMD="./node_modules/.bin/openclaw"
else
  OPENCLAW_CMD="npx openclaw"
fi

# Configure Git inside cloud container
git config --global user.name "${GIT_USER_NAME:-Udaiveer Aggarwal}"
git config --global user.email "${GIT_USER_EMAIL:-udaiveer@openclaw.cloud}"
git config --global init.defaultBranch main

cd "$WORKSPACE_DIR"

TARGET_REPO_URL="$PRIVATE_REPO_URL"
if [ -z "$TARGET_REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
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
# ==============================================================================
(
  echo "[Auto-Sync Daemon] Started monitoring $WORKSPACE_DIR..."
  while true; do
    sleep 20
    if [ -d "$WORKSPACE_DIR/.git" ]; then
      cd "$WORKSPACE_DIR"
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo "[Auto-Sync] Changes detected! Saving and pushing to GitHub..."
        git add -A
        git commit -m "Auto-save: $(date -u +'%Y-%m-%d %H:%M:%S UTC')" || true
        if git remote get-url origin >/dev/null 2>&1; then
          git push origin main 2>&1 || echo "[Auto-Sync] Remote push pending"
        fi
      fi
    fi
  done
) &

# Generate OpenClaw Configuration
cat <<EOF > "$OPENCLAW_DIR/openclaw.json"
{
  "env": {
    "vars": {
      "OPENROUTER_API_KEY": "${OPENROUTER_API_KEY}",
      "GITHUB_TOKEN": "${GITHUB_TOKEN}"
    }
  },
  "agents": {
    "defaults": {
      "workspace": "${WORKSPACE_DIR}",
      "model": {
        "primary": "openrouter/nvidia/nemotron-3-ultra-550b-a55b:free",
        "fallbacks": [
          "openrouter/nvidia/nemotron-3.5-lightning:free",
          "openrouter/poolside/laguna-s-2.1:free",
          "openrouter/google/gemma-4-31b-it:free"
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
        "workspace": "${WORKSPACE_DIR}",
        "agentDir": "${OPENCLAW_DIR}/agents/main/agent",
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

# Register OpenRouter API key into OpenClaw internal auth profiles
if [ -n "$OPENROUTER_API_KEY" ]; then
  echo "Registering OpenRouter API key into OpenClaw auth profile..."
  printf '%s' "$OPENROUTER_API_KEY" | $OPENCLAW_CMD models auth paste-api-key --provider openrouter --profile-id openrouter:default 2>/dev/null || true
  printf '%s' "$OPENROUTER_API_KEY" | $OPENCLAW_CMD models auth paste-api-key --provider openrouter --profile-id openrouter:manual 2>/dev/null || true
fi

PORT="${PORT:-18789}"
echo "Starting OpenClaw Gateway on port $PORT using $OPENCLAW_CMD..."
exec $OPENCLAW_CMD gateway run --port "$PORT" --bind lan --allow-unconfigured
