# 🌐 OpenClaw Cloud — Universal 24/7 Deployment

Deploy your autonomous **OpenClaw** instance to any cloud provider with one click. Features browser Web Control UI, Telegram Bot integration, and continuous auto-save to a private GitHub repository.

---

## 🚀 1-Click Cloud Deployments

### 1. Deploy on Render
[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)
- Uses included `render.yaml` Blueprint.
- Native Docker container execution on port `18789`.

### 2. Deploy on Railway
[![Deploy on Railway](https://railway.com/button.svg)](https://railway.app/new)
- Connect this repository and Railway auto-detects `railway.json` and `Dockerfile`.
- Set Networking port to `18789` and generate a domain.

### 3. Deploy with Docker Compose (Any VPS / Server)
```bash
# Clone the repository
git clone https://github.com/udaiveeraggarwal-del/OPEN.git
cd OPEN

# Create your .env file
cp .env.example .env
# Edit .env with your keys

# Launch in background
docker compose up -d
```

### 4. Deploy on Fly.io
```bash
fly launch
fly secrets set OPENROUTER_API_KEY="..." TELEGRAM_BOT_TOKEN="..." GITHUB_TOKEN="..."
fly deploy
```

---

## 🔑 Required Environment Variables

Configure these variables in your cloud provider dashboard:

| Variable | Description | Example / Default |
| :--- | :--- | :--- |
| `OPENROUTER_API_KEY` | OpenRouter API Key for free LLMs | `sk-or-v1-...` |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot API Token | `8934206861:AAGzmumef...` |
| `GITHUB_TOKEN` | GitHub Fine-Grained Token (contents:write) | `github_pat_...` |
| `PRIVATE_REPO` | Target private repo to auto-sync files to | `udaiveeraggarwal-del/OPENCLAW-CLOUD-` |
| `OPENCLAW_GATEWAY_TOKEN`| Security token for the Browser UI | `cbc5fcfa43305654e0d5339c2808e04b38172f142b41d991` |
| `PORT` | Web port for OpenClaw Gateway | `18789` |

---

## 🔒 Automated Autonomous Git Backup Daemon
Once deployed, OpenClaw runs an autonomous background sync loop every 20 seconds:
- Any file created, modified, or written by OpenClaw or you in the workspace is automatically committed.
- Automatically pushes to `origin/main` of your private repository (`udaiveeraggarwal-del/OPENCLAW-CLOUD-`).
- Zero data loss across cloud restarts or redeployments.

---

## 🖥️ Accessing OpenClaw After Deployment
Once deployed, access OpenClaw via:
- **Web Browser**: `https://<YOUR-CLOUD-DOMAIN>/?token=<OPENCLAW_GATEWAY_TOKEN>`
- **Telegram Bot**: Open your configured Telegram bot in Telegram and start chatting.
