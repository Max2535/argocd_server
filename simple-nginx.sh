#!/bin/bash

echo "🌐 Simple Nginx Reverse Proxy สำหรับ ArgoCD"
echo "============================================"

# Function to check if kubectl port-forward is running
check_kubectl_proxy() {
    if curl -k -s https://localhost:8080 > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to start kubectl port-forward
start_kubectl_proxy() {
    echo "🔄 เริ่มต้น kubectl port-forward..."
    
    # Kill existing port-forward if any
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null
    
    # Start new port-forward in background
    kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
    local pid=$!
    echo $pid > .kubectl-proxy.pid
    
    # Wait and test
    sleep 3
    if check_kubectl_proxy; then
        echo "✅ kubectl port-forward ทำงานอยู่ (PID: $pid)"
        return 0
    else
        echo "❌ kubectl port-forward ไม่ทำงาง"
        return 1
    fi
}

# Function to setup simple nginx
setup_simple_nginx() {
    echo "🐳 ตั้งค่า Simple Nginx..."
    
    # Create simple nginx config
    mkdir -p nginx-simple
    
    cat > nginx-simple/default.conf <<EOF
upstream argocd {
    server host.docker.internal:8080;
}

server {
    listen 80;
    server_name localhost;
    
    location / {
        proxy_pass https://argocd;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
    
    location /health {
        return 200 "OK";
        add_header Content-Type text/plain;
    }
}
EOF
    
    echo "✅ สร้าง nginx config แล้ว"
}

# Function to start nginx container
start_nginx() {
    echo "🚀 เริ่มต้น Nginx container..."
    
    # Remove existing container
    docker rm -f nginx-argocd 2>/dev/null || true
    
    # Get absolute path for Windows
    CURRENT_DIR="$(pwd)"
    
    # Start nginx container with corrected path
    docker run -d \
        --name nginx-argocd \
        --restart unless-stopped \
        -p 80:80 \
        -v "${CURRENT_DIR}/nginx-simple/default.conf:/etc/nginx/conf.d/default.conf:ro" \
        nginx:alpine
    
    if [ $? -eq 0 ]; then
        echo "✅ Nginx container เริ่มต้นสำเร็จ"
        
        # Wait a moment for nginx to start
        sleep 2
        
        # Check if config is mounted correctly
        if docker exec nginx-argocd sh -c "grep -q 'upstream argocd' /etc/nginx/conf.d/default.conf" 2>/dev/null; then
            echo "✅ Nginx configuration mounted สำเร็จ"
        else
            echo "⚠️  Nginx configuration อาจไม่ถูกต้อง"
        fi
        
        return 0
    else
        echo "❌ Nginx container เริ่มต้นไม่สำเร็จ"
        return 1
    fi
}

# Function to test connection
test_connection() {
    echo "🔍 ทดสอบการเชื่อมต่อ..."
    
    sleep 5
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200\|301\|302"; then
        echo "✅ เชื่อมต่อ nginx สำเร็จ"
        return 0
    else
        echo "❌ เชื่อมต่อ nginx ไม่สำเร็จ"
        return 1
    fi
}

# Function to show status
show_status() {
    echo "📊 Status:"
    echo "=========="
    
    # Check ArgoCD
    if kubectl get pods -n argocd | grep -q "Running"; then
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
    if docker ps | grep -q nginx-argocd; then
        echo "✅ nginx: Running"
        echo "🌐 ArgoCD UI: http://localhost"
    else
        echo "❌ nginx: Not Running"
    fi
    
    # Test connection
    if curl -s -o /dev/null http://localhost 2>/dev/null; then
        echo "✅ Connection: OK"
    else
        echo "❌ Connection: Failed"
    fi
}

# Function to stop services
stop_services() {
    echo "🛑 หยุด services..."
    
    # Stop nginx
    docker rm -f nginx-argocd 2>/dev/null && echo "✅ หยุด nginx container แล้ว"
    
    # Stop kubectl port-forward
    if [ -f .kubectl-proxy.pid ]; then
        local pid=$(cat .kubectl-proxy.pid)
        if kill $pid 2>/dev/null; then
            echo "✅ หยุด kubectl port-forward แล้ว"
        fi
        rm -f .kubectl-proxy.pid
    fi
    
    # Kill any remaining kubectl port-forward processes
    pkill -f "kubectl.*port-forward.*argocd-server" 2>/dev/null || true
}

# Function to show logs
show_logs() {
    if docker ps | grep -q nginx-argocd; then
        echo "📜 Nginx logs:"
        docker logs nginx-argocd --tail=50 -f
    else
        echo "❌ nginx container ไม่ทำงาน"
    fi
}

# Main execution
case "$1" in
    start)
        # Start kubectl port-forward first
        if ! start_kubectl_proxy; then
            echo "❌ ไม่สามารถเริ่ม kubectl port-forward ได้"
            exit 1
        fi
        
        # Setup and start nginx
        setup_simple_nginx
        start_nginx
        test_connection
        
        echo ""
        show_status
        echo ""
        echo "🎉 Setup เสร็จสมบูรณ์!"
        echo "🌐 เข้าใช้งาน ArgoCD ที่: http://localhost"
        echo "🔑 Username: admin"
        
        # Get admin password
        password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
        if [ ! -z "$password" ]; then
            echo "🔑 Password: $password"
        fi
        ;;
    stop)
        stop_services
        ;;
    restart)
        stop_services
        sleep 2
        $0 start
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start   - เริ่มต้น nginx reverse proxy"
        echo "  stop    - หยุด nginx และ port-forward"
        echo "  restart - restart ทุก services"
        echo "  status  - แสดงสถานะ"
        echo "  logs    - แสดง nginx logs"
        ;;
esac
