#!/bin/bash

# =============================================================================
# 🔑 ดึงรหัสผ่าน ArgoCD Admin หรือรีเซ็ตรหัสผ่านใหม่
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

echo "🔑 ดึงรหัสผ่าน ArgoCD Admin หรือรีเซ็ตรหัสผ่านใหม่"
echo "================================================"

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
log "กำลังค้นหารหัสผ่าน admin จาก secret..."
admin_password=$(kubectl -n argocd get secret argocd-initial-admin-password -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

# ตรวจสอบว่าได้รหัสผ่านหรือไม่
if [ -n "$admin_password" ]; then
    log "✅ พบรหัสผ่าน admin"
    echo ""
    echo "👤 Username: admin"
    echo "🔑 Password: $admin_password"
    echo ""
    
    # สอบถามว่าต้องการรีเซ็ตรหัสผ่านหรือไม่
    read -p "ต้องการรีเซ็ตรหัสผ่านหรือไม่? (y/N): " reset_choice
    if [[ "$reset_choice" =~ ^[Yy]$ ]]; then
        log "กำลังรีเซ็ตรหัสผ่าน..."
        # จะทำในขั้นตอนถัดไป
    else
        log "ยังคงใช้รหัสผ่านเดิม"
        exit 0
    fi
else
    warn "❌ ไม่พบ secret 'argocd-initial-admin-password'"
    echo ""
    echo "สาเหตุที่เป็นไปได้:"
    echo "1. ArgoCD อาจจะถูกติดตั้งมานานแล้วและ secret ถูกลบไปแล้ว"
    echo "2. ArgoCD อาจจะถูกติดตั้งด้วยวิธีที่ไม่ได้สร้าง secret นี้"
    echo "3. มีการเปลี่ยนแปลงรหัสผ่าน admin แล้ว"
    echo ""
    
    # สอบถามว่าต้องการรีเซ็ตรหัสผ่านหรือไม่
    read -p "ต้องการรีเซ็ตรหัสผ่าน admin หรือไม่? (Y/n): " reset_choice
    if [[ "$reset_choice" =~ ^[Nn]$ ]]; then
        log "ยกเลิกการรีเซ็ตรหัสผ่าน"
        exit 0
    fi
    
    log "กำลังเตรียมรีเซ็ตรหัสผ่าน..."
fi

# รีเซ็ตรหัสผ่าน admin
log "กำลังตรวจสอบวิธีการรีเซ็ตรหัสผ่านที่เหมาะสม..."

# ตรวจสอบว่ามี argocd CLI หรือไม่
if command -v argocd >/dev/null 2>&1; then
    log "พบ argocd CLI จะใช้วิธีนี้ในการรีเซ็ตรหัสผ่าน"
    
    # ตรวจสอบว่าสามารถเข้าถึง ArgoCD API server ได้หรือไม่
    argocd_server_running=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    if [ "$argocd_server_running" = "Running" ]; then
        # ดึง ArgoCD Server URL
        log "กำลังตรวจสอบ URL ของ ArgoCD server..."
        
        # ตรวจสอบว่ามีการ port-forward หรือไม่
        if pgrep -f "kubectl.*port-forward.*argocd-server" >/dev/null; then
            log "พบการทำ port-forward สำหรับ ArgoCD server"
            
            # ดู port ที่ใช้
            port_forward_info=$(ps aux | grep "kubectl.*port-forward.*argocd-server" | grep -v grep | head -1)
            forwarded_port=$(echo "$port_forward_info" | grep -o "[0-9]\+:[0-9]\+" | cut -d: -f1)
            
            if [ -n "$forwarded_port" ]; then
                log "กำลังใช้ port $forwarded_port สำหรับการเชื่อมต่อกับ ArgoCD server"
                argocd_server_url="https://localhost:$forwarded_port"
            else
                # ถ้าไม่สามารถดึง port ได้ ใช้ค่าเริ่มต้น
                log "ไม่สามารถระบุ port ที่ใช้ จะใช้ port 8080"
                argocd_server_url="https://localhost:8080"
            fi
        else
            # ถ้าไม่มีการ port-forward ทำ port-forward
            log "ไม่พบการทำ port-forward สำหรับ ArgoCD server กำลังทำ port-forward..."
            kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
            sleep 3
            argocd_server_url="https://localhost:8080"
        fi
        
        # ทำการ login
        log "กำลังพยายาม login เข้า ArgoCD เพื่อรีเซ็ตรหัสผ่าน..."
        
        # ตรวจสอบว่าสามารถ login ด้วยรหัสผ่านเดิมได้หรือไม่
        if [ -n "$admin_password" ]; then
            if argocd login --insecure "$argocd_server_url" --username admin --password "$admin_password" >/dev/null 2>&1; then
                log "✅ login สำเร็จด้วยรหัสผ่านเดิม"
                can_login=true
            else
                warn "⚠️ ไม่สามารถ login ด้วยรหัสผ่านเดิมได้"
                can_login=false
            fi
        else
            can_login=false
        fi
        
        if [ "$can_login" = true ]; then
            # สร้างรหัสผ่านใหม่
            new_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
            
            # เปลี่ยนรหัสผ่าน
            log "กำลังเปลี่ยนรหัสผ่าน..."
            if argocd account update-password --current-password "$admin_password" --new-password "$new_password"; then
                log "✅ เปลี่ยนรหัสผ่านสำเร็จ"
                echo ""
                echo "👤 Username: admin"
                echo "🔑 รหัสผ่านใหม่: $new_password"
                echo ""
                echo "โปรดจดรหัสผ่านใหม่ไว้ในที่ปลอดภัย"
            else
                error "❌ ไม่สามารถเปลี่ยนรหัสผ่านได้"
            fi
        else
            # ไม่สามารถ login ได้ ใช้วิธี patch secret
            warn "ไม่สามารถใช้ argocd CLI เพื่อรีเซ็ตรหัสผ่านได้"
            warn "จะใช้วิธี patch secret แทน"
            use_patch_method=true
        fi
    else
        warn "ArgoCD server ไม่ทำงาน จะใช้วิธี patch secret แทน"
        use_patch_method=true
    fi
else
    log "ไม่พบ argocd CLI จะใช้วิธี patch secret แทน"
    use_patch_method=true
fi

# ถ้าต้องใช้วิธี patch secret
if [ "${use_patch_method:-false}" = true ]; then
    log "กำลังใช้วิธี patch secret เพื่อรีเซ็ตรหัสผ่าน..."
    
    # ตรวจสอบ bcrypt
    if ! command -v htpasswd >/dev/null 2>&1; then
        warn "ไม่พบคำสั่ง htpasswd (จาก apache2-utils หรือ httpd-tools)"
        warn "จะใช้รหัสผ่านแบบเรียบง่ายแทน"
        
        # สร้างรหัสผ่านใหม่
        new_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
        hashed_password="$new_password"
    else
        # สร้างรหัสผ่านใหม่
        new_password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
        
        # Hash รหัสผ่านด้วย bcrypt
        hashed_password=$(htpasswd -bnBC 10 "" "$new_password" | tr -d ':\n')
    fi
    
    # ตรวจสอบว่ามี secret argocd-secret หรือไม่
    if kubectl get secret argocd-secret -n argocd >/dev/null 2>&1; then
        log "พบ secret 'argocd-secret' กำลังปรับปรุง..."
        
        # สร้างไฟล์ patch
        patch_file=$(mktemp)
        cat > "$patch_file" << EOF
{
  "stringData": {
    "admin.password": "$hashed_password",
    "admin.passwordMtime": "$(date +%FT%T%Z)"
  }
}
EOF
        
        # Patch secret
        if kubectl patch secret argocd-secret -n argocd --patch-file "$patch_file"; then
            log "✅ ปรับปรุง secret สำเร็จ"
            echo ""
            echo "👤 Username: admin"
            echo "🔑 รหัสผ่านใหม่: $new_password"
            echo ""
            echo "โปรดจดรหัสผ่านใหม่ไว้ในที่ปลอดภัย"
            
            # รีสตาร์ท ArgoCD server
            log "กำลังรีสตาร์ท ArgoCD server เพื่อให้การเปลี่ยนแปลงมีผล..."
            kubectl -n argocd rollout restart deploy argocd-server
            
            # ลบไฟล์ patch
            rm "$patch_file"
        else
            error "❌ ไม่สามารถ patch secret ได้"
            # ลบไฟล์ patch
            rm "$patch_file"
        fi
    else
        error "❌ ไม่พบ secret 'argocd-secret'"
        error "ไม่สามารถรีเซ็ตรหัสผ่านได้"
    fi
fi

echo ""
log "✅ การดำเนินการเสร็จสิ้น"
