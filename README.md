# 🚀 ArgoCD Full Stack Installer

**One-Click Kubernetes + ArgoCD + Nginx Reverse Proxy Installation**

ระบบติดตั้ง ArgoCD แบบอัตโนมัติ 100% รองรับทั้ง Linux และ Windows พร้อมใช้งานทันทีในครั้งเดียว

## ✨ คุณสมบัติหลัก

- 🎯 **One-Click Installation** - ติดตั้งครั้งเดียวพร้อมใช้งาน
- 🔧 **Cross-Platform** - รองรับทั้ง Linux และ Windows  
- 🌐 **No Port Forwarding** - ใช้ nginx reverse proxy
- 📱 **Mobile Friendly** - เข้าถึงได้จากมือถือ
- 🛠️ **Complete Management** - สคริปต์จัดการครบครัน
- 🎬 **Ready-to-Use Demos** - มีตัวอย่างพร้อมใช้

## 🚀 Quick Start

### ติดตั้งครั้งแรก

```bash
# สำหรับผู้เริ่มต้น (แนะนำ)
./quick-start.sh

# หรือติดตั้งแบบ Silent
./install-full-stack.sh -y
```

### เข้าใช้งาน ArgoCD

- 🌐 **URL:** http://localhost
- 👤 **Username:** admin  
- 🔑 **Password:** รัน `./get-password.sh`

## 📋 สคริปต์ที่มีให้

### 🚀 การติดตั้ง
| สคริปต์ | คำอธิบาย |
|---------|----------|
| `quick-start.sh` | ติดตั้งอย่างง่าย พร้อมตรวจสอบระบบ |
| `install-full-stack.sh` | ติดตั้งอัตโนมัติ 100% |
| `check-system-windows.sh` | ตรวจสอบความพร้อมของระบบ (Windows) |
| `start-services.sh` | เปิด Docker และ Kubernetes services |

### 🛠️ การจัดการ
| สคริปต์ | คำอธิบาย |
|---------|----------|
| `start-argocd.sh` | เปิดระบบ ArgoCD ทั้งหมด |
| `stop-argocd.sh` | ปิดระบบ ArgoCD ทั้งหมด |
| `status-argocd.sh` | ตรวจสอบสถานะระบบ |
| `get-password.sh` | ดูรหัสผ่าน ArgoCD admin |
| `reset-admin-password.sh` | รีเซ็ตรหัสผ่าน admin ใหม่ |
| `manage-argocd.sh` | เมนูจัดการ ArgoCD |
| `fix-docker-ubuntu.sh` | แก้ไขปัญหา Docker ใน Ubuntu |
| `fix-installation.sh` | แก้ไขปัญหาการติดตั้งทั่วไป |
| `join-cluster-guide.sh` | คู่มือการ join Kubernetes cluster |
| `join-kind-cluster.sh` | Join kind cluster client อัตโนมัติ |
| `fix-502-gateway.sh` | แก้ไขปัญหา 502 Bad Gateway |
| `fix-linux-nginx.sh` | แก้ไขปัญหา nginx บน Linux |
| `argocd-direct-https.sh` | เข้าถึง ArgoCD ผ่าน HTTPS โดยตรง |
| `diagnose-argocd.sh` | วินิจฉัยปัญหา ArgoCD อย่างละเอียด |
| `install-argocd-service.sh` | ติดตั้ง ArgoCD เป็น systemd service |

### 🌐 เครือข่าย
| สคริปต์ | คำอธิบาย |
|---------|----------|
| `simple-nginx.sh` | Nginx reverse proxy อย่างง่าย |
| `nginx-setup.sh` | การตั้งค่า nginx ขั้นสูง |

### 🎬 Demo และอื่นๆ
| สคริปต์ | คำอธิบาย |
|---------|----------|
| `demo-apps.sh` | ติดตั้งแอพพลิเคชันตัวอย่าง |
| `uninstall-argocd.sh` | ถอนการติดตั้งทั้งหมด |
| `overview.sh` | ภาพรวมของระบบ |

## 🔧 การใช้งานประจำวัน

### เปิด/ปิดระบบ
```bash
# เปิดระบบ
./start-argocd.sh

# ตรวจสอบสถานะ
./status-argocd.sh

# ปิดระบบ
./stop-argocd.sh
```

