#!/bin/bash

# =============================================================================
# 🔧 Fix Docker Issues on Ubuntu Server
# =============================================================================

echo "🔧 แก้ไขปัญหา Docker ใน Ubuntu Server"
echo "=================================="

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

# 1. ตรวจสอบสถานะ Docker
echo -e "\n1️⃣ ตรวจสอบสถานะ Docker..."
if systemctl is-active --quiet docker; then
    log "Docker service กำลังทำงาน"
else
    log_warn "Docker service ไม่ทำงาน"
    echo "   Status: $(systemctl is-active docker)"
fi

echo "   Docker service status:"
sudo systemctl status docker --no-pager --lines=3

# 2. เริ่ม Docker service
echo -e "\n2️⃣ เริ่ม Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

if systemctl is-active --quiet docker; then
    log "✅ Docker service เริ่มทำงานแล้ว"
else
    log_error "❌ ไม่สามารถเริ่ม Docker service ได้"
    exit 1
fi

# 3. ตรวจสอบ Docker group
echo -e "\n3️⃣ ตรวจสอบ Docker group..."
if groups $USER | grep -q docker; then
    log "User $USER อยู่ใน docker group แล้ว"
else
    log_warn "เพิ่ม user $USER เข้า docker group..."
    sudo usermod -aG docker $USER
    log "✅ เพิ่ม user เข้า docker group แล้ว"
fi

# 4. แก้ไข socket permissions
echo -e "\n4️⃣ แก้ไข Docker socket permissions..."
if [ -e /var/run/docker.sock ]; then
    SOCKET_PERMS=$(stat -c %a /var/run/docker.sock)
    log "Docker socket permissions: $SOCKET_PERMS"
    
    sudo chmod 666 /var/run/docker.sock
    log "✅ แก้ไข socket permissions แล้ว"
else
    log_error "❌ ไม่พบ Docker socket"
fi

# 5. ทดสอบ Docker
echo -e "\n5️⃣ ทดสอบ Docker..."

# Test without sudo first
if docker info >/dev/null 2>&1; then
    log "✅ Docker ทำงานปกติ (ไม่ต้อง sudo)"
    echo "   Docker version: $(docker --version)"
elif sudo docker info >/dev/null 2>&1; then
    log_warn "⚠️ Docker ทำงานด้วย sudo เท่านั้น"
    echo "   Docker version: $(sudo docker --version)"
    
    # Try newgrp workaround
    echo -e "\n   พยายามแก้ไขด้วย newgrp..."
    if command -v newgrp >/dev/null; then
        # This might not work in script, but worth trying
        echo "docker info >/dev/null 2>&1 && echo 'newgrp works'" | newgrp docker
    fi
else
    log_error "❌ Docker ยังคงมีปัญหา"
    
    echo -e "\n🔍 ข้อมูลการ debug:"
    echo "   Docker service status:"
    sudo systemctl status docker --no-pager --lines=5
    
    echo -e "\n   Docker logs:"
    sudo journalctl -u docker.service --no-pager --lines=5
    
    echo -e "\n   Docker socket info:"
    ls -la /var/run/docker.sock 2>/dev/null || echo "   ไม่พบ socket file"
fi

# 6. คำแนะนำ
echo -e "\n💡 คำแนะนำ:"

if ! docker info >/dev/null 2>&1; then
    echo "   🔄 เนื่องจาก user ถูกเพิ่มเข้า docker group ใหม่"
    echo "   📝 กรุณาทำอย่างใดอย่างหนึ่ง:"
    echo "   1️⃣ Logout และ Login ใหม่"
    echo "   2️⃣ รัน: newgrp docker"
    echo "   3️⃣ Reboot server: sudo reboot"
    echo ""
    echo "   🧪 ทดสอบหลังจากนั้น:"
    echo "   docker info"
else
    echo "   ✅ Docker พร้อมใช้งานแล้ว!"
    echo "   🚀 สามารถรัน ArgoCD installer ได้:"
    echo "   ./install-full-stack.sh"
fi

echo -e "\n🎯 การแก้ไขเสร็จสิ้น!"
