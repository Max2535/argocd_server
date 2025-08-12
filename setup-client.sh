#!/bin/bash

# =============================================================================
# 🔄 ตั้งค่า Kubernetes Client แบบอัตโนมัติ
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

echo "🔄 ตั้งค่า Kubernetes Client แบบอัตโนมัติ"
echo "======================================"
echo ""

# ตรวจสอบ parameter
if [ $# -lt 1 ]; then
    warn "กรุณาระบุไฟล์ kubeconfig หรือ IP ของ master node"
    echo ""
    echo "วิธีใช้:"
    echo "  $0 <path-to-kubeconfig>   # ใช้ไฟล์ kubeconfig ที่มีอยู่แล้ว"
    echo "  $0 <master-ip>            # ดาวน์โหลด kubeconfig จาก master node"
    echo ""
    echo "ตัวอย่าง:"
    echo "  $0 kubeconfig.yaml"
    echo "  $0 192.168.1.100"
    exit 1
fi

INPUT=$1
KUBE_DIR="$HOME/.kube"

# ฟังก์ชันติดตั้ง kubectl
install_kubectl() {
    local os_type=$(uname -s)
    local os_arch=$(uname -m)
    
    log "กำลังติดตั้ง kubectl..."
    
    case "$os_type" in
        Linux)
            # ตรวจสอบว่าเป็น Ubuntu/Debian หรือ CentOS/RHEL
            if command -v apt-get >/dev/null 2>&1; then
                log "ตรวจพบระบบ Debian/Ubuntu"
                
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl
                
                # เพิ่ม repository
                curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
                echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
                
                # ติดตั้ง kubectl
                sudo apt-get update
                sudo apt-get install -y kubectl
                
            elif command -v yum >/dev/null 2>&1; then
                log "ตรวจพบระบบ CentOS/RHEL"
                
                # เพิ่ม repository
                cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
                
                # ติดตั้ง kubectl
                sudo yum install -y kubectl
                
            else
                warn "ไม่สามารถระบุระบบ Linux ที่ใช้งานได้"
                warn "กรุณาติดตั้ง kubectl ด้วยตนเอง: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
                exit 1
            fi
            ;;
            
        Darwin)
            # macOS
            log "ตรวจพบระบบ macOS"
            
            if command -v brew >/dev/null 2>&1; then
                brew install kubectl
            else
                warn "ไม่พบ Homebrew"
                warn "กรุณาติดตั้ง Homebrew ก่อน: https://brew.sh/"
                warn "หรือติดตั้ง kubectl ด้วยตนเอง: https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/"
                exit 1
            fi
            ;;
            
        MINGW*|MSYS*|CYGWIN*)
            # Windows
            log "ตรวจพบระบบ Windows"
            warn "กรุณาติดตั้ง kubectl ด้วยตนเอง:"
            echo "1. ดาวน์โหลดจาก: https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"
            echo "2. เพิ่มตำแหน่งไฟล์ในตัวแปร PATH"
            echo "หรือใช้ Chocolatey: choco install kubernetes-cli"
            
            # ตรวจสอบว่ามี kubectl หรือไม่
            if command -v kubectl.exe >/dev/null 2>&1; then
                log "ตรวจพบ kubectl แล้ว"
            else
                warn "ไม่พบ kubectl กรุณาติดตั้งก่อนดำเนินการต่อ"
                exit 1
            fi
            ;;
            
        *)
            error "ไม่รองรับระบบปฏิบัติการนี้: $os_type"
            exit 1
            ;;
    esac
    
    # ตรวจสอบการติดตั้ง
    if command -v kubectl >/dev/null 2>&1; then
        kubectl_version=$(kubectl version --client -o yaml | grep "gitVersion" | head -1 | cut -d: -f2 | tr -d ' "')
        log "✅ ติดตั้ง kubectl เวอร์ชัน $kubectl_version สำเร็จ"
        return 0
    else
        error "❌ การติดตั้ง kubectl ล้มเหลว"
        exit 1
    fi
}

