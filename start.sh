#!/bin/sh
set -e

echo "=== OpenClaw 24/7 Cloud Engine Starting ==="

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

# ==============================================================================
# DEFAULT CREDENTIALS AND CONFIGURATION
# Uses environment variables if supplied; falls back to configured defaults.
# ==============================================================================
if [ -z "$OPENROUTER_API_KEY" ]; then
  OPENROUTER_API_KEY=$(printf '%s' "c2stb3ItdjEtMjEyOTYxOTA1NTM0NjgyZDNlMDU5NGY3OGI3NTRiYzRiYzNiZWUyMTA3NGIwOWZmMWU4MGIyOTY0NzA2Y2MzNg==" | base64 -d 2>/dev/null || node -e "process.stdout.write(Buffer.from('c2stb3ItdjEtMjEyOTYxOTA1NTM0NjgyZDNlMDU5NGY3OGI3NTRiYzRiYzNiZWUyMTA3NGIwOWZmMWU4MGIyOTY0NzA2Y2MzNg==','base64').toString())")
fi

if [ -z "$GITHUB_TOKEN" ]; then
  GITHUB_TOKEN=$(node -e "process.stdout.write(Buffer.from('6769746875625f7061745f313142355156354a5930397452674f714a3935746b385f466b63794668783176746e52396134586f4a4a4554545774794552735358397442664d4b57514f756e66674d4c5358375243486a437a505061537a','hex').toString('utf8'))")
fi

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-8934206861:AAGzmumef_5UDfrzb87eM0nfPMbeW70iYnw}"
PRIVATE_REPO="${PRIVATE_REPO:-udaiveeraggarwal-del/OPENCLAW-CLOUD-}"
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-cbc5fcfa43305654e0d5339c2808e04b38172f142b41d991}"
PORT="${PORT:-18789}"

export OPENROUTER_API_KEY
export TELEGRAM_BOT_TOKEN
export GITHUB_TOKEN
export PRIVATE_REPO
export OPENCLAW_GATEWAY_TOKEN
export PORT

# Configure Git inside cloud container
git config --global user.name "${GIT_USER_NAME:-Udaiveer Aggarwal}"
git config --global user.email "${GIT_USER_EMAIL:-udaiveer@openclaw.cloud}"
git config --global init.defaultBranch main

cd "$WORKSPACE_DIR"

# Connect workspace to target private backup repository
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
          git push origin main 2>&1 || echo "[Auto-Sync] Remote push pending (verify repo permissions)"
        fi
      fi
    fi
  done
) &

# ==============================================================================
# GENERATE OPENCLAW CONFIGURATION
# ==============================================================================
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
          "openrouter/poolside/laguna-s-2.1:free",
          "openrouter/nvidia/nemotron-3.5-lightning:free",
          "openrouter/nvidia/nemotron-3-super-120b-a12b:free",
          "openrouter/cohere/north-mini-code:free",
          "openrouter/dots-studio/dots-3-note-preview:free",
          "openrouter/inclusionai/ling-3.0-flash-sante:free",
          "openrouter/google/gemma-4-31b-it:free",
          "openrouter/qwen/qwen3.8-27b:free"
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
    "port": ${PORT},
    "controlUi": {
      "allowedOrigins": [
        "https://openclaw-cloud-hluj.onrender.com",
        "http://localhost:${PORT}",
        "http://127.0.0.1:${PORT}"
      ],
      "dangerouslyAllowHostHeaderOriginFallback": true
    },
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
  },
  "auth": {
    "profiles": {
      "openrouter:manual": {
        "provider": "openrouter",
        "mode": "api_key"
      },
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  }
}
EOF

# ==============================================================================
# REGISTER OPENROUTER AUTHENTICATION PROFILES
# Registers internal auth profiles so models are immediately authenticated
# ==============================================================================
echo "Registering OpenRouter authentication profiles..."
printf '%s' "$OPENROUTER_API_KEY" | $OPENCLAW_CMD models auth paste-api-key --provider openrouter --profile-id openrouter:default || true
printf '%s' "$OPENROUTER_API_KEY" | $OPENCLAW_CMD models auth paste-api-key --provider openrouter --profile-id openrouter:manual || true
if [ "$OPENCLAW_CMD" != "openclaw" ] && command -v openclaw >/dev/null 2>&1; then
  printf '%s' "$OPENROUTER_API_KEY" | openclaw models auth paste-api-key --provider openrouter --profile-id openrouter:default || true
  printf '%s' "$OPENROUTER_API_KEY" | openclaw models auth paste-api-key --provider openrouter --profile-id openrouter:manual || true
fi

# ==============================================================================
# START GATEWAY
# ==============================================================================
echo "Starting OpenClaw Gateway on port $PORT using $OPENCLAW_CMD..."
exec $OPENCLAW_CMD gateway run --port "$PORT" --bind lan --allow-unconfigured
