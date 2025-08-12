#!/bin/bash

# =============================================================================
# 🎬 ArgoCD Demo Application Deployer
# =============================================================================
# สำหรับสาธิตการใช้งาน ArgoCD หลังติดตั้งเสร็จ
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║              🎬 ArgoCD Demo Applications 🎬                ║"
echo "║                                                            ║"
echo "║    สาธิตการ Deploy Applications ด้วย GitOps และ ArgoCD     ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if ArgoCD is running
echo -e "${BLUE}🔍 ตรวจสอบ ArgoCD...${NC}"

if ! kubectl get pods -n argocd >/dev/null 2>&1; then
    echo -e "${RED}❌ ArgoCD ไม่ได้ติดตั้งหรือไม่ทำงาน${NC}"
    echo -e "${YELLOW}📋 กรุณารัน ./install-full-stack.sh ก่อน${NC}"
    exit 1
fi

ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l)
total_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)

if [[ $ready_pods -eq $total_pods ]] && [[ $ready_pods -gt 0 ]]; then
    echo -e "${GREEN}✅ ArgoCD ทำงานอยู่ ($ready_pods/$total_pods pods)${NC}"
else
    echo -e "${RED}❌ ArgoCD pods ไม่พร้อม ($ready_pods/$total_pods)${NC}"
    echo -e "${YELLOW}📋 กรุณารัน ./start-argocd.sh ก่อน${NC}"
    exit 1
fi

# Function to create demo applications
create_guestbook_app() {
    echo -e "${CYAN}📱 สร้าง Guestbook Demo Application...${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  labels:
    app: guestbook
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
    syncOptions:
    - CreateNamespace=true
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Guestbook application สร้างสำเร็จ${NC}"
    else
        echo -e "${RED}❌ ไม่สามารถสร้าง Guestbook application ได้${NC}"
    fi
}

create_helm_demo_app() {
    echo -e "${CYAN}📱 สร้าง Helm Chart Demo Application...${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-demo
  namespace: argocd
  labels:
    app: helm-demo
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: helm-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Helm demo application สร้างสำเร็จ${NC}"
    else
        echo -e "${RED}❌ ไม่สามารถสร้าง Helm demo application ได้${NC}"
    fi
}

create_kustomize_demo_app() {
    echo -e "${CYAN}📱 สร้าง Kustomize Demo Application...${NC}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kustomize-demo
  namespace: argocd
  labels:
    app: kustomize-demo
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: kustomize-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: kustomize-demo
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ Kustomize demo application สร้างสำเร็จ${NC}"
    else
        echo -e "${RED}❌ ไม่สามารถสร้าง Kustomize demo application ได้${NC}"
    fi
}

# Function to show application status
show_app_status() {
    echo -e "${BLUE}📊 สถานะ Applications:${NC}"
    echo "========================"
    
    # Get all ArgoCD applications
    apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | awk '{print $1}' || echo "")
    
    if [[ -z "$apps" ]]; then
        echo -e "${YELLOW}ไม่พบ Applications${NC}"
        return
    fi
    
    for app in $apps; do
        status=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        sync=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        
        case $status in
            "Healthy")
                health_icon="✅"
                ;;
            "Progressing")
                health_icon="🔄"
                ;;
            "Degraded")
                health_icon="❌"
                ;;
            *)
                health_icon="❓"
                ;;
        esac
        
        case $sync in
            "Synced")
                sync_icon="✅"
                ;;
            "OutOfSync")
                sync_icon="⚠️"
                ;;
            *)
                sync_icon="❓"
                ;;
        esac
        
        echo -e "$health_icon $sync_icon $app (Health: $status, Sync: $sync)"
    done
}

