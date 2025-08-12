#!/bin/bash

# =============================================================================
# 🔗 การเชื่อมต่อ Client เข้ากับ Kubernetes Cluster
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

echo "🔗 การเชื่อมต่อ Client เข้ากับ Kubernetes Cluster"
echo "=============================================="
echo ""

# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    error "ไม่พบคำสั่ง kubectl กรุณาติดตั้งก่อนใช้งาน"
    warn "วิธีติดตั้ง kubectl:"
    echo "- Windows: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    echo "- Linux: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
    echo "- macOS: https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/"
    exit 1
fi

# ตรวจสอบว่ากำลังรันบน Master Node หรือไม่
if ! kubectl get nodes >/dev/null 2>&1; then
    warn "ไม่พบ Kubernetes nodes หรือคุณไม่มีสิทธิ์เข้าถึง"
    echo ""
    info "สคริปต์นี้ต้องรันบน Master Node ที่มี Kubernetes Cluster ทำงานอยู่"
    echo ""
    exit 1
fi

# ดึงข้อมูล cluster
CLUSTER_NAME=$(kubectl config current-context 2>/dev/null || echo "kubernetes")
SERVER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "Unknown")
MASTER_IP=$(echo "$SERVER_URL" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || hostname -I | awk '{print $1}')

# แสดงข้อมูล cluster
echo "ข้อมูล Kubernetes Cluster:"
echo "=========================="
echo "🔹 Cluster Name: $CLUSTER_NAME"
echo "🔹 Master IP: $MASTER_IP"
echo "🔹 API Server: $SERVER_URL"
echo ""

# ดึงรายชื่อ nodes
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
echo "🖥️ จำนวน Nodes ทั้งหมด: $NODE_COUNT"
kubectl get nodes -o wide | head -1
kubectl get nodes -o wide | tail -n+2 | sort
echo ""

