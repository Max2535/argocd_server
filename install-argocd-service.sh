#!/bin/bash

# =============================================================================
# 🔄 ติดตั้ง ArgoCD เป็น Systemd Service
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

echo "🔄 ติดตั้ง ArgoCD เป็น Systemd Service"
echo "===================================="

# ตรวจสอบว่าเป็น root หรือไม่
if [ "$(id -u)" -ne 0 ]; then
    error "กรุณารันสคริปต์นี้ด้วยสิทธิ์ root (sudo)"
    exit 1
fi

# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    error "kubectl ไม่ได้ติดตั้ง กรุณาติดตั้งก่อนใช้งาน"
    exit 1
fi

# ตรวจสอบว่ามี systemd หรือไม่
if ! command -v systemctl >/dev/null 2>&1; then
    error "systemd ไม่ได้ติดตั้ง สคริปต์นี้ใช้ได้เฉพาะกับระบบที่ใช้ systemd"
    exit 1
fi

# 1. สร้างไฟล์ service
log "1. กำลังสร้างไฟล์ service..."

# ดึงชื่อผู้ใช้ปัจจุบัน
current_user=$(logname || echo "max")
home_dir=$(eval echo ~$current_user)
log "ใช้ผู้ใช้: $current_user บน $home_dir"

cat > /etc/systemd/system/argocd-http.service <<EOF
[Unit]
Description=ArgoCD Server HTTP Access
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$current_user
WorkingDirectory=$home_dir
ExecStart=/usr/bin/kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 2. สร้างไฟล์ service สำหรับ nginx
log "2. กำลังสร้างไฟล์ service สำหรับ nginx..."
cat > /etc/systemd/system/argocd-nginx.service <<EOF
[Unit]
Description=ArgoCD Nginx Proxy
After=argocd-http.service
Requires=argocd-http.service

[Service]
Type=simple
User=$current_user
WorkingDirectory=$home_dir
ExecStart=/usr/bin/docker run --rm --name nginx-argocd --network host -v $home_dir/nginx-simple/nginx-linux.conf:/etc/nginx/conf.d/default.conf:ro nginx:alpine
ExecStop=/usr/bin/docker stop nginx-argocd
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 3. โหลด systemd configuration ใหม่
log "3. กำลังโหลด systemd configuration ใหม่..."
systemctl daemon-reload

# 4. เริ่ม service
log "4. กำลังเริ่ม service..."
systemctl enable argocd-http.service
systemctl start argocd-http.service
systemctl enable argocd-nginx.service
systemctl start argocd-nginx.service

# 5. ตรวจสอบสถานะ service
log "5. กำลังตรวจสอบสถานะ service..."
echo ""
echo "สถานะ ArgoCD HTTP Service:"
systemctl status argocd-http.service --no-pager
echo ""
echo "สถานะ ArgoCD Nginx Service:"
systemctl status argocd-nginx.service --no-pager

# 6. แสดงข้อมูลเพิ่มเติม
echo ""
echo "🎉 ติดตั้ง ArgoCD เป็น Systemd Service สำเร็จแล้ว!"
echo "🌐 เข้าใช้ ArgoCD ได้ที่: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "คำสั่งที่เป็นประโยชน์:"
echo "   - ดูสถานะ: systemctl status argocd-http.service"
echo "   - เริ่ม service: systemctl start argocd-http.service"
echo "   - หยุด service: systemctl stop argocd-http.service"
echo "   - ดู log: journalctl -u argocd-http.service -f"
echo ""
echo "✅ เสร็จสิ้น!"
