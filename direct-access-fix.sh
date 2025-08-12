#!/bin/bash

# =============================================================================
# 🔧 Alternative Fix for 502 Bad Gateway - Direct Access
# =============================================================================

echo "🔧 Alternative Fix for 502 Bad Gateway - Direct Access"
echo "==================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Check if ArgoCD is running
log "1. Checking if ArgoCD is running..."
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    log_error "❌ ArgoCD is not installed"
    exit 1
fi

# 2. Stop any existing port forwarding
log "2. Stopping any existing port forwarding..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 3

# 3. Find a free port
log "3. Finding a free port..."
for port in 8081 8082 8083 8084 8085; do
    if ! netstat -tuln | grep -q ":$port\s"; then
        free_port=$port
        log "✅ Found free port: $free_port"
        break
    fi
done

if [ -z "$free_port" ]; then
    log_error "❌ No free port found"
    log_warn "⚠️ Will use port 8090 and hope for the best"
    free_port=8090
fi

# 4. Start port forwarding with the free port
log "4. Starting port forwarding on port $free_port..."
kubectl port-forward svc/argocd-server -n argocd $free_port:443 --address 0.0.0.0 > /dev/null 2>&1 &
echo $! > .kubectl-direct-proxy.pid
sleep 5

# 5. Test the connection
log "5. Testing the connection..."
if curl -k -s https://localhost:$free_port >/dev/null 2>&1; then
    log "✅ Connection successful"
    echo ""
    echo "🎉 Fix successful!"
    echo "🌐 Access ArgoCD directly at: https://$(hostname -I | awk '{print $1}'):$free_port"
    echo "👤 Username: admin"
    echo "🔑 Password: Run './get-password.sh'"
    echo ""
    log_warn "⚠️ Note: You'll need to accept the self-signed certificate in your browser"
    log_warn "⚠️ Port forwarding is running in the background - it will stop if you log out"
    echo "Run this to stop port forwarding: kill \$(cat .kubectl-direct-proxy.pid)"
else
    log_error "❌ Connection failed"
fi
