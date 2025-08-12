#!/bin/bash

echo "🎛️  ArgoCD Management Scripts"
echo "==========================="

# Function to show ArgoCD status
show_status() {
    echo "📊 ArgoCD Status:"
    echo "=================="
    
    echo "🔍 Cluster context: $(kubectl config current-context)"
    echo ""
    
    echo "📦 ArgoCD Pods:"
    kubectl get pods -n argocd
    echo ""
    
    echo "🌐 ArgoCD Services:"
    kubectl get svc -n argocd
    echo ""
    
    echo "🔑 Admin Password:"
    local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ ! -z "$password" ]; then
        echo "   Username: admin"
        echo "   Password: $password"
    else
        echo "   ❌ ไม่สามารถดึงรหัสผ่านได้"
    fi
    echo ""
}

# Function to start port forwarding
start_port_forward() {
    echo "🚀 Starting ArgoCD UI Port Forwarding..."
    echo "🌐 URL: https://localhost:8080"
    echo "💡 กด Ctrl+C เพื่อหยุด"
    echo ""
    
    # Get admin password
    local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ ! -z "$password" ]; then
        echo "🔑 Login Info:"
        echo "   Username: admin"
        echo "   Password: $password"
        echo ""
    fi
    
    kubectl port-forward svc/argocd-server -n argocd 8080:443
}

# Function to reset admin password
reset_admin_password() {
    echo "🔄 Resetting Admin Password..."
    
    # Delete the initial admin secret to regenerate
    kubectl delete secret argocd-initial-admin-secret -n argocd 2>/dev/null
    
    # Restart argocd-server to regenerate the secret
    kubectl rollout restart deployment argocd-server -n argocd
    
    echo "⏳ Waiting for ArgoCD server to restart..."
    kubectl rollout status deployment argocd-server -n argocd
    
    # Wait a bit for the secret to be regenerated
    sleep 10
    
    echo "🔑 New Admin Password:"
    local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    if [ ! -z "$password" ]; then
        echo "   Username: admin"
        echo "   Password: $password"
    else
        echo "   ❌ ไม่สามารถดึงรหัสผ่านใหม่ได้ ลองอีกครั้งในอีกสักครู่"
    fi
}

# Function to uninstall ArgoCD
uninstall_argocd() {
    echo "🗑️  Uninstalling ArgoCD..."
    echo "⚠️  คำเตือน: การกระทำนี้จะลบ ArgoCD ทั้งหมด"
    echo "🔄 ต้องการดำเนินการต่อหรือไม่? (y/N)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🧹 Removing ArgoCD..."
        kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        kubectl delete namespace argocd
        echo "✅ ArgoCD ถูกลบแล้ว"
    else
        echo "❌ ยกเลิกการลบ"
    fi
}

# Function to create sample application
create_sample_app() {
    echo "📱 Creating Sample Application..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
    
    if [ $? -eq 0 ]; then
        echo "✅ Sample application 'guestbook' created successfully"
        echo "🌐 คุณสามารถดูใน ArgoCD UI ได้แล้ว"
    else
        echo "❌ Failed to create sample application"
    fi
}

# Function to show logs
show_logs() {
    echo "📋 ArgoCD Logs:"
    echo "==============="
    echo "1. ArgoCD Server"
    echo "2. ArgoCD Application Controller"
    echo "3. ArgoCD Repo Server"
    echo "4. All Components"
    echo ""
    echo "เลือกตัวเลือก (1-4): "
    read -r choice
    
    case $choice in
        1)
            echo "📜 ArgoCD Server Logs:"
            kubectl logs -f deployment/argocd-server -n argocd
            ;;
        2)
            echo "📜 ArgoCD Application Controller Logs:"
            kubectl logs -f statefulset/argocd-application-controller -n argocd
            ;;
        3)
            echo "📜 ArgoCD Repo Server Logs:"
            kubectl logs -f deployment/argocd-repo-server -n argocd
            ;;
        4)
            echo "📜 All ArgoCD Logs:"
            kubectl logs --selector=app.kubernetes.io/part-of=argocd -n argocd --all-containers=true -f
            ;;
        *)
            echo "❌ ตัวเลือกไม่ถูกต้อง"
            ;;
    esac
}

# Main menu
show_menu() {
    echo ""
    echo "🎛️  ArgoCD Management Menu:"
    echo "=========================="
    echo "1. 📊 Show Status"
    echo "2. 🌐 Start Port Forward (UI Access)"
    echo "3. 🔑 Reset Admin Password"
    echo "4. 📱 Create Sample Application"
    echo "5. 📜 Show Logs"
    echo "6. 🗑️  Uninstall ArgoCD"
    echo "7. ❌ Exit"
    echo ""
    echo "เลือกตัวเลือก (1-7): "
}

# Main execution
if [ "$1" = "status" ]; then
    show_status
elif [ "$1" = "ui" ] || [ "$1" = "port-forward" ]; then
    start_port_forward
elif [ "$1" = "reset-password" ]; then
    reset_admin_password
elif [ "$1" = "sample" ]; then
    create_sample_app
elif [ "$1" = "logs" ]; then
    show_logs
elif [ "$1" = "uninstall" ]; then
    uninstall_argocd
else
    # Interactive mode
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                show_status
                ;;
            2)
                start_port_forward
                ;;
            3)
                reset_admin_password
                ;;
            4)
                create_sample_app
                ;;
            5)
                show_logs
                ;;
            6)
                uninstall_argocd
                ;;
            7)
                echo "👋 ลาก่อน!"
                exit 0
                ;;
            *)
                echo "❌ ตัวเลือกไม่ถูกต้อง กรุณาเลือก 1-7"
                ;;
        esac
        
        echo ""
        echo "กด Enter เพื่อกลับไปยังเมนูหลัก..."
        read
    done
fi
