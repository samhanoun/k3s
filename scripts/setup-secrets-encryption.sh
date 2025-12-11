#!/bin/bash
# K3S Secrets Encryption Setup Script
# This script enables encryption at rest for Kubernetes secrets using K3S native commands

set -e

# Control plane nodes
CONTROL_NODES=("192.168.1.46" "192.168.1.198" "192.168.1.92")
PRIMARY_NODE="${CONTROL_NODES[0]}"  # k3s-03 - commands only need to run on one node
SSH_USER="tech"

echo "============================================"
echo "K3S Secrets Encryption Setup"
echo "============================================"
echo ""
echo "Control Plane Nodes:"
echo "  - k3s-03: 192.168.1.46 (primary)"
echo "  - k3s-04: 192.168.1.198"
echo "  - k3s-05: 192.168.1.92"
echo ""
echo "Note: K3S secrets-encrypt commands only need to run on one"
echo "control plane node - changes propagate via etcd automatically."
echo ""

# Step 1: Enable secrets encryption
echo "[1/4] Enabling secrets encryption on primary node..."
ssh "${SSH_USER}@${PRIMARY_NODE}" "sudo k3s secrets-encrypt enable"
echo "[OK] Secrets encryption enabled"

echo ""
echo "[2/4] Waiting for encryption to propagate to all nodes..."
sleep 10

# Step 2: Check status on all nodes
echo "[3/4] Verifying encryption status on all control plane nodes..."
for node in "${CONTROL_NODES[@]}"; do
  echo "--- Node: $node ---"
  ssh "${SSH_USER}@${node}" "sudo k3s secrets-encrypt status" || echo "Warning: Could not check $node"
  echo ""
done

echo "[4/4] Re-encrypting existing secrets..."
ssh "${SSH_USER}@${PRIMARY_NODE}" "sudo k3s secrets-encrypt reencrypt"

echo ""
echo "============================================"
echo "Secrets encryption setup complete"
echo "============================================"
echo ""
echo "Verification commands:"
for node in "${CONTROL_NODES[@]}"; do
  echo "  ssh tech@$node 'sudo k3s secrets-encrypt status'"
done
echo ""
echo "Note: The encryption key is automatically managed by K3S"
echo "and stored at /var/lib/rancher/k3s/server/cred/encryption-config.json"
echo ""
