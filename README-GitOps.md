# ArgoCD GitOps Setup Guide

## 🚀 การติดตั้งและใช้งาน ArgoCD

### 1. ติดตั้ง Kubernetes + ArgoCD
```bash
# สำหรับ Master Node
./install_argocd.sh master

# สำหรับ Worker Node (ใช้ข้อมูลจาก kubectl info.txt)
./install_argocd.sh worker 192.168.1.69:6443 3ahbh3.kydxy70vx4t4jv1v 0d72007ce0a0aff33388c965e1469e131df23150e71fc42a8a2ebf29cc30a87
```

### 2. เข้าใช้งาน ArgoCD Web UI
- URL จะแสดงหลังจากติดตั้งเสร็จ
- Username: `admin`
- Password: จะแสดงหลังจากติดตั้งเสร็จ

### 3. ติดตั้ง ArgoCD CLI
```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### 4. สร้าง Git Repository Structure
```
your-k8s-manifests/
├── apps/
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   └── backend/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── argocd/
    └── applications/
        ├── app1.yaml
        └── app2.yaml
```

### 5. สร้าง Application ใน ArgoCD

#### วิธี 1: ใช้ Web UI
1. เข้า ArgoCD Web UI
2. คลิก "NEW APP"
3. กรอกข้อมูล:
   - Application Name: `my-app`
   - Project: `default`
   - Repository URL: `https://github.com/your-username/k8s-manifests`
   - Path: `.`
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: `default`

#### วิธี 2: ใช้ CLI
```bash
argocd app create my-app \
  --repo https://github.com/your-username/k8s-manifests \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

#### วิธี 3: ใช้ YAML Manifest
```bash
kubectl apply -f argocd-app-example.yaml
```

### 6. GitOps Workflow

1. **แก้ไข Kubernetes manifests** ใน Git repository
2. **Commit และ Push** ไปยัง Git repository
3. **ArgoCD จะ detect การเปลี่ยนแปลง** และ sync อัตโนมัติ
4. **ตรวจสอบสถานะ** ผ่าน ArgoCD Web UI หรือ CLI

### 7. คำสั่ง ArgoCD CLI ที่สำคัญ

```bash
# ดู list applications
argocd app list

# ดูรายละเอียด application
argocd app get my-app

# Sync application manually
argocd app sync my-app

# ดู application logs
argocd app logs my-app

# Delete application
argocd app delete my-app
```

### 8. Best Practices

1. **แยก Environment**: ใช้ branch หรือ folder แยกสำหรับ dev, staging, prod
2. **App of Apps Pattern**: สร้าง root application ที่จัดการ applications อื่นๆ
3. **Secret Management**: ใช้ tools อย่าง Sealed Secrets หรือ External Secrets
4. **Resource Quotas**: กำหนด resource limits สำหรับแต่ละ namespace
5. **RBAC**: ตั้งค่า permissions ให้เหมาะสมกับ team

### 9. Monitoring และ Troubleshooting

```bash
# ดู ArgoCD pods status
kubectl get pods -n argocd

# ดู ArgoCD logs
kubectl logs -n argocd deployment/argocd-server

# ดู application sync status
argocd app get my-app --show-params

# Refresh application
argocd app get my-app --refresh
```

### 10. การ Backup และ Restore

```bash
# Backup ArgoCD configurations
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml

# Restore
kubectl apply -f argocd-apps-backup.yaml
kubectl apply -f argocd-projects-backup.yaml
```
