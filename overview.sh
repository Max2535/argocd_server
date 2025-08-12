#!/bin/bash

# =============================================================================
# 📋 ArgoCD Full Stack Overview
# =============================================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║              🚀 ArgoCD Full Stack Installation 🚀                  ║"
echo "║                                                                    ║"
echo "║    One-Click Kubernetes + ArgoCD + Nginx Reverse Proxy Installer   ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BLUE}📋 Available Scripts:${NC}"
echo "===================="
echo ""

echo -e "${GREEN}🚀 Installation Scripts:${NC}"
echo "   ./quick-start.sh           - Quick installation with system check"
echo "   ./install-full-stack.sh    - Complete automated installer"
echo "   ./check-system-windows.sh  - System requirements checker (Windows)"
echo "   ./start-services.sh        - Start Docker and Kubernetes services"
echo ""

echo -e "${GREEN}🛠️ Management Scripts:${NC}"
echo "   ./start-argocd.sh          - Start ArgoCD full stack"
echo "   ./stop-argocd.sh           - Stop ArgoCD full stack"
echo "   ./status-argocd.sh         - Show system status"
echo "   ./get-password.sh          - Get ArgoCD admin password"
echo "   ./manage-argocd.sh         - ArgoCD management menu"
echo "   ./fix-docker-ubuntu.sh     - Fix Docker issues on Ubuntu"
echo ""

echo -e "${GREEN}🌐 Networking Scripts:${NC}"
echo "   ./simple-nginx.sh          - Simple nginx reverse proxy"
echo "   ./nginx-setup.sh           - Advanced nginx setup"
echo ""

echo -e "${GREEN}🎬 Demo Scripts:${NC}"
echo "   ./demo-apps.sh             - Deploy demo applications"
echo ""

echo -e "${GREEN}🗑️ Cleanup Scripts:${NC}"
echo "   ./uninstall-argocd.sh      - Complete uninstallation"
echo ""

echo -e "${BLUE}🎯 Quick Start Guide:${NC}"
echo "===================="
echo ""

echo -e "${CYAN}1️⃣ First Time Installation:${NC}"
echo "   ${YELLOW}./quick-start.sh${NC}           # Recommended for beginners"
echo "   หรือ"
echo "   ${YELLOW}./install-full-stack.sh -y${NC}  # Silent installation"
echo ""

echo -e "${CYAN}2️⃣ Daily Usage:${NC}"
echo "   ${YELLOW}./start-argocd.sh${NC}          # Start ArgoCD"
echo "   ${YELLOW}./status-argocd.sh${NC}         # Check status"
echo "   ${YELLOW}./stop-argocd.sh${NC}           # Stop ArgoCD"
echo ""

echo -e "${CYAN}3️⃣ ArgoCD Access:${NC}"
echo "   🌐 URL: ${BLUE}http://localhost${NC}"
echo "   👤 Username: ${YELLOW}admin${NC}"
echo "   🔑 Password: ${YELLOW}./get-password.sh${NC}"
echo ""

echo -e "${CYAN}4️⃣ Try Demo Applications:${NC}"
echo "   ${YELLOW}./demo-apps.sh${NC}             # Deploy sample apps"
echo ""

echo -e "${BLUE}💡 Pro Tips:${NC}"
echo "==========="
echo ""

echo -e "${CYAN}📱 For Mobile/Easy Access:${NC}"
echo "   - ArgoCD UI is optimized for mobile browsers"
echo "   - Access via http://localhost from any device on same network"
echo ""

echo -e "${CYAN}🔧 Troubleshooting:${NC}"
echo "   - Check logs: ${YELLOW}cat argocd-install.log${NC}"
echo "   - System status: ${YELLOW}./status-argocd.sh${NC}"
echo "   - Restart services: ${YELLOW}./stop-argocd.sh && ./start-argocd.sh${NC}"
echo ""

echo -e "${CYAN}📚 Learn More:${NC}"
echo "   - ArgoCD Docs: https://argo-cd.readthedocs.io/"
echo "   - Kubernetes Docs: https://kubernetes.io/docs/"
echo "   - GitOps Guide: https://www.gitops.tech/"
echo ""

echo -e "${BLUE}🎉 Components Installed:${NC}"
echo "========================"

# Check if components exist
if [[ -f "install-full-stack.sh" ]]; then
    echo -e "   ✅ Full Stack Installer"
else
    echo -e "   ❌ Full Stack Installer"
fi

if command -v kubectl >/dev/null 2>&1; then
    echo -e "   ✅ kubectl"
else
    echo -e "   ❌ kubectl"
fi

if command -v docker >/dev/null 2>&1; then
    echo -e "   ✅ Docker"
else
    echo -e "   ❌ Docker"
fi

if command -v kind >/dev/null 2>&1; then
    echo -e "   ✅ kind"
else
    echo -e "   ❌ kind"
fi

# Check if ArgoCD is installed
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "   ✅ ArgoCD"
    ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep Running | wc -l || echo 0)
    total_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l || echo 0)
    echo -e "       Pods: $ready_pods/$total_pods running"
else
    echo -e "   ❌ ArgoCD (not installed)"
fi

# Check nginx proxy
if docker ps | grep -q nginx-argocd; then
    echo -e "   ✅ Nginx Reverse Proxy"
else
    echo -e "   ❌ Nginx Reverse Proxy (not running)"
fi

echo ""

# System info
echo -e "${BLUE}💻 System Information:${NC}"
echo "====================="
echo "   OS: $(uname -s)"
echo "   Architecture: $(uname -m)"
if command -v nproc >/dev/null 2>&1; then
    echo "   CPU Cores: $(nproc)"
fi

if [[ -f /proc/meminfo ]]; then
    ram_gb=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
    echo "   RAM: ${ram_gb}GB"
fi

if command -v df >/dev/null 2>&1; then
    disk_gb=$(df / | awk 'NR==2{printf "%.1f", $4/1024/1024}')
    echo "   Available Disk: ${disk_gb}GB"
fi

echo ""

echo -e "${GREEN}🚀 Ready to start your GitOps journey!${NC}"
echo ""

# Show next steps based on current state
if kubectl get namespace argocd >/dev/null 2>&1; then
    echo -e "${YELLOW}🎯 Next Steps:${NC}"
    echo "   1. ./status-argocd.sh     # Check current status"
    echo "   2. Open http://localhost  # Access ArgoCD UI"
    echo "   3. ./demo-apps.sh         # Try demo applications"
else
    echo -e "${YELLOW}🎯 Next Steps:${NC}"
    echo "   1. ./quick-start.sh       # Install ArgoCD"
    echo "   2. ./demo-apps.sh         # Try demo applications"
fi

echo ""