### ตรวจสอบข้อมูล
```bash
# ดูรหัสผ่าน admin
./get-password.sh

# ดูภาพรวมระบบ
./overview.sh
```

## 🔗 การ Join Kubernetes Cluster

### การเชื่อมต่อ Client Machine เพิ่ม

```bash
# คู่มือทั่วไป
./join-cluster-guide.sh

# สำหรับ kind cluster (อัตโนมัติ)
./join-kind-cluster.sh
```

### ขั้นตอนพื้นฐาน

1. **สร้าง kubeconfig** สำหรับ client
2. **Copy ไฟล์** ไปยัง client machine  
3. **ติดตั้ง kubectl** บน client
4. **ทดสอบการเชื่อมต่อ**

## 🔐 การเข้าถึง ArgoCD บนเซิร์ฟเวอร์ Linux

ระบบนี้รองรับการเข้าถึง ArgoCD บนเซิร์ฟเวอร์ Linux ด้วย 2 วิธี:

### วิธีที่ 1: ผ่าน HTTP (port 80) ด้วย Nginx

```bash
# แก้ไขปัญหา 502 Bad Gateway สำหรับ Linux
./fix-linux-nginx.sh

# เข้าใช้งานผ่าน URL
http://[your-server-ip]
```

### วิธีที่ 2: ผ่าน HTTPS โดยตรง (แนะนำ)

```bash
# เข้าถึง ArgoCD ผ่าน HTTPS โดยตรง
./argocd-direct-https.sh

# เข้าใช้งานผ่าน URL (จะแสดงหลังรันสคริปต์)
https://[your-server-ip]:[port]
```

### ติดตั้งเป็น Systemd Service

```bash
# ติดตั้ง ArgoCD เป็น systemd service (ต้องใช้ sudo)
sudo ./install-argocd-service.sh

# ตรวจสอบสถานะ service
systemctl status argocd-http.service
```

### วินิจฉัยปัญหา

```bash
# วินิจฉัยปัญหา ArgoCD อย่างละเอียด
./diagnose-argocd.sh
```

## 🎬 ลองใช้ Demo Applications

```bash
# ติดตั้งแอพตัวอย่าง
./demo-apps.sh
```

Demo applications ที่มีให้:
- **Guestbook** - แอพ PHP + Redis แบบคลาสสิก
- **2048 Game** - เกมปริศนาตัวเลข
- **Nginx Hello** - เว็บเซิร์ฟเวอร์ทดสอบ

## 🛠️ ข้อกำหนดระบบ

### Windows
- Windows 10/11
- Git Bash หรือ WSL
- Docker Desktop
- อย่างน้อย 4GB RAM

### Linux
- Ubuntu 18.04+ / CentOS 7+ / หรือ distro อื่นๆ
- Docker
- kubectl
- อย่างน้อย 4GB RAM

## 🔍 Troubleshooting

### ปัญหาที่พบบ่อย

**1. Docker ไม่ทำงาน (Ubuntu/Linux)**
```bash
# ตรวจสอบสถานะ Docker
sudo systemctl status docker

# เริ่ม Docker service
sudo systemctl start docker
sudo systemctl enable docker

# แก้ไข permissions
sudo usermod -aG docker $USER
sudo chmod 666 /var/run/docker.sock

# ทดสอบ
docker info

# หากยังไม่ได้ ให้ logout/login หรือ reboot
```

**2. Docker ไม่ทำงาน (Windows)**
```bash
# ตรวจสอบสถานะ Docker
./check-system-windows.sh

# เปิด Docker services
./start-services.sh
```

**3. เข้า ArgoCD UI ไม่ได้**
```bash
# ตรวจสอบสถานะ nginx
./status-argocd.sh

# รีสตาร์ท nginx
./simple-nginx.sh

# แก้ไข 502 Bad Gateway
./fix-502-gateway.sh
```

**3. เข้า ArgoCD UI ไม่ได้ (502 Bad Gateway)**

สำหรับ Windows:
```bash
# แก้ไข 502 Bad Gateway
./fix-502-gateway.sh
```

สำหรับ Linux:
```bash
# แก้ไข 502 Bad Gateway สำหรับ Linux
./fix-linux-nginx.sh

# หรือใช้วิธีเข้าถึงโดยตรง (แนะนำ)
./argocd-direct-https.sh
```

