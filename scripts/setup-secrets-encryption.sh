#!/bin/bash
# K3S Secrets Encryption Setup Script
# This script enables encryption at rest for Kubernetes secrets using K3S native commands

set -e

# Control plane node (primary - where we run commands)
CONTROL_NODE="192.168.1.92"
SSH_USER="tech"

echo "============================================"
echo "K3S Secrets Encryption Setup"
echo "============================================"
echo ""

# Step 1: Enable secrets encryption
echo "[1/3] Enabling secrets encryption..."
ssh "${SSH_USER}@${CONTROL_NODE}" "sudo k3s secrets-encrypt enable"
echo "[OK] Secrets encryption enabled"

echo ""
echo "[2/3] Waiting for encryption to propagate to all nodes..."
sleep 10

# Check status
ssh "${SSH_USER}@${CONTROL_NODE}" "sudo k3s secrets-encrypt status"

echo ""
echo "[3/3] Re-encrypting existing secrets..."
ssh "${SSH_USER}@${CONTROL_NODE}" "sudo k3s secrets-encrypt reencrypt"

echo ""
echo "============================================"
echo "Secrets encryption setup complete"
echo "============================================"
echo ""
echo "Verification command:"
echo "  ssh tech@192.168.1.92 'sudo k3s secrets-encrypt status'"
echo ""
echo "Note: The encryption key is automatically managed by K3S"
echo "and stored at /var/lib/rancher/k3s/server/cred/encryption-config.json"
echo ""
