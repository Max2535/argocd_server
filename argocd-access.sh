#!/bin/bash

# =============================================================================
# 🚀 ArgoCD Access Manager - Easy Access Solution
# =============================================================================

echo "🚀 ArgoCD Access Manager"
echo "======================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if ArgoCD is installed
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    error "ArgoCD is not installed. Please install it first."
    exit 1
fi

# Check if ArgoCD server is running
if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null | grep -q Running; then
    error "ArgoCD server is not running. Please check your installation."
    exit 1
fi

# Check if we're on Linux
is_linux=false
if [[ "$(uname -s)" == "Linux" ]]; then
    is_linux=true
fi

# Detect platform
if [[ "$is_linux" == "true" ]]; then
    log "Detected Linux platform"
    platform="linux"
else
    log "Detected non-Linux platform (Windows/Mac)"
    platform="other"
fi

# Ask user which method they prefer
echo ""
echo "Please choose how you want to access ArgoCD:"
echo ""
echo "1) Direct HTTPS Access (Recommended for Linux)"
echo "   Advantages: More reliable, simpler setup"
echo "   Disadvantages: Uses non-standard port, requires accepting self-signed certificate"
echo ""
echo "2) Nginx Proxy (Standard HTTP Port 80)"
echo "   Advantages: Uses standard port 80, no certificate warnings"
echo "   Disadvantages: More complex, may have Docker networking issues on Linux"
echo ""
read -p "Enter your choice (1 or 2): " choice

# Process choice
case $choice in
    1)
        log "Setting up Direct HTTPS Access..."
        
        # Stop any existing port forwards
        pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
        sleep 2
        
        # Find a free port
        for port in 8081 8082 8083 8084 8085; do
            if ! netstat -tuln | grep -q ":$port\s"; then
                free_port=$port
                log "Found free port: $free_port"
                break
            fi
        done
        
        if [ -z "$free_port" ]; then
            warn "No free port found, using 8090"
            free_port=8090
        fi
        
        # Start port forwarding
        log "Starting port forwarding on port $free_port..."
        kubectl port-forward svc/argocd-server -n argocd $free_port:443 --address 0.0.0.0 > /dev/null 2>&1 &
        echo $! > .kubectl-direct-proxy.pid
        sleep 5
        
        # Test connection
        if curl -k -s https://localhost:$free_port >/dev/null 2>&1; then
            log "Connection successful!"
            echo ""
            echo "🎉 ArgoCD is now accessible!"
            echo "🌐 Access via: https://$(hostname -I | awk '{print $1}'):$free_port"
            echo "👤 Username: admin"
            echo "🔑 Password: $(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Run ./get-password.sh")"
            echo ""
            warn "Note: You'll need to accept the self-signed certificate in your browser"
            warn "Port forwarding is running in the background and will stop if you log out"
        else
            error "Connection failed"
        fi
        ;;
        
    2)
        log "Setting up Nginx Proxy..."
        
        # Setup port forwarding
        pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
        sleep 2
        kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
        echo $! > .kubectl-proxy.pid
        
        # Create nginx config
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

        # Create appropriate docker-compose file
        if [[ "$platform" == "linux" ]]; then
            log "Creating Linux-specific docker-compose file..."
            cat > docker-compose-nginx.yml <<'EOF'
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
        else
            log "Creating standard docker-compose file..."
            cat > docker-compose-nginx.yml <<'EOF'
version: '3'

services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd
    ports:
      - "80:80"
    volumes:
      - ./nginx-simple/default.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
        fi
        
        # Stop any existing nginx containers
        log "Stopping any existing nginx containers..."
        docker stop nginx-argocd >/dev/null 2>&1 || true
        docker rm nginx-argocd >/dev/null 2>&1 || true
        
        # Start nginx
        log "Starting nginx container..."
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f docker-compose-nginx.yml down >/dev/null 2>&1 || true
            docker-compose -f docker-compose-nginx.yml up -d
        elif docker compose version >/dev/null 2>&1; then
            docker compose -f docker-compose-nginx.yml down >/dev/null 2>&1 || true
            docker compose -f docker-compose-nginx.yml up -d
        else
            error "Docker Compose not found. Please install it and try again."
            exit 1
        fi
        
        # Wait for services to start
        log "Waiting for services to start..."
        sleep 5
        
        # Test connection
        if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
            log "Nginx health check passed"
            
            if curl -s http://localhost/ | grep -q "ArgoCD\|loading\|<!DOCTYPE html>"; then
                log "ArgoCD UI responding"
                echo ""
                echo "🎉 ArgoCD is now accessible!"
                echo "🌐 Access via: http://$(hostname -I | awk '{print $1}')"
                echo "👤 Username: admin"
                echo "🔑 Password: $(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Run ./get-password.sh")"
            else
                warn "ArgoCD UI not responding yet - may need a moment to initialize"
                echo "Try accessing http://$(hostname -I | awk '{print $1}') in a browser"
            fi
        else
            error "Nginx health check failed"
        fi
        ;;
        
    *)
        error "Invalid choice. Please run the script again and select 1 or 2."
        exit 1
        ;;
esac

echo ""
echo "✅ Setup complete!"
echo "📝 For troubleshooting, see argocd-access-guide.md"
