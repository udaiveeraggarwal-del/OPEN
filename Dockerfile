FROM node:24-slim

# Install system utilities and curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install openclaw globally
RUN npm install -g openclaw@2026.9.7

# Copy files
COPY . .

# Grant execute permissions to start script
RUN chmod +x start.sh

# Expose default port
EXPOSE 18789

# Start OpenClaw
CMD ["sh", "start.sh"]
