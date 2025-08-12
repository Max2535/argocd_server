#!/bin/bash

echo "🌐 ตั้งค่า Nginx Reverse Proxy สำหรับ ArgoCD"
echo "============================================="

# Check if running on Windows
is_windows() {
    [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$OS" == "Windows_NT" ]]
}

# Function to check if nginx is installed
check_nginx() {
    if command -v nginx &> /dev/null; then
        echo "✅ nginx ติดตั้งแล้ว"
        echo "   Version: $(nginx -v 2>&1)"
        return 0
    else
        echo "❌ nginx ยังไม่ติดตั้ง"
        return 1
    fi
}

# Function to install nginx
install_nginx() {
    echo "📦 ติดตั้ง nginx..."
    
    if is_windows; then
        echo "🪟 สำหรับ Windows:"
        echo "   วิธีที่ 1: ใช้ Chocolatey"
        echo "   choco install nginx"
        echo ""
        echo "   วิธีที่ 2: ดาวน์โหลดจาก http://nginx.org/en/download.html"
        echo "   - ดาวน์โหลด nginx สำหรับ Windows"
        echo "   - แตกไฟล์ไปที่ C:\\nginx"
        echo "   - เพิ่ม C:\\nginx ลงใน PATH"
        echo ""
        echo "   วิธีที่ 3: ใช้ Docker (แนะนำ)"
        echo "   docker run -d --name nginx-argocd -p 80:80 -p 443:443 nginx"
        echo ""
        echo "🔄 ต้องการติดตั้งผ่าน Docker หรือไม่? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            setup_nginx_docker
            return $?
        fi
    else
        # Linux installation
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y nginx
        elif command -v yum &> /dev/null; then
            sudo yum install -y nginx
        elif command -v pacman &> /dev/null; then
            sudo pacman -S nginx
        else
            echo "❌ ไม่สามารถติดตั้ง nginx ได้ กรุณาติดตั้งด้วยตนเอง"
            return 1
        fi
    fi
}

# Function to create HTTP-only nginx config
create_http_nginx_config() {
    cat > nginx-config/conf.d/nginx-argocd.conf <<EOF
# Nginx configuration for ArgoCD reverse proxy (HTTP only)
server {
    listen 80;
    server_name localhost argocd.local;
    
    # ArgoCD specific headers
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-Server \$host;
    
    # Required for ArgoCD Server Sent Events (SSE)
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_buffering off;
    proxy_read_timeout 86400;
    
    # Increase body size for large Git repos
    client_max_body_size 0;
    
    # ArgoCD UI
    location / {
        proxy_pass https://127.0.0.1:8080;
        proxy_ssl_verify off;
    }
    
    # ArgoCD API
    location /api/ {
        proxy_pass https://127.0.0.1:8080/api/;
        proxy_ssl_verify off;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
}

# Function to setup nginx with Docker
setup_nginx_docker() {
    echo "🐳 ตั้งค่า Nginx ผ่าน Docker..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo "❌ Docker ไม่ทำงาน กรุณาเปิด Docker ก่อน"
        return 1
    fi
    
    # Create nginx directories
    mkdir -p nginx-config/ssl nginx-config/conf.d nginx-logs
    
    # Generate SSL certificates
    if generate_ssl_certs "nginx-config/ssl"; then
        # Use HTTPS config
        cp nginx-argocd.conf nginx-config/conf.d/
        USE_HTTPS=true
    else
        # Use HTTP-only config
        create_http_nginx_config
        USE_HTTPS=false
    fi
    
    # Create docker-compose.yml for nginx
    if [ "$USE_HTTPS" = true ]; then
        cat > docker-compose-nginx.yml <<EOF
services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-config/conf.d:/etc/nginx/conf.d
      - ./nginx-config/ssl:/etc/nginx/ssl
      - ./nginx-logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - argocd-network

  kubectl-proxy:
    image: bitnami/kubectl:latest
    container_name: kubectl-proxy
    command: >
      sh -c "
        echo 'Setting up kubectl proxy...' &&
        kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0
      "
    volumes:
      - ~/.kube:/home/kubectl/.kube:ro
    network_mode: host
    restart: unless-stopped

networks:
  argocd-network:
    driver: bridge
EOF
    else
        cat > docker-compose-nginx.yml <<EOF
services:
  nginx-argocd:
    image: nginx:alpine
    container_name: nginx-argocd
    ports:
      - "80:80"
    volumes:
      - ./nginx-config/conf.d:/etc/nginx/conf.d
      - ./nginx-logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - argocd-network

  kubectl-proxy:
    image: bitnami/kubectl:latest
    container_name: kubectl-proxy
    command: >
      sh -c "
        echo 'Setting up kubectl proxy...' &&
        kubectl port-forward svc/argocd-server -n argocd 8080:443 --address=0.0.0.0
      "
    volumes:
      - ~/.kube:/home/kubectl/.kube:ro
    network_mode: host
    restart: unless-stopped

networks:
  argocd-network:
    driver: bridge
EOF
    fi
    
    echo "✅ สร้าง Docker Compose configuration แล้ว"
    
    # Start nginx
    echo "🚀 เริ่มต้น Nginx..."
    docker-compose -f docker-compose-nginx.yml up -d
    
    if [ $? -eq 0 ]; then
        echo "✅ Nginx เริ่มต้นสำเร็จ"
        if [ "$USE_HTTPS" = true ]; then
            echo "🌐 ArgoCD UI: https://localhost"
            echo "🌐 ArgoCD UI (HTTP): http://localhost (จะ redirect ไป HTTPS)"
        else
            echo "🌐 ArgoCD UI: http://localhost"
        fi
        return 0
    else
        echo "❌ Nginx เริ่มต้นไม่สำเร็จ"
        return 1
    fi
}

# Function to generate SSL certificates
generate_ssl_certs() {
    local ssl_dir=$1
    echo "🔐 สร้าง SSL certificates..."
    
    # Create SSL directory
    mkdir -p "$ssl_dir"
    
    # Generate private key
    openssl genrsa -out "$ssl_dir/argocd.key" 2048 2>/dev/null
    
    # Generate certificate - fix the subject format for Windows
    if is_windows; then
        # For Windows, use quotes to handle the subject properly
        openssl req -new -x509 -key "$ssl_dir/argocd.key" -out "$ssl_dir/argocd.crt" -days 365 -subj "//C=TH\ST=Bangkok\L=Bangkok\O=ArgoCD\OU=Local\CN=localhost" 2>/dev/null
    else
        openssl req -new -x509 -key "$ssl_dir/argocd.key" -out "$ssl_dir/argocd.crt" -days 365 -subj "/C=TH/ST=Bangkok/L=Bangkok/O=ArgoCD/OU=Local/CN=localhost" 2>/dev/null
    fi
    
    if [ $? -eq 0 ] && [ -f "$ssl_dir/argocd.crt" ] && [ -f "$ssl_dir/argocd.key" ]; then
        echo "✅ SSL certificates สร้างสำเร็จ"
    else
        echo "⚠️  ไม่สามารถสร้าง SSL certificates ได้ กำลังใช้ HTTP แทน"
        # Create a simple nginx config without SSL
        create_http_nginx_config
        return 1
    fi
}

# Function to setup nginx configuration
setup_nginx_config() {
    echo "⚙️  ตั้งค่า nginx configuration..."
    
    if is_windows; then
        echo "📋 สำหรับ Windows กับ nginx แบบ native:"
        echo "   1. copy nginx-argocd.conf ไปที่ nginx/conf/conf.d/"
        echo "   2. สร้าง SSL certificates"
        echo "   3. แก้ไข nginx.conf ให้ include conf.d/*.conf"
        echo "   4. restart nginx"
        return 0
    fi
    
    # Linux setup
    local nginx_dir="/etc/nginx"
    local ssl_dir="/etc/nginx/ssl"
    
    # Create SSL directory
    sudo mkdir -p "$ssl_dir"
    
    # Generate SSL certificates
    generate_ssl_certs "$ssl_dir"
    
    # Copy nginx configuration
    sudo cp nginx-argocd.conf "$nginx_dir/sites-available/"
    
    # Enable site
    sudo ln -sf "$nginx_dir/sites-available/nginx-argocd.conf" "$nginx_dir/sites-enabled/"
    
    # Remove default site
    sudo rm -f "$nginx_dir/sites-enabled/default"
    
    # Test nginx configuration
    sudo nginx -t
    
    if [ $? -eq 0 ]; then
        echo "✅ nginx configuration ถูกต้อง"
        return 0
    else
        echo "❌ nginx configuration มีปัญหา"
        return 1
    fi
}

# Function to start services
start_services() {
    echo "🚀 เริ่มต้น services..."
    
    # Start kubectl port-forward in background
    echo "🔄 เริ่มต้น kubectl port-forward..."
    kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
    local kubectl_pid=$!
    
    # Save PID for later cleanup
    echo $kubectl_pid > .kubectl-proxy.pid
    
    sleep 5
    
    # Test if port-forward is working
    if curl -k -s https://localhost:8080 > /dev/null; then
        echo "✅ kubectl port-forward ทำงานอยู่"
    else
        echo "❌ kubectl port-forward ไม่ทำงาน"
        return 1
    fi
    
    # Start nginx
    if is_windows; then
        echo "🪟 เริ่มต้น nginx บน Windows..."
        # For Windows, we're using Docker approach
        return 0
    else
        echo "🐧 เริ่มต้น nginx บน Linux..."
        sudo systemctl start nginx
        sudo systemctl enable nginx
        
        if systemctl is-active --quiet nginx; then
            echo "✅ nginx ทำงานอยู่"
            return 0
        else
            echo "❌ nginx ไม่ทำงาน"
            return 1
        fi
    fi
}

# Function to stop services
stop_services() {
    echo "🛑 หยุด services..."
    
    # Stop nginx
    if is_windows; then
        if docker ps | grep -q nginx-argocd; then
            docker-compose -f docker-compose-nginx.yml down
            echo "✅ หยุด nginx container แล้ว"
        fi
    else
        sudo systemctl stop nginx
        echo "✅ หยุด nginx แล้ว"
    fi
    
    # Stop kubectl port-forward
    if [ -f .kubectl-proxy.pid ]; then
        local pid=$(cat .kubectl-proxy.pid)
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            echo "✅ หยุด kubectl port-forward แล้ว"
        fi
        rm -f .kubectl-proxy.pid
    fi
}

# Function to show status
show_status() {
    echo "📊 Status:"
    echo "=========="
    
    # Check ArgoCD
    if kubectl get pods -n argocd | grep -q Running; then
        echo "✅ ArgoCD: Running"
    else
        echo "❌ ArgoCD: Not Running"
    fi
    
    # Check kubectl port-forward
    if [ -f .kubectl-proxy.pid ]; then
        local pid=$(cat .kubectl-proxy.pid)
        if kill -0 $pid 2>/dev/null; then
            echo "✅ kubectl port-forward: Running (PID: $pid)"
        else
            echo "❌ kubectl port-forward: Not Running"
        fi
    else
        echo "❌ kubectl port-forward: Not Running"
    fi
    
    # Check nginx
    if is_windows; then
        if docker ps | grep -q nginx-argocd; then
            echo "✅ nginx: Running (Docker)"
            echo "🌐 ArgoCD UI: https://localhost"
        else
            echo "❌ nginx: Not Running"
        fi
    else
        if systemctl is-active --quiet nginx; then
            echo "✅ nginx: Running"
            echo "🌐 ArgoCD UI: https://localhost"
        else
            echo "❌ nginx: Not Running"
        fi
    fi
}

# Function to show help
show_help() {
    echo "📋 Available commands:"
    echo "===================="
    echo "  start    - ติดตั้งและเริ่มต้น nginx reverse proxy"
    echo "  stop     - หยุด nginx และ kubectl port-forward"
    echo "  restart  - restart services"
    echo "  status   - แสดงสถานะ services"
    echo "  logs     - แสดง nginx logs"
    echo "  help     - แสดงข้อมูลนี้"
    echo ""
    echo "📝 Example:"
    echo "  ./nginx-setup.sh start"
    echo "  ./nginx-setup.sh status"
}

# Function to show logs
show_logs() {
    echo "📜 Nginx Logs:"
    echo "=============="
    
    if is_windows; then
        if docker ps | grep -q nginx-argocd; then
            echo "🐳 Docker nginx logs:"
            docker logs nginx-argocd --tail=50 -f
        else
            echo "❌ nginx container ไม่ทำงาน"
        fi
    else
        if [ -f /var/log/nginx/argocd.access.log ]; then
            echo "📋 Access logs:"
            tail -f /var/log/nginx/argocd.access.log
        else
            echo "❌ nginx log files ไม่พบ"
        fi
    fi
}

# Main execution
case "$1" in
    start)
        if ! check_nginx; then
            install_nginx
        fi
        setup_nginx_config
        start_services
        show_status
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        start_services
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "🌐 Nginx Reverse Proxy Setup สำหรับ ArgoCD"
        echo "=========================================="
        echo ""
        show_help
        ;;
esac
