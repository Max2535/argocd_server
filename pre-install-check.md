# Pre-installation Checks for Ubuntu Server 24.04

## System Requirements Check Script

```bash
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

echo ""
echo "================================================"
echo "🎯 สรุป:"
echo "   - ตรวจสอบให้แน่ใจว่าระบบมี RAM อย่างน้อย 2GB"
echo "   - ตรวจสอบให้แน่ใจว่ามี disk space อย่างน้อย 20GB"
echo "   - หาก Docker ติดตั้งแล้ว ควรหยุดและปิดการใช้งาน"
echo "   - หาก ports ถูกใช้งาน ให้หยุด services ที่เกี่ยวข้อง"
echo ""
```

## Manual Checks

### 1. Check if Docker needs to be stopped:
```bash
# หาก Docker ติดตั้งแล้ว ให้หยุดและปิดการใช้งาน
sudo systemctl stop docker
sudo systemctl disable docker
```

### 2. Check system resources:
```bash
# ต้องมี RAM อย่างน้อย 2GB
free -h

# ต้องมี disk space อย่างน้อย 20GB
df -h

# ต้องมี CPU อย่างน้อย 2 cores
nproc
```

### 3. Check network configuration:
```bash
# ตรวจสอบ IP address
ip addr show

# ตรวจสอบ default gateway
ip route show default

# ตรวจสอบ DNS
cat /etc/resolv.conf
```
