#!/bin/bash
set -e

# ===============================
# Ubuntu Server 24.04 LTS + Kubernetes + ArgoCD Installation
# ===============================
echo "🚀 เริ่มติดตั้ง Kubernetes + ArgoCD บน Ubuntu Server 24.04"
echo "📅 Date: $(date)"
echo "🖥️  OS: $(lsb_release -d | cut -f2)"

# ตรวจสอบว่าเป็น root หรือมี sudo
if [[ $EUID -eq 0 ]]; then
   echo "❌ ไม่ควรรันสคริปต์นี้ด้วย root โปรดใช้ user ที่มี sudo privileges"
   exit 1
fi

# ===============================
# 1. อัปเดตระบบและติดตั้ง dependencies
# ===============================
echo "📦 อัปเดตระบบและติดตั้ง dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common

# ===============================
# 2. ตั้งค่า system requirements สำหรับ Kubernetes
# ===============================
echo "⚙️  ตั้งค่า system requirements..."

# ปิด Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# เปิดใช้งาน kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# ตั้งค่า sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# ===============================
# 3. ปิด Firewall (ถ้าไม่ต้องการจำกัด)
# ===============================
echo "🔥 ตั้งค่า Firewall..."
sudo ufw disable || true

# ===============================
# 4. ติดตั้ง Containerd (Container Runtime)
# ===============================
echo "📦 ติดตั้ง Containerd..."

# ติดตั้ง containerd
sudo apt install -y containerd

# สร้างและตั้งค่า containerd config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# เปิดใช้งาน SystemdCgroup (จำเป็นสำหรับ Kubernetes)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# restart และ enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# ตรวจสอบสถานะ containerd
if ! sudo systemctl is-active --quiet containerd; then
    echo "❌ Containerd ไม่สามารถเริ่มทำงานได้"
    exit 1
fi
echo "✅ Containerd ติดตั้งและทำงานเรียบร้อย"

# ===============================
# 5. ติดตั้ง kubeadm, kubelet, kubectl
# ===============================
echo "☸️  ติดตั้ง Kubernetes components..."

# เพิ่ม Kubernetes GPG key และ repository
sudo mkdir -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key |
    sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" |
    sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# เปิดใช้งาน kubelet
sudo systemctl enable kubelet

echo "✅ Kubernetes components ติดตั้งเรียบร้อย"
echo "📋 เวอร์ชัน: $(kubeadm version -o short)"

# ===============================
# 6. Initial Control Plane (Master Node)
# ===============================
if [ "$1" == "master" ]; then
    echo "🎛️  เริ่มติดตั้ง Control Plane (Master Node)..."
    
    # ดึง IP address ของ server
    SERVER_IP=$(ip route get 8.8.8.8 | awk -F"src " 'NR==1{split($2,a," ");print a[1]}')
    echo "🌐 Server IP: $SERVER_IP"
    
    # Initialize Kubernetes cluster
    sudo kubeadm init \
        --pod-network-cidr=10.244.0.0/16 \
        --apiserver-advertise-address=$SERVER_IP \
        --node-name=$(hostname)

    # ตั้งค่า kubectl สำหรับ user
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    # รอให้ API server พร้อม
    echo "⏳ รอให้ Kubernetes API server พร้อม..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    # ติดตั้ง Flannel CNI
    echo "🌐 ติดตั้ง Flannel CNI Plugin..."
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

    echo "✅ Control Plane ติดตั้งเสร็จสิ้น"
    echo "⏳ รอให้ Cluster พร้อมก่อนติดตั้ง ArgoCD..."
    
    # รอให้ Control Plane และ CNI พร้อม
    sleep 30
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # ===============================
    # ติดตั้ง ArgoCD สำหรับ GitOps
    # ===============================
    echo "🚀 เริ่มติดตั้ง ArgoCD..."
    
    # สร้าง namespace สำหรับ ArgoCD
    kubectl create namespace argocd
    
    # ติดตั้ง ArgoCD (ใช้ stable version)
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # รอให้ ArgoCD pods พร้อม
    echo "⏳ รอให้ ArgoCD pods พร้อม (อาจใช้เวลา 2-3 นาที)..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
    kubectl wait --for=condition=ready --timeout=600s pod -l app.kubernetes.io/name=argocd-server -n argocd
    
    # เปลี่ยน ArgoCD service เป็น NodePort เพื่อเข้าถึงจากภายนอก
    kubectl patch svc argocd-server -n argocd -p '{"spec":{"type":"NodePort","ports":[{"port":80,"nodePort":30080,"name":"http"},{"port":443,"nodePort":30443,"name":"https"}]}}'
    
    # รอสักครู่ให้ service update
    sleep 10
    
    # ดึง initial admin password
    echo "🔐 ดึง ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # แสดงข้อมูลการเข้าใช้งาน
    NODEPORT_HTTP=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    NODEPORT_HTTPS=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    # บันทึกข้อมูลลงไฟล์
    cat > argocd-access-info.txt <<EOF
