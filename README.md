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
| `manage-argocd.sh` | เมนูจัดการ ArgoCD |
| `fix-docker-ubuntu.sh` | แก้ไขปัญหา Docker ใน Ubuntu |
| `fix-installation.sh` | แก้ไขปัญหาการติดตั้งทั่วไป |
| `join-cluster-guide.sh` | คู่มือการ join Kubernetes cluster |
| `join-kind-cluster.sh` | Join kind cluster client อัตโนมัติ |

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

**4. ลืมรหัสผ่าน**
```bash
# ดูรหัสผ่าน admin
./get-password.sh
```

### ดู Log
```bash
# ดู installation log
cat argocd-install.log

# ดูสถานะทั้งหมด
./status-argocd.sh
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
