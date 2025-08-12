#!/bin/bash

# =============================================================================
# 🔑 รีเซ็ตรหัสผ่าน ArgoCD Admin อย่างง่าย
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

echo "🔑 รีเซ็ตรหัสผ่าน ArgoCD Admin อย่างง่าย"
echo "======================================"

log "วิธีนี้ใช้ได้เฉพาะบนเซิร์ฟเวอร์ที่รัน ArgoCD เท่านั้น"
echo ""
log "กรุณารันคำสั่งต่อไปนี้บนเซิร์ฟเวอร์ ArgoCD:"
echo ""
echo "-----------------------"
echo "kubectl -n argocd patch secret argocd-secret \\"
echo "  -p '{\"stringData\": {\"admin.password\": \"\$2a\$10\$rRyRGXRBRUscQPZALMCDQOTtSbZqNRA0Dv9k7hkyFxNQeGYR3pjMW\", \"admin.passwordMtime\": \"'\"$(date +%FT%T%Z)\"'\"}}'"
echo "-----------------------"
echo ""
log "รหัสผ่านใหม่คือ: admin123"
echo ""
log "หลังจากรันคำสั่งแล้ว กรุณารีสตาร์ท ArgoCD server:"
echo ""
echo "-----------------------"
echo "kubectl -n argocd rollout restart deploy argocd-server"
echo "-----------------------"
echo ""
log "รอประมาณ 30 วินาที แล้วลองล็อกอินด้วย username: admin, password: admin123"
echo ""
warn "อย่าลืมเปลี่ยนรหัสผ่านใหม่หลังจากล็อกอินได้แล้ว เพื่อความปลอดภัย!"
