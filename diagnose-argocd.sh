#!/bin/bash

# =============================================================================
# 🔍 วินิจฉัยปัญหา ArgoCD
# =============================================================================

# สีสำหรับแสดงผล
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
header() { echo -e "\n${CYAN}[${1}]${NC} ${2}"; }

echo "🔍 วินิจฉัยปัญหา ArgoCD"
echo "======================"

# 1. ตรวจสอบระบบปฏิบัติการ
header "1" "ตรวจสอบระบบปฏิบัติการ"
os_name=$(uname -s)
os_version=$(uname -r)
echo "ระบบปฏิบัติการ: $os_name $os_version"

# ตรวจสอบ Linux Distribution
if [ "$os_name" = "Linux" ]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "Linux Distribution: $NAME $VERSION_ID"
    fi
fi

# 2. ตรวจสอบสถานะ Kubernetes
header "2" "ตรวจสอบสถานะ Kubernetes"
if command -v kubectl >/dev/null 2>&1; then
    echo "kubectl: ✅ พบ"
    kubectl_version=$(kubectl version --client --short 2>/dev/null)
    echo "kubectl version: $kubectl_version"
    
    # ตรวจสอบการเชื่อมต่อกับ cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        echo "Kubernetes Cluster: ✅ เชื่อมต่อได้"
        echo "Context: $(kubectl config current-context)"
        
        # ตรวจสอบ namespace argocd
        if kubectl get namespace argocd >/dev/null 2>&1; then
            echo "Namespace argocd: ✅ พบ"
            
            # ตรวจสอบ pods
            echo -e "\nArgoCD Pods:"
            kubectl get pods -n argocd
            
            # ตรวจสอบ services
            echo -e "\nArgoCD Services:"
            kubectl get svc -n argocd
            
            # ตรวจสอบ svc/argocd-server
            server_svc=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].port}' 2>/dev/null)
            if [ -n "$server_svc" ]; then
                echo -e "\nsvc/argocd-server port: $server_svc (HTTPS)"
            else
                echo -e "\nsvc/argocd-server: ❌ ไม่พบพอร์ต HTTPS"
            fi
        else
            error "Namespace argocd: ❌ ไม่พบ"
        fi
    else
        error "Kubernetes Cluster: ❌ ไม่สามารถเชื่อมต่อได้"
    fi
else
    error "kubectl: ❌ ไม่พบ"
fi

# 3. ตรวจสอบ port forwarding
header "3" "ตรวจสอบ Port Forwarding"
if pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
    echo "Port Forwarding: ✅ กำลังทำงาน"
    echo -e "\nPort Forwarding Processes:"
    ps aux | grep "kubectl.*port-forward.*argocd-server" | grep -v grep
    
    # ตรวจสอบ port ที่เปิด
    echo -e "\nPorts ที่เปิด:"
    netstat -tuln | grep -E ':(8080|8081|8443)' | grep LISTEN
    
    # ทดสอบการเชื่อมต่อ
    for port in 8080 8081 8443; do
        if netstat -tuln | grep -q ":$port "; then
            echo -e "\nทดสอบ port $port:"
            curl -k -I https://localhost:$port/ >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "https://localhost:$port: ✅ เชื่อมต่อได้"
            else
                echo "https://localhost:$port: ❌ เชื่อมต่อไม่ได้"
            fi
        fi
    done
else
    warn "Port Forwarding: ❌ ไม่ได้ทำงาน"
fi

