# Service IPs Reference

This document lists all fixed LoadBalancer IPs for cluster services.

**Important:** These IPs are now **permanently assigned** using `loadBalancerIP` in each service spec. They will not change on cluster restart or upgrade.

## Service IP Assignments

| Service | Namespace | IP Address | Port | Protocol |
|---------|-----------|------------|------|----------|
| Grafana | monitoring | `192.168.1.60` | 80 | HTTP |
| Prometheus | monitoring | `192.168.1.61` | 9090 | HTTP |
| Portainer | portainer | `192.168.1.62` | 9443 | HTTPS |
| ArgoCD | argocd | `192.168.1.63` | 443 | HTTPS |
| whoami | default | `192.168.1.64` | 80 | HTTP |
| Kubernetes Dashboard | kubernetes-dashboard | `192.168.1.65` | 443 | HTTPS |
| n8n | n8n | `192.168.1.66` | 5678 | HTTP |
| Traefik | kube-system | `192.168.1.67` | 80, 443 | HTTP/HTTPS |

## MetalLB IP Pool

The cluster uses MetalLB with the following IP range:
```
192.168.1.60 - 192.168.1.80
```

## Cloudflare Tunnel Configuration

If using Cloudflare tunnels, configure your routes as follows:

| Subdomain | Service URL |
|-----------|-------------|
| grafana.your-domain.com | `http://192.168.1.60:80` |
| n8n.your-domain.com | `http://192.168.1.66:5678` |
| argocd.your-domain.com | `https://192.168.1.63:443` |
| proxmox.your-domain.com | `https://192.168.1.100:8006` |
| portainer.your-domain.com | `https://192.168.1.62:9443` |

## How IPs Are Fixed

Each service has `loadBalancerIP` set in its spec:

```yaml
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.1.XX  # Fixed IP
```

This was applied on December 25, 2025 after the K3S v1.33.6 upgrade caused MetalLB to reassign IPs.

## Quick Commands

```bash
# Check all LoadBalancer IPs
kubectl get svc -A -o custom-columns="NAME:.metadata.name,NAMESPACE:.metadata.namespace,IP:.status.loadBalancer.ingress[0].ip,PORT:.spec.ports[0].port" | grep -E "192.168.1.6"

# Fix an IP for a service
kubectl patch svc <service-name> -n <namespace> -p '{"spec":{"loadBalancerIP":"192.168.1.XX"}}'
```

---

*Last Updated: December 25, 2025*
