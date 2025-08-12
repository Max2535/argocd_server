#!/bin/bash

# =============================================================================
# 🔐 เข้าถึง ArgoCD ผ่าน HTTPS โดยตรง
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

echo "🔐 เข้าถึง ArgoCD ผ่าน HTTPS โดยตรง"
echo "=================================="

# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    error "kubectl ไม่ได้ติดตั้ง กรุณาติดตั้งก่อนใช้งาน"
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

# 1. ยกเลิก port forwarding เดิม (ถ้ามี)
log "1. กำลังยกเลิก port forwarding เดิม..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 3

# 2. ค้นหา port ที่ว่าง
log "2. กำลังค้นหา port ที่ว่าง..."
PREFERRED_PORTS=(8443 8080 8081 8082 8083 8090)
PORT_FOUND=false

for port in "${PREFERRED_PORTS[@]}"; do
    if ! netstat -tuln | grep -q ":$port "; then
        free_port=$port
        PORT_FOUND=true
        log "✅ พบ port ที่ว่าง: $free_port"
        break
    fi
done

if [ "$PORT_FOUND" = false ]; then
    warn "⚠️ ไม่พบ port ที่ว่าง กำลังใช้ port 9090 แทน"
    free_port=9090
fi

# 3. ตรวจสอบว่า port ที่เลือกว่างหรือไม่
log "3. กำลังตรวจสอบว่า port $free_port ว่างหรือไม่..."
if netstat -tuln | grep -q ":$free_port "; then
    warn "⚠️ Port $free_port มีการใช้งานอยู่"
    warn "กำลังพยายามยกเลิกการใช้งาน port $free_port..."
    
    # พยายามหา process ที่ใช้ port
    pid=$(lsof -t -i:$free_port 2>/dev/null)
    if [ -n "$pid" ]; then
        warn "พบ process ID: $pid กำลังใช้งาน port $free_port"
        warn "กำลังพยายามยกเลิก process..."
        kill $pid 2>/dev/null || true
        sleep 2
    fi
fi

# 4. เริ่ม port forwarding
log "4. กำลังเริ่ม port forwarding บน port $free_port..."
kubectl port-forward svc/argocd-server -n argocd $free_port:443 --address 0.0.0.0 > /dev/null 2>&1 &
port_forward_pid=$!
echo $port_forward_pid > .argocd-https-pid
log "✅ เริ่ม port forwarding บน port $free_port แล้ว (PID: $port_forward_pid)"
sleep 5

# 5. ตรวจสอบว่า port forwarding ทำงานหรือไม่
log "5. กำลังตรวจสอบว่า port forwarding ทำงานหรือไม่..."
if ps -p $port_forward_pid > /dev/null; then
    log "✅ Port forwarding ทำงานปกติ"
else
    error "❌ Port forwarding ไม่ทำงาน"
    error "กำลังลองใหม่อีกครั้ง..."
    kubectl port-forward svc/argocd-server -n argocd $free_port:443 --address 0.0.0.0 > /dev/null 2>&1 &
    port_forward_pid=$!
    echo $port_forward_pid > .argocd-https-pid
    sleep 5
fi

# 6. ตรวจสอบว่าสามารถเข้าถึง ArgoCD ได้หรือไม่
log "6. กำลังตรวจสอบว่าสามารถเข้าถึง ArgoCD ได้หรือไม่..."
if curl -k -s https://localhost:$free_port/ | grep -q "ArgoCD\|loading\|<!DOCTYPE html>"; then
    log "✅ สามารถเข้าถึง ArgoCD ได้"
    echo ""
    echo "🎉 การตั้งค่าสำเร็จ!"
    echo "🌐 เข้าใช้ ArgoCD ได้ที่: https://$(hostname -I | awk '{print $1}'):$free_port"
    echo "👤 Username: admin"
    
    # พยายามดึงรหัสผ่าน
    password=$(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ -n "$password" ]; then
        echo "🔑 Password: $password"
    else
        echo "🔑 Password: รัน ./get-password.sh เพื่อดูรหัสผ่าน"
    fi
    
    echo ""
    warn "⚠️ หมายเหตุ: คุณจะต้องยอมรับใบรับรองที่ลงนามด้วยตนเอง (self-signed certificate) ในเบราว์เซอร์"
    warn "⚠️ Port forwarding ทำงานในเบื้องหลังและจะหยุดทำงานเมื่อคุณออกจากระบบ"
    info "ℹ️ หากต้องการหยุด port forwarding ให้รันคำสั่ง: kill $(cat .argocd-https-pid)"
else
    warn "⚠️ ยังไม่สามารถเข้าถึง ArgoCD ได้"
    warn "อาจต้องรอสักครู่ หรือลองตรวจสอบด้วยคำสั่ง: curl -k -I https://localhost:$free_port/"
fi

# 7. สร้างสคริปต์สำหรับเริ่ม ArgoCD ในครั้งถัดไป
log "7. กำลังสร้างสคริปต์สำหรับเริ่ม ArgoCD ในครั้งถัดไป..."
cat > ./start-argocd-https.sh <<EOF
#!/bin/bash
# สคริปต์สำหรับเริ่ม ArgoCD HTTPS
echo "🔄 กำลังเริ่ม ArgoCD HTTPS..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
sleep 2
kubectl port-forward svc/argocd-server -n argocd $free_port:443 --address 0.0.0.0 > /dev/null 2>&1 &
echo \$! > .argocd-https-pid
echo "✅ เริ่ม ArgoCD HTTPS บน port $free_port แล้ว"
echo "🌐 เข้าใช้ ArgoCD ได้ที่: https://\$(hostname -I | awk '{print \$1}'):$free_port"
EOF
chmod +x ./start-argocd-https.sh
log "✅ สร้างสคริปต์ start-argocd-https.sh แล้ว"

# 8. สร้างสคริปต์สำหรับหยุด ArgoCD
log "8. กำลังสร้างสคริปต์สำหรับหยุด ArgoCD..."
cat > ./stop-argocd-https.sh <<EOF
#!/bin/bash
# สคริปต์สำหรับหยุด ArgoCD HTTPS
echo "🛑 กำลังหยุด ArgoCD HTTPS..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
echo "✅ หยุด ArgoCD HTTPS แล้ว"
EOF
chmod +x ./stop-argocd-https.sh
log "✅ สร้างสคริปต์ stop-argocd-https.sh แล้ว"

# 9. แสดงข้อมูลสำหรับการตรวจสอบเพิ่มเติม
echo ""
echo "ℹ️ ข้อมูลสำหรับการตรวจสอบเพิ่มเติม:"
echo "   - สถานะ Kubernetes: kubectl get pods -n argocd"
echo "   - สถานะ Port Forwarding: ps aux | grep port-forward"
echo "   - HTTPS Status: curl -k -I https://localhost:$free_port"
echo ""
echo "✅ เสร็จสิ้น!"
