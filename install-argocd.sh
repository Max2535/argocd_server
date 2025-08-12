#!/bin/bash

echo "🔱 สคริปต์ติดตั้ง ArgoCD บน Kubernetes"
echo "====================================="

# Check if kubectl is available and cluster is running
echo "🔍 ตรวจสอบ Kubernetes cluster..."
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Kubernetes cluster ไม่พร้อมใช้งาน"
    echo "💡 กรุณารัน ./start-services.sh ก่อน"
    exit 1
fi

echo "✅ Kubernetes cluster พร้อมใช้งาน"
echo "   Context: $(kubectl config current-context)"
echo "   Cluster: $(kubectl cluster-info | head -1 | grep -o 'https://[^[:space:]]*')"

# Create ArgoCD namespace
echo ""
echo "📦 สร้าง namespace สำหรับ ArgoCD..."
if kubectl get namespace argocd &> /dev/null; then
    echo "⚠️  namespace 'argocd' มีอยู่แล้ว"
else
    kubectl create namespace argocd
    echo "✅ สร้าง namespace 'argocd' สำเร็จ"
fi

# Install ArgoCD
echo ""
echo "🚀 ติดตั้ง ArgoCD..."
echo "⏳ กำลังดาวน์โหลดและติดตั้ง ArgoCD manifests..."

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

if [ $? -eq 0 ]; then
    echo "✅ ติดตั้ง ArgoCD manifests สำเร็จ"
else
    echo "❌ ติดตั้ง ArgoCD ไม่สำเร็จ"
    exit 1
fi

# Wait for ArgoCD to be ready
echo ""
echo "⏳ รอให้ ArgoCD pods เริ่มต้น..."
echo "   (อาจใช้เวลา 2-3 นาที สำหรับการดาวน์โหลด images)"

# Wait for deployment to be available
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

if [ $? -eq 0 ]; then
    echo "✅ ArgoCD server พร้อมใช้งาน!"
else
    echo "⚠️  ArgoCD server ใช้เวลานานกว่าปกติ กำลังตรวจสอบสถานะ..."
fi

# Check ArgoCD status
echo ""
echo "📊 สถานะ ArgoCD pods:"
kubectl get pods -n argocd

# Get initial admin password
echo ""
echo "🔑 รับรหัสผ่าน admin เริ่มต้น..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ ! -z "$ADMIN_PASSWORD" ]; then
    echo "✅ รหัสผ่าน admin: $ADMIN_PASSWORD"
else
    echo "⚠️  ไม่สามารถดึงรหัสผ่าน admin ได้ (อาจยังไม่พร้อม)"
    echo "💡 ลองคำสั่งนี้ภายหลัง:"
    echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
fi

# Setup port forwarding
echo ""
echo "🌐 ตั้งค่าการเข้าถึง ArgoCD UI..."
echo "📋 วิธีเข้าใช้งาน ArgoCD:"
echo ""
echo "1. เปิด port forwarding (ใน terminal ใหม่):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. เปิดเบราว์เซอร์ไปที่: https://localhost:8080"
echo "   (อาจมี certificate warning - คลิก 'Advanced' แล้ว 'Proceed')"
echo ""
echo "3. เข้าสู่ระบบด้วย:"
echo "   Username: admin"
if [ ! -z "$ADMIN_PASSWORD" ]; then
    echo "   Password: $ADMIN_PASSWORD"
else
    echo "   Password: (ใช้คำสั่งข้างบนเพื่อดูรหัสผ่าน)"
fi
echo ""

# Ask if user wants to start port forwarding now
echo "🔄 ต้องการเริ่ม port forwarding ทันทีหรือไม่? (y/N)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "🚀 เริ่ม port forwarding..."
    echo "💡 กด Ctrl+C เพื่อหยุด port forwarding"
    echo "🌐 ArgoCD UI จะเปิดที่: https://localhost:8080"
    echo ""
    kubectl port-forward svc/argocd-server -n argocd 8080:443
else
    echo ""
    echo "💡 เมื่อพร้อมใช้งาน ให้รันคำสั่ง:"
    echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
fi

echo ""
echo "====================================="
echo "🎉 การติดตั้ง ArgoCD เสร็จสมบูรณ์!"
echo ""
echo "📝 สรุปการติดตั้ง:"
echo "✅ Namespace: argocd"
echo "✅ ArgoCD Server: argocd-server"
echo "✅ UI Access: https://localhost:8080 (เมื่อ port forwarding)"
echo "✅ Username: admin"
if [ ! -z "$ADMIN_PASSWORD" ]; then
    echo "✅ Password: $ADMIN_PASSWORD"
fi
echo ""
echo "🔗 เอกสารเพิ่มเติม:"
echo "   - ArgoCD Documentation: https://argo-cd.readthedocs.io/"
echo "   - Getting Started: https://argo-cd.readthedocs.io/en/stable/getting_started/"
echo "====================================="
