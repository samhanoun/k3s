# N8N Deployment on K3S

This document explains the n8n deployment on the K3S cluster, including architecture, configuration, security considerations, and how to manage secrets properly.

## Table of Contents

1. [What is N8N](#what-is-n8n)
2. [Deployment Architecture](#deployment-architecture)
3. [Manifest Files Explained](#manifest-files-explained)
4. [Accessing N8N](#accessing-n8n)
5. [Security Configuration](#security-configuration)
6. [Secrets Management](#secrets-management)
7. [Securing Secrets in Kubernetes](#securing-secrets-in-kubernetes)
8. [Backup and Recovery](#backup-and-recovery)
9. [Troubleshooting](#troubleshooting)
10. [Maintenance](#maintenance)

---

## What is N8N

N8N is a workflow automation tool similar to Zapier or Make, but self-hosted. It allows you to connect different services and automate tasks between them. For example, you could create a workflow that watches for new emails and automatically creates tasks in your project management tool.

Running n8n on your own infrastructure means:
- Your data stays on your servers
- No subscription fees
- No workflow limits
- Full control over integrations

---

## Deployment Architecture

The n8n deployment consists of several Kubernetes resources working together:

```
                                    Internet
                                        |
                                        v
                            +-------------------+
                            | Cloudflare Tunnel |
                            | (blue-mercurius)  |
                            +-------------------+
                                        |
                                        v
                            +-------------------+
                            |     MetalLB       |
                            |   192.168.1.66    |
                            +-------------------+
                                        |
                                        v
+------------------------------------------------------------------+
|                         K3S Cluster                               |
|                                                                   |
|   +------------------+    +------------------+                    |
|   |   n8n Service    |    |   n8n Secret     |                    |
|   |   LoadBalancer   |    |   (credentials)  |                    |
|   |   Port 5678      |    +------------------+                    |
|   +--------+---------+              |                             |
|            |                        |                             |
|            v                        v                             |
|   +------------------------------------------+                    |
|   |            n8n Deployment                |                    |
|   |  +------------------------------------+  |                    |
|   |  |          n8n Container             |  |                    |
|   |  |  - Workflow engine                 |  |                    |
|   |  |  - Web interface                   |  |                    |
|   |  |  - Webhook endpoints               |  |                    |
|   |  +------------------------------------+  |                    |
|   +------------------------------------------+                    |
|            |                                                      |
|            v                                                      |
|   +------------------+                                            |
|   |       PVC        |                                            |
|   |    n8n-data      |                                            |
|   |    (5Gi)         |                                            |
|   +------------------+                                            |
|                                                                   |
+------------------------------------------------------------------+
```

**Components:**

| Component | Purpose |
|-----------|---------|
| Namespace | Isolates n8n resources from other applications |
| Secret | Stores sensitive data like encryption keys |
| PersistentVolumeClaim | Stores workflows, credentials, and execution history |
| Deployment | Runs the n8n container with proper configuration |
| Service | Exposes n8n via MetalLB LoadBalancer |

---

## Manifest Files Explained

The deployment is organized into separate files for clarity and maintainability:

### namespace.yaml

Creates an isolated namespace for n8n. This keeps n8n resources separate from other applications and allows for easier management, resource quotas, and access control.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: n8n
```

### secret.yaml

Contains sensitive configuration that should not be stored in plain text:

- **N8N_ENCRYPTION_KEY**: Used to encrypt credentials stored in n8n. If you lose this key, you cannot decrypt saved credentials in your workflows. This is a 32-byte hex string.
- **N8N_BASIC_AUTH_USER/PASSWORD**: Optional basic authentication for webhook endpoints.

### pvc.yaml

Requests 5GB of persistent storage using the local-path storage class. This stores:
- Workflow definitions
- Encrypted credentials
- Execution history
- User preferences

The storage persists even if the pod restarts or moves to a different node.

### deployment.yaml

The main configuration file that defines how n8n runs:

**Key Environment Variables:**

| Variable | Value | Purpose |
|----------|-------|---------|
| N8N_HOST | n8n.blue-mercurius.com | Public hostname for n8n |
| N8N_PROTOCOL | https | Tells n8n that SSL is handled externally |
| WEBHOOK_URL | https://n8n.blue-mercurius.com/ | Base URL for webhook callbacks |
| GENERIC_TIMEZONE | America/New_York | Timezone for scheduled workflows |
| EXECUTIONS_DATA_PRUNE | true | Automatically delete old execution data |
| EXECUTIONS_DATA_MAX_AGE | 168 | Keep execution data for 7 days (168 hours) |
| N8N_METRICS | true | Enable Prometheus metrics endpoint |

**Resource Limits:**

| Resource | Request | Limit |
|----------|---------|-------|
| Memory | 256Mi | 1Gi |
| CPU | 100m | 1000m |

These limits prevent n8n from consuming excessive cluster resources while allowing it to scale up during heavy workflow execution.

### service.yaml

Exposes n8n using a LoadBalancer service. MetalLB assigns an IP from the configured pool (192.168.1.60-80). The assigned IP is 192.168.1.66.

### kustomization.yaml

Ties all manifests together and adds common labels. This allows deploying everything with a single command:

```bash
kubectl apply -k apps/n8n/
```

---

## Accessing N8N

### Local Network Access

From any device on your local network:

```
http://192.168.1.66:5678
```

### External Access via Cloudflare Tunnel

After configuring Cloudflare Tunnel:

```
https://n8n.blue-mercurius.com
```

**Cloudflare Tunnel Configuration:**

In the Cloudflare Zero Trust dashboard, add a public hostname:

| Field | Value |
|-------|-------|
| Subdomain | n8n |
| Domain | blue-mercurius.com |
| Service Type | HTTP |
| URL | 192.168.1.66:5678 |

Note: Use HTTP as the service type because n8n runs HTTP internally. Cloudflare handles HTTPS termination for external users.

---

## Security Configuration

### Current Security Measures

1. **Encryption at Rest**: All credentials stored in n8n are encrypted using the N8N_ENCRYPTION_KEY.

2. **HTTPS via Cloudflare**: External traffic is encrypted between users and Cloudflare.

3. **Network Isolation**: N8N runs in its own namespace, separate from other workloads.

4. **Resource Limits**: Prevents denial of service through resource exhaustion.

5. **Execution Pruning**: Old execution data is automatically deleted, limiting data exposure.

### Recommended Additional Security

**1. Enable Cloudflare Access**

Add an authentication layer in front of n8n:

1. Go to Cloudflare Zero Trust dashboard
2. Navigate to Access > Applications
3. Create application for n8n.blue-mercurius.com
4. Configure authentication policy (email OTP, SSO, etc.)

This ensures only authenticated users can access the n8n interface.

**2. Restrict Webhook Access**

If you enable basic auth for webhooks, configure it in the secret:

```yaml
N8N_BASIC_AUTH_ACTIVE: "true"
N8N_BASIC_AUTH_USER: "admin"
N8N_BASIC_AUTH_PASSWORD: "strong-password-here"
```

**3. Network Policies**

Add a NetworkPolicy to restrict which pods can communicate with n8n:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: n8n-network-policy
  namespace: n8n
spec:
  podSelector:
    matchLabels:
      app: n8n
  policyTypes:
  - Ingress
  ingress:
  - from: []
    ports:
    - port: 5678
```

---

## Secrets Management

### The Problem with Kubernetes Secrets

Kubernetes Secrets are not encrypted by default. They are merely base64 encoded, which is not encryption. Anyone with access to read secrets in the namespace can decode them:

```bash
kubectl get secret n8n-secrets -n n8n -o jsonpath='{.data.N8N_ENCRYPTION_KEY}' | base64 -d
```

This is a significant security concern. The secret.yaml file in the repository contains sensitive values in plain text.

### Current Secrets in This Project

| Location | Secret | Risk |
|----------|--------|------|
| apps/n8n/secret.yaml | N8N_ENCRYPTION_KEY | High - Can decrypt all n8n credentials |
| apps/n8n/secret.yaml | N8N_BASIC_AUTH_PASSWORD | Medium - Webhook access |
| scripts/etcd-backup.sh | Proxmox connection details | Medium - Backup system access |

---

## Securing Secrets in Kubernetes

There are several approaches to properly secure secrets, listed from simplest to most robust:

### Option 1: Enable Encryption at Rest in K3S

K3S can encrypt secrets stored in etcd. This is the easiest first step.

**Step 1: Create encryption configuration**

On the K3S server node, create `/var/lib/rancher/k3s/server/encryption-config.yaml`:

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}
```

Generate the key:

```bash
head -c 32 /dev/urandom | base64
```

**Step 2: Configure K3S to use encryption**

Add to K3S server config (`/etc/rancher/k3s/config.yaml`):

```yaml
secrets-encryption: true
```

Restart K3S:

```bash
sudo systemctl restart k3s
```

**Step 3: Re-encrypt existing secrets**

```bash
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

This ensures secrets are encrypted in etcd. However, anyone with cluster access can still read them via kubectl.

### Option 2: External Secrets Operator

External Secrets Operator synchronizes secrets from external vaults into Kubernetes. This keeps the actual secret values out of your git repository and etcd.

**Supported backends:**
- HashiCorp Vault
- AWS Secrets Manager
- Azure Key Vault
- Google Secret Manager
- 1Password
- Doppler

**How it works:**

1. Store secrets in external vault
2. Install External Secrets Operator in cluster
3. Create ExternalSecret resource pointing to vault
4. Operator creates Kubernetes Secret from vault data

Example ExternalSecret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: n8n-secrets
  namespace: n8n
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: vault-backend
  target:
    name: n8n-secrets
  data:
  - secretKey: N8N_ENCRYPTION_KEY
    remoteRef:
      key: n8n/config
      property: encryption_key
```

### Option 3: Sealed Secrets

Sealed Secrets by Bitnami allows you to encrypt secrets that can only be decrypted by the controller running in your cluster.

**How it works:**

1. Install Sealed Secrets controller in cluster
2. Use kubeseal CLI to encrypt secrets locally
3. Commit encrypted SealedSecret to git
4. Controller decrypts and creates regular Secret

**Benefits:**
- Secrets can be safely committed to git
- Only your cluster can decrypt them
- No external dependencies

**Installation:**

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

**Usage:**

```bash
# Install kubeseal CLI
# Create a regular secret file
# Encrypt it
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
```

The sealed-secret.yaml can be committed to git. It looks like:

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: n8n-secrets
  namespace: n8n
spec:
  encryptedData:
    N8N_ENCRYPTION_KEY: AgA8x9d7K... (encrypted)
```

### Option 4: SOPS with Age or GPG

Mozilla SOPS encrypts files in place, allowing you to commit encrypted secrets to git.

**How it works:**

1. Generate encryption key (Age or GPG)
2. Encrypt secret files with sops
3. Commit encrypted files to git
4. Use sops to decrypt before applying

**Example workflow:**

```bash
# Encrypt
sops --encrypt --age <public-key> secret.yaml > secret.enc.yaml

# Decrypt and apply
sops --decrypt secret.enc.yaml | kubectl apply -f -
```

**Integration with Flux or ArgoCD:**

Both GitOps tools can decrypt SOPS-encrypted files automatically during deployment.

### Recommendation for This Project

Given the current setup with ArgoCD already deployed, here is the recommended approach:

**Short term (do now):**
1. Enable K3S secrets encryption at rest
2. Remove plaintext secrets from git history

**Medium term:**
1. Install Sealed Secrets
2. Convert existing secrets to SealedSecrets
3. Update ArgoCD to deploy SealedSecrets

**Long term (if scaling):**
1. Deploy HashiCorp Vault
2. Use External Secrets Operator
3. Centralize all secrets in Vault

### Removing Secrets from Git History

The secret.yaml file with plaintext values is now in your git history. To remove it:

**Option 1: BFG Repo-Cleaner (recommended)**

```bash
# Install BFG
# Create file with patterns to remove
echo "N8N_ENCRYPTION_KEY" > patterns.txt
echo "N8N_BASIC_AUTH_PASSWORD" >> patterns.txt

# Run BFG
bfg --replace-text patterns.txt k3s.git

# Force push
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git push --force
```

**Option 2: Use git filter-branch**

More complex but built into git. Not recommended for large repositories.

**Option 3: Rotate secrets**

If removing history is too complex, simply rotate the secrets:
1. Generate new encryption key
2. Update secret in cluster
3. Re-encrypt n8n credentials

---

## Backup and Recovery

### What to Backup

1. **PVC Data**: Contains workflows and encrypted credentials
2. **Secret Values**: The encryption key must be preserved

### Backup Commands

```bash
# Export n8n workflows via API
curl -X GET http://192.168.1.66:5678/api/v1/workflows -H "X-N8N-API-KEY: <key>"

# Backup secret
kubectl get secret n8n-secrets -n n8n -o yaml > n8n-secrets-backup.yaml
```

### Recovery

1. Apply secret first (encryption key must exist before data)
2. Apply PVC
3. Apply deployment
4. Workflows should be available

---

## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
kubectl get pods -n n8n
kubectl describe pod -n n8n <pod-name>

# Check logs
kubectl logs -n n8n <pod-name>
```

### Common Issues

**Image Pull Errors:**
```bash
kubectl describe pod -n n8n <pod-name> | grep -A5 "Events"
```

**PVC Not Binding:**
```bash
kubectl get pvc -n n8n
kubectl describe pvc n8n-data -n n8n
```

**Service No External IP:**
```bash
kubectl get svc -n n8n
# Check MetalLB
kubectl get pods -n metallb-system
```

### Accessing Logs

```bash
# Current logs
kubectl logs -n n8n -l app=n8n

# Follow logs
kubectl logs -n n8n -l app=n8n -f

# Previous container logs (after restart)
kubectl logs -n n8n -l app=n8n --previous
```

---

## Maintenance

### Updating N8N

The deployment uses `latest` tag. To update:

```bash
# Delete pod to pull new image
kubectl delete pod -n n8n -l app=n8n

# Or rollout restart
kubectl rollout restart deployment/n8n -n n8n
```

For production, pin to specific version:

```yaml
image: docker.n8n.io/n8nio/n8n:1.20.0
```

### Checking Health

```bash
# Pod health
kubectl get pods -n n8n

# Endpoint health
curl http://192.168.1.66:5678/healthz
```

### Scaling

N8N does not support horizontal scaling with the default SQLite database. For scaling, you would need to:

1. Deploy PostgreSQL or MySQL
2. Configure n8n to use external database
3. Then scale replicas

---

## File Locations

| Path | Purpose |
|------|---------|
| apps/n8n/namespace.yaml | Namespace definition |
| apps/n8n/secret.yaml | Secrets (should be encrypted) |
| apps/n8n/pvc.yaml | Persistent storage claim |
| apps/n8n/deployment.yaml | Main deployment configuration |
| apps/n8n/service.yaml | LoadBalancer service |
| apps/n8n/kustomization.yaml | Kustomize configuration |

---

## Quick Reference

| Item | Value |
|------|-------|
| Namespace | n8n |
| Internal IP | 192.168.1.66 |
| Port | 5678 |
| External URL | https://n8n.blue-mercurius.com |
| Storage | 5Gi (local-path) |
| Memory Limit | 1Gi |
| CPU Limit | 1 core |
