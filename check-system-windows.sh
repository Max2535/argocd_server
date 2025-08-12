#!/bin/bash

echo "🔍 ตรวจสอบระบบก่อนติดตั้ง Kubernetes + ArgoCD (Windows Version)"
echo "============================================================"

# Check OS Version
echo "📋 ข้อมูลระบบ:"
if command -v lsb_release &> /dev/null; then
    echo "OS: $(lsb_release -d | cut -f2)"
else
    echo "OS: Windows (Git Bash)"
fi
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"

# Check Resources
echo ""
echo "💾 ทรัพยากรระบบ:"

# Check RAM - use wmic on Windows or alternative methods
if command -v wmic &> /dev/null; then
    TOTAL_RAM_KB=$(wmic computersystem get TotalPhysicalMemory /value | grep -o '[0-9]*' | head -1)
    if [ ! -z "$TOTAL_RAM_KB" ]; then
        TOTAL_RAM_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_RAM_KB/1024/1024/1024}")
        echo "RAM: ${TOTAL_RAM_GB}GB total"
    else
        echo "RAM: ไม่สามารถตรวจสอบได้"
    fi
elif command -v free &> /dev/null; then
    echo "RAM: $(free -h | awk 'NR==2{printf "%.1f/%.1f GB (%.2f%%)\n", $3/1024/1024,$2/1024/1024,$3*100/$2 }')"
else
    echo "RAM: ไม่สามารถตรวจสอบได้ (ต้องการ wmic หรือ free command)"
fi

echo "CPU: $(nproc) cores"
echo "Disk: $(df -h / | awk 'NR==2{print $4" available"}')"

# Check Network
echo ""
echo "🌐 การเชื่อมต่อเครือข่าย:"
if ping -c 1 8.8.8.8 &> /dev/null || ping -n 1 8.8.8.8 &> /dev/null; then
    echo "✅ Internet connection: OK"
else
    echo "❌ Internet connection: Failed"
fi

# Check if running as administrator (Windows equivalent of root)
echo ""
echo "👤 ผู้ใช้งาน:"
echo "✅ รันด้วย user: $(whoami)"

# Check if running with administrator privileges
if net session &> /dev/null; then
    echo "✅ มี Administrator privileges"
else
    echo "⚠️  ไม่มี Administrator privileges (อาจจำเป็นสำหรับการติดตั้งบางอย่าง)"
fi

# Check Docker
echo ""
echo "📦 ตรวจสอบ software ที่ติดตั้งแล้ว:"

if command -v docker &> /dev/null; then
    echo "⚠️  Docker ติดตั้งแล้ว"
    echo "   Version: $(docker --version)"
    if docker info &> /dev/null; then
        echo "   Status: Docker daemon กำลังทำงาน"
    else
        echo "   Status: Docker daemon ไม่ทำงาน"
    fi
fi

if command -v kubectl &> /dev/null; then
    echo "✅ kubectl ติดตั้งแล้ว"
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)
    echo "   Version: $KUBECTL_VERSION"
fi

if command -v minikube &> /dev/null; then
    echo "✅ minikube ติดตั้งแล้ว"
    echo "   Version: $(minikube version | head -1)"
fi

if command -v kind &> /dev/null; then
    echo "✅ kind ติดตั้งแล้ว"
    echo "   Version: $(kind version)"
fi

# Check ports (use netstat instead of ss for Windows compatibility)
echo ""
echo "🔌 ตรวจสอบ ports ที่จำเป็น:"
REQUIRED_PORTS="6443 2379 2380 10250 10259 10257"
for port in $REQUIRED_PORTS; do
    if netstat -an 2>/dev/null | grep -q ":$port "; then
        echo "❌ Port $port กำลังใช้งานอยู่"
    else
        echo "✅ Port $port ว่าง"
    fi
done

# Check minimum requirements
echo ""
echo "📊 ตรวจสอบความต้องการขั้นต่ำ:"

# RAM check (minimum 4GB for Windows + Kubernetes)
if [ ! -z "$TOTAL_RAM_GB" ]; then
    RAM_CHECK=$TOTAL_RAM_GB
else
    # Fallback: assume we have enough RAM if we can't detect it
    RAM_CHECK=8.0
fi

if awk "BEGIN {exit !($RAM_CHECK >= 4)}"; then
    echo "✅ RAM: ${RAM_CHECK}GB (ขั้นต่ำ 4GB สำหรับ Windows + Kubernetes)"
else
    echo "❌ RAM: ${RAM_CHECK}GB (ต้องการอย่างน้อย 4GB สำหรับ Windows + Kubernetes)"
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
if awk "BEGIN {exit !($DISK_GB >= 20)}"; then
    echo "✅ Disk: ${DISK_GB}GB available (ขั้นต่ำ 20GB)"
else
    echo "❌ Disk: ${DISK_GB}GB available (ต้องการอย่างน้อย 20GB)"
fi

echo ""
echo "============================================================"
echo "🎯 สรุปผลการตรวจสอบ:"

# Count issues
ISSUES=0

# Check internet connection
if ! (ping -c 1 8.8.8.8 &> /dev/null || ping -n 1 8.8.8.8 &> /dev/null); then
    echo "❌ ไม่สามารถเชื่อมต่อ Internet ได้"
    ISSUES=$((ISSUES+1))
fi

# Check RAM
if [ ! -z "$RAM_CHECK" ] && awk "BEGIN {exit !($RAM_CHECK < 4)}"; then
    echo "❌ RAM ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

# Check CPU
if [ $CPU_CORES -lt 2 ]; then
    echo "❌ CPU cores ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

# Check Disk
if awk "BEGIN {exit !($DISK_GB < 20)}"; then
    echo "❌ Disk space ไม่เพียงพอ"
    ISSUES=$((ISSUES+1))
fi

if [ $ISSUES -eq 0 ]; then
    echo "✅ ระบบพร้อมสำหรับการติดตั้ง Kubernetes + ArgoCD"
    echo ""
    echo "🚀 สำหรับ Windows แนะนำให้ใช้:"
    echo "   - Docker Desktop with Kubernetes enabled"
    echo "   - minikube"
    echo "   - kind"
    echo ""
    echo "💡 ตัวอย่างการติดตั้ง minikube:"
    echo "   1. ติดตั้ง minikube: https://minikube.sigs.k8s.io/docs/start/"
    echo "   2. เริ่มต้น cluster: minikube start"
    echo "   3. ติดตั้ง ArgoCD: kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
else
    echo "⚠️  พบปัญหา $ISSUES รายการ กรุณาแก้ไขก่อนติดตั้ง"
fi

echo "============================================================"
