#!/bin/bash

# =============================================================================
# 🔧 Fix Installation Issues
# =============================================================================

echo "🔧 แก้ไขปัญหาการติดตั้ง"
echo "======================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Docker compose command wrapper
docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    elif docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        log_error "ไม่พบ docker-compose หรือ docker compose"
        return 1
    fi
}

echo -e "\n1️⃣ ตรวจสอบ Docker Compose..."

# Check docker compose
if command -v docker-compose >/dev/null 2>&1; then
    log "✅ docker-compose พร้อมใช้งาน"
    docker-compose --version
elif docker compose version >/dev/null 2>&1; then
    log "✅ docker compose พร้อมใช้งาน"
    docker compose version
else
    log_warn "⚠️ ไม่พบ Docker Compose - กำลังติดตั้ง..."
    
    # Install docker-compose
    if command -v apt-get >/dev/null 2>&1; then
        # Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
    elif command -v yum >/dev/null 2>&1; then
        # RHEL/CentOS
        sudo yum install -y docker-compose-plugin
    else
        # Manual install
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Test again
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        log "✅ Docker Compose ติดตั้งสำเร็จ"
    else
        log_error "❌ ไม่สามารถติดตั้ง Docker Compose ได้"
    fi
fi

echo -e "\n2️⃣ สร้าง Management Scripts ใหม่..."

# Create start script with docker compose detection
cat > start-argocd.sh <<'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Docker compose wrapper
docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    elif docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        log_error "ไม่พบ docker-compose หรือ docker compose"
        return 1
    fi
}

echo "🚀 Starting ArgoCD Full Stack..."

# Start Kubernetes cluster (kind)
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_warn "Kubernetes cluster ไม่ทำงาน กำลังเริ่มต้น..."
    if command -v kind >/dev/null 2>&1; then
        kind create cluster --name argocd-cluster 2>/dev/null || echo "Cluster อาจมีอยู่แล้ว"
    fi
fi

# Wait for cluster to be ready
log "รอ cluster พร้อม..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Start port forwarding
log "Starting port forwarding..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 2
kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
echo $! > .kubectl-proxy.pid

# Start nginx proxy
log "Starting Nginx proxy..."
if [[ -f docker-compose-proxy.yml ]]; then
    docker_compose -f docker-compose-proxy.yml up -d
elif [[ -f docker-compose-simple.yml ]]; then
    docker_compose -f docker-compose-simple.yml up -d
else
    log_warn "ไม่พบไฟล์ docker-compose - ใช้ port forwarding เท่านั้น"
fi

log "✅ ArgoCD เริ่มต้นสำเร็จ!"
echo ""
echo "🌐 Access URLs:"
echo "   http://localhost (Nginx proxy)"
echo "   http://localhost:8080 (Port forward)"
echo ""
echo "👤 Username: admin"
echo "🔑 Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo 'ใช้คำสั่ง: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d')"
EOF

# Create stop script
cat > stop-argocd.sh <<'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Docker compose wrapper
docker_compose() {
    if command -v docker-compose >/dev/null 2>&1; then
        docker-compose "$@"
    elif docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    else
        return 1
    fi
}

echo "🛑 Stopping ArgoCD Full Stack..."

# Stop nginx proxy
log "Stopping Nginx proxy..."
docker_compose -f docker-compose-proxy.yml down 2>/dev/null || true
docker_compose -f docker-compose-simple.yml down 2>/dev/null || true

# Stop port forwarding
log "Stopping port forwarding..."
if [[ -f .kubectl-proxy.pid ]]; then
    kill $(cat .kubectl-proxy.pid) 2>/dev/null || true
    rm -f .kubectl-proxy.pid
fi
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true

log "✅ ArgoCD หยุดแล้ว"
EOF

# Create status script
cat > status-argocd.sh <<'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 ArgoCD Full Stack Status${NC}"
echo "=========================="

# Kubernetes cluster
echo -e "\n🔧 Kubernetes Cluster:"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Running${NC} ($(kubectl config current-context))"
    echo "  📦 Nodes: $(kubectl get nodes --no-headers | wc -l)"
    echo "  📊 Resources:"
    kubectl top nodes 2>/dev/null | head -2 || echo "     (metrics ไม่พร้อม)"
else
    echo -e "  ${RED}❌ Not Running${NC}"
fi

# ArgoCD
echo -e "\n🔱 ArgoCD:"
if kubectl get namespace argocd >/dev/null 2>&1; then
    ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l || echo 0)
    total_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo 0)
    if [[ $ready_pods -gt 0 ]]; then
        echo -e "  ${GREEN}✅ Running${NC} ($ready_pods/$total_pods pods)"
        
        # Show services
        echo "  🌐 Services:"
        kubectl get svc -n argocd --no-headers | while read line; do
            echo "     $line"
        done
    else
        echo -e "  ${RED}❌ Not Running${NC}"
    fi
else
    echo -e "  ${RED}❌ Not Installed${NC}"
fi

