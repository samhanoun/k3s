#!/bin/bash
#
# K3S Etcd Backup Setup Script
#
# Run this script on your K3S server node (k3s-01) to set up automated backups
# Prerequisites: SSH key access to Proxmox host
#

set -euo pipefail

echo "============================================"
echo "  K3S Etcd Backup Setup"
echo "============================================"
echo ""

# Configuration - Update these values
PROXMOX_HOST="${1:-192.168.1.100}"
PROXMOX_USER="${2:-root}"
BACKUP_DIR="/var/backups/k3s-etcd"
SCRIPT_DIR="/opt/k3s-backup"
SCRIPT_NAME="etcd-backup.sh"

echo "Configuration:"
echo "  Proxmox Host: ${PROXMOX_HOST}"
echo "  Proxmox User: ${PROXMOX_USER}"
echo "  Remote Backup Dir: ${BACKUP_DIR}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run as root (sudo)"
    exit 1
fi

# Step 1: Test SSH connection to Proxmox
echo "[1/5] Testing SSH connection to Proxmox..."
if ssh -o ConnectTimeout=5 "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'SSH OK'" 2>/dev/null; then
    echo "  ✓ SSH connection successful"
else
    echo "  ✗ Cannot connect to Proxmox"
    echo ""
    echo "  Please set up SSH key authentication first:"
    echo "    1. Generate key (if needed): ssh-keygen -t ed25519"
    echo "    2. Copy to Proxmox: ssh-copy-id ${PROXMOX_USER}@${PROXMOX_HOST}"
    echo ""
    exit 1
fi

# Step 2: Create backup directory on Proxmox
echo "[2/5] Creating backup directory on Proxmox..."
ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "mkdir -p ${BACKUP_DIR} && echo '  ✓ Directory created: ${BACKUP_DIR}'"

# Step 3: Install backup script
echo "[3/5] Installing backup script..."
mkdir -p "${SCRIPT_DIR}"

# Check if script exists in current directory or use embedded version
if [[ -f "./${SCRIPT_NAME}" ]]; then
    cp "./${SCRIPT_NAME}" "${SCRIPT_DIR}/${SCRIPT_NAME}"
elif [[ -f "./scripts/${SCRIPT_NAME}" ]]; then
    cp "./scripts/${SCRIPT_NAME}" "${SCRIPT_DIR}/${SCRIPT_NAME}"
else
    echo "  ERROR: Cannot find ${SCRIPT_NAME}"
    echo "  Please ensure etcd-backup.sh is in current directory or scripts/"
    exit 1
fi

chmod +x "${SCRIPT_DIR}/${SCRIPT_NAME}"

# Update the script with actual Proxmox details
sed -i "s/PROXMOX_HOST=\".*\"/PROXMOX_HOST=\"${PROXMOX_HOST}\"/" "${SCRIPT_DIR}/${SCRIPT_NAME}"
sed -i "s/PROXMOX_USER=\".*\"/PROXMOX_USER=\"${PROXMOX_USER}\"/" "${SCRIPT_DIR}/${SCRIPT_NAME}"

echo "  ✓ Script installed to ${SCRIPT_DIR}/${SCRIPT_NAME}"

# Step 4: Set up cron job
echo "[4/5] Setting up cron job (daily at 2:00 AM)..."
CRON_JOB="0 2 * * * ${SCRIPT_DIR}/${SCRIPT_NAME} >> /var/log/k3s-backup.log 2>&1"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "etcd-backup.sh"; then
    echo "  ⚠ Cron job already exists, updating..."
    (crontab -l 2>/dev/null | grep -v "etcd-backup.sh"; echo "${CRON_JOB}") | crontab -
else
    (crontab -l 2>/dev/null; echo "${CRON_JOB}") | crontab -
fi
echo "  ✓ Cron job configured"

# Step 5: Run initial backup
echo "[5/5] Running initial backup..."
echo ""
"${SCRIPT_DIR}/${SCRIPT_NAME}"

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Backup Schedule:"
echo "  - Runs daily at 2:00 AM"
echo "  - Keeps 3 snapshots locally"
echo "  - Keeps 7 backups on Proxmox"
echo ""
echo "Useful Commands:"
echo "  Manual backup:  ${SCRIPT_DIR}/${SCRIPT_NAME}"
echo "  View logs:      tail -f /var/log/k3s-backup.log"
echo "  List backups:   ls -lh /var/lib/rancher/k3s/server/db/snapshots/"
echo "  Remote backups: ssh ${PROXMOX_USER}@${PROXMOX_HOST} 'ls -lh ${BACKUP_DIR}/'"
echo ""
echo "To restore from backup:"
echo "  k3s server --cluster-reset --cluster-reset-restore-path=/path/to/snapshot.zip"
echo ""
