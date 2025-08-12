#!/bin/bash

# =============================================================================
# 🔗 Auto Join kind Cluster Client
# =============================================================================

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

echo "🔗 Auto Join kind Cluster Client"
echo "==============================="

# Check if kind is available
if ! command -v kind >/dev/null 2>&1; then
    log_error "kind ไม่ได้ติดตั้ง"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    log_error "kubectl ไม่ได้ติดตั้ง"
    exit 1
fi

# List available clusters
echo -e "\n1️⃣ ตรวจสอบ kind clusters ที่มีอยู่:"
CLUSTERS=$(kind get clusters 2>/dev/null)

if [ -z "$CLUSTERS" ]; then
    log_error "ไม่พบ kind clusters"
    echo "   กรุณาสร้าง cluster ก่อน:"
    echo "   ./install-full-stack.sh"
    exit 1
fi

echo "   พบ clusters:"
echo "$CLUSTERS" | sed 's/^/   - /'

# Select cluster
if [ $# -eq 1 ]; then
    CLUSTER_NAME="$1"
else
    echo -e "\n📝 เลือก cluster:"
    select CLUSTER_NAME in $CLUSTERS; do
        if [ -n "$CLUSTER_NAME" ]; then
            break
        fi
        echo "เลือกไม่ถูกต้อง"
    done
fi

log "เลือก cluster: $CLUSTER_NAME"

# Get cluster info
echo -e "\n2️⃣ ข้อมูล cluster:"
kubectl cluster-info --context kind-$CLUSTER_NAME 2>/dev/null || {
    log_error "ไม่สามารถเชื่อมต่อ cluster ได้"
    exit 1
}

# Get server IP/Port
CLUSTER_ENDPOINT=$(kubectl config view --context kind-$CLUSTER_NAME -o jsonpath='{.clusters[0].cluster.server}')
log "Cluster endpoint: $CLUSTER_ENDPOINT"

# Extract port
CLUSTER_PORT=$(echo $CLUSTER_ENDPOINT | sed 's/.*://')
log "Cluster port: $CLUSTER_PORT"

# Get current server IP (for Docker networks)
if command -v docker >/dev/null 2>&1; then
    CONTAINER_NAME="$CLUSTER_NAME-control-plane"
    CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $CONTAINER_NAME 2>/dev/null)
    if [ -n "$CONTAINER_IP" ]; then
        log "Container IP: $CONTAINER_IP"
    fi
fi

# Get current external IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "unknown")
LOCAL_IP=$(ip route get 1 | awk '{print $7}' | head -1 2>/dev/null || hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")

echo -e "\n3️⃣ ตัวเลือก IP สำหรับ client connection:"
echo "   1. Local: 127.0.0.1 (localhost only)"
echo "   2. LAN: $LOCAL_IP (local network)"
if [ "$EXTERNAL_IP" != "unknown" ]; then
    echo "   3. External: $EXTERNAL_IP (internet)"
fi
echo ""

read -p "เลือก IP type (1-3): " ip_choice

case $ip_choice in
    1) TARGET_IP="127.0.0.1" ;;
    2) TARGET_IP="$LOCAL_IP" ;;
    3) TARGET_IP="$EXTERNAL_IP" ;;
    *) TARGET_IP="127.0.0.1" ;;
esac

log "ใช้ IP: $TARGET_IP"

# Generate kubeconfig
echo -e "\n4️⃣ สร้าง kubeconfig สำหรับ client:"

OUTPUT_FILE="kubeconfig-$CLUSTER_NAME-client.yaml"
kind get kubeconfig --name=$CLUSTER_NAME > $OUTPUT_FILE

if [ $? -eq 0 ]; then
    log "✅ สร้าง kubeconfig: $OUTPUT_FILE"
    
    # Replace server IP
    if [ "$TARGET_IP" != "127.0.0.1" ]; then
        sed -i "s/127.0.0.1/$TARGET_IP/g" $OUTPUT_FILE
        log "✅ แก้ไข server IP เป็น $TARGET_IP"
    fi
    
    # Show content
    echo -e "\n📄 เนื้อหา kubeconfig:"
    cat $OUTPUT_FILE | head -20
    echo "   ..."
    
else
    log_error "❌ ไม่สามารถสร้าง kubeconfig ได้"
    exit 1
fi

# Generate client setup script
echo -e "\n5️⃣ สร้างสคริปต์สำหรับ client machine:"

CLIENT_SCRIPT="setup-client-$CLUSTER_NAME.sh"
cat > $CLIENT_SCRIPT << EOF
#!/bin/bash

# Auto-generated client setup script for kind cluster: $CLUSTER_NAME
# Generated on: $(date)

echo "🔗 Setup Kubernetes Client for $CLUSTER_NAME"
echo "============================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "\${GREEN}[INFO]\${NC} \$1"; }
log_warn() { echo -e "\${YELLOW}[WARN]\${NC} \$1"; }
log_error() { echo -e "\${RED}[ERROR]\${NC} \$1"; }

# 1. Check kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    log_warn "kubectl ไม่ได้ติดตั้ง"
    echo "Installing kubectl..."
    
    # Install kubectl (Linux)
    curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    
    if ! command -v kubectl >/dev/null 2>&1; then
        log_error "ไม่สามารถติดตั้ง kubectl ได้"
        exit 1
    fi