# Port forwarding
echo -e "\n🔗 Port Forwarding:"
if [[ -f .kubectl-proxy.pid ]] && kill -0 $(cat .kubectl-proxy.pid) 2>/dev/null; then
    echo -e "  ${GREEN}✅ Running${NC} (PID: $(cat .kubectl-proxy.pid))"
elif pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
    echo -e "  ${GREEN}✅ Running${NC} (active process)"
else
    echo -e "  ${RED}❌ Not Running${NC}"
fi

# Nginx proxy
echo -e "\n🌐 Nginx Proxy:"
if docker ps --format "table {{.Names}}" | grep -q nginx; then
    echo -e "  ${GREEN}✅ Running${NC}"
    
    # Test connectivity
    if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ Health check: OK${NC}"
    elif curl -s http://localhost >/dev/null 2>&1; then
        echo -e "  ${YELLOW}⚠️  Health check: Partial${NC}"
    else
        echo -e "  ${RED}❌ Health check: Failed${NC}"
    fi
else
    echo -e "  ${RED}❌ Not Running${NC}"
fi

# Access information
echo -e "\n🌐 Access Information:"
echo "   http://localhost (Nginx proxy)"
echo "   http://localhost:8080 (Direct port forward)"
echo ""
echo "👤 Login: admin"
echo "🔑 Password command:"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"

EOF

# Create get password script
cat > get-password.sh <<'EOF'
#!/bin/bash

echo "🔑 ArgoCD Admin Password:"
echo "========================"

if kubectl get namespace argocd >/dev/null 2>&1; then
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    if [[ -n "$password" ]]; then
        echo ""
        echo "Password: $password"
        echo ""
        echo "Login Info:"
        echo "  URL: http://localhost"
        echo "  Username: admin"
        echo "  Password: $password"
    else
        echo "❌ ไม่สามารถดึง password ได้"
        echo ""
        echo "ลองคำสั่งเหล่านี้:"
        echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
        echo "หรือ"
        echo "kubectl -n argocd get secrets"
    fi
else
    echo "❌ ArgoCD ยังไม่ได้ติดตั้ง"
fi
EOF

# Make all scripts executable
chmod +x start-argocd.sh stop-argocd.sh status-argocd.sh get-password.sh

log "✅ สร้าง management scripts สำเร็จ"

echo -e "\n3️⃣ ตรวจสอบไฟล์ที่จำเป็น..."

# Check for docker-compose files
if [[ ! -f docker-compose-proxy.yml ]] && [[ ! -f docker-compose-simple.yml ]]; then
    log_warn "ไม่พบไฟล์ docker-compose - สร้างไฟล์ง่ายๆ"
    
    cat > docker-compose-simple.yml <<'EOF'
version: '3.8'

services:
  nginx-argocd-proxy:
    image: nginx:alpine
    container_name: nginx-argocd-proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx-simple:/etc/nginx/conf.d:ro
    restart: unless-stopped
    depends_on:
      - argocd-proxy-check
    networks:
      - default

  argocd-proxy-check:
    image: busybox
    command: ['sh', '-c', 'echo "ArgoCD proxy helper started"']

networks:
  default:
    driver: bridge
EOF

    # Create nginx config
    mkdir -p nginx-simple
    cat > nginx-simple/default.conf <<'EOF'
upstream argocd-server {
    server host.docker.internal:8080;
}

server {
    listen 80;
    server_name localhost;

    # ArgoCD UI
    location / {
        proxy_pass http://argocd-server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /nginx-status {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    log "✅ สร้างไฟล์ docker-compose และ nginx config แล้ว"
fi

echo -e "\n4️⃣ ทดสอบระบบ..."

# Test Docker
if docker info >/dev/null 2>&1; then
    log "✅ Docker ทำงานปกติ"
else
    log_error "❌ Docker ไม่ทำงาน"
    echo "   แก้ไข: sudo systemctl start docker"
fi

# Test kubectl
if kubectl version --client >/dev/null 2>&1; then
    log "✅ kubectl พร้อมใช้งาน"
else
    log_error "❌ kubectl ไม่พร้อม"
fi

# Test kind
if command -v kind >/dev/null 2>&1; then
    log "✅ kind พร้อมใช้งาน"
    
    # List clusters
    clusters=$(kind get clusters 2>/dev/null)
    if [[ -n "$clusters" ]]; then
        log "Clusters: $clusters"
    else
        log_warn "ไม่พบ kind clusters"
    fi
else
    log_error "❌ kind ไม่ได้ติดตั้ง"
fi

echo -e "\n✅ การแก้ไขเสร็จสิ้น!"
echo ""
echo "📋 คำสั่งที่ใช้ได้:"
echo "   ./start-argocd.sh    - เริ่มระบบ"
echo "   ./stop-argocd.sh     - หยุดระบบ"
echo "   ./status-argocd.sh   - ตรวจสอบสถานะ"
echo "   ./get-password.sh    - ดูรหัสผ่าน"
echo ""
echo "🎯 ลองรัน: ./start-argocd.sh"
