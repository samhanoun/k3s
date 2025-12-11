# Secrets Management

This document describes how secrets are managed in the K3S cluster.

## Overview

We use [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) to encrypt Kubernetes secrets so they can be safely stored in Git. The Sealed Secrets controller runs in the cluster and decrypts SealedSecrets into regular Kubernetes Secrets.

## Architecture

```
secret.yaml.example  -->  secret.yaml (local, gitignored)  -->  kubeseal  -->  sealed-secret.yaml (in Git)
                                                                                       |
                                                                                       v
                                                                         [Sealed Secrets Controller]
                                                                                       |
                                                                                       v
                                                                              secret (in cluster)
```

## Components

### Sealed Secrets Controller

- **Installed via Helm** in the `kube-system` namespace
- **Controller name:** `sealed-secrets`
- **Certificate validity:** 10 years (auto-rotates)
- **Private key:** Stored as a secret in `kube-system`

### kubeseal CLI

Installed on the control plane node at `/usr/local/bin/kubeseal`.

## Usage

### Creating a New Sealed Secret

1. **Create a regular secret manifest** (use `.example` as template):

   ```bash
   cp apps/myapp/secret.yaml.example apps/myapp/secret.yaml
   # Edit secret.yaml with your actual values
   ```

2. **Seal the secret**:

   ```bash
   # From a control plane node
   kubectl create secret generic myapp-secrets \
     --namespace myapp \
     --from-literal=KEY1=value1 \
     --from-literal=KEY2=value2 \
     --dry-run=client -o yaml | \
   kubeseal \
     --controller-name=sealed-secrets \
     --controller-namespace=kube-system \
     --format yaml > apps/myapp/sealed-secret.yaml
   ```

3. **Apply to cluster**:

   ```bash
   kubectl apply -f apps/myapp/sealed-secret.yaml
   ```

4. **Update kustomization.yaml** to reference `sealed-secret.yaml` instead of `secret.yaml`

5. **Commit the sealed secret** (never commit plaintext secrets!)

### Updating an Existing Secret

1. Create a new sealed secret with the updated values (same process as above)
2. Apply to cluster - the controller will update the underlying Secret
3. Restart any pods that use the secret

### Rotating the Sealing Key

The controller automatically rotates keys every 30 days. Old sealed secrets remain valid. To fetch the current certificate:

```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=kube-system --fetch-cert
```

### Backup the Sealing Key

**Critical:** Back up the private key to recover sealed secrets if the cluster is lost:

```bash
kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
```

Store this backup securely (password manager, encrypted storage, etc.)

## Security Guidelines

### DO:
- Always use SealedSecrets for any sensitive data in Git
- Back up the sealing key securely
- Use separate secrets per application
- Rotate application credentials periodically
- Use namespace-scoped sealed secrets (default)

### DON'T:
- Commit plaintext `secret.yaml` files (they're gitignored)
- Share the sealing private key
- Expose the `secret.yaml.example` with real values
- Use the same secret across namespaces (seal per-namespace)

## n8n Secrets

The n8n application uses the following secrets:

| Key | Description |
|-----|-------------|
| `N8N_ENCRYPTION_KEY` | 64-character hex string for encrypting credentials |
| `N8N_BASIC_AUTH_USER` | Username for webhook authentication |
| `N8N_BASIC_AUTH_PASSWORD` | Password for webhook authentication |

**Important:** The `N8N_ENCRYPTION_KEY` cannot be changed after n8n first starts, as it stores the key in its config file and uses it to encrypt saved credentials.

## File Structure

```
apps/n8n/
  kustomization.yaml      # References sealed-secret.yaml
  sealed-secret.yaml      # Encrypted (safe to commit)
  secret.yaml.example     # Template with placeholder values
  secret.yaml             # NOT in Git (gitignored)
```

## Troubleshooting

### Check SealedSecret status

```bash
kubectl get sealedsecret -n n8n
```

Look for `SYNCED: True`. If `False`, describe the resource for error details:

```bash
kubectl describe sealedsecret n8n-secrets -n n8n
```

### Secret not updating

If a SealedSecret won't update an existing secret:

```bash
# Delete the existing secret
kubectl delete secret mysecret -n mynamespace

# Delete and recreate the SealedSecret
kubectl delete sealedsecret mysecret -n mynamespace
kubectl apply -f sealed-secret.yaml
```

### Verify secret contents

```bash
kubectl get secret n8n-secrets -n n8n -o jsonpath='{.data.N8N_ENCRYPTION_KEY}' | base64 -d
```

## K3S Secrets Encryption at Rest

In addition to SealedSecrets (for Git), K3S can encrypt secrets at rest in etcd. This is a separate layer of protection.

### Cluster Architecture

Our K3S cluster has 3 control plane nodes:

| Node | IP Address |
|------|------------|
| k3s-03 | 192.168.1.46 |
| k3s-04 | 192.168.1.198 |
| k3s-05 | 192.168.1.92 |

### How It Works

K3S secrets encryption uses AES-CBC encryption with a key managed by K3S. When enabled:

1. **New secrets** are encrypted before being stored in etcd
2. **Existing secrets** remain unencrypted until you run `reencrypt`
3. **The encryption key** is stored at `/var/lib/rancher/k3s/server/cred/encryption-config.json`
4. **Changes propagate via etcd** - you only need to run commands on one control plane node

### Enable Encryption at Rest

Use the provided script or run manually:

```bash
# Using the script (recommended)
./scripts/setup-secrets-encryption.sh

# Or manually on any control plane node
ssh tech@192.168.1.46 "sudo k3s secrets-encrypt enable"
ssh tech@192.168.1.46 "sudo k3s secrets-encrypt reencrypt"
```

### Check Status

Verify encryption is enabled on all control plane nodes:

```bash
# Check all nodes
for ip in 192.168.1.46 192.168.1.198 192.168.1.92; do
  echo "--- $ip ---"
  ssh tech@$ip "sudo k3s secrets-encrypt status"
done
```

Expected output when enabled:
```
Encryption Status: Enabled
Current Rotation Stage: secrets_encrypted
```

### Rotate Encryption Key

To rotate the encryption key (recommended periodically):

```bash
ssh tech@192.168.1.46 "sudo k3s secrets-encrypt rotate-keys"
ssh tech@192.168.1.46 "sudo k3s secrets-encrypt reencrypt"
```

## Two Layers of Protection

| Layer | Purpose | Protects Against |
|-------|---------|------------------|
| **Sealed Secrets** | Encrypt secrets in Git | Secrets exposed in source control |
| **K3S Encryption at Rest** | Encrypt secrets in etcd | Direct etcd access, disk theft |

Both layers work together for defense in depth.

## References

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [K3S Secrets Encryption](https://docs.k3s.io/security/secrets-encryption)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/#best-practices)
