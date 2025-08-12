#!/bin/bash

# =============================================================================
# 🔧 Fix 502 Bad Gateway - ArgoCD Nginx Proxy
# =============================================================================

echo "🔧 แก้ไข 502 Bad Gateway - ArgoCD Nginx Proxy"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

echo "📊 ตรวจสอบสถานะปัจจุบัน..."

# 1. Check Kubernetes cluster
echo -e "\n1️⃣ Kubernetes Cluster:"
if kubectl cluster-info >/dev/null 2>&1; then
    log "✅ Kubernetes cluster ทำงาน"
    echo "   Context: $(kubectl config current-context)"
else
    log_error "❌ Kubernetes cluster ไม่ทำงาน"
    echo "   แก้ไข: ต้องเริ่ม cluster ก่อน"
    exit 1
fi

# 2. Check ArgoCD namespace and pods
echo -e "\n2️⃣ ArgoCD Status:"
if kubectl get namespace argocd >/dev/null 2>&1; then
    log "✅ ArgoCD namespace มีอยู่"
    
    # Check pods
    echo "   📦 ArgoCD Pods:"
    kubectl get pods -n argocd --no-headers | while read line; do
        echo "      $line"
    done
    
    # Check if argocd-server is ready
    ready_pods=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers 2>/dev/null | grep Running | wc -l || echo 0)
    if [[ $ready_pods -gt 0 ]]; then
        log "✅ ArgoCD server pods running: $ready_pods"
    else
        log_error "❌ ArgoCD server pods ไม่ ready"
        echo "   กำลังรอ pods ready..."
        kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    fi
    
else
    log_error "❌ ArgoCD ยังไม่ได้ติดตั้ง"
    echo "   แก้ไข: รัน ./install-full-stack.sh"
    exit 1
fi

# 3. Check ArgoCD service
echo -e "\n3️⃣ ArgoCD Service:"
argocd_svc=$(kubectl get svc argocd-server -n argocd --no-headers 2>/dev/null)
if [[ -n "$argocd_svc" ]]; then
    log "✅ ArgoCD service มีอยู่"
    echo "   $argocd_svc"
    
    # Get service port
    svc_port=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].port}' 2>/dev/null || echo "443")
    log "Service port: $svc_port"
else
    log_error "❌ ArgoCD service ไม่พบ"
    exit 1
fi

# 4. Check port forwarding
echo -e "\n4️⃣ Port Forwarding:"
if pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
    log "✅ Port forwarding ทำงานอยู่"
    
    # Test local connection
    echo "   🧪 ทดสอบการเชื่อมต่อ local:"
    if curl -k -s https://localhost:8080 >/dev/null 2>&1; then
        log "✅ https://localhost:8080 เชื่อมต่อได้"
    elif curl -s http://localhost:8080 >/dev/null 2>&1; then
        log "✅ http://localhost:8080 เชื่อมต่อได้"
    else
        log_warn "⚠️ localhost:8080 เชื่อมต่อไม่ได้"
        
        # Restart port forwarding
        log "🔄 รีสตาร์ท port forwarding..."
        pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
        sleep 2
        kubectl port-forward svc/argocd-server -n argocd 8080:$svc_port >/dev/null 2>&1 &
        echo $! > .kubectl-proxy.pid
        
        # Wait and test again
        sleep 5
        if curl -k -s https://localhost:8080 >/dev/null 2>&1; then
            log "✅ Port forwarding รีสตาร์ทสำเร็จ"
        else
            log_error "❌ Port forwarding ยังไม่ทำงาน"
        fi
    fi
else
    log_warn "⚠️ Port forwarding ไม่ทำงาน - กำลังเริ่มใหม่..."
    kubectl port-forward svc/argocd-server -n argocd 8080:$svc_port >/dev/null 2>&1 &
    echo $! > .kubectl-proxy.pid
    sleep 5
    
    if pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
        log "✅ Port forwarding เริ่มแล้ว"
    else
        log_error "❌ ไม่สามารถเริ่ม port forwarding ได้"
    fi
fi

# 5. Check nginx container
echo -e "\n5️⃣ Nginx Proxy:"
nginx_container=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep nginx | head -1)
if [[ -n "$nginx_container" ]]; then
    log "✅ Nginx container ทำงาน"
    echo "   $nginx_container"
else
    log_error "❌ Nginx container ไม่ทำงาน"
    echo "   แก้ไข: รัน ./start-argocd.sh"
    exit 1
fi

# 6. Check nginx configuration
echo -e "\n6️⃣ Nginx Configuration:"
nginx_config_paths=("nginx-simple/default.conf" "nginx/default.conf" "nginx-proxy/default.conf")
config_found=false

for config_path in "${nginx_config_paths[@]}"; do
    if [[ -f "$config_path" ]]; then
        log "✅ พบ nginx config: $config_path"
        config_found=true
        
        # Check upstream configuration
        echo "   🔍 ตรวจสอบ upstream config:"
        if grep -q "host.docker.internal:8080" "$config_path"; then
            log "✅ Upstream: host.docker.internal:8080"
        elif grep -q "localhost:8080" "$config_path"; then
            log "⚠️ Upstream: localhost:8080 (อาจไม่ทำงานใน container)"
        elif grep -q "127.0.0.1:8080" "$config_path"; then
            log "⚠️ Upstream: 127.0.0.1:8080 (อาจไม่ทำงานใน container)"
        else
            log_warn "❓ Upstream config ไม่ชัดเจน"
        fi
        
        # Show relevant lines
        echo "   📄 Upstream config lines:"
        grep -n "upstream\|server.*8080\|proxy_pass" "$config_path" | head -5 | sed 's/^/      /'
        break
    fi
