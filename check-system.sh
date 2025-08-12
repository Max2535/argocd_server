#!/bin/bash

echo "🔍 ตรวจสอบระบบก่อนติดตั้ง Kubernetes + ArgoCD"
echo "================================================"

# Check OS Version
echo "📋 ข้อมูลระบบ:"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

# Check Resources
echo ""
echo "💾 ทรัพยากรระบบ:"
echo "RAM: $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.2f%%)\n", $3/1024/1024,$2/1024/1024,$3*100/$2 }')"
echo "CPU: $(nproc) cores"
echo "Disk: $(df -h / | awk 'NR==2{print $4" available"}')"

# Check Network
echo ""
echo "🌐 การเชื่อมต่อเครือข่าย:"
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo "✅ Internet connection: OK"
else
    echo "❌ Internet connection: Failed"
fi

# Check if running as root
echo ""
echo "👤 ผู้ใช้งาน:"
if [[ $EUID -eq 0 ]]; then
    echo "❌ กำลังรันด้วย root user (ไม่แนะนำ)"
    echo "   ควรใช้ user ที่มี sudo privileges"
else
    echo "✅ รันด้วย user: $(whoami)"
    if sudo -n true 2>/dev/null; then
        echo "✅ มี sudo privileges"
    else
        echo "❌ ไม่มี sudo privileges"
    fi
fi

# Check Swap
echo ""
echo "🔄 Swap:"
if [ $(swapon --show | wc -l) -eq 0 ]; then
    echo "✅ Swap ปิดอยู่"
else
    echo "⚠️  Swap เปิดอยู่ (จะถูกปิดระหว่างการติดตั้ง)"
fi

# Check Firewall
echo ""
echo "🔥 Firewall:"
if sudo ufw status | grep -q "Status: active"; then
    echo "⚠️  UFW Firewall เปิดอยู่ (จะถูกปิดระหว่างการติดตั้ง)"
else
    echo "✅ UFW Firewall ปิดอยู่"
fi

# Check existing installations
echo ""
echo "📦 ตรวจสอบ software ที่ติดตั้งแล้ว:"

if command -v docker &> /dev/null; then
    echo "⚠️  Docker ติดตั้งแล้ว (อาจมีความขัดแย้งกับ containerd)"
    echo "   Version: $(docker --version)"
    echo "   แนะนำให้หยุด Docker: sudo systemctl stop docker && sudo systemctl disable docker"
fi

if command -v containerd &> /dev/null; then
    echo "✅ Containerd ติดตั้งแล้ว"
    echo "   Version: $(containerd --version)"
fi

if command -v kubectl &> /dev/null; then
    echo "✅ kubectl ติดตั้งแล้ว"
    echo "   Version: $(kubectl version --client --short 2>/dev/null)"
fi

if command -v kubeadm &> /dev/null; then
    echo "✅ kubeadm ติดตั้งแล้ว"
    echo "   Version: $(kubeadm version -o short)"
fi

# Check ports
echo ""
echo "🔌 ตรวจสอบ ports ที่จำเป็น:"
REQUIRED_PORTS="6443 2379 2380 10250 10259 10257"
for port in $REQUIRED_PORTS; do
    if ss -tuln | grep -q ":$port "; then
        echo "❌ Port $port กำลังใช้งานอยู่"
    else
        echo "✅ Port $port ว่าง"
    fi
done

# Check minimum requirements
echo ""
echo "📊 ตรวจสอบความต้องการขั้นต่ำ:"

# RAM check (minimum 2GB)
RAM_GB=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
if (( $(echo "$RAM_GB >= 2" | bc -l) )); then
    echo "✅ RAM: ${RAM_GB}GB (ขั้นต่ำ 2GB)"
else
    echo "❌ RAM: ${RAM_GB}GB (ต้องการอย่างน้อย 2GB)"
fi

# CPU check (minimum 2 cores)
CPU_CORES=$(nproc)
if [ $CPU_CORES -ge 2 ]; then
    echo "✅ CPU: ${CPU_CORES} cores (ขั้นต่ำ 2 cores)"
else
    echo "❌ CPU: ${CPU_CORES} cores (ต้องการอย่างน้อย 2 cores)"
fi

# Disk check (minimum 20GB available)
DISK_GB=$(df / | awk 'NR==2{printf "%.1f", $4/1024/1024}')
if (( $(echo "$DISK_GB >= 20" | bc -l) )); then
    echo "✅ Disk: ${DISK_GB}GB available (ขั้นต่ำ 20GB)"
else
    echo "❌ Disk: ${DISK_GB}GB available (ต้องการอย่างน้อย 20GB)"
fi

echo ""
echo "================================================"
echo "🎯 สรุปผลการตรวจสอบ:"

# Count issues
ISSUES=0

if [[ $EUID -eq 0 ]]; then
    echo "❌ กำลังรันด้วย root user"
    ISSUES=$((ISSUES+1))
fi

if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "❌ ไม่สามารถเชื่อมต่อ Internet ได้"
    ISSUES=$((ISSUES+1))
fi

if command -v docker &> /dev/null && systemctl is-active --quiet docker; then
    echo "❌ Docker กำลังทำงานอยู่ (ควรหยุดก่อนติดตั้ง)"
    ISSUES=$((ISSUES+1))
fi

if (( $(echo "$RAM_GB < 2" | bc -l) )); then
    echo "❌ RAM ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

if [ $CPU_CORES -lt 2 ]; then
    echo "❌ CPU cores ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

if (( $(echo "$DISK_GB < 20" | bc -l) )); then
    echo "❌ Disk space ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ ระบบพร้อมสำหรับการติดตั้ง Kubernetes + ArgoCD"
    echo ""
    echo "🚀 คำสั่งติดตั้ง:"
    echo "   chmod +x install_argocd.sh"
    echo "   ./install_argocd.sh master"
else
    echo "⚠️  พบปัญหา $ISSUES รายการ กรุณาแก้ไขก่อนติดตั้ง"
fi

echo "================================================"
