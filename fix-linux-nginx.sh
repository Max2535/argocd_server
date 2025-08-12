#!/bin/bash

# =============================================================================
# 🔧 แก้ไขปัญหา 502 Bad Gateway สำหรับ ArgoCD บน Linux
# =============================================================================

# สีสำหรับแสดงผล
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "🔧 แก้ไขปัญหา 502 Bad Gateway - ArgoCD บน Linux"
echo "=============================================="

# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    error "kubectl ไม่ได้ติดตั้ง กรุณาติดตั้งก่อนใช้งาน"
    exit 1
fi

# ตรวจสอบว่ามี docker หรือไม่
if ! command -v docker >/dev/null 2>&1; then
    error "docker ไม่ได้ติดตั้ง กรุณาติดตั้งก่อนใช้งาน"
    exit 1
fi

# ตรวจสอบว่า ArgoCD ทำงานอยู่หรือไม่
log "กำลังตรวจสอบสถานะ ArgoCD..."
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    error "ไม่พบ namespace argocd กรุณาติดตั้ง ArgoCD ก่อน"
    exit 1
fi

# ตรวจสอบ pod ของ ArgoCD Server
if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null | grep -q Running; then
    error "ArgoCD Server ไม่ได้ทำงาน กรุณาตรวจสอบสถานะ pod"
    echo "kubectl get pods -n argocd"
    exit 1
else
    log "✅ ArgoCD Server กำลังทำงาน"
fi

# 1. สร้างไดเรกทอรีสำหรับ nginx config
log "1. กำลังสร้างไดเรกทอรีสำหรับ nginx config..."
mkdir -p nginx-simple

# 2. สร้างไฟล์ config สำหรับ nginx
log "2. กำลังสร้างไฟล์ config สำหรับ nginx..."
cat > nginx-simple/nginx-linux.conf <<'EOF'
upstream argocd-server {
    # ใช้ localhost แทน host.docker.internal สำหรับ Linux
    server localhost:8080;
}