# 4. ตรวจสอบ Docker
header "4" "ตรวจสอบ Docker"
if command -v docker >/dev/null 2>&1; then
    echo "Docker: ✅ พบ"
    docker_version=$(docker --version)
    echo "Docker Version: $docker_version"
    
    # ตรวจสอบ Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose (v1): ✅ พบ"
        dc_version=$(docker-compose --version)
        echo "Docker Compose Version: $dc_version"
    elif docker compose version >/dev/null 2>&1; then
        echo "Docker Compose (v2): ✅ พบ"
        dc_version=$(docker compose version)
        echo "Docker Compose Version: $dc_version"
    else
        warn "Docker Compose: ❌ ไม่พบ"
    fi
    
    # ตรวจสอบ nginx container
    echo -e "\nNginx Containers:"
    docker ps --filter "name=nginx" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # ตรวจสอบ log ของ nginx container
    nginx_container=$(docker ps --filter "name=nginx-argocd" --format "{{.Names}}" | head -1)
    if [ -n "$nginx_container" ]; then
        echo -e "\nNginx Container Log (สุดท้าย 10 บรรทัด):"
        docker logs $nginx_container --tail 10
        
        # ทดสอบ nginx health check
        echo -e "\nทดสอบ Nginx Health Check:"
        curl -s http://localhost/nginx-status >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "http://localhost/nginx-status: ✅ ทำงานปกติ"
            echo "Response: $(curl -s http://localhost/nginx-status)"
        else
            error "http://localhost/nginx-status: ❌ ไม่ทำงาน"
        fi
        
        # ทดสอบ ArgoCD UI
        echo -e "\nทดสอบ ArgoCD UI:"
        curl -I http://localhost/ >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "http://localhost/: ✅ ทำงานปกติ"
            echo "Status: $(curl -s -I http://localhost/ | head -1)"
        else
            error "http://localhost/: ❌ ไม่ทำงาน"
        fi
    else
        warn "Nginx Container: ❌ ไม่พบ"
    fi
else
    error "Docker: ❌ ไม่พบ"
fi

# 5. ตรวจสอบไฟล์ config
header "5" "ตรวจสอบไฟล์ Config"
if [ -d "nginx-simple" ]; then
    echo "Nginx Config Directory: ✅ พบ"
    
    # ตรวจสอบไฟล์ config
    if [ -f "nginx-simple/default.conf" ]; then
        echo "Nginx Config File: ✅ พบ (default.conf)"
        echo -e "\nNginx Config Summary:"
        grep -n "upstream\|server.*8080\|proxy_pass" nginx-simple/default.conf | head -5
    elif [ -f "nginx-simple/nginx-linux.conf" ]; then
        echo "Nginx Config File: ✅ พบ (nginx-linux.conf)"
        echo -e "\nNginx Config Summary:"
        grep -n "upstream\|server.*8080\|proxy_pass" nginx-simple/nginx-linux.conf | head -5
    else
        warn "Nginx Config File: ❌ ไม่พบ"
    fi
    
    # ตรวจสอบไฟล์ docker-compose
    if [ -f "docker-compose-linux-nginx.yml" ]; then
        echo -e "\nDocker Compose File: ✅ พบ (docker-compose-linux-nginx.yml)"
        echo "Network Mode: $(grep -o "network_mode:.*" docker-compose-linux-nginx.yml)"
    elif [ -f "docker-compose-nginx.yml" ]; then
        echo -e "\nDocker Compose File: ✅ พบ (docker-compose-nginx.yml)"
        echo "Network Mode: $(grep -o "network_mode:.*" docker-compose-nginx.yml 2>/dev/null || echo "standard (bridge)")"
    elif [ -f "docker-compose-simple.yml" ]; then
        echo -e "\nDocker Compose File: ✅ พบ (docker-compose-simple.yml)"
        echo "Network Mode: $(grep -o "network_mode:.*" docker-compose-simple.yml 2>/dev/null || echo "standard (bridge)")"
    else
        warn "Docker Compose File: ❌ ไม่พบ"
    fi
else
    warn "Nginx Config Directory: ❌ ไม่พบ"
fi

# 6. ตรวจสอบการเชื่อมต่อเครือข่าย
header "6" "ตรวจสอบการเชื่อมต่อเครือข่าย"
echo "Network Interfaces:"
ip addr show | grep -E 'inet.*global' || ifconfig | grep -E 'inet '

echo -e "\nOpen Ports (LISTEN):"
netstat -tuln | grep LISTEN | head -10

echo -e "\nHost IP Address: $(hostname -I | awk '{print $1}')"

