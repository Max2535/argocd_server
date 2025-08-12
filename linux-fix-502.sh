#!/bin/bash

# =============================================================================
# 🔧 Simple Linux Fix for 502 Bad Gateway - ArgoCD Nginx Proxy
# =============================================================================

echo "🔧 Fix 502 Bad Gateway - ArgoCD Nginx Proxy for Linux"
echo "==================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Ensure port forwarding is running
log "1. Configuring port forwarding..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 2
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 > /dev/null 2>&1 &
echo $! > .kubectl-proxy.pid

# 2. Create nginx config
log "2. Creating nginx config..."
mkdir -p nginx-simple
cat > nginx-simple/default.conf <<'EOF'
upstream argocd-server {
    server localhost:8080;
}

server {
    listen 80;
    server_name localhost;

    # Health check
    location /nginx-status {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # ArgoCD UI
    location / {
        proxy_pass http://argocd-server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for ArgoCD
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 3. Create docker-compose
log "3. Creating docker-compose..."
cat > docker-compose-linux.yml <<'EOF'
version: '3'

services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd
    network_mode: "host"  # Use host network for easy localhost access
    volumes:
      - ./nginx-simple/default.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
EOF

# 4. Restart nginx container
log "4. Restarting nginx container..."
docker stop nginx-argocd >/dev/null 2>&1 || true
docker rm nginx-argocd >/dev/null 2>&1 || true

# Start with the Linux config
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose-linux.yml down >/dev/null 2>&1 || true
    docker-compose -f docker-compose-linux.yml up -d
elif docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose-linux.yml down >/dev/null 2>&1 || true
    docker compose -f docker-compose-linux.yml up -d
else
    log_error "Docker Compose not found. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    docker-compose -f docker-compose-linux.yml up -d
fi

# 5. Wait for services to start
log "5. Waiting for services..."
sleep 5

# 6. Test the fix
log "6. Testing..."
if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
    log "✅ Nginx health check passed"
    
    if curl -s http://localhost/ | grep -q "ArgoCD\|loading\|<!DOCTYPE html>"; then
        log "✅ ArgoCD UI responding"
        echo ""
        echo "🎉 Fix successful!"
        echo "🌐 Access at: http://$(hostname -I | awk '{print $1}')"
        echo "👤 Username: admin"
        echo "🔑 Password: Run ./get-password.sh"
    else
        log_error "❌ ArgoCD UI not responding - may need a moment"
    fi
else
    log_error "❌ Nginx health check failed"
fi

echo -e "\n✅ Done!"
