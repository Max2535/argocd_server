#!/bin/bash

echo "🚀 สคริปต์เปิดและตั้งค่า Services สำหรับ Kubernetes + ArgoCD"
echo "================================================================"

# Function to check if running on Windows
is_windows() {
    [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$OS" == "Windows_NT" ]]
}

# Function to start Docker
start_docker() {
    echo "🐳 กำลังเปิด Docker..."
    
    if is_windows; then
        echo "📋 สำหรับ Windows:"
        echo "   1. เปิด Docker Desktop จาก Start Menu"
        echo "   2. รอให้ Docker Desktop เริ่มต้นเสร็จ"
        echo "   3. ตรวจสอบว่ามี whale icon ใน system tray"
        
        # Try to start Docker Desktop if it's installed
        if [ -f "/c/Program Files/Docker/Docker/Docker Desktop.exe" ]; then
            echo "🔄 พยายามเปิด Docker Desktop..."
            "/c/Program Files/Docker/Docker/Docker Desktop.exe" &
            echo "✅ ได้ส่งคำสั่งเปิด Docker Desktop แล้ว"
        elif [ -f "/c/Users/$USER/AppData/Local/Docker/Docker Desktop.exe" ]; then
            echo "🔄 พยายามเปิด Docker Desktop..."
            "/c/Users/$USER/AppData/Local/Docker/Docker Desktop.exe" &
            echo "✅ ได้ส่งคำสั่งเปิด Docker Desktop แล้ว"
        else
            echo "❌ ไม่พบ Docker Desktop ที่ตำแหน่งมาตรฐาน"
            echo "   กรุณาเปิด Docker Desktop ด้วยตนเอง"
        fi
        
        echo "⏳ รอ Docker เริ่มต้น (อาจใช้เวลา 1-2 นาที)..."
        sleep 10
        
    else
        # Linux commands
        echo "🐧 สำหรับ Linux:"
        if command -v systemctl &> /dev/null; then
            echo "🔄 เริ่มต้น Docker service..."
            sudo systemctl start docker
            sudo systemctl enable docker
            echo "✅ เปิด Docker service แล้ว"
        elif command -v service &> /dev/null; then
            echo "🔄 เริ่มต้น Docker service..."
            sudo service docker start
            echo "✅ เปิด Docker service แล้ว"
        else
            echo "❌ ไม่สามารถเริ่มต้น Docker ได้ (ไม่พบ systemctl หรือ service)"
        fi
    fi
}

# Function to check Docker status
check_docker_status() {
    echo ""
    echo "🔍 ตรวจสอบสถานะ Docker..."
    
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker info &> /dev/null; then
            echo "✅ Docker daemon กำลังทำงานอยู่"
            echo "   Version: $(docker --version)"
            echo "   Status: $(docker info --format '{{.ServerVersion}}' 2>/dev/null || echo 'Running')"
            return 0
        else
            echo "⏳ รอ Docker เริ่มต้น... (ครั้งที่ $attempt/$max_attempts)"
            sleep 5
            ((attempt++))
        fi
    done
    
    echo "❌ Docker ยังไม่พร้อมใช้งาน"
    echo "💡 ลองตรวจสอบ:"
    echo "   - Docker Desktop เปิดอยู่หรือไม่"
    echo "   - มี error message ใน Docker Desktop หรือไม่"
    echo "   - ลอง restart Docker Desktop"
    return 1
}

# Function to enable Kubernetes in Docker Desktop
enable_kubernetes() {
    echo ""
    echo "⚙️  การเปิดใช้งาน Kubernetes:"
    
    if is_windows; then
        echo "📋 สำหรับ Docker Desktop บน Windows:"
        echo "   1. เปิด Docker Desktop"
        echo "   2. ไปที่ Settings (เครื่องหมายฟันเฟือง)"
        echo "   3. เลือก Kubernetes ทางซ้าย"
        echo "   4. ติ๊กถูก 'Enable Kubernetes'"
        echo "   5. คลิก 'Apply & Restart'"
        echo "   6. รอให้ Kubernetes เริ่มต้น"
    else
        echo "📋 สำหรับ Linux:"
        echo "   Docker Desktop หรือใช้ minikube/kind แทน"
    fi
}

# Function to check Kubernetes status
check_kubernetes_status() {
    echo ""
    echo "🔍 ตรวจสอบสถานะ Kubernetes..."
    
    if command -v kubectl &> /dev/null; then
        if kubectl cluster-info &> /dev/null; then
            echo "✅ Kubernetes cluster พร้อมใช้งาน"
            echo "   Context: $(kubectl config current-context 2>/dev/null || echo 'Unknown')"
            echo "   Server: $(kubectl cluster-info | head -1 | grep -o 'https://[^[:space:]]*' || echo 'Unknown')"
            
            # Check nodes
            echo "📊 Nodes:"
            kubectl get nodes --no-headers 2>/dev/null | while read line; do
                echo "   $line"
            done
            
            return 0
        else
            echo "❌ Kubernetes cluster ไม่พร้อมใช้งาน"
            echo "💡 ลองตรวจสอบ:"
            echo "   - เปิดใช้งาน Kubernetes ใน Docker Desktop"
            echo "   - หรือใช้ minikube start"
            echo "   - หรือใช้ kind create cluster"
            return 1
        fi
    else
        echo "❌ kubectl ไม่ได้ติดตั้ง"
        return 1
    fi
}

# Function to start minikube if available
start_minikube() {
    echo ""
    echo "🎯 ตัวเลือกสำหรับ Kubernetes:"
    
    if command -v minikube &> /dev/null; then
        echo "🔄 พบ minikube - ต้องการเริ่มต้น minikube cluster หรือไม่? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "🚀 เริ่มต้น minikube..."
            minikube start --driver=docker
            if [ $? -eq 0 ]; then
                echo "✅ minikube เริ่มต้นสำเร็จ"
                kubectl config use-context minikube
            else
                echo "❌ minikube เริ่มต้นไม่สำเร็จ"
            fi
        fi
    fi
    
    if command -v kind &> /dev/null; then
        echo "🔄 พบ kind - ต้องการสร้าง kind cluster หรือไม่? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "🚀 สร้าง kind cluster..."
            kind create cluster --name argocd-cluster
            if [ $? -eq 0 ]; then
                echo "✅ kind cluster สร้างสำเร็จ"
                kubectl config use-context kind-argocd-cluster
            else
                echo "❌ kind cluster สร้างไม่สำเร็จ"
            fi
        fi
    fi
}

# Main execution
echo "🔧 เริ่มต้นการตั้งค่า..."

# Start Docker
start_docker

# Check Docker status
if check_docker_status; then
    echo ""
    echo "🎉 Docker พร้อมใช้งานแล้ว!"
    
    # Check Kubernetes
    if ! check_kubernetes_status; then
        enable_kubernetes
        start_minikube
    else
        echo ""
        echo "🎉 Kubernetes พร้อมใช้งานแล้ว!"
    fi
else
    echo ""
    echo "❌ Docker ยังไม่พร้อม - กรุณาตรวจสอบและเปิด Docker ด้วยตนเอง"
fi

echo ""
echo "================================================================"
echo "📝 สรุป:"
echo "1. ✅ ตรวจสอบ Docker status"
echo "2. ✅ ตรวจสอบ Kubernetes status"
echo "3. 💡 แนะนำวิธีการเปิดใช้งาน services"
echo ""
echo "🚀 หากทุกอย่างพร้อมแล้ว สามารถติดตั้ง ArgoCD ได้ด้วย:"
echo "   kubectl create namespace argocd"
echo "   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
echo "================================================================"
