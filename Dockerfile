FROM node:24-slim

# Install system utilities: git, curl, ca-certificates, jq
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install openclaw globally
RUN npm install -g openclaw@2026.9.7

# Copy project files
COPY . .

# Grant execute permissions to start script
RUN chmod +x start.sh

# Expose port (default 18789, or overridden by Railway $PORT)
EXPOSE 18789

# Run startup script
CMD ["sh", "start.sh"]
