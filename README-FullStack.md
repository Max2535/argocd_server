# 🚀 ArgoCD Full Stack Auto Installer

ติดตั้ง Kubernetes + ArgoCD + Nginx Reverse Proxy แบบ **One-Click** สำหรับทั้ง **Linux** และ **Windows**

## ✨ Features

- 🔧 **Fully Automated**: ติดตั้งครั้งเดียวแล้วพร้อมใช้งานทันที
- 🌍 **Cross-Platform**: รองรับ Linux (Ubuntu/CentOS/RHEL) และ Windows (Git Bash/WSL)
- ⚡ **Quick Setup**: ติดตั้งได้ภายใน 5-10 นาที
- 🌐 **Easy Access**: เข้าใช้งานผ่าน http://localhost
- 🛠️ **Management Scripts**: มี scripts จัดการครบครัน
- 🧪 **Auto Testing**: ทดสอบการติดตั้งอัตโนมัติ

## 📋 ความต้องการของระบบ

### Linux (Ubuntu/CentOS/RHEL)
- **RAM**: 4GB ขึ้นไป (แนะนำ 8GB)
- **CPU**: 2 cores ขึ้นไป
- **Disk**: 20GB ว่างขึ้นไป
- **Internet**: เชื่อมต่อ Internet ได้
- **User**: ไม่ควรเป็น root (ต้องมี sudo privileges)

### Windows
- **RAM**: 8GB ขึ้นไป (แนะนำ 16GB)
- **CPU**: 4 cores ขึ้นไป  
- **Disk**: 50GB ว่างขึ้นไป
- **Docker Desktop**: ติดตั้งแล้วและเปิดใช้งาน
- **kubectl**: ติดตั้งแล้ว
- **Git Bash**: สำหรับรัน shell scripts

## 🚀 Quick Start

### 1️⃣ One-Click Installation

```bash
# ดาวน์โหลดและรัน installer
curl -fsSL https://raw.githubusercontent.com/Max2535/argocd_server/main/install-full-stack.sh | bash

# หรือ clone repository
git clone https://github.com/Max2535/argocd_server.git
cd argocd_server
chmod +x install-full-stack.sh
./install-full-stack.sh
```

### 2️⃣ เข้าใช้งาน ArgoCD

เมื่อติดตั้งเสร็จ:
- **URL**: http://localhost
- **Username**: `admin`
- **Password**: ดู output หรือใช้ `./get-password.sh`

## 🛠️ Management Commands

หลังติดตั้งเสร็จจะได้ scripts จัดการ:

```bash
./start-argocd.sh      # 🚀 เริ่มต้น ArgoCD
./stop-argocd.sh       # 🛑 หยุด ArgoCD  
./status-argocd.sh     # 📊 ตรวจสอบสถานะ
./get-password.sh      # 🔑 ดูรหัสผ่าน admin
./uninstall-argocd.sh  # 🗑️ ถอนการติดตั้ง
```

## 🧩 ส่วนประกอบที่ติดตั้ง

1. **Kubernetes Cluster** (kind)
   - Single-node cluster
   - Ready สำหรับ development/testing

2. **ArgoCD**
   - GitOps continuous delivery tool
   - Web UI สำหรับจัดการ applications

3. **Nginx Reverse Proxy**
   - เข้าถึงง่ายผ่าน http://localhost
   - ไม่ต้อง port forwarding

4. **Management Scripts**
   - Start/Stop/Status commands
   - Password retrieval
   - Complete uninstall

## 📖 Advanced Usage

### Silent Installation (Non-Interactive)

```bash
./install-full-stack.sh -y
```

### Skip Dependencies Installation

```bash
./install-full-stack.sh --skip-deps
```

### Check System Requirements

```bash
# สำหรับ Windows
./check-system-windows.sh

# สำหรับ Linux (หลังติดตั้ง)
./check-system.sh
```

## 🐛 Troubleshooting

### ปัญหาทั่วไป

1. **Docker ไม่ทำงาน**
   ```bash
   # Linux
   sudo systemctl start docker
   
   # Windows
   # เปิด Docker Desktop
   ```

2. **kubectl ไม่พบ**
   ```bash
   # Linux
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install kubectl /usr/local/bin/
   
   # Windows
   choco install kubernetes-cli
   ```

3. **Port 80 ถูกใช้**
   ```bash
   # หา process ที่ใช้ port 80
   sudo netstat -tlnp | grep :80
   sudo fuser -k 80/tcp
   ```

4. **ArgoCD UI ไม่แสดง**
   ```bash
   # ตรวจสอบสถานะ
   ./status-argocd.sh
   
   # Restart services
   ./stop-argocd.sh
   ./start-argocd.sh
   ```

### ดู Logs

```bash
# ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Nginx logs  
docker logs nginx-argocd-proxy

# Installation logs
cat argocd-install.log
```

## 🔧 Manual Steps (หากจำเป็น)

### 1. ติดตั้ง Dependencies ด้วยตนเอง

#### Linux (Ubuntu)
```bash
# Docker
curl -fsSL https://get.docker.com | bash
sudo usermod -aG docker $USER

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/

# kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

#### Windows
1. ติดตั้ง Docker Desktop
2. ติดตั้ง kubectl: `choco install kubernetes-cli`
3. ติดตั้ง kind: `choco install kind`

### 2. สร้าง Kubernetes Cluster

```bash
# สร้าง kind cluster
kind create cluster --name argocd-cluster

# ตรวจสอบ
kubectl cluster-info
kubectl get nodes
```

### 3. ติดตั้ง ArgoCD

```bash
# สร้าง namespace
kubectl create namespace argocd

# ติดตั้ง ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# รอให้พร้อม
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# รับรหัสผ่าน
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 📚 เอกสารเพิ่มเติม

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kind Documentation](https://kind.sigs.k8s.io/)

## 🤝 Contributing

หากพบปัญหาหรือมีข้อเสนอแนะ:
1. สร้าง Issue ใน GitHub
2. ส่ง Pull Request
3. ติดต่อผู้พัฒนา

## 📄 License

MIT License - ใช้งานฟรีสำหรับทุกวัตถุประสงค์

---

**Happy GitOps with ArgoCD! 🚀**
