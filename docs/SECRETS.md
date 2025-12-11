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

### Enable Encryption at Rest

```bash
# On a control plane node
sudo k3s secrets-encrypt enable
sudo k3s secrets-encrypt reencrypt
```

### Check Status

```bash
sudo k3s secrets-encrypt status
```

## References

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [K3S Secrets Encryption](https://docs.k3s.io/security/secrets-encryption)
- [Kubernetes Secrets Best Practices](https://kubernetes.io/docs/concepts/configuration/secret/#best-practices)
