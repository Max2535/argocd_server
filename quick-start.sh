#!/bin/bash

# =============================================================================
# 🚀 ArgoCD Quick Start Script
# =============================================================================
# สำหรับผู้ที่ต้องการติดตั้งอย่างรวดเร็ว
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${PURPLE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║           🚀 ArgoCD Quick Start Installer 🚀               ║"
echo "║                                                            ║"
echo "║     ติดตั้ง ArgoCD ภายใน 5 นาที - พร้อมใช้งานทันที!         ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if install-full-stack.sh exists
if [[ ! -f "install-full-stack.sh" ]]; then
    echo -e "${YELLOW}🔄 ดาวน์โหลด installer...${NC}"
    
    # Try to download from GitHub
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o install-full-stack.sh https://raw.githubusercontent.com/Max2535/argocd_server/main/install-full-stack.sh
    elif command -v wget >/dev/null 2>&1; then
        wget -O install-full-stack.sh https://raw.githubusercontent.com/Max2535/argocd_server/main/install-full-stack.sh
    else
        echo -e "${RED}❌ ไม่พบ curl หรือ wget กรุณาติดตั้งก่อน${NC}"
        exit 1
    fi
    
    chmod +x install-full-stack.sh
    echo -e "${GREEN}✅ ดาวน์โหลดสำเร็จ${NC}"
fi

echo -e "${BLUE}🔍 ตรวจสอบระบบ...${NC}"

# Basic system check
errors=0

# Check if running on supported system
if [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]] || [[ "$OS" == "Windows_NT" ]]; then
    OS_TYPE="windows"
    echo -e "${GREEN}✅ ระบบ: Windows${NC}"
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker ไม่ได้ติดตั้ง${NC}"
        echo -e "${YELLOW}📋 กรุณาติดตั้ง Docker Desktop จาก: https://docs.docker.com/desktop/install/windows/${NC}"
        ((errors++))
    elif ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker ไม่ทำงาน${NC}"
        echo -e "${YELLOW}📋 กรุณาเปิด Docker Desktop${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ Docker ทำงานอยู่${NC}"
    fi
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        echo -e "${RED}❌ kubectl ไม่ได้ติดตั้ง${NC}"
        echo -e "${YELLOW}📋 กรุณาติดตั้ง kubectl: choco install kubernetes-cli${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ kubectl ติดตั้งแล้ว${NC}"
    fi
    
elif [[ "$(uname -s)" == "Linux" ]]; then
    OS_TYPE="linux"
    echo -e "${GREEN}✅ ระบบ: Linux${NC}"
    
    # Check if user has sudo
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  กำลังรันด้วย root user (ไม่แนะนำ)${NC}"
    elif ! sudo -n true 2>/dev/null; then
        echo -e "${RED}❌ ไม่มี sudo privileges${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✅ sudo privileges มีอยู่${NC}"
    fi
    
else
    echo -e "${RED}❌ ระบบปฏิบัติการไม่รองรับ${NC}"
    exit 1
fi

# Check Internet connection
if ping -c 1 8.8.8.8 >/dev/null 2>&1 || ping -n 1 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ เชื่อมต่อ Internet ได้${NC}"
else
    echo -e "${RED}❌ ไม่สามารถเชื่อมต่อ Internet ได้${NC}"
    ((errors++))
fi

# Check available ports
if command -v netstat >/dev/null 2>&1; then
    if netstat -an 2>/dev/null | grep -q ":80 "; then
        echo -e "${YELLOW}⚠️  Port 80 ถูกใช้อยู่ (จะหยุดและใช้งานใหม่)${NC}"
    else
        echo -e "${GREEN}✅ Port 80 ว่าง${NC}"
    fi
fi

echo ""

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}❌ พบปัญหา $errors รายการ กรุณาแก้ไขก่อนดำเนินการต่อ${NC}"
    echo ""
    echo -e "${BLUE}📋 วิธีแก้ไขสำหรับ Windows:${NC}"
    echo "1. ติดตั้ง Docker Desktop และเปิดใช้งาน"
    echo "2. ติดตั้ง kubectl: choco install kubernetes-cli" 
    echo "3. ติดตั้ง kind: choco install kind"
    echo ""
    echo -e "${BLUE}📋 วิธีแก้ไขสำหรับ Linux:${NC}"
    echo "1. ตรวจสอบ sudo privileges"
    echo "2. ตรวจสอบการเชื่อมต่อ Internet"
    echo ""
    exit 1
fi

echo -e "${GREEN}🎉 ระบบพร้อมสำหรับติดตั้ง!${NC}"
echo ""

# Ask for confirmation
echo -e "${BLUE}📋 สิ่งที่จะติดตั้ง:${NC}"
echo "   🔧 Kubernetes cluster (kind)"
echo "   🔱 ArgoCD GitOps platform"
echo "   🌐 Nginx reverse proxy"
echo "   🛠️ Management scripts"
echo ""

read -p "🚀 เริ่มการติดตั้งหรือไม่? (y/N): " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "การติดตั้งถูกยกเลิก"
    exit 0
fi

echo ""
echo -e "${PURPLE}🚀 เริ่มการติดตั้ง ArgoCD Full Stack...${NC}"
echo ""

# Run the main installer
if [[ "$OS_TYPE" == "windows" ]]; then
    # For Windows, skip dependency installation since Docker Desktop is manual
    ./install-full-stack.sh -y --skip-deps
else
    # For Linux, install everything
    ./install-full-stack.sh -y
fi

echo ""
echo -e "${GREEN}🎊 การติดตั้งเสร็จสมบูรณ์!${NC}"
echo ""
echo -e "${BLUE}🚀 เข้าใช้งาน ArgoCD:${NC}"
echo "   🌐 URL: http://localhost"
echo "   👤 Username: admin"
echo "   🔑 Password: ใช้คำสั่ง ./get-password.sh"
echo ""
echo -e "${BLUE}🛠️ คำสั่งจัดการ:${NC}"
echo "   ./start-argocd.sh      - เริ่มต้น ArgoCD"
echo "   ./stop-argocd.sh       - หยุด ArgoCD"
echo "   ./status-argocd.sh     - ตรวจสอบสถานะ"
echo "   ./get-password.sh      - ดูรหัสผ่าน"
echo ""
echo -e "${GREEN}🎯 พร้อมสำหรับ GitOps แล้ว!${NC}"

# Try to open browser
if command -v python3 >/dev/null 2>&1; then
    read -p "🌐 เปิดเบราว์เซอร์ไปที่ ArgoCD UI หรือไม่? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [[ "$OS_TYPE" == "windows" ]]; then
            start http://localhost
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open http://localhost
        elif command -v open >/dev/null 2>&1; then
            open http://localhost
        fi
    fi
fi
