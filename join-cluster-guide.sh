#!/bin/bash

# =============================================================================
# 🔗 Join Kubernetes Cluster - Client Setup Guide
# =============================================================================

echo "🔗 วิธีการ Join Kubernetes Cluster Client"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "\n${BLUE}📋 เลือกประเภท Cluster ที่ต้องการ Join:${NC}"
echo "1️⃣  kind Cluster (Local Development)"
echo "2️⃣  kubeadm Cluster (Production)"
echo "3️⃣  Cloud Cluster (EKS, GKE, AKS)"
echo "4️⃣  Existing Cluster (มี kubeconfig แล้ว)"
echo ""

read -p "เลือก (1-4): " cluster_type

case $cluster_type in
    1)
        echo -e "\n${CYAN}🐳 kind Cluster - Local Development${NC}"
        echo "=================================="
        
        echo -e "\n1️⃣ ตรวจสอบ kind clusters ที่มีอยู่:"
        echo "   kind get clusters"
        
        echo -e "\n2️⃣ ดู kubeconfig ของ cluster:"
        echo "   kind get kubeconfig --name=argocd-cluster"
        
        echo -e "\n3️⃣ Copy kubeconfig ไปยัง client machine:"
        echo "   # บน server (ที่มี kind cluster)"
        echo "   kind get kubeconfig --name=argocd-cluster > argocd-kubeconfig.yaml"
        echo ""
        echo "   # แก้ไข server IP ใน kubeconfig"
        echo "   sed -i 's/127.0.0.1/SERVER_IP_ADDRESS/g' argocd-kubeconfig.yaml"
        echo ""
        echo "   # Copy ไปยัง client"
        echo "   scp argocd-kubeconfig.yaml user@client-machine:~/.kube/config"
        
        echo -e "\n4️⃣ บน client machine:"
        echo "   # ติดตั้ง kubectl"
        echo "   curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        echo "   sudo install kubectl /usr/local/bin/"
        echo ""
        echo "   # ทดสอบการเชื่อมต่อ"
        echo "   kubectl cluster-info"
        echo "   kubectl get nodes"
        
        echo -e "\n${YELLOW}⚠️  หมายเหตุ:${NC}"
        echo "   - kind cluster ใช้ Docker port mapping"
        echo "   - ต้องแก้ไข IP address ใน kubeconfig"
        echo "   - เหมาะสำหรับ development เท่านั้น"
        ;;
        
    2)
        echo -e "\n${CYAN}⚙️ kubeadm Cluster - Production${NC}"
        echo "================================"
        
        echo -e "\n1️⃣ บน Master Node - สร้าง join token:"
        echo "   # สร้าง token ใหม่"
        echo "   kubeadm token create --print-join-command"
        echo ""
        echo "   # หรือดู token ที่มีอยู่"
        echo "   kubeadm token list"
        echo ""
        echo "   # ดู CA cert hash"
        echo "   openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'"
        
        echo -e "\n2️⃣ บน Worker Node - Join cluster:"
        echo "   # รัน command ที่ได้จาก master"
        echo "   sudo kubeadm join <MASTER_IP>:6443 \\"
        echo "     --token <TOKEN> \\"
        echo "     --discovery-token-ca-cert-hash sha256:<HASH>"
        
        echo -e "\n3️⃣ Setup kubectl บน client machine:"
        echo "   # Copy admin kubeconfig จาก master"
        echo "   scp root@master-node:/etc/kubernetes/admin.conf ~/.kube/config"
        echo ""
        echo "   # แก้ไข ownership"
        echo "   sudo chown \$(id -u):\$(id -g) ~/.kube/config"
        echo ""
        echo "   # ทดสอบ"
        echo "   kubectl get nodes"
        
        echo -e "\n${YELLOW}⚠️  ข้อกำหนด:${NC}"
        echo "   - Ports 6443, 2379-2380, 10250-10252 ต้องเปิด"
        echo "   - CNI plugin ต้องติดตั้งแล้ว"
        echo "   - Container runtime ต้องพร้อม"
        ;;
        
    3)
        echo -e "\n${CYAN}☁️ Cloud Cluster (EKS, GKE, AKS)${NC}"
        echo "================================"
        
        echo -e "\n${BLUE}🌊 AWS EKS:${NC}"
        echo "   # ติดตั้ง AWS CLI และ eksctl"
        echo "   curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
        echo "   unzip awscliv2.zip && sudo ./aws/install"
        echo ""
        echo "   # Configure AWS credentials"
        echo "   aws configure"
        echo ""
        echo "   # Get kubeconfig"
        echo "   aws eks update-kubeconfig --region <region> --name <cluster-name>"
        
        echo -e "\n${BLUE}🌐 Google GKE:${NC}"
        echo "   # ติดตั้ง gcloud CLI"
        echo "   curl https://sdk.cloud.google.com | bash"
        echo "   exec -l \$SHELL"
        echo ""
        echo "   # Login และ set project"
        echo "   gcloud auth login"
        echo "   gcloud config set project <project-id>"
        echo ""
        echo "   # Get kubeconfig"
        echo "   gcloud container clusters get-credentials <cluster-name> --zone <zone>"
        
        echo -e "\n${BLUE}🔷 Azure AKS:${NC}"
        echo "   # ติดตั้ง Azure CLI"
        echo "   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        echo ""
        echo "   # Login"
        echo "   az login"
        echo ""
        echo "   # Get kubeconfig"
        echo "   az aks get-credentials --resource-group <rg-name> --name <cluster-name>"
        
        echo -e "\n4️⃣ ทดสอบการเชื่อมต่อ:"
        echo "   kubectl cluster-info"
        echo "   kubectl get nodes"
        ;;
        
    4)
        echo -e "\n${CYAN}📝 Existing Cluster (มี kubeconfig แล้ว)${NC}"
        echo "======================================="
        
        echo -e "\n1️⃣ Copy kubeconfig file:"
        echo "   # วิธีที่ 1: Copy ทั้งไฟล์"
        echo "   cp /path/to/kubeconfig ~/.kube/config"
        echo ""
        echo "   # วิธีที่ 2: Merge กับ config ที่มีอยู่"
        echo "   KUBECONFIG=~/.kube/config:/path/to/new-config kubectl config view --flatten > ~/.kube/merged-config"
        echo "   mv ~/.kube/merged-config ~/.kube/config"
        
        echo -e "\n2️⃣ เลือก context:"
        echo "   # ดู contexts ที่มีอยู่"
        echo "   kubectl config get-contexts"
        echo ""
        echo "   # เปลี่ยน context"
        echo "   kubectl config use-context <context-name>"
        
        echo -e "\n3️⃣ ทดสอบการเชื่อมต่อ:"
        echo "   kubectl cluster-info"
        echo "   kubectl get nodes"
        echo "   kubectl get namespaces"
        
        echo -e "\n4️⃣ Access ArgoCD (ถ้ามี):"
        echo "   # ดู ArgoCD service"
        echo "   kubectl get svc -n argocd"
        echo ""
        echo "   # Port forward"
        echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo ""
        echo "   # หรือใช้ LoadBalancer/Ingress ถ้ามี"
        ;;
        
    *)
        log_error "❌ เลือกไม่ถูกต้อง"
        exit 1
        ;;