# Function to wait for applications to be ready
wait_for_apps() {
    echo -e "${YELLOW}⏳ รอให้ Applications พร้อม...${NC}"
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        local all_ready=true
        
        # Check all applications
        for app in $(kubectl get applications -n argocd --no-headers 2>/dev/null | awk '{print $1}' || echo ""); do
            if [[ ! -z "$app" ]]; then
                local status=$(kubectl get application $app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
                local sync=$(kubectl get application $app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
                
                if [[ "$status" != "Healthy" ]] || [[ "$sync" != "Synced" ]]; then
                    all_ready=false
                    break
                fi
            fi
        done
        
        if $all_ready; then
            echo -e "${GREEN}✅ Applications พร้อมทั้งหมด!${NC}"
            return 0
        fi
        
        echo -n "."
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    echo ""
    echo -e "${YELLOW}⚠️  Applications ยังไม่พร้อมทั้งหมด (timeout หลัง 5 นาที)${NC}"
    return 1
}

# Function to show services and access info
show_access_info() {
    echo -e "${BLUE}🌐 ข้อมูลการเข้าถึง Applications:${NC}"
    echo "==================================="
    
    # Guestbook
    if kubectl get application guestbook -n argocd >/dev/null 2>&1; then
        echo -e "${CYAN}📱 Guestbook Application:${NC}"
        if kubectl get svc guestbook-ui -n default >/dev/null 2>&1; then
            echo "   Service: guestbook-ui (default namespace)"
            echo "   Port Forward: kubectl port-forward svc/guestbook-ui -n default 8081:80"
            echo "   Access: http://localhost:8081"
        fi
        echo ""
    fi
    
    # Helm Demo
    if kubectl get application helm-demo -n argocd >/dev/null 2>&1; then
        echo -e "${CYAN}📱 Helm Demo Application:${NC}"
        if kubectl get svc -n helm-demo >/dev/null 2>&1; then
            echo "   Namespace: helm-demo"
            echo "   Services: $(kubectl get svc -n helm-demo --no-headers 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || echo 'None')"
        fi
        echo ""
    fi
    
    # Kustomize Demo
    if kubectl get application kustomize-demo -n argocd >/dev/null 2>&1; then
        echo -e "${CYAN}📱 Kustomize Demo Application:${NC}"
        if kubectl get svc -n kustomize-demo >/dev/null 2>&1; then
            echo "   Namespace: kustomize-demo"
            echo "   Services: $(kubectl get svc -n kustomize-demo --no-headers 2>/dev/null | awk '{print $1}' | tr '\n' ' ' || echo 'None')"
        fi
        echo ""
    fi
}

# Function to cleanup demo apps
cleanup_demos() {
    echo -e "${RED}🗑️  ลบ Demo Applications...${NC}"
    
    # Delete applications
    kubectl delete application guestbook -n argocd 2>/dev/null || true
    kubectl delete application helm-demo -n argocd 2>/dev/null || true
    kubectl delete application kustomize-demo -n argocd 2>/dev/null || true
    
    # Delete namespaces
    kubectl delete namespace helm-demo 2>/dev/null || true
    kubectl delete namespace kustomize-demo 2>/dev/null || true
    
    # Clean up default namespace resources
    kubectl delete deployment guestbook-ui -n default 2>/dev/null || true
    kubectl delete service guestbook-ui -n default 2>/dev/null || true
    kubectl delete deployment redis-master -n default 2>/dev/null || true
    kubectl delete service redis-master -n default 2>/dev/null || true
    kubectl delete deployment redis-slave -n default 2>/dev/null || true
    kubectl delete service redis-slave -n default 2>/dev/null || true
    
    echo -e "${GREEN}✅ Demo Applications ถูกลบแล้ว${NC}"
}

# Main menu
show_menu() {
    echo -e "${BLUE}📋 เลือกการสาธิต:${NC}"
    echo "=================="
    echo "1. 📱 สร้าง Guestbook Demo (Plain YAML)"
    echo "2. 📱 สร้าง Helm Chart Demo"
    echo "3. 📱 สร้าง Kustomize Demo"
    echo "4. 🚀 สร้างทั้งหมด (แนะนำ)"
    echo "5. 📊 แสดงสถานะ Applications"
    echo "6. 🌐 แสดงข้อมูลการเข้าถึง"
    echo "7. 🗑️  ลบ Demo Applications"
    echo "8. ❌ ออก"
    echo ""
}

# Main execution
case "${1:-menu}" in
    "guestbook"|"1")
        create_guestbook_app
        wait_for_apps
        show_app_status
        show_access_info
        ;;
    "helm"|"2")
        create_helm_demo_app
        wait_for_apps
        show_app_status
        show_access_info
        ;;
    "kustomize"|"3")
        create_kustomize_demo_app
        wait_for_apps
        show_app_status
        show_access_info
        ;;
    "all"|"4")
        create_guestbook_app
        create_helm_demo_app
        create_kustomize_demo_app
        wait_for_apps
        show_app_status
        show_access_info
        ;;
    "status"|"5")
        show_app_status
        ;;
    "access"|"6")
        show_access_info
        ;;
    "cleanup"|"7")
        cleanup_demos
        ;;
    "menu"|*)
        while true; do
            show_menu
            read -p "เลือกตัวเลือก (1-8): " choice
            
            case $choice in
                1)
                    create_guestbook_app
                    wait_for_apps
                    show_app_status
                    ;;
                2)
                    create_helm_demo_app
                    wait_for_apps
                    show_app_status
                    ;;
                3)
                    create_kustomize_demo_app
                    wait_for_apps
                    show_app_status
                    ;;
                4)
                    create_guestbook_app
                    create_helm_demo_app
                    create_kustomize_demo_app
                    wait_for_apps
                    show_app_status
                    show_access_info
                    ;;
                5)
                    show_app_status
                    ;;
                6)
                    show_access_info
                    ;;
                7)
                    cleanup_demos
                    ;;
                8)
                    echo -e "${GREEN}👋 ลาก่อน!${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}❌ ตัวเลือกไม่ถูกต้อง${NC}"
                    ;;
            esac
            
            echo ""
            read -p "กด Enter เพื่อกลับไปยังเมนู..."
        done
        ;;
esac

echo ""
echo -e "${GREEN}🎬 Demo เสร็จสิ้น!${NC}"
echo -e "${BLUE}🌐 เข้าดู ArgoCD UI ที่: http://localhost${NC}"
echo -e "${YELLOW}💡 ลองดูการเปลี่ยนแปลงใน Applications tab${NC}"