done

if [[ "$config_found" == "false" ]]; then
    log_error "❌ ไม่พบ nginx config file"
    echo "   แก้ไข: สร้าง nginx config ใหม่"
fi

# 7. Test backend connectivity from nginx container
echo -e "\n7️⃣ ทดสอบการเชื่อมต่อจาก Nginx Container:"

# Get nginx container name
nginx_container_name=$(docker ps --format "{{.Names}}" | grep nginx | head -1)

if [[ -n "$nginx_container_name" ]]; then
    log "ทดสอบจาก container: $nginx_container_name"
    
    # Test different upstream targets
    echo "   🧪 ทดสอบการเชื่อมต่อ:"
    
    # Test host.docker.internal
    if docker exec "$nginx_container_name" wget -q --spider --timeout=5 http://host.docker.internal:8080 2>/dev/null; then
        log "✅ host.docker.internal:8080 เชื่อมต่อได้"
    else
        log_warn "❌ host.docker.internal:8080 เชื่อมต่อไม่ได้"
    fi
    
    # Test gateway IP
    gateway_ip=$(docker network inspect bridge --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "172.17.0.1")
    if docker exec "$nginx_container_name" wget -q --spider --timeout=5 "http://$gateway_ip:8080" 2>/dev/null; then
        log "✅ $gateway_ip:8080 เชื่อมต่อได้"
    else
        log_warn "❌ $gateway_ip:8080 เชื่อมต่อไม่ได้"
    fi
else
    log_error "❌ ไม่พบ nginx container"
fi

# 8. Automatic fix suggestions
echo -e "\n8️⃣ การแก้ไขอัตโนมัติ:"

read -p "ต้องการให้แก้ไขอัตโนมัติหรือไม่? (y/N): " fix_choice

if [[ "$fix_choice" =~ ^[Yy]$ ]]; then
    log "🔧 กำลังแก้ไข..."
    
    # Fix 1: Ensure port forwarding is running
    log "1. รีสตาร์ท port forwarding..."
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
    sleep 2
    kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
    echo $! > .kubectl-proxy.pid
    
    # Fix 2: Update nginx config for Docker compatibility
    log "2. อัปเดต nginx config..."
    
    # Create correct nginx config
    mkdir -p nginx-simple
    cat > nginx-simple/default.conf <<'EOF'
upstream argocd-server {
    server host.docker.internal:8080;
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
        
        # ArgoCD specific headers
        proxy_set_header Accept-Encoding "";
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
    }
}
EOF
    
    # Fix 3: Restart nginx container
    log "3. รีสตาร์ท nginx container..."
    
    # Find and restart docker compose
    if [[ -f docker-compose-simple.yml ]]; then
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f docker-compose-simple.yml down
            docker-compose -f docker-compose-simple.yml up -d
        elif docker compose version >/dev/null 2>&1; then
            docker compose -f docker-compose-simple.yml down
            docker compose -f docker-compose-simple.yml up -d
        fi
    elif [[ -f docker-compose-proxy.yml ]]; then
        if command -v docker-compose >/dev/null 2>&1; then
            docker-compose -f docker-compose-proxy.yml down
            docker-compose -f docker-compose-proxy.yml up -d
        elif docker compose version >/dev/null 2>&1; then
            docker compose -f docker-compose-proxy.yml down
            docker compose -f docker-compose-proxy.yml up -d
        fi
    fi
    
    # Wait for services to start
    log "4. รอ services พร้อม..."
    sleep 10
    
    # Test the fix
    log "5. ทดสอบการแก้ไข..."
    
    if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
        log "✅ Nginx health check ผ่าน"
        
        if curl -s http://localhost/ | grep -q "ArgoCD\|loading\|<!DOCTYPE html>"; then
            log "✅ ArgoCD UI ตอบสนอง"
            echo ""
            echo "🎉 แก้ไขสำเร็จ!"
            echo "🌐 เข้าใช้ได้ที่: http://localhost"
            echo "👤 Username: admin"
            echo "🔑 Password: รัน ./get-password.sh"
        else
            log_warn "⚠️ ArgoCD UI ยังไม่พร้อม - อาจต้องรอสักครู่"
        fi
    else
        log_error "❌ ยังแก้ไขไม่สำเร็จ"
    fi
    
else
    echo ""
    echo "💡 คำแนะนำการแก้ไขด้วยตนเอง:"
    echo ""
    echo "1️⃣ รีสตาร์ท port forwarding:"
    echo "   pkill -f kubectl.*port-forward"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
    echo ""
    echo "2️⃣ ตรวจสอบ nginx config:"
    echo "   cat nginx-simple/default.conf"
    echo "   # ต้องมี: server host.docker.internal:8080;"
    echo ""
    echo "3️⃣ รีสตาร์ท nginx:"
    echo "   docker compose -f docker-compose-simple.yml restart"
    echo ""
    echo "4️⃣ ทดสอบ:"
    echo "   curl http://localhost/nginx-status"
    echo "   curl http://localhost/"
fi

echo -e "\n✅ การตรวจสอบเสร็จสิ้น!"