esac

echo -e "\n${GREEN}🔧 ขั้นตอนทั่วไปหลัง Join Cluster:${NC}"
echo "================================="

echo -e "\n1️⃣ ตรวจสอบสถานะ cluster:"
echo "   kubectl cluster-info"
echo "   kubectl get nodes -o wide"
echo "   kubectl get namespaces"

echo -e "\n2️⃣ ตรวจสอบ permissions:"
echo "   kubectl auth can-i get pods"
echo "   kubectl auth can-i create deployments"
echo "   kubectl auth can-i '*' '*' --all-namespaces"

echo -e "\n3️⃣ Setup namespace (ถ้าต้องการ):"
echo "   kubectl create namespace my-app"
echo "   kubectl config set-context --current --namespace=my-app"

echo -e "\n4️⃣ Access ArgoCD UI:"
echo "   # ดู ArgoCD service"
echo "   kubectl get svc -n argocd"
echo ""
echo "   # Get admin password"
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"

echo -e "\n${YELLOW}🛠️ Troubleshooting:${NC}"
echo "==================="

echo -e "\n❌ Connection refused:"
echo "   - ตรวจสอบ firewall/security groups"
echo "   - ตรวจสอบ API server endpoint"
echo "   - ตรวจสอบ network connectivity"

echo -e "\n❌ Permission denied:"
echo "   - ตรวจสอบ RBAC permissions"
echo "   - ใช้ service account ที่ถูกต้อง"
echo "   - ตรวจสอบ kubeconfig context"

echo -e "\n❌ Certificate errors:"
echo "   - ตรวจสอบ CA certificate"
echo "   - ตรวจสอบ system time"
echo "   - ลอง kubectl --insecure-skip-tls-verify (ไม่แนะนำสำหรับ production)"

echo -e "\n${GREEN}🎯 สรุป:${NC}"
echo "======="
echo "1. เลือกวิธี join ตามประเภท cluster"
echo "2. Copy kubeconfig ไปยัง client machine"
echo "3. ติดตั้ง kubectl บน client"
echo "4. ทดสอบการเชื่อมต่อ"
echo "5. Setup permissions และ namespace ตามต้องการ"

echo -e "\n${BLUE}📚 เอกสารเพิ่มเติม:${NC}"
echo "- Kubernetes Documentation: https://kubernetes.io/docs/"
echo "- kubectl Cheat Sheet: https://kubernetes.io/docs/reference/kubectl/cheatsheet/"
echo "- RBAC Guide: https://kubernetes.io/docs/reference/access-authn-authz/rbac/"

echo -e "\n✅ เสร็จสิ้นการแนะนำ!"