ArgoCD Access Information
========================
Generated: $(date)
Server IP: $NODE_IP

Web UI Access:
- HTTP:  http://$NODE_IP:$NODEPORT_HTTP
- HTTPS: https://$NODE_IP:$NODEPORT_HTTPS (self-signed cert)

Login Credentials:
- Username: admin
- Password: $ARGOCD_PASSWORD

ArgoCD CLI Commands:
# Install ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Login with CLI
argocd login $NODE_IP:$NODEPORT_HTTPS --username admin --password $ARGOCD_PASSWORD --insecure

# Change admin password (recommended)
argocd account update-password --account admin --current-password $ARGOCD_PASSWORD

Kubernetes Cluster Info:
# Get join command for worker nodes
sudo kubeadm token create --print-join-command
EOF
    
    echo ""
    echo "🎉 ArgoCD ติดตั้งเสร็จสิ้น!"
    echo "==============================================="
    echo "🌐 ArgoCD Web UI:"
    echo "   HTTP:  http://$NODE_IP:$NODEPORT_HTTP"
    echo "   HTTPS: https://$NODE_IP:$NODEPORT_HTTPS"
    echo "👤 Username: admin"
    echo "🔑 Password: $ARGOCD_PASSWORD"
    echo "📄 ข้อมูลทั้งหมดบันทึกไว้ใน: argocd-access-info.txt"
    echo "==============================================="
    echo ""
    
    # แสดงคำสั่งสำหรับ worker nodes
    echo "📋 สำหรับเพิ่ม Worker Nodes:"
    sudo kubeadm token create --print-join-command > worker-join-command.txt
    echo "   คำสั่งบันทึกไว้ใน: worker-join-command.txt"
    echo ""
fi

# ===============================
# 7. Worker Node Join
# ===============================
if [ "$1" == "worker" ]; then
    if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
        echo "❌ โปรดระบุพารามิเตอร์ครบถ้วน:"
        echo "   Usage: $0 worker <MASTER_IP:PORT> <TOKEN> <HASH>"
        echo "   Example: $0 worker 192.168.1.69:6443 3ahbh3.kydxy70vx4t4jv1v 0d72007ce0a0aff33388c965e1469e131df23150e71fc42a8a2ebf29cc30a87"
        exit 1
    fi
    
    echo "🔗 เชื่อมต่อ Worker Node เข้า Kubernetes Cluster..."
    echo "📡 Master: $2"
    echo "🎫 Token: $3"
    
    # Join cluster
    sudo kubeadm join $2 --token $3 --discovery-token-ca-cert-hash sha256:$4
    
    # ตรวจสอบสถานะ
    if [ $? -eq 0 ]; then
        echo "✅ Worker Node เข้าร่วม Cluster สำเร็จ"
        echo "📋 ตรวจสอบสถานะบน Master Node:"
        echo "   kubectl get nodes"
    else
        echo "❌ เกิดข้อผิดพลาดในการ join cluster"
        exit 1
    fi
fi

# ===============================
# GitOps Guide
# ===============================
if [ "$1" == "master" ]; then
    echo ""
    echo "📚 GitOps Quick Start Guide:"
    echo "==============================================="
    echo "1. สร้าง Git Repository สำหรับ Kubernetes manifests"
    echo "2. สร้าง Application ใน ArgoCD:"
    echo ""
    echo "   kubectl apply -f - <<EOF"
    echo "   apiVersion: argoproj.io/v1alpha1"
    echo "   kind: Application"
    echo "   metadata:"
    echo "     name: my-app"
    echo "     namespace: argocd"
    echo "   spec:"
    echo "     project: default"
    echo "     source:"
    echo "       repoURL: https://github.com/yourusername/your-k8s-manifests"
    echo "       targetRevision: HEAD"
    echo "       path: ."
    echo "     destination:"
    echo "       server: https://kubernetes.default.svc"
    echo "       namespace: default"
    echo "     syncPolicy:"
    echo "       automated:"
    echo "         prune: true"
    echo "         selfHeal: true"
    echo "   EOF"
    echo ""
    echo "3. หรือใช้ ArgoCD CLI:"
    echo "   argocd app create my-app \\"
    echo "     --repo https://github.com/yourusername/your-k8s-manifests \\"
    echo "     --path . \\"
    echo "     --dest-server https://kubernetes.default.svc \\"
    echo "     --dest-namespace default"
    echo ""
    echo "4. Sync Application:"
    echo "   argocd app sync my-app"
    echo "==============================================="
fi