**4. ลืมรหัสผ่าน หรือไม่สามารถดึงรหัสผ่านได้**
```bash
# ดูรหัสผ่าน admin
./get-password.sh

# หรือรีเซ็ตรหัสผ่านใหม่
./reset-admin-password.sh
```

### ดู Log
```bash
# ดู installation log
cat argocd-install.log

# ดูสถานะทั้งหมด
./status-argocd.sh
```

### การแก้ไขปัญหา 502 Bad Gateway บน Linux

ปัญหา 502 Bad Gateway บน Linux มักเกิดจาก:

1. **ปัญหา hostname**: `host.docker.internal` ไม่ทำงานบน Linux
2. **ปัญหา network**: nginx container ไม่สามารถเข้าถึง ArgoCD ได้
3. **ปัญหา port forwarding**: port forwarding ไม่ทำงานหรือไม่ได้เปิดกับ interface ทั้งหมด

วิธีแก้ไข:

```bash
# วิธีที่ 1: ใช้ nginx ผ่าน host network
./fix-linux-nginx.sh

# วิธีที่ 2: เข้าถึง ArgoCD โดยตรงผ่าน HTTPS
./argocd-direct-https.sh

# วิธีที่ 3: วินิจฉัยปัญหาอย่างละเอียด
./diagnose-argocd.sh
```

### การแก้ไขปัญหา "secrets argocd-initial-admin-password not found"

หากคุณเห็นข้อความ `Error from server (NotFound): secrets "argocd-initial-admin-password" not found` หรือไม่สามารถดึงรหัสผ่าน admin ได้ นี่อาจเกิดจาก:

1. **ArgoCD ติดตั้งมานาน**: secret อาจถูกลบไปตามขั้นตอนทำความสะอาด
2. **ไม่มีการสร้าง secret**: การติดตั้งอาจไม่ได้สร้าง secret ไว้
3. **รหัสผ่านถูกเปลี่ยน**: ผู้ดูแลระบบอาจเปลี่ยนรหัสผ่านไปแล้ว

วิธีแก้ไข:

```bash
# รีเซ็ตรหัสผ่าน admin ใหม่ (แนะนำ)
./reset-admin-password.sh

# หรือลองดูรหัสผ่านเดิมถ้ายังมีอยู่
./get-password.sh
```

### ดู Log เพิ่มเติม
```bash
# ดู installation log
cat argocd-install.log

# ดูสถานะทั้งหมด
./status-argocd.sh

# ดู log ของ nginx container
docker logs nginx-argocd

# ดู log ของ ArgoCD server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### รีสตาร์ทระบบ
```bash
# ปิดแล้วเปิดใหม่
./stop-argocd.sh && ./start-argocd.sh
```

## 📚 เอกสารเพิ่มเติม

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitOps Guide](https://www.gitops.tech/)
- [kind Documentation](https://kind.sigs.k8s.io/)

## 🏗️ สถาปัตยกรรม

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│   User Browser  │───▶│  Nginx Proxy    │───▶│   ArgoCD UI     │
│                 │    │  (localhost)    │    │  (port 8080)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │                 │
                       │ kind Cluster    │
                       │ (argocd-cluster)│
                       └─────────────────┘
```

สถาปัตยกรรมสำหรับ Linux Server:

```
# วิธีที่ 1: ผ่าน Nginx (HTTP)
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│   Web Browser   │───▶│  Nginx (host)   │───▶│   ArgoCD UI     │
│                 │    │    (port 80)    │    │  (port 8080)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘

# วิธีที่ 2: โดยตรง (HTTPS)
┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │
│   Web Browser   │───▶│   ArgoCD UI     │
│                 │    │  (port 8081)    │
└─────────────────┘    └─────────────────┘
```

## 🤝 การสนับสนุน

หากพบปัญหาหรือต้องการความช่วยเหลือ:

1. ตรวจสอบ [Troubleshooting](#-troubleshooting) ก่อน
2. รัน `./status-argocd.sh` เพื่อดูสถานะระบบ
3. ดู log ไฟล์: `cat argocd-install.log`

## 📄 License

MIT License - ใช้งานได้อย่างอิสระ

## 🎉 เริ่มต้นการเดินทาง GitOps!

```bash
# เริ่มต้นเลย!
./quick-start.sh
```

---

*สร้างด้วย ❤️ สำหรับชุมชน DevOps และ Kubernetes*