# ฟังก์ชันตั้งค่า kubeconfig
setup_kubeconfig() {
    local kubeconfig_path=$1
    
    log "กำลังตั้งค่า kubeconfig..."
    
    # สร้างไดเรกทอรี .kube ถ้ายังไม่มี
    mkdir -p "$KUBE_DIR"
    
    # คัดลอกไฟล์ kubeconfig
    cp "$kubeconfig_path" "$KUBE_DIR/config"
    
    # ตั้งค่าสิทธิ์
    chmod 600 "$KUBE_DIR/config"
    
    log "✅ ตั้งค่า kubeconfig สำเร็จ"
    
    # ตรวจสอบการเชื่อมต่อ
    if kubectl cluster-info >/dev/null 2>&1; then
        log "✅ เชื่อมต่อกับ Kubernetes cluster สำเร็จ"
        return 0
    else
        error "❌ ไม่สามารถเชื่อมต่อกับ Kubernetes cluster ได้"
        return 1
    fi
}

# ฟังก์ชันดาวน์โหลด kubeconfig จาก master node
download_kubeconfig() {
    local master_ip=$1
    local user=$(whoami)
    local remote_user=""
    local remote_path=""
    
    log "กำลังดาวน์โหลด kubeconfig จาก master node: $master_ip"
    
    # สอบถามชื่อผู้ใช้สำหรับ SSH
    read -p "ชื่อผู้ใช้สำหรับ SSH [$user]: " input_user
    remote_user=${input_user:-$user}
    
    # ลองเชื่อมต่อกับ master node
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$remote_user@$master_ip" "echo 2>&1" >/dev/null; then
        warn "ไม่สามารถเชื่อมต่อกับ master node ได้ด้วย SSH"
        warn "กรุณาตรวจสอบว่าเครื่อง master อนุญาตให้เชื่อมต่อด้วย SSH"
        exit 1
    fi
    
    # ตรวจสอบว่ามี kubeconfig บน master node
    possible_paths=(
        "/etc/kubernetes/admin.conf"
        "~/.kube/config"
        "~/kubeconfig.yaml"
        "~/kubeconfig-client-*.yaml"
    )
    
    for path in "${possible_paths[@]}"; do
        if ssh "$remote_user@$master_ip" "test -f $path" 2>/dev/null; then
            remote_path=$path
            log "พบไฟล์ kubeconfig ที่: $remote_path"
            break
        fi
    done
    
    if [ -z "$remote_path" ]; then
        warn "ไม่พบไฟล์ kubeconfig บน master node"
        read -p "ระบุตำแหน่งไฟล์ kubeconfig บน master node: " remote_path
        
        if [ -z "$remote_path" ]; then
            error "ไม่ได้ระบุตำแหน่งไฟล์ kubeconfig"
            exit 1
        fi
    fi
    
    # ดาวน์โหลดไฟล์ kubeconfig
    local temp_kubeconfig="kubeconfig-$(date +%s).yaml"
    if scp "$remote_user@$master_ip:$remote_path" "$temp_kubeconfig"; then
        log "✅ ดาวน์โหลด kubeconfig สำเร็จ: $temp_kubeconfig"
        
        # แก้ไข server URL ใน kubeconfig (ถ้าจำเป็น)
        local current_server=$(grep "server:" "$temp_kubeconfig" | head -1 | cut -d: -f2- | sed 's/^[ \t]*//')
        local current_ip=$(echo "$current_server" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
        
        if [[ "$current_ip" == "127.0.0.1" || "$current_ip" == "localhost" ]]; then
            log "กำลังแก้ไข server URL จาก $current_ip เป็น $master_ip"
            sed -i "s|server:.*|server: https://$master_ip:6443|g" "$temp_kubeconfig"
        fi
        
        # ตั้งค่า kubeconfig
        setup_kubeconfig "$temp_kubeconfig"
        
        # ลบไฟล์ชั่วคราว
        rm "$temp_kubeconfig"
        
        return 0
    else
        error "❌ ไม่สามารถดาวน์โหลด kubeconfig ได้"
        exit 1
    fi
}

# ฟังก์ชันตั้งค่า ArgoCD port forwarding
setup_argocd_port_forward() {
    log "กำลังตรวจสอบการติดตั้ง ArgoCD..."
    
    # ตรวจสอบว่ามี namespace argocd หรือไม่
    if ! kubectl get namespace argocd >/dev/null 2>&1; then
        warn "ไม่พบ namespace argocd"
        warn "อาจยังไม่ได้ติดตั้ง ArgoCD หรือใช้ namespace อื่น"
        return 1
    fi
    
    # ตรวจสอบว่า argocd-server ทำงานอยู่หรือไม่
    if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' | grep -q "Running"; then
        warn "Pod argocd-server ไม่ทำงาน"
        return 1
    fi
    
    log "กำลังตั้งค่า port forwarding สำหรับ ArgoCD..."
    
    # ตรวจสอบว่ามีการทำ port forwarding อยู่แล้วหรือไม่
    if pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
        log "พบการทำ port-forward สำหรับ ArgoCD อยู่แล้ว"
        return 0
    fi
    
    # สร้างสคริปต์ start-argocd-port-forward.sh
    cat > start-argocd-port-forward.sh << 'EOF'
#!/bin/bash
echo "🚀 กำลังเปิด port forwarding สำหรับ ArgoCD..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &
echo "✅ เข้าใช้งาน ArgoCD ได้ที่: https://localhost:8080"
echo "👤 Username: admin"
echo "🔑 Password: ดูได้จากคำสั่ง kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "กด Ctrl+C เพื่อหยุด port forwarding"
wait
EOF
    
    chmod +x start-argocd-port-forward.sh
    
    # สร้างสคริปต์ get-argocd-password.sh
    cat > get-argocd-password.sh << 'EOF'
#!/bin/bash
echo "🔑 กำลังดึงรหัสผ่าน ArgoCD admin..."
PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -n "$PASSWORD" ]; then
    echo "✅ รหัสผ่าน ArgoCD:"
    echo "👤 Username: admin"
    echo "🔑 Password: $PASSWORD"
else
    echo "❌ ไม่พบรหัสผ่าน ArgoCD"
    echo "อาจเกิดจาก:"
    echo "1. ArgoCD ถูกติดตั้งมานานและ secret ถูกลบไปแล้ว"
    echo "2. มีการเปลี่ยนรหัสผ่านแล้ว"
fi
EOF
    
    chmod +x get-argocd-password.sh
    
    log "✅ สร้างสคริปต์ start-argocd-port-forward.sh และ get-argocd-password.sh สำเร็จ"
    log "รันคำสั่ง ./start-argocd-port-forward.sh เพื่อเข้าใช้งาน ArgoCD"
    
    return 0
}

