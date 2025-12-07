#!/bin/bash
#
# K3S Etcd Backup Script with Rotation
# 
# This script creates etcd snapshots and backs them up to a remote Proxmox host
# with automatic rotation to prevent storage saturation.
#
# Usage: Run this on your K3S server node (k3s-01 / master1)
# Schedule via cron: 0 2 * * * /opt/k3s-backup/etcd-backup.sh
#

set -euo pipefail

#############################################
#           CONFIGURATION                   #
#############################################

# Proxmox host details
PROXMOX_HOST="192.168.1.100"        # Change to your Proxmox IP
PROXMOX_USER="root"                  # Proxmox user
PROXMOX_BACKUP_DIR="/var/backups/k3s-etcd"  # Directory on Proxmox

# Retention settings
KEEP_LOCAL=3                         # Keep last 3 snapshots locally
KEEP_REMOTE=7                        # Keep last 7 snapshots on Proxmox

# Local snapshot directory (K3S default)
LOCAL_SNAPSHOT_DIR="/var/lib/rancher/k3s/server/db/snapshots"

# Backup naming
CLUSTER_NAME="k3s-homelab"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_NAME="${CLUSTER_NAME}-${TIMESTAMP}"

# Logging
LOG_FILE="/var/log/k3s-backup.log"

#############################################
#           FUNCTIONS                       #
#############################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR: This script must be run as root"
        exit 1
    fi
}

check_k3s() {
    if ! systemctl is-active --quiet k3s; then
        log "ERROR: K3S service is not running"
        exit 1
    fi
}

create_snapshot() {
    log "Creating etcd snapshot: ${SNAPSHOT_NAME}"
    
    if k3s etcd-snapshot save --name "${SNAPSHOT_NAME}"; then
        log "SUCCESS: Snapshot created"
        return 0
    else
        log "ERROR: Failed to create snapshot"
        return 1
    fi
}

rotate_local() {
    log "Rotating local snapshots (keeping last ${KEEP_LOCAL})"
    
    # List snapshots, sort by date, remove old ones
    local count=$(ls -1 "${LOCAL_SNAPSHOT_DIR}"/*.zip 2>/dev/null | wc -l)
    
    if [[ $count -gt $KEEP_LOCAL ]]; then
        local to_delete=$((count - KEEP_LOCAL))
        log "Removing ${to_delete} old local snapshot(s)"
        
        ls -1t "${LOCAL_SNAPSHOT_DIR}"/*.zip | tail -n "${to_delete}" | while read -r file; do
            log "  Deleting: $(basename "$file")"
            rm -f "$file"
        done
    else
        log "  No rotation needed (${count} snapshots present)"
    fi
}

backup_to_proxmox() {
    log "Backing up to Proxmox host: ${PROXMOX_HOST}"
    
    # Find the latest snapshot
    local latest_snapshot=$(ls -1t "${LOCAL_SNAPSHOT_DIR}"/*.zip 2>/dev/null | head -1)
    
    if [[ -z "$latest_snapshot" ]]; then
        log "ERROR: No snapshot found to backup"
        return 1
    fi
    
    local snapshot_file=$(basename "$latest_snapshot")
    local snapshot_size=$(du -h "$latest_snapshot" | cut -f1)
    
    log "  Transferring: ${snapshot_file} (${snapshot_size})"
    
    # Create remote directory if it doesn't exist
    ssh "${PROXMOX_USER}@${PROXMOX_HOST}" "mkdir -p ${PROXMOX_BACKUP_DIR}" 2>/dev/null || {
        log "ERROR: Cannot connect to Proxmox or create directory"
        return 1
    }
    
    # Copy the snapshot
    if scp -q "$latest_snapshot" "${PROXMOX_USER}@${PROXMOX_HOST}:${PROXMOX_BACKUP_DIR}/"; then
        log "SUCCESS: Backup transferred to Proxmox"
        return 0
    else
        log "ERROR: Failed to transfer backup"
        return 1
    fi
}

rotate_remote() {
    log "Rotating remote snapshots on Proxmox (keeping last ${KEEP_REMOTE})"
    
    ssh "${PROXMOX_USER}@${PROXMOX_HOST}" bash -s << EOF
        cd "${PROXMOX_BACKUP_DIR}" 2>/dev/null || exit 0
        count=\$(ls -1 *.zip 2>/dev/null | wc -l)
        if [[ \$count -gt ${KEEP_REMOTE} ]]; then
            to_delete=\$((count - ${KEEP_REMOTE}))
            ls -1t *.zip | tail -n "\$to_delete" | xargs rm -f
            echo "  Removed \$to_delete old backup(s)"
        else
            echo "  No rotation needed (\$count backups present)"
        fi
EOF
}

show_status() {
    log "=== Backup Status ==="
    
    # Local status
    local local_count=$(ls -1 "${LOCAL_SNAPSHOT_DIR}"/*.zip 2>/dev/null | wc -l)
    local local_size=$(du -sh "${LOCAL_SNAPSHOT_DIR}" 2>/dev/null | cut -f1)
    log "Local: ${local_count} snapshots, ${local_size:-0} total"
    
    # Remote status
    ssh "${PROXMOX_USER}@${PROXMOX_HOST}" bash -s << EOF 2>/dev/null || echo "  Cannot connect to Proxmox"
        if [[ -d "${PROXMOX_BACKUP_DIR}" ]]; then
            count=\$(ls -1 "${PROXMOX_BACKUP_DIR}"/*.zip 2>/dev/null | wc -l)
            size=\$(du -sh "${PROXMOX_BACKUP_DIR}" 2>/dev/null | cut -f1)
            echo "Remote: \${count} backups, \${size} total"
        else
            echo "Remote: No backups yet"
        fi
EOF
    
    log "===================="
}

#############################################
#           MAIN                            #
#############################################

main() {
    log "=========================================="
    log "K3S Etcd Backup Started"
    log "=========================================="
    
    check_root
    check_k3s
    
    # Create snapshot
    if ! create_snapshot; then
        log "FAILED: Backup aborted"
        exit 1
    fi
    
    # Backup to Proxmox
    if ! backup_to_proxmox; then
        log "WARNING: Remote backup failed, snapshot saved locally only"
    fi
    
    # Rotate old backups
    rotate_local
    rotate_remote
    
    # Show final status
    show_status
    
    log "Backup completed successfully"
    log "=========================================="
}

# Run main function
main "$@"
