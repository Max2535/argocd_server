#!/bin/bash

# =============================================================================
# 🚀 ArgoCD Full Stack Auto Installer
# =============================================================================
# ติดตั้ง Kubernetes + ArgoCD + Nginx Reverse Proxy แบบ One-Click
# รองรับ: Linux (Ubuntu/CentOS/RHEL) และ Windows (Git Bash/WSL)
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="$(pwd)"
LOG_FILE="$INSTALL_DIR/argocd-install.log"
ARGOCD_PASSWORD=""
KUBECTL_PID=""

# =============================================================================
# 🔧 Utility Functions
# =============================================================================

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}" | tee -a "$LOG_FILE"
}

# Check if running on Windows
is_windows() {
    [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$OS" == "Windows_NT" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for user confirmation
confirm() {
    local message="$1"
    if [[ "$AUTO_YES" == "true" ]]; then
        return 0
    fi
    
    echo -e "${CYAN}$message (y/N): ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# 🔍 System Detection and Requirements Check
# =============================================================================

detect_system() {
    log "🔍 ตรวจสอบระบบปฏิบัติการ..."
    
    if is_windows; then
        OS_TYPE="windows"
        log_info "ระบบ: Windows (Git Bash/WSL)"
    elif is_linux; then
        OS_TYPE="linux"
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            DISTRO="$ID"
            VERSION="$VERSION_ID"
            log_info "ระบบ: $PRETTY_NAME"
        else
            DISTRO="unknown"
            log_warn "ไม่สามารถระบุ Linux distribution ได้"
        fi
    else
        log_error "ระบบปฏิบัติการไม่รองรับ"
        exit 1
    fi
}

check_requirements() {
    log "📋 ตรวจสอบความต้องการขั้นต่ำ..."
    
    local errors=0
    
    # Check RAM
    if is_linux; then
        RAM_GB=$(free -m | awk 'NR==2{printf "%.1f", $2/1024}')
        if (( $(echo "$RAM_GB < 4" | bc -l 2>/dev/null || echo "0") )); then
            log_error "RAM: ${RAM_GB}GB (ต้องการอย่างน้อย 4GB)"
            ((errors++))
        else
            log "✅ RAM: ${RAM_GB}GB"
        fi
    else
        log_info "RAM: ข้ามการตรวจสอบบน Windows"
    fi
    
    # Check CPU
    CPU_CORES=$(nproc 2>/dev/null || echo "1")
    if [[ $CPU_CORES -lt 2 ]]; then
        log_error "CPU: ${CPU_CORES} cores (ต้องการอย่างน้อย 2 cores)"
        ((errors++))
    else
        log "✅ CPU: ${CPU_CORES} cores"
    fi
    
    # Check Disk
    if command_exists df; then
        DISK_GB=$(df / 2>/dev/null | awk 'NR==2{printf "%.1f", $4/1024/1024}' || echo "50")
        if (( $(echo "$DISK_GB < 20" | bc -l 2>/dev/null || echo "0") )); then
            log_error "Disk: ${DISK_GB}GB available (ต้องการอย่างน้อย 20GB)"
            ((errors++))
        else
            log "✅ Disk: ${DISK_GB}GB available"
        fi
    fi
    
    # Check Internet
    if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -n 1 8.8.8.8 >/dev/null 2>&1; then
        log "✅ Internet connection"
    else
        log_error "ไม่สามารถเชื่อมต่อ Internet ได้"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "พบปัญหา $errors รายการ"
        if ! confirm "ต้องการดำเนินการต่อหรือไม่?"; then
            exit 1
        fi
    fi
}

# =============================================================================
# 📦 Package Installation Functions
# =============================================================================

install_dependencies_linux() {
    log "📦 ติดตั้ง dependencies สำหรับ Linux..."
    
    if is_root; then
        log_warn "กำลังรันด้วย root user (ไม่แนะนำ)"
    fi
    
    # Detect package manager and install dependencies
    if command_exists apt-get; then
        # Ubuntu/Debian
        log_info "ใช้ APT package manager"
        sudo apt-get update
        sudo apt-get install -y curl wget gnupg2 software-properties-common apt-transport-https ca-certificates lsb-release
        
        # Install Docker
        if ! command_exists docker; then
            log_info "ติดตั้ง Docker..."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo usermod -aG docker $USER
        fi
        
    elif command_exists yum; then
        # RHEL/CentOS
        log_info "ใช้ YUM package manager"
        sudo yum update -y
        sudo yum install -y curl wget
        
        # Install Docker
        if ! command_exists docker; then
            log_info "ติดตั้ง Docker..."
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo usermod -aG docker $USER
        fi
        
    elif command_exists dnf; then
        # Fedora
        log_info "ใช้ DNF package manager"
        sudo dnf update -y
        sudo dnf install -y curl wget
        
        # Install Docker
        if ! command_exists docker; then
            log_info "ติดตั้ง Docker..."
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            sudo usermod -aG docker $USER
        fi
    else
        log_error "ไม่สามารถระบุ package manager ได้"
        exit 1
    fi
    
    # Start Docker and fix permissions
    fix_docker_permissions
    
    # Install kubectl
    install_kubectl_linux
    
    # Install kind
    install_kind_linux
}

install_kubectl_linux() {
    if ! command_exists kubectl; then
        log_info "ติดตั้ง kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
}

install_kind_linux() {
    if ! command_exists kind; then
        log_info "ติดตั้ง kind..."
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
}

fix_docker_permissions() {
    log "🔧 แก้ไขปัญหา Docker permissions..."
    
    # Start Docker service
    log_info "เริ่ม Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    log_info "เพิ่ม user เข้า docker group..."
    sudo usermod -aG docker $USER
    
    # Fix socket permissions
    log_info "แก้ไข Docker socket permissions..."
    sudo chmod 666 /var/run/docker.sock
    
    # Test Docker connection
    if docker info >/dev/null 2>&1; then
        log "✅ Docker ทำงานปกติ"
    else
        log_warn "Docker อาจยังไม่พร้อม - ลอง logout/login หรือ reboot"
        log_info "หรือรัน: newgrp docker"
        
        # Try newgrp workaround
        if command_exists newgrp; then
            log_info "พยายามแก้ไขด้วย newgrp..."
            echo "docker info >/dev/null 2>&1" | newgrp docker
        fi
        
        # Final check with sudo
        if sudo docker info >/dev/null 2>&1; then
            log_warn "Docker ทำงานด้วย sudo เท่านั้น"
            log_info "แนะนำให้ logout/login หรือ reboot เพื่อใช้งานโดยไม่ต้อง sudo"
        else
            log_error "Docker ยังคงมีปัญหา"
            log_info "โปรดตรวจสอบ:"
            log_info "1. sudo systemctl status docker"
            log_info "2. sudo journalctl -u docker.service"
            if ! confirm "ต้องการดำเนินการต่อหรือไม่?"; then
                exit 1
            fi
        fi
    fi
}

install_dependencies_windows() {
    log "📦 ตรวจสอบ dependencies สำหรับ Windows..."
    
    # Check Docker
    if ! command_exists docker; then
        log_error "Docker ไม่ได้ติดตั้ง"
        log_info "กรุณาติดตั้ง Docker Desktop:"
        log_info "1. ดาวน์โหลดจาก: https://docs.docker.com/desktop/install/windows/"
        log_info "2. ติดตั้งและเปิดใช้งาน Kubernetes ใน Docker Desktop"
        log_info "3. รัน script นี้อีกครั้ง"
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker ไม่ทำงาน กรุณาเปิด Docker Desktop"
        exit 1
    fi
    
    # Check kubectl
    if ! command_exists kubectl; then
        log_error "kubectl ไม่ได้ติดตั้ง"
        log_info "กรุณาติดตั้ง kubectl:"
        log_info "1. choco install kubernetes-cli"
        log_info "2. หรือดาวน์โหลดจาก: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
        exit 1
    fi
    
    # Check kind
    if ! command_exists kind; then
        log_info "ติดตั้ง kind..."
        if command_exists choco; then
            choco install kind
        else
            log_info "กรุณาติดตั้ง kind manually:"
            log_info "1. ดาวน์โหลดจาก: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
            log_info "2. หรือติดตั้ง Chocolatey และรัน: choco install kind"
            if ! confirm "ติดตั้ง kind แล้วหรือยัง?"; then
                exit 1
            fi
        fi
    fi
}

# =============================================================================
# ⚙️ Kubernetes Cluster Setup
# =============================================================================

setup_kubernetes_cluster() {
    log "⚙️ ตั้งค่า Kubernetes cluster..."
    
    # Check Docker first for Linux
    if is_linux; then
        if ! docker info >/dev/null 2>&1; then
            log_warn "Docker ไม่พร้อม - พยายามแก้ไขอีกครั้ง..."
            fix_docker_permissions
            
            # Final check
            if ! docker info >/dev/null 2>&1 && ! sudo docker info >/dev/null 2>&1; then
                log_error "Docker ยังคงไม่ทำงาน"
                log_info "กรุณาแก้ไขปัญหา Docker ก่อน:"
                log_info "1. sudo systemctl restart docker"
                log_info "2. sudo chmod 666 /var/run/docker.sock"
                log_info "3. logout และ login ใหม่"
                log_info "4. หรือ reboot server"
                exit 1
            fi
        fi
    fi
    
    # Check if cluster already exists
    if kubectl cluster-info >/dev/null 2>&1; then
        CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
        log_warn "พบ Kubernetes cluster ที่มีอยู่แล้ว: $CURRENT_CONTEXT"
        
        if confirm "ต้องการใช้ cluster ที่มีอยู่หรือไม่?"; then
            log "✅ ใช้ cluster ที่มีอยู่: $CURRENT_CONTEXT"
            return 0
        fi
    fi
    
    # Create new kind cluster
    log_info "สร้าง kind cluster ใหม่..."
    
    # Delete existing cluster if any
    kind delete cluster --name argocd-cluster 2>/dev/null || true
    
    # Create kind cluster configuration
    cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: argocd-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
EOF
    
    # Create cluster
    kind create cluster --config kind-config.yaml --wait 300s
    
    if [[ $? -eq 0 ]]; then
        log "✅ Kind cluster สร้างสำเร็จ"
        kubectl config use-context kind-argocd-cluster
    else
        log_error "ไม่สามารถสร้าง kind cluster ได้"
        exit 1
    fi
    
    # Wait for cluster to be ready
    log_info "รอให้ cluster พร้อม..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Clean up
    rm -f kind-config.yaml
}

# =============================================================================
# 🔱 ArgoCD Installation
# =============================================================================

install_argocd() {
    log "🔱 ติดตั้ง ArgoCD..."
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    log_info "ดาวน์โหลดและติดตั้ง ArgoCD manifests..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "รอให้ ArgoCD pods เริ่มต้น (อาจใช้เวลา 2-3 นาที)..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    
    if [[ $? -eq 0 ]]; then
        log "✅ ArgoCD ติดตั้งสำเร็จ"
    else
        log_error "ArgoCD ติดตั้งไม่สำเร็จ"
        exit 1
    fi
    
    # Get initial admin password
    log_info "รับรหัสผ่าน admin เริ่มต้น..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
        if [[ ! -z "$ARGOCD_PASSWORD" ]]; then
            log "✅ รหัสผ่าน admin: $ARGOCD_PASSWORD"
            break
        fi
        log_info "รอรหัสผ่าน admin... (ครั้งที่ $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [[ -z "$ARGOCD_PASSWORD" ]]; then
        log_warn "ไม่สามารถรับรหัสผ่าน admin ได้ ลองใช้คำสั่งนี้ภายหลัง:"
        log_warn "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
    fi
}

# =============================================================================
# 🌐 Nginx Reverse Proxy Setup
# =============================================================================

setup_nginx_proxy() {
    log "🌐 ตั้งค่า Nginx Reverse Proxy..."
    
    # Create nginx config directory
    mkdir -p nginx-proxy
    
    # Create nginx configuration
    cat > nginx-proxy/default.conf <<EOF
upstream argocd {
    server host.docker.internal:8080;
}

server {
    listen 80;
    server_name localhost;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    location / {
        proxy_pass https://argocd;
        proxy_ssl_verify off;
        
        # Headers for ArgoCD
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        
        # WebSocket support for ArgoCD
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
        
        # Handle large requests
        client_max_body_size 0;
        proxy_request_buffering off;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "ArgoCD Proxy OK\\n";
        add_header Content-Type text/plain;
    }
    
    # Nginx status page
    location /nginx-status {
        access_log off;
        return 200 "Nginx OK\\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Create docker-compose for nginx
    cat > docker-compose-proxy.yml <<EOF
services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd-proxy
    ports:
      - "80:80"
    volumes:
      - ./nginx-proxy/default.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/nginx-status"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - argocd-net

networks:
  argocd-net:
    driver: bridge
EOF
    
    log "✅ Nginx configuration สร้างสำเร็จ"
}

start_nginx_proxy() {
    log "🚀 เริ่มต้น Nginx Reverse Proxy..."
    
    # Stop existing nginx if any
    docker-compose -f docker-compose-proxy.yml down 2>/dev/null || true
    
    # Start nginx
    docker-compose -f docker-compose-proxy.yml up -d
    
    if [[ $? -eq 0 ]]; then
        log "✅ Nginx Reverse Proxy เริ่มต้นสำเร็จ"
        
        # Wait for nginx to be ready
        sleep 5
        
        # Test nginx
        if curl -s -o /dev/null -w "%{http_code}" http://localhost/nginx-status 2>/dev/null | grep -q "200"; then
            log "✅ Nginx health check ผ่าน"
        else
            log_warn "Nginx health check ไม่ผ่าน"
        fi
    else
        log_error "Nginx Reverse Proxy เริ่มต้นไม่สำเร็จ"
        exit 1
    fi
}

# =============================================================================
# 🔗 Port Forwarding Setup
# =============================================================================

setup_port_forwarding() {
    log "🔗 ตั้งค่า kubectl port-forwarding..."
    
    # Kill existing port-forward processes
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
    
    # Start port-forward in background
    kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
    KUBECTL_PID=$!
    
    # Save PID for cleanup
    echo $KUBECTL_PID > .kubectl-proxy.pid
    
    # Wait and test
    sleep 5
    if kill -0 $KUBECTL_PID 2>/dev/null; then
        if curl -k -s https://localhost:8080 >/dev/null 2>&1; then
            log "✅ kubectl port-forward ทำงานอยู่ (PID: $KUBECTL_PID)"
        else
            log_warn "kubectl port-forward ทำงานแต่ ArgoCD ยังไม่พร้อม"
        fi
    else
        log_error "kubectl port-forward ไม่ทำงาน"
        exit 1
    fi
}

# =============================================================================
# 🧪 System Testing
# =============================================================================

test_installation() {
    log "🧪 ทดสอบการติดตั้ง..."
    
    local errors=0
    
    # Test Kubernetes cluster
    log_info "ทดสอบ Kubernetes cluster..."
    if kubectl cluster-info >/dev/null 2>&1; then
        log "✅ Kubernetes cluster ทำงานอยู่"
    else
        log_error "Kubernetes cluster ไม่ทำงาน"
        ((errors++))
    fi
    
    # Test ArgoCD pods
    log_info "ทดสอบ ArgoCD pods..."
    local ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l)
    local total_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
    
    if [[ $ready_pods -gt 0 ]] && [[ $ready_pods -eq $total_pods ]]; then
        log "✅ ArgoCD pods ทำงานอยู่ ($ready_pods/$total_pods)"
    else
        log_error "ArgoCD pods ไม่ทำงาง ($ready_pods/$total_pods)"
        ((errors++))
    fi
    
    # Test port forwarding
    log_info "ทดสอบ kubectl port-forward..."
    if curl -k -s https://localhost:8080 >/dev/null 2>&1; then
        log "✅ kubectl port-forward ทำงานอยู่"
    else
        log_error "kubectl port-forward ไม่ทำงาน"
        ((errors++))
    fi
    
    # Test nginx proxy
    log_info "ทดสอบ Nginx proxy..."
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
    if [[ "$response" == "200" ]]; then
        log "✅ Nginx proxy ทำงานอยู่"
    else
        log_error "Nginx proxy ไม่ทำงาน (HTTP $response)"
        ((errors++))
    fi
    
    # Test ArgoCD UI
    log_info "ทดสอบ ArgoCD UI..."
    if curl -s http://localhost 2>/dev/null | grep -q "Argo CD"; then
        log "✅ ArgoCD UI พร้อมใช้งาน"
    else
        log_error "ArgoCD UI ไม่พร้อมใช้งาน"
        ((errors++))
    fi
    
    return $errors
}

# =============================================================================
# 📝 Management Scripts Creation
# =============================================================================

create_management_scripts() {
    log "📝 สร้าง management scripts..."
    
    # Create start script
    cat > start-argocd.sh <<'EOF'
#!/bin/bash
echo "🚀 Starting ArgoCD Full Stack..."

# Start Kubernetes cluster (kind)
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "⚠️  Kubernetes cluster ไม่ทำงาน กำลังเริ่มต้น..."
    if command -v kind >/dev/null 2>&1; then
        kind create cluster --name argocd-cluster 2>/dev/null || echo "Cluster อาจมีอยู่แล้ว"
    fi
fi

# Start port forwarding
echo "🔗 Starting port forwarding..."
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
echo $! > .kubectl-proxy.pid

# Start nginx proxy
echo "🌐 Starting Nginx proxy..."
docker-compose -f docker-compose-proxy.yml up -d

echo "✅ ArgoCD เริ่มต้นสำเร็จ!"
echo "🌐 URL: http://localhost"
echo "👤 Username: admin"
echo "🔑 Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo 'ใช้คำสั่ง get-password.sh')"
EOF
    
    # Create stop script
    cat > stop-argocd.sh <<'EOF'
#!/bin/bash
echo "🛑 Stopping ArgoCD Full Stack..."

# Stop nginx proxy
echo "🌐 Stopping Nginx proxy..."
docker-compose -f docker-compose-proxy.yml down 2>/dev/null || true

# Stop port forwarding
echo "🔗 Stopping port forwarding..."
if [[ -f .kubectl-proxy.pid ]]; then
    kill $(cat .kubectl-proxy.pid) 2>/dev/null || true
    rm -f .kubectl-proxy.pid
fi
pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true

echo "✅ ArgoCD หยุดแล้ว"
EOF
    
    # Create status script
    cat > status-argocd.sh <<'EOF'
#!/bin/bash
echo "📊 ArgoCD Full Stack Status"
echo "=========================="

# Kubernetes cluster
echo "🔧 Kubernetes Cluster:"
if kubectl cluster-info >/dev/null 2>&1; then
    echo "  ✅ Running ($(kubectl config current-context))"
    echo "  📦 Nodes: $(kubectl get nodes --no-headers | wc -l)"
else
    echo "  ❌ Not Running"
fi

# ArgoCD
echo ""
echo "🔱 ArgoCD:"
ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l || echo 0)
total_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo 0)
if [[ $ready_pods -gt 0 ]]; then
    echo "  ✅ Running ($ready_pods/$total_pods pods)"
else
    echo "  ❌ Not Running"
fi

# Port forwarding
echo ""
echo "🔗 Port Forwarding:"
if [[ -f .kubectl-proxy.pid ]] && kill -0 $(cat .kubectl-proxy.pid) 2>/dev/null; then
    echo "  ✅ Running (PID: $(cat .kubectl-proxy.pid))"
else
    echo "  ❌ Not Running"
fi

# Nginx proxy
echo ""
echo "🌐 Nginx Proxy:"
if docker ps | grep -q nginx-argocd-proxy; then
    echo "  ✅ Running"
    if curl -s http://localhost/nginx-status >/dev/null 2>&1; then
        echo "  ✅ Health check: OK"
    else
        echo "  ⚠️  Health check: Failed"
    fi
else
    echo "  ❌ Not Running"
fi

# ArgoCD UI
echo ""
echo "🖥️  ArgoCD UI:"
if curl -s http://localhost >/dev/null 2>&1; then
    echo "  ✅ Accessible at http://localhost"
    echo "  👤 Username: admin"
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    if [[ ! -z "$password" ]]; then
        echo "  🔑 Password: $password"
    else
        echo "  🔑 Password: ใช้คำสั่ง get-password.sh"
    fi
else
    echo "  ❌ Not Accessible"
fi
EOF
    
    # Create password retrieval script
    cat > get-password.sh <<'EOF'
#!/bin/bash
echo "🔑 ArgoCD Admin Password:"
password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
if [[ ! -z "$password" ]]; then
    echo "Password: $password"
else
    echo "❌ ไม่สามารถรับรหัสผ่านได้"
    echo "ลองคำสั่ง: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi
EOF
    
    # Create uninstall script
    cat > uninstall-argocd.sh <<'EOF'
#!/bin/bash
echo "🗑️  Uninstalling ArgoCD Full Stack..."

read -p "⚠️  คำเตือน: การกระทำนี้จะลบ ArgoCD ทั้งหมด ต้องการดำเนินการต่อหรือไม่? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "ยกเลิกการลบ"
    exit 0
fi

# Stop services
echo "🛑 Stopping services..."
./stop-argocd.sh 2>/dev/null || true

# Remove ArgoCD
echo "🔱 Removing ArgoCD..."
kubectl delete namespace argocd 2>/dev/null || true

# Remove kind cluster
echo "🔧 Removing kind cluster..."
kind delete cluster --name argocd-cluster 2>/dev/null || true

# Remove Docker containers and images
echo "🐳 Cleaning up Docker..."
docker-compose -f docker-compose-proxy.yml down --rmi all 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Remove files
echo "🧹 Cleaning up files..."
rm -f .kubectl-proxy.pid
rm -rf nginx-proxy/
rm -f docker-compose-proxy.yml
rm -f kind-config.yaml

echo "✅ ArgoCD ถูกลบเรียบร้อยแล้ว"
EOF
    
    # Make scripts executable
    chmod +x start-argocd.sh stop-argocd.sh status-argocd.sh get-password.sh uninstall-argocd.sh
    
    log "✅ Management scripts สร้างสำเร็จ"
}

# =============================================================================
# 📋 Installation Summary and Instructions
# =============================================================================

show_installation_summary() {
    log "🎉 การติดตั้ง ArgoCD เสร็จสมบูรณ์!"
    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}🚀 ArgoCD Full Stack Ready! 🚀${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo -e "${CYAN}📋 ข้อมูลการเข้าใช้งาน:${NC}"
    echo -e "   🌐 URL: ${BLUE}http://localhost${NC}"
    echo -e "   👤 Username: ${YELLOW}admin${NC}"
    if [[ ! -z "$ARGOCD_PASSWORD" ]]; then
        echo -e "   🔑 Password: ${YELLOW}$ARGOCD_PASSWORD${NC}"
    else
        echo -e "   🔑 Password: ใช้คำสั่ง ${YELLOW}./get-password.sh${NC}"
    fi
    echo ""
    echo -e "${CYAN}🛠️  Management Commands:${NC}"
    echo -e "   ${GREEN}./start-argocd.sh${NC}     - เริ่มต้น ArgoCD"
    echo -e "   ${RED}./stop-argocd.sh${NC}      - หยุด ArgoCD"
    echo -e "   ${BLUE}./status-argocd.sh${NC}    - ตรวจสอบสถานะ"
    echo -e "   ${YELLOW}./get-password.sh${NC}     - ดูรหัสผ่าน admin"
    echo -e "   ${RED}./uninstall-argocd.sh${NC} - ถอนการติดตั้ง"
    echo ""
    echo -e "${CYAN}📦 ส่วนประกอบที่ติดตั้ง:${NC}"
    echo -e "   ✅ Kubernetes cluster (kind)"
    echo -e "   ✅ ArgoCD"
    echo -e "   ✅ Nginx Reverse Proxy"
    echo -e "   ✅ Management Scripts"
    echo ""
    echo -e "${CYAN}🔗 Links:${NC}"
    echo -e "   📖 ArgoCD Documentation: ${BLUE}https://argo-cd.readthedocs.io/${NC}"
    echo -e "   🎓 Getting Started Guide: ${BLUE}https://argo-cd.readthedocs.io/en/stable/getting_started/${NC}"
    echo ""
    echo -e "${GREEN}🎯 Ready to deploy your applications with GitOps!${NC}"
    echo ""
}

# =============================================================================
# 🚨 Error Handling and Cleanup
# =============================================================================

cleanup_on_error() {
    log_error "การติดตั้งไม่สำเร็จ กำลังทำความสะอาด..."
    
    # Stop services
    docker-compose -f docker-compose-proxy.yml down 2>/dev/null || true
    
    # Kill port forwarding
    if [[ ! -z "$KUBECTL_PID" ]]; then
        kill $KUBECTL_PID 2>/dev/null || true
    fi
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
    
    # Remove temporary files
    rm -f .kubectl-proxy.pid kind-config.yaml docker-compose-proxy.yml
    
    log_error "ดู log file สำหรับรายละเอียด: $LOG_FILE"
}

# Set trap for cleanup on error
trap cleanup_on_error ERR

# =============================================================================
# 🎬 Main Installation Flow
# =============================================================================

main() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║              🚀 ArgoCD Full Stack Auto Installer 🚀              ║"
    echo "║                                                                  ║"
    echo "║  ติดตั้ง Kubernetes + ArgoCD + Nginx Reverse Proxy แบบ One-Click  ║"
    echo "║                                                                  ║"
    echo "║        รองรับ: Linux (Ubuntu/CentOS/RHEL) และ Windows            ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Parse command line arguments
    AUTO_YES=false
    SKIP_DEPS=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                AUTO_YES=true
                shift
                ;;
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -y, --yes       ตอบ 'yes' ทุกคำถาม (non-interactive mode)"
                echo "  --skip-deps     ข้ามการติดตั้ง dependencies"
                echo "  -h, --help      แสดงข้อมูลนี้"
                exit 0
                ;;
            *)
                log_error "ตัวเลือกไม่รู้จัก: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "ArgoCD Full Stack Installation Log - $(date)" > "$LOG_FILE"
    
    log "🏁 เริ่มต้นการติดตั้ง ArgoCD Full Stack..."
    
    # Step 1: Detect system
    detect_system
    
    # Step 2: Check requirements
    check_requirements
    
    # Step 3: Install dependencies
    if [[ "$SKIP_DEPS" != "true" ]]; then
        if is_linux; then
            install_dependencies_linux
        else
            install_dependencies_windows
        fi
    else
        log_info "ข้ามการติดตั้ง dependencies"
    fi
    
    # Step 4: Setup Kubernetes cluster
    setup_kubernetes_cluster
    
    # Step 5: Install ArgoCD
    install_argocd
    
    # Step 6: Setup port forwarding
    setup_port_forwarding
    
    # Step 7: Setup Nginx reverse proxy
    setup_nginx_proxy
    start_nginx_proxy
    
    # Step 8: Test installation
    log "🧪 ทดสอบการติดตั้ง..."
    if ! test_installation; then
        log_error "การทดสอบไม่ผ่าน"
        exit 1
    fi
    
    # Step 9: Create management scripts
    create_management_scripts
    
    # Step 10: Show summary
    show_installation_summary
    
    log "✅ การติดตั้งเสร็จสมบูรณ์!"
}

# =============================================================================
# 🚀 Script Entry Point
# =============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
