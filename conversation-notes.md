# Conversation Notes - K3S Cluster Setup

## Session 1: November 27, 2025 - Initial Setup

### 1. Created GitHub Repository
- Created a new public GitHub repo: https://github.com/samhanoun/k3s
- Pushed the k3s folder contents
- Excluded SSH key files (`id_ed25519` and `id_ed25519.pub`) using `.gitignore`

### 2. Initial Files in the Repository
- `.gitignore` - Excludes SSH keys
- `README.md` - Comprehensive K3S setup guide (3000+ lines)
- `ipAddressPool` - MetalLB IP pool configuration
- `k3s.sh` - Main installation script
- `k3sup` - K3sup binary
- `kube-vip` - Kube-VIP manifest
- `kubectl` - Kubectl binary

---

## Session 2: November 29, 2025 - GitOps, Monitoring & External Access

### 1. GitOps Setup with ArgoCD

**ArgoCD Installed:**
- Deployed ArgoCD to the cluster
- Exposed via LoadBalancer at `192.168.1.63`
- Admin password retrieved and stored

**ArgoCD Access:**
| Item | Value |
|------|-------|
| URL | https://192.168.1.63 |
| Username | admin |
| Password | NUybZUjmKc4dDJyI |

**Files Created:**
- `argocd/applications/whoami.yaml` - Test application
- `argocd/applications/monitoring.yaml` - Prometheus + Grafana stack
- `apps/whoami/deployment.yaml` - Whoami test app

### 2. GitHub Actions CI/CD

**Workflows Created:**
- `.github/workflows/lint.yaml` - YAML linting with yamllint
- `.github/workflows/validate.yaml` - Kubernetes manifest validation
- `.github/workflows/security.yaml` - Security scanning with Kubescape

**Issues Fixed:**
- Trailing whitespace in `monitoring.yaml` causing lint failures
- Added `--validate=false` flag to kubectl dry-run for CRDs

### 3. Cloudflare Tunnel Configuration

**Tunnel: blue-mercurius**

| Subdomain | Type | Service | Notes |
|-----------|------|---------|-------|
| proxmox.blue-mercurius.com | HTTPS | 192.168.1.100:8006 | noTLSVerify |
| portainer.blue-mercurius.com | HTTPS | 192.168.1.187:9443 | noTLSVerify |
| nord.blue-mercurius.com | HTTPS | 192.168.1.18:5678 | noTLSVerify |
| n8nn.blue-mercurius.com | HTTPS | n8n-production-c7d6.up.railway.app:5678 | noTLSVerify |
| wazuh.blue-mercurius.com | HTTPS | 192.168.1.189:443 | noTLSVerify |
| kalis.blue-mercurius.com | SSH | 192.168.1.212:22 | - |
| semaphore.blue-mercurius.com | HTTP | 192.168.1.235:3000 | - |
| k3s-api.blue-mercurius.com | HTTPS | 192.168.1.50:6443 | noTLSVerify |
| grafana.blue-mercurius.com | HTTP | 192.168.1.64:80 | - |

**K3S API External Access:**
```bash
# Use kubeconfig with external endpoint
kubectl --server=https://k3s-api.blue-mercurius.com get nodes
```

### 4. Prometheus + Grafana Monitoring Stack

**Deployed via ArgoCD using kube-prometheus-stack Helm chart (v65.1.1)**

**Service URLs:**
| Service | Internal URL | External URL |
|---------|--------------|--------------|
| Grafana | http://192.168.1.64 | https://grafana.blue-mercurius.com |
| Prometheus | http://192.168.1.60:9090 | - |
| Alertmanager | ClusterIP only | - |

**Grafana Credentials:**
| Item | Value |
|------|-------|
| Username | admin |
| Password | Wasko!!wasko1024 |

**Issues Fixed:**
- Prometheus CrashLoopBackOff - increased memory limit from 512Mi to 1Gi
- Dashboard 15282 (RKE) showing N/A values - incompatible with K3S metrics

**Custom Dashboard Created:**
- `dashboards/k3s-cluster-overview.json` - Custom K3S-compatible dashboard
- Imported manually into Grafana
- Shows: CPU, Memory, Filesystem, Network, Pod counts by namespace

**Recommended Dashboards:**
- K3S Cluster Overview (custom) - Works perfectly
- Node Exporter Full (ID: 1860) - Detailed node metrics
- Kubernetes / Compute Resources / Cluster (built-in)

### 5. Kubernetes Dashboard Token

**Permanent Token Method (Recommended):**
```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d"
```

**Temporary Token Method:**
```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl -n kubernetes-dashboard create token admin-user"
```

---

## Cluster Architecture

### Nodes

| Node Name | Role | IP Address |
|-----------|------|------------|
| k3s-05 | Master | 192.168.1.92 |
| k3s-04 | Master | 192.168.1.198 |
| k3s-03 | Master | 192.168.1.46 |
| k3s-02 | Worker | 192.168.1.171 |
| k3s-01 | Worker | 192.168.1.113 |

### Network Configuration

| Purpose | IP/Range |
|---------|----------|
| Virtual IP (Kube-VIP) | 192.168.1.50 |
| MetalLB Range | 192.168.1.60-80 |
| Pod Network (Flannel) | 10.42.0.0/16 |
| Service Network | 10.43.0.0/16 |

### Service IP Assignments (MetalLB)