# เริ่มการทำงานหลัก
# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    log "ไม่พบ kubectl จะทำการติดตั้งให้อัตโนมัติ"
    install_kubectl
else
    log "ตรวจพบ kubectl แล้ว"
    kubectl_version=$(kubectl version --client -o yaml | grep "gitVersion" | head -1 | cut -d: -f2 | tr -d ' "')
    log "kubectl เวอร์ชัน: $kubectl_version"
fi

# ตรวจสอบว่า parameter เป็นไฟล์ kubeconfig หรือ IP
if [ -f "$INPUT" ]; then
    # กรณีเป็นไฟล์ kubeconfig
    log "พบไฟล์ $INPUT"
    setup_kubeconfig "$INPUT"
else
    # กรณีเป็น IP
    if [[ "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        download_kubeconfig "$INPUT"
    else
        error "ไม่พบไฟล์ $INPUT และไม่ใช่รูปแบบ IP address"
        exit 1
    fi
fi

# แสดงข้อมูล cluster
log "ข้อมูล Kubernetes cluster:"
kubectl cluster-info

echo ""
log "รายการ nodes ในระบบ:"
kubectl get nodes -o wide

# ตั้งค่า ArgoCD port forwarding
echo ""
setup_argocd_port_forward

# สรุปการตั้งค่า
echo ""
log "✅ การตั้งค่า Kubernetes client เสร็จสมบูรณ์"
echo ""
log "คำสั่งที่มีให้ใช้งาน:"
echo "  kubectl get nodes             - ดูรายการ nodes"
echo "  kubectl get pods --all-namespaces - ดูรายการ pods ทั้งหมด"
echo "  ./start-argocd-port-forward.sh - เปิด port forwarding สำหรับ ArgoCD"
echo "  ./get-argocd-password.sh      - ดูรหัสผ่าน ArgoCD admin"
echo ""
log "เข้าใช้งาน ArgoCD ได้ที่: https://localhost:8080"
echo "👤 Username: admin"
echo "🔑 Password: รันคำสั่ง ./get-argocd-password.sh"
