FROM node:24-slim

# Install system utilities: git, curl, ca-certificates, jq, python3
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install openclaw globally
RUN npm install -g openclaw@2026.9.7

# Copy project files
COPY . .

# Normalize line endings and grant execute permissions to start script
RUN sed -i 's/\r$//' start.sh && chmod +x start.sh

# Expose port (default 18789, or overridden by cloud environment $PORT)
EXPOSE 18789

# Run startup script
CMD ["sh", "start.sh"]