fi

log "✅ kubectl version: \$(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# 2. Setup kubeconfig
log "Setup kubeconfig..."
mkdir -p ~/.kube

# Backup existing config
if [ -f ~/.kube/config ]; then
    cp ~/.kube/config ~/.kube/config.backup.\$(date +%Y%m%d_%H%M%S)
    log "✅ Backup existing config"
fi

# Use the kubeconfig from this directory
if [ -f kubeconfig-$CLUSTER_NAME-client.yaml ]; then
    cp kubeconfig-$CLUSTER_NAME-client.yaml ~/.kube/config
    log "✅ Setup kubeconfig"
else
    log_error "❌ ไม่พบไฟล์ kubeconfig-$CLUSTER_NAME-client.yaml"
    exit 1
fi

# 3. Test connection
log "ทดสอบการเชื่อมต่อ..."
if kubectl cluster-info >/dev/null 2>&1; then
    log "✅ เชื่อมต่อ cluster สำเร็จ"
    
    echo ""
    echo "📊 Cluster Information:"
    kubectl cluster-info
    
    echo ""
    echo "🔍 Nodes:"
    kubectl get nodes -o wide
    
    echo ""
    echo "📦 Namespaces:"
    kubectl get namespaces
    
    # Check ArgoCD
    if kubectl get namespace argocd >/dev/null 2>&1; then
        echo ""
        echo "🚀 ArgoCD Status:"
        kubectl get pods -n argocd
        
        echo ""
        echo "🌐 ArgoCD Service:"
        kubectl get svc -n argocd
        
        echo ""
        echo "🔑 ArgoCD Admin Password:"
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
        echo ""
        
        echo ""
        echo "💡 Access ArgoCD:"
        echo "   1. Port Forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo "   2. Browse: http://localhost:8080"
        echo "   3. Login: admin / <password above>"
    fi
    
else
    log_error "❌ ไม่สามารถเชื่อมต่อ cluster ได้"
    echo ""
    echo "🔍 Troubleshooting:"
    echo "   1. ตรวจสอบ network connectivity:"
    echo "      ping $TARGET_IP"
    echo "      telnet $TARGET_IP $CLUSTER_PORT"
    echo ""
    echo "   2. ตรวจสอบ firewall:"
    echo "      Port $CLUSTER_PORT ต้องเปิด"
    echo ""
    echo "   3. ตรวจสอบ cluster บน server:"
    echo "      kubectl cluster-info"
    echo "      docker ps | grep $CLUSTER_NAME"
    exit 1
fi

echo ""
log "🎉 Setup เสร็จสิ้น!"
echo ""
echo "📝 คำสั่งพื้นฐาน:"
echo "   kubectl get nodes"
echo "   kubectl get pods --all-namespaces"
echo "   kubectl config get-contexts"
echo ""

EOF

chmod +x $CLIENT_SCRIPT
log "✅ สร้างสคริปต์ client: $CLIENT_SCRIPT"

# Generate copy instructions
echo -e "\n6️⃣ วิธีใช้งานบน client machine:"
echo "================================"

echo "📋 Copy files ไปยัง client machine:"
echo "   scp $OUTPUT_FILE user@client-machine:~/"
echo "   scp $CLIENT_SCRIPT user@client-machine:~/"
echo ""

echo "📋 รันบน client machine:"
echo "   chmod +x $CLIENT_SCRIPT"
echo "   ./$CLIENT_SCRIPT"
echo ""

echo "📋 หรือ manual setup:"
echo "   mkdir -p ~/.kube"
echo "   cp $OUTPUT_FILE ~/.kube/config"
echo "   kubectl cluster-info"
echo ""

# Test current connection
echo -e "\n7️⃣ ทดสอบการเชื่อมต่อจาก server:"
if kubectl cluster-info >/dev/null 2>&1; then
    log "✅ เชื่อมต่อจาก server ได้"
    
    echo ""
    echo "📊 Cluster Info:"
    kubectl cluster-info
    
    # Check if accessible from target IP
    if [ "$TARGET_IP" != "127.0.0.1" ]; then
        echo ""
        log "🔍 ทดสอบการเข้าถึงจาก IP: $TARGET_IP"
        if timeout 5 bash -c "echo >/dev/tcp/$TARGET_IP/$CLUSTER_PORT" 2>/dev/null; then
            log "✅ Port $CLUSTER_PORT เปิดอยู่บน $TARGET_IP"
        else
            log_warn "⚠️ ไม่สามารถเข้าถึง port $CLUSTER_PORT บน $TARGET_IP ได้"
            echo "   อาจต้องแก้ไข firewall หรือ network settings"
        fi
    fi
    
else
    log_error "❌ เชื่อมต่อ cluster ไม่ได้"
fi

echo -e "\n📁 ไฟล์ที่สร้าง:"
echo "   - $OUTPUT_FILE (kubeconfig)"
echo "   - $CLIENT_SCRIPT (client setup script)"

echo -e "\n${GREEN}🎯 เสร็จสิ้น!${NC}"
