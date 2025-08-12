#!/bin/bash

# =============================================================================
# 🔑 ดึงรหัสผ่าน ArgoCD Admin
# =============================================================================

# สีสำหรับแสดงผล
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

echo "🔑 ดึงรหัสผ่าน ArgoCD Admin"
echo "================================"

# ตรวจสอบว่ามี kubectl หรือไม่
if ! command -v kubectl >/dev/null 2>&1; then
    error "ไม่พบคำสั่ง kubectl กรุณาติดตั้งก่อนใช้งาน"
    exit 1
fi

# ตรวจสอบว่าสามารถเข้าถึง Kubernetes cluster ได้หรือไม่
if ! kubectl cluster-info >/dev/null 2>&1; then
    error "ไม่สามารถเข้าถึง Kubernetes cluster ได้"
    error "กรุณาตรวจสอบการตั้งค่า kubeconfig หรือการเชื่อมต่อกับ cluster"
    exit 1
fi

# ตรวจสอบ namespace argocd
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    error "ไม่พบ namespace argocd"
    error "กรุณาตรวจสอบว่าได้ติดตั้ง ArgoCD แล้ว"
    exit 1
fi

# พยายามดึงรหัสผ่านจาก secret
log "กำลังดึงรหัสผ่าน admin จาก secret..."

# ตรวจสอบชื่อ secret ที่ถูกต้อง (มีหลายรูปแบบที่อาจใช้)
possible_secrets=("argocd-initial-admin-password" "argocd-initial-admin-secret")
admin_password=""

for secret_name in "${possible_secrets[@]}"; do
    log "กำลังตรวจสอบ secret '$secret_name'..."
    password=$(kubectl -n argocd get secret $secret_name -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    
    if [ -n "$password" ]; then
        admin_password="$password"
        log "✅ พบรหัสผ่าน admin ใน secret '$secret_name'"
        break
    fi
done

# ถ้าไม่พบรหัสผ่านในทั้งสอง secret ลองวิธีอื่น
if [ -z "$admin_password" ]; then
    warn "⚠️ ไม่พบรหัสผ่านใน secret ทั่วไป"
    
    # ตรวจสอบว่า ArgoCD ถูกติดตั้งมานานแล้วหรือไม่
    argocd_created=$(kubectl get -n argocd deployment argocd-server -o jsonpath="{.metadata.creationTimestamp}" 2>/dev/null)
    if [ -n "$argocd_created" ]; then
        creation_date=$(date -d "$argocd_created" +"%Y-%m-%d" 2>/dev/null || echo "$argocd_created")
        warn "ArgoCD ถูกติดตั้งเมื่อ: $creation_date"
        warn "Secret อาจถูกลบไปแล้วเนื่องจากติดตั้งมานาน"
    fi
    
    # ถ้าไม่พบ secret แต่ ArgoCD ยังทำงานอยู่ แนะนำให้ใช้ reset-admin-password.sh
    if kubectl get -n argocd deployment argocd-server >/dev/null 2>&1; then
        warn "ArgoCD กำลังทำงานแต่ไม่พบรหัสผ่านเริ่มต้น"
        echo ""
        echo "สาเหตุที่เป็นไปได้:"
        echo "1. ArgoCD อาจถูกติดตั้งมานานแล้วและ secret ถูกลบไปแล้ว"
        echo "2. มีการเปลี่ยนแปลงรหัสผ่าน admin แล้ว"
        echo "3. ArgoCD อาจถูกติดตั้งด้วยวิธีที่ไม่ได้สร้าง secret สำหรับรหัสผ่านเริ่มต้น"
        echo ""
        warn "หากต้องการรีเซ็ตรหัสผ่าน admin กรุณาใช้:"
        echo "  ./reset-admin-password.sh"
        exit 1
    else
        error "❌ ไม่พบการติดตั้ง ArgoCD ที่ทำงานอยู่"
        error "กรุณาตรวจสอบการติดตั้ง ArgoCD ก่อน"
        exit 1
    fi
fi

# แสดงผลรหัสผ่าน
echo ""
echo "👤 Username: admin"
echo "🔑 Password: $admin_password"
echo ""
log "✅ การดำเนินการเสร็จสิ้น"