# เมนูหลัก
while true; do
    echo "โปรดเลือกวิธีการเชื่อมต่อ Client:"
    echo "1) สร้าง kubeconfig สำหรับการเชื่อมต่อ"
    echo "2) สร้าง join token สำหรับ worker node"
    echo "3) แสดงขั้นตอนการติดตั้ง kubectl บน client"
    echo "4) ดูสถานะการเชื่อมต่อปัจจุบัน"
    echo "5) สร้าง kubeconfig แบบ portable"
    echo "q) ออกจากโปรแกรม"
    
    read -p "เลือกตัวเลือก (1-5 หรือ q): " choice
    echo ""
    
    case $choice in
        1)
            # สร้าง kubeconfig
            echo "🔧 สร้าง kubeconfig สำหรับการเชื่อมต่อ"
            echo "=================================="
            
            # สร้างไฟล์ kubeconfig
            KUBECONFIG_FILE="kubeconfig-client-$(date +%Y%m%d).yaml"
            
            log "กำลังสร้างไฟล์ kubeconfig..."
            kubectl config view --raw > "$KUBECONFIG_FILE"
            
            if [ -f "$KUBECONFIG_FILE" ]; then
                log "✅ สร้างไฟล์ kubeconfig สำเร็จ: $KUBECONFIG_FILE"
                log "ขนาดไฟล์: $(du -h "$KUBECONFIG_FILE" | cut -f1)"
                
                echo ""
                log "วิธีใช้งานบน client:"
                echo "1. คัดลอกไฟล์ $KUBECONFIG_FILE ไปยัง client"
                echo "2. บน client ให้ตั้งค่า environment variable:"
                echo "   export KUBECONFIG=/path/to/$KUBECONFIG_FILE"
                echo "3. ทดสอบด้วยคำสั่ง: kubectl cluster-info"
                echo ""
                
                # สร้างคำสั่งสำหรับการคัดลอกไฟล์
                echo "📋 คำสั่งสำหรับคัดลอกไฟล์จาก client (รันบน client):"
                echo "scp $(whoami)@$MASTER_IP:$(pwd)/$KUBECONFIG_FILE ~/kubeconfig.yaml"
                echo ""
            else
                error "❌ ไม่สามารถสร้างไฟล์ kubeconfig ได้"
            fi
            ;;
        
        2)
            # สร้าง join token
            echo "🔑 สร้าง Join Token สำหรับ Worker Node"
            echo "=================================="
            
            # ตรวจสอบว่าเป็น kubeadm cluster หรือไม่
            if ! command -v kubeadm >/dev/null 2>&1; then
                error "ไม่พบคำสั่ง kubeadm"
                warn "คุณสมบัตินี้ใช้ได้เฉพาะกับ cluster ที่สร้างด้วย kubeadm เท่านั้น"
                echo ""
                continue
            fi
            
            log "กำลังสร้าง token สำหรับ join node..."
            JOIN_COMMAND=$(sudo kubeadm token create --print-join-command 2>/dev/null)
            
            if [ -n "$JOIN_COMMAND" ]; then
                log "✅ สร้าง token สำเร็จ"
                echo ""
                echo "📋 คำสั่งสำหรับเพิ่ม node (รันบน worker node ด้วยสิทธิ์ root):"
                echo "$JOIN_COMMAND"
                echo ""
                
                log "วิธีใช้งานบน worker node:"
                echo "1. ติดตั้ง Docker, kubelet, kubeadm และ kubectl บน worker node"
                echo "2. รันคำสั่ง join ข้างต้นด้วยสิทธิ์ root"
                echo "3. ตรวจสอบผลด้วยคำสั่ง: kubectl get nodes"
                echo ""
            else
                error "❌ ไม่สามารถสร้าง join token ได้"
                warn "อาจเกิดจากไม่มีสิทธิ์ในการสร้าง token หรือไม่ใช่ kubeadm cluster"
                echo ""
            fi
            ;;
        
        3)
            # แสดงขั้นตอนการติดตั้ง kubectl
            echo "🔧 วิธีติดตั้ง kubectl บน Client"
            echo "==========================="
            
            echo "📋 สำหรับ Ubuntu/Debian:"
            echo "sudo apt-get update"
            echo "sudo apt-get install -y apt-transport-https ca-certificates curl"
            echo "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
            echo "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"
            echo "sudo apt-get update"
            echo "sudo apt-get install -y kubectl"
            echo ""
            
            echo "📋 สำหรับ CentOS/RHEL:"
            echo "cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo"
            echo "[kubernetes]"
            echo "name=Kubernetes"
            echo "baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/"
            echo "enabled=1"
            echo "gpgcheck=1"
            echo "gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key"
            echo "EOF"
            echo "sudo yum install -y kubectl"
            echo ""
            
            echo "📋 สำหรับ Windows (PowerShell):"
            echo "# ใช้ Chocolatey"
            echo "choco install kubernetes-cli"
            echo ""
            echo "# หรือใช้ winget"
            echo "winget install -e --id Kubernetes.kubectl"
            echo ""
            
            echo "📋 สำหรับ macOS:"
            echo "# ใช้ Homebrew"
            echo "brew install kubectl"
            echo ""
            
            echo "🔍 ทดสอบการติดตั้ง:"
            echo "kubectl version --client"
            echo ""
            ;;
        
        4)
            # แสดงสถานะการเชื่อมต่อปัจจุบัน
            echo "🔍 สถานะการเชื่อมต่อปัจจุบัน"
            echo "========================="
            
            log "ข้อมูล cluster:"
            kubectl cluster-info
            echo ""
            
            log "ข้อมูล context ปัจจุบัน:"
            kubectl config get-contexts
            echo ""
            
            log "ข้อมูล namespace:"
            kubectl get namespaces
            echo ""
            
            # ตรวจสอบ ArgoCD
            if kubectl get namespace argocd >/dev/null 2>&1; then
                log "สถานะ ArgoCD:"
                kubectl get pods -n argocd
                echo ""
                
                log "ArgoCD Service:"
                kubectl get svc -n argocd
                echo ""
            fi
            ;;
        
        5)
            # สร้าง kubeconfig แบบ portable
            echo "🔧 สร้าง kubeconfig แบบ portable"
            echo "============================="
            
            # ขอ IP address ที่จะใช้
            read -p "ป้อน IP address ของ Master Node ที่ client จะใช้เชื่อมต่อ [$MASTER_IP]: " custom_ip
            CUSTOM_IP=${custom_ip:-$MASTER_IP}
            
            # สร้างไฟล์ kubeconfig แบบ portable
            PORTABLE_KUBECONFIG="kubeconfig-portable-$(date +%Y%m%d).yaml"
            
            log "กำลังสร้างไฟล์ kubeconfig แบบ portable..."
            kubectl config view --raw > "$PORTABLE_KUBECONFIG.tmp"
            
            # แทนที่ server URL ด้วย IP ที่กำหนด
            API_PORT=$(echo "$SERVER_URL" | grep -oE ':[0-9]+$' || echo ":6443")
            sed "s|server:.*|server: https://$CUSTOM_IP$API_PORT|g" "$PORTABLE_KUBECONFIG.tmp" > "$PORTABLE_KUBECONFIG"
            rm "$PORTABLE_KUBECONFIG.tmp"
            
            if [ -f "$PORTABLE_KUBECONFIG" ]; then
                log "✅ สร้างไฟล์ kubeconfig แบบ portable สำเร็จ: $PORTABLE_KUBECONFIG"
                log "ขนาดไฟล์: $(du -h "$PORTABLE_KUBECONFIG" | cut -f1)"
                
                echo ""
                log "วิธีใช้งานบน client:"
                echo "1. คัดลอกไฟล์ $PORTABLE_KUBECONFIG ไปยัง client"
                echo "2. บน client ให้ตั้งค่า environment variable:"
                echo "   export KUBECONFIG=/path/to/$PORTABLE_KUBECONFIG"
                echo "3. ทดสอบด้วยคำสั่ง: kubectl cluster-info"
                echo ""
                
                # สร้างคำสั่งสำหรับการคัดลอกไฟล์
                echo "📋 คำสั่งสำหรับคัดลอกไฟล์จาก client (รันบน client):"
                echo "scp $(whoami)@$MASTER_IP:$(pwd)/$PORTABLE_KUBECONFIG ~/kubeconfig.yaml"
                echo ""
            else
                error "❌ ไม่สามารถสร้างไฟล์ kubeconfig แบบ portable ได้"
            fi
            ;;
        
        q|Q)
            log "ออกจากโปรแกรม"
            exit 0
            ;;
        
        *)
            warn "ตัวเลือกไม่ถูกต้อง กรุณาเลือกใหม่"
            ;;
    esac
    
    echo "----------------------------------------"
    echo ""
done