| Service | IP | Port |
|---------|-----|------|
| Prometheus | 192.168.1.60 | 9090 |
| Portainer | 192.168.1.61 | 9443 |
| Kubernetes Dashboard | 192.168.1.62 | 443 |
| ArgoCD | 192.168.1.63 | 443 |
| Grafana | 192.168.1.64 | 80 |
| Whoami | 192.168.1.65 | 80 |

---

## Quick Reference Commands

### ArgoCD
```bash
# Sync an application
kubectl -n argocd patch app monitoring --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Grafana
```bash
# Get Grafana service IP
kubectl get svc -n monitoring monitoring-grafana
```

### Prometheus
```bash
# Port-forward Prometheus (if needed)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Check available metrics
kubectl exec -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 -- wget -qO- 'http://localhost:9090/api/v1/label/__name__/values'
```

### Dashboard Token
```powershell
# Get permanent token
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d"
```

### Git Operations
```powershell
cd "c:\Users\harry\Documents\k3s"
git add -A
git commit -m "Your message"
git push
```

---

## Repository Structure

```
k3s/
├── .github/
│   └── workflows/
│       ├── lint.yaml          # YAML linting
│       ├── validate.yaml      # K8s manifest validation
│       └── security.yaml      # Security scanning
├── apps/
│   └── whoami/
│       └── deployment.yaml    # Test application
├── argocd/
│   └── applications/
│       ├── monitoring.yaml    # Prometheus + Grafana
│       └── whoami.yaml        # Whoami app
├── dashboards/
│   └── k3s-cluster-overview.json  # Custom Grafana dashboard
├── .gitignore
├── README.md                  # Comprehensive K3S guide
├── conversation-notes.md      # This file
├── ipAddressPool              # MetalLB config
├── k3s.sh                     # Installation script
├── k3sup                      # K3sup binary
├── kube-vip                   # Kube-VIP manifest
└── kubectl                    # Kubectl binary
```

---

## Issues Encountered & Solutions

| Issue | Solution |
|-------|----------|
| Dashboard 401 Unauthorized | Created permanent token secret `admin-user-token` |
| Prometheus CrashLoopBackOff | Increased memory limit to 1Gi |
| GitHub Actions lint failing | Removed trailing whitespace from YAML files |
| Grafana dashboard N/A values | Dashboard 15282 is for RKE, not K3S. Created custom dashboard |
| Cloudflare tunnel not resolving | DNS propagation delay - flush DNS with `ipconfig /flushdns` |
| Grafana HTTPS tunnel not working | Grafana uses HTTP, not HTTPS. Changed tunnel type to HTTP |

---

## External Access Summary

| Service | Local URL | External URL (Cloudflare) |
|---------|-----------|---------------------------|
| K3S API | https://192.168.1.50:6443 | https://k3s-api.blue-mercurius.com |
| Grafana | http://192.168.1.64 | https://grafana.blue-mercurius.com |
| ArgoCD | https://192.168.1.63 | - (not exposed) |
| Kubernetes Dashboard | https://192.168.1.62 | - (not exposed) |
| Prometheus | http://192.168.1.60:9090 | - (not exposed) |

---

## Session 3: December 25, 2025 - Hyper-V Node Expansion

### 1. Added Two New Worker Nodes via Hyper-V

**Why Hyper-V?**
- Expanding cluster capacity using local Windows machine
- VMs running alongside Proxmox nodes on home network

**New Nodes Created:**

| Node | IP | Location | Specs | K3S Version |
|------|-----|----------|-------|-------------|
| k3s-06 | 192.168.1.200 | Hyper-V | 4 CPU, 4GB RAM, 30GB | v1.33.6+k3s1 |
| k3s-07 | 192.168.1.201 | Hyper-V | 4 CPU, 4GB RAM, 30GB | v1.33.6+k3s1 |

**Setup Process:**
1. Created PowerShell script `scripts/create-hyperv-vms.ps1` for VM automation
2. Installed Ubuntu 24.04 Server on both VMs
3. Configured static IPs and SSH keys
4. Joined nodes to K3S cluster using k3sup token

**Files Created:**
- `scripts/create-hyperv-vms.ps1` - PowerShell script for Hyper-V VM creation
- `docs/HYPERV_SETUP.md` - Comprehensive setup guide

**Files Updated:**
- `ansible/inventory/hosts.yaml` - Added new nodes with `location` tags (proxmox/hyperv)
- `k3s.sh` - Added worker3 and worker4 IP addresses

### 2. Current Cluster Architecture (7 Nodes)

```
┌─────────────────────────────────────────────────────────────────┐
│                     K3S HA Cluster                              │
├─────────────────────────────────────────────────────────────────┤
│  CONTROL PLANE (Proxmox)           │  WORKERS                  │
│  ─────────────────────────         │  ───────────────────────  │
│  k3s-03: 192.168.1.46              │  k3s-01: 192.168.1.113    │
│  k3s-04: 192.168.1.198             │  k3s-02: 192.168.1.171    │
│  k3s-05: 192.168.1.92              │  k3s-06: 192.168.1.200 *  │
│                                    │  k3s-07: 192.168.1.201 *  │
│  VIP: 192.168.1.50 (Kube-VIP)      │  * = Hyper-V nodes        │
└─────────────────────────────────────────────────────────────────┘
```

### 3. Note: K3S Version Mismatch

| Location | Nodes | K3S Version |
|----------|-------|-------------|
| Proxmox | k3s-01 to k3s-05 | v1.26.10+k3s2 |
| Hyper-V | k3s-06, k3s-07 | v1.33.6+k3s1 |

The new nodes run a newer K3S version. Consider upgrading Proxmox nodes for consistency.

---

*Last Updated: December 25, 2025*
