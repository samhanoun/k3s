# Conversation Notes - November 27, 2025

## What we did in this session:

### 1. Created GitHub Repository
- Created a new public GitHub repo: https://github.com/samhanoun/k3s
- Pushed the k3s folder contents
- Excluded SSH key files (`id_ed25519` and `id_ed25519.pub`) using `.gitignore`

### 2. Files in the Repository
- `.gitignore` - Excludes SSH keys
- `README.md` - Comprehensive K3S setup guide (3000+ lines)
- `ipAddressPool` - MetalLB IP pool configuration
- `k3s.sh` - Main installation script
- `k3sup` - K3sup binary
- `kube-vip` - Kube-VIP manifest
- `kubectl` - Kubectl binary

### 3. Kubernetes Dashboard Token
The token is NOT saved - it's generated dynamically. To get a token, run:

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl -n kubernetes-dashboard create token admin-user"
```

Then paste the token at: https://192.168.1.62

### 4. Key URLs
- GitHub Repo: https://github.com/samhanoun/k3s
- Kubernetes Dashboard: https://192.168.1.62
- Portainer: https://192.168.1.61:9443
- Nginx (test): http://192.168.1.60

### 5. Previous Conversation
The previous conversation where the README was created was lost when the folder was opened in VS Code. Conversations cannot be retrieved once the session ends.

---
*Tip: Save important conversations by copying them or exporting before closing.*