server {
    listen 80;
    server_name localhost;

    # Health check endpoint
    location /nginx-status {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # ArgoCD UI และ API endpoints
    location / {
        proxy_pass http://argocd-server;
        
        # Headers จำเป็นสำหรับ proxy
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # สนับสนุน WebSocket สำหรับ terminal และ real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # ตั้งค่า timeout ให้เหมาะกับการใช้งาน ArgoCD
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # เพิ่ม buffer sizes สำหรับ response ขนาดใหญ่
        proxy_buffer_size 8k;
        proxy_buffers 4 32k;
        proxy_busy_buffers_size 64k;
    }
}
EOF

# 3. สร้างไฟล์ docker-compose สำหรับ Linux
log "3. กำลังสร้างไฟล์ docker-compose สำหรับ Linux..."
cat > docker-compose-linux-nginx.yml <<'EOF'
version: '3'

services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd
    # ใช้ host network mode สำหรับ Linux เพื่อให้เข้าถึง localhost ได้โดยตรง
    network_mode: "host"
    volumes:
      - ./nginx-simple/nginx-linux.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
    # คำสั่งสำหรับตรวจสอบว่า nginx ทำงานถูกต้องหรือไม่
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/nginx-status"]
      interval: 10s
      timeout: 5s
      retries: 3
EOF

# 4. ยกเลิก port forwarding เดิม (ถ้ามี)
log "4. กำลังยกเลิก port forwarding เดิม..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 3

# 5. ตรวจสอบว่า port 8080 ว่างหรือไม่
log "5. กำลังตรวจสอบว่า port 8080 ว่างหรือไม่..."
if netstat -tuln | grep -q ":8080 "; then
    warn "⚠️ Port 8080 มีการใช้งานอยู่"
    warn "กำลังพยายามยกเลิกการใช้งาน port 8080..."
    
    # พยายามหา process ที่ใช้ port 8080
    pid=$(lsof -t -i:8080 2>/dev/null)
    if [ -n "$pid" ]; then
        warn "พบ process ID: $pid กำลังใช้งาน port 8080"
        warn "กำลังพยายามยกเลิก process..."
        kill $pid 2>/dev/null || true
        sleep 2
    fi
fi

# 6. เริ่ม port forwarding ใหม่
log "6. กำลังเริ่ม port forwarding..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 > /dev/null 2>&1 &
echo $! > .kubectl-proxy.pid
log "✅ เริ่ม port forwarding บน port 8080 แล้ว (PID: $(cat .kubectl-proxy.pid))"
sleep 5

# 7. ยกเลิก nginx container เดิม (ถ้ามี)
log "7. กำลังยกเลิก nginx container เดิม..."
docker stop nginx-argocd >/dev/null 2>&1 || true
docker rm nginx-argocd >/dev/null 2>&1 || true

# 8. เริ่ม nginx container ใหม่
log "8. กำลังเริ่ม nginx container ใหม่..."
if command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose-linux-nginx.yml down >/dev/null 2>&1 || true
    docker-compose -f docker-compose-linux-nginx.yml up -d
elif docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose-linux-nginx.yml down >/dev/null 2>&1 || true
    docker compose -f docker-compose-linux-nginx.yml up -d
else
    error "ไม่พบคำสั่ง docker-compose หรือ docker compose"
    error "กำลังใช้คำสั่ง docker run แทน..."
    
    docker run -d --name nginx-argocd \
        --network host \
        -v $(pwd)/nginx-simple/nginx-linux.conf:/etc/nginx/conf.d/default.conf:ro \
        --restart unless-stopped \
        nginx:alpine
fi

# 9. รอให้ nginx เริ่มทำงาน
log "9. กำลังรอให้ nginx เริ่มทำงาน..."
sleep 5

# 10. ตรวจสอบว่า nginx ทำงานหรือไม่
log "10. กำลังตรวจสอบว่า nginx ทำงานหรือไม่..."
if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
    log "✅ Nginx ทำงานปกติ"
else
    error "❌ Nginx ไม่ทำงาน"
    error "กรุณาตรวจสอบ log ด้วยคำสั่ง: docker logs nginx-argocd"
fi

# 11. ตรวจสอบว่าสามารถเข้าถึง ArgoCD ได้หรือไม่
log "11. กำลังตรวจสอบว่าสามารถเข้าถึง ArgoCD ได้หรือไม่..."
if curl -s http://localhost/ | grep -q "ArgoCD\|loading\|<!DOCTYPE html>"; then
    log "✅ สามารถเข้าถึง ArgoCD ได้"
    echo ""
    echo "🎉 แก้ไขปัญหาสำเร็จ!"
    echo "🌐 เข้าใช้ ArgoCD ได้ที่: http://$(hostname -I | awk '{print $1}')"
    echo "👤 Username: admin"
    
    # พยายามดึงรหัสผ่าน
    password=$(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ -n "$password" ]; then
        echo "🔑 Password: $password"
    else
        echo "🔑 Password: รัน ./get-password.sh เพื่อดูรหัสผ่าน"
    fi
else
    warn "⚠️ ยังไม่สามารถเข้าถึง ArgoCD ได้"
    warn "อาจต้องรอสักครู่ หรือลองตรวจสอบด้วยคำสั่ง: curl -I http://localhost/"
fi

# 12. แสดงข้อมูลสำหรับการตรวจสอบเพิ่มเติม
echo ""
echo "ℹ️ ข้อมูลสำหรับการตรวจสอบเพิ่มเติม:"
echo "   - Kubernetes Pods: kubectl get pods -n argocd"
echo "   - Port Forwarding: ps aux | grep port-forward"
echo "   - Nginx Container: docker ps | grep nginx-argocd"
echo "   - Nginx Logs: docker logs nginx-argocd"
echo "   - HTTP Status: curl -I http://localhost/"
echo ""
echo "✅ เสร็จสิ้น!"