# 7. ตรวจสอบ systemd services (ถ้ามี)
header "7" "ตรวจสอบ Systemd Services"
if command -v systemctl >/dev/null 2>&1; then
    echo "Systemd: ✅ พบ"
    
    # ตรวจสอบ argocd services
    if systemctl list-unit-files | grep -q argocd; then
        echo -e "\nArgoCD Services:"
        systemctl list-unit-files | grep argocd
        
        # ตรวจสอบสถานะ services
        for service in argocd-http.service argocd-nginx.service; do
            if systemctl list-unit-files | grep -q $service; then
                echo -e "\nสถานะ $service:"
                systemctl status $service --no-pager | head -5
                
                if systemctl is-active $service >/dev/null 2>&1; then
                    echo "สถานะ: ✅ ทำงานอยู่"
                else
                    warn "สถานะ: ❌ ไม่ทำงาน"
                fi
            fi
        done
    else
        info "ArgoCD Systemd Services: ไม่พบ (ไม่ได้ติดตั้งเป็น service)"
    fi
else
    info "Systemd: ไม่พบ (อาจไม่ได้ใช้ systemd)"
fi

# 8. สรุปผลและแนะนำการแก้ไข
header "8" "สรุปผลและแนะนำการแก้ไข"

# เช็คปัญหาพื้นฐาน
problems=0

# ปัญหา Kubernetes
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    error "ปัญหา: ไม่พบ namespace argocd"
    echo "แก้ไข: ตรวจสอบการติดตั้ง ArgoCD หรือรัน ./install-argocd.sh"
    problems=$((problems + 1))
fi

# ปัญหา Port Forwarding
if ! pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
    error "ปัญหา: Port Forwarding ไม่ทำงาน"
    echo "แก้ไข: รัน kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 &"
    problems=$((problems + 1))
fi

# ปัญหา Nginx
nginx_container=$(docker ps --filter "name=nginx-argocd" --format "{{.Names}}" | head -1)
if [ -z "$nginx_container" ]; then
    error "ปัญหา: ไม่พบ Nginx container"
    echo "แก้ไข: รัน ./fix-linux-nginx.sh เพื่อเริ่ม Nginx container"
    problems=$((problems + 1))
else
    # ตรวจสอบ nginx health check
    if ! curl -s http://localhost/nginx-status >/dev/null 2>&1; then
        error "ปัญหา: Nginx health check ไม่ทำงาน"
        echo "แก้ไข: ตรวจสอบ log ของ Nginx: docker logs $nginx_container"
        problems=$((problems + 1))
    fi
fi

# ปัญหา Config
if [ ! -f "nginx-simple/default.conf" ] && [ ! -f "nginx-simple/nginx-linux.conf" ]; then
    error "ปัญหา: ไม่พบไฟล์ config ของ Nginx"
    echo "แก้ไข: รัน ./fix-linux-nginx.sh เพื่อสร้างไฟล์ config"
    problems=$((problems + 1))
fi

# แนะนำการแก้ไข
if [ $problems -eq 0 ]; then
    echo -e "${GREEN}✅ ไม่พบปัญหาร้ายแรง${NC}"
    echo "ถ้ายังเข้าไม่ได้ ลองตรวจสอบ:"
    echo "1. ไฟร์วอลล์ - ตรวจสอบว่าอนุญาตพอร์ต 80 หรือไม่"
    echo "2. Network Mode - ลองใช้ host network mode"
    echo "3. เปลี่ยนเป็นการเข้าถึงโดยตรง - รัน ./argocd-direct-https.sh"
else
    echo -e "${RED}❌ พบ $problems ปัญหา${NC}"
    echo "แนะนำให้รันสคริปต์ต่อไปนี้:"
    echo "1. สำหรับการเข้าถึงผ่าน HTTP (port 80): ./fix-linux-nginx.sh"
    echo "2. สำหรับการเข้าถึงผ่าน HTTPS โดยตรง: ./argocd-direct-https.sh"
    echo "3. สำหรับการติดตั้งเป็น service: sudo ./install-argocd-service.sh"
fi

echo -e "\n✅ การวินิจฉัยเสร็จสิ้น!"
