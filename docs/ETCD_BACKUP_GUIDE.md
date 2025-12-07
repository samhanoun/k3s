# K3S Etcd Backup System

This document explains the etcd backup system implemented for the K3S cluster, including all components, their responsibilities, and how they communicate.

## Table of Contents

1. [Overview](#overview)
2. [Why Etcd Backups Matter](#why-etcd-backups-matter)
3. [Architecture](#architecture)
4. [Components](#components)
5. [SSH Configuration](#ssh-configuration)
6. [How the Backup Process Works](#how-the-backup-process-works)
7. [Rotation Policy](#rotation-policy)
8. [File Locations](#file-locations)
9. [Restoring from Backup](#restoring-from-backup)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The backup system creates snapshots of the K3S etcd database and copies them to the Proxmox host for safekeeping. It runs automatically every day at 2:00 AM and maintains a rolling set of backups to prevent storage saturation while ensuring you always have recent restore points.

---

## Why Etcd Backups Matter

Etcd is the database that stores everything about your Kubernetes cluster. When you create a deployment, a service, a secret, or any other Kubernetes resource, that information lives in etcd. If etcd is lost or corrupted and you have no backup, you lose your entire cluster configuration. The pods, the services, the ingress rules, the secrets - all gone.

K3S does create automatic snapshots every 12 hours and keeps 5 of them. However, these snapshots are stored on the same server as etcd itself. If that server's disk fails, both etcd and its backups are lost together. This is why we copy backups to a separate machine - the Proxmox host in this case.

---

## Architecture

The backup system involves three machines:

```
+-------------------+          +-------------------+          +-------------------+
|   Your Laptop     |          |     k3s-05        |          |   Proxmox Host    |
|   (Windows)       |          |  192.168.1.92     |          |   192.168.1.100   |
|                   |          |                   |          |                   |
|   Management &    |   SSH    |   K3S Server      |   SSH    |   Backup Storage  |
|   Monitoring      | -------> |   Runs Backups    | -------> |   /var/backups/   |
|                   |  tech@   |                   |  root@   |   k3s-etcd/       |
+-------------------+          +-------------------+          +-------------------+
```

Your laptop is where you manage everything. The k3s-05 node is where the backup script runs because it has access to the etcd data. The Proxmox host is where the backups are stored for safety.

---

## Components

### etcd-backup.sh

Location on k3s-05: `/opt/k3s-backup/etcd-backup.sh`

This is the main backup script. It does four things:

1. Creates a new etcd snapshot using the k3s command
2. Copies that snapshot to the Proxmox host via SCP
3. Deletes old local snapshots to save space
4. Deletes old remote snapshots to save space on Proxmox

The script runs as root because it needs access to the etcd data and the root SSH key.

### setup-etcd-backup.sh

Location in repository: `scripts/setup-etcd-backup.sh`

This is a one-time setup script that you run when first configuring backups. It does the following:

1. Tests the SSH connection to Proxmox
2. Creates the backup directory on Proxmox
3. Copies the backup script to the right location
4. Sets up the cron job for daily execution
5. Runs an initial backup to verify everything works

You typically run this once and then forget about it.

### Cron Job

Location on k3s-05: `/etc/cron.d/k3s-backup`

Contents:
```
0 2 * * * root /opt/k3s-backup/etcd-backup.sh >> /var/log/k3s-backup.log 2>&1
```

This tells the system to run the backup script every day at 2:00 AM. The output goes to a log file so you can review what happened.

### Log File

Location on k3s-05: `/var/log/k3s-backup.log`

Every time the backup runs, it appends its output to this file. You can check it to see if backups are succeeding or failing.

---

## SSH Configuration

The backup system relies on SSH key authentication. Here is how the connections work:

### Your Laptop to k3s-05

- Source: Your Windows laptop
- Destination: k3s-05 (192.168.1.92)
- User: tech
- Key: `~/.ssh/id_ed25519` (or the key in your k3s repository)
- Purpose: Running commands on the K3S server, checking logs, manual backups

This connection was set up when you built the K3S cluster. The public key was deployed via cloud-init to all the K3S nodes.

### k3s-05 to Proxmox

- Source: k3s-05 (192.168.1.92)
- Destination: Proxmox host (192.168.1.100)
- User: root
- Key: `/root/.ssh/id_ed25519` on k3s-05
- Purpose: Copying snapshot files to Proxmox storage

This connection was set up specifically for backups. We generated a new SSH key pair on k3s-05 and added the public key to the Proxmox root user's authorized_keys file.

The key on k3s-05:
```
/root/.ssh/id_ed25519      (private key - stays on k3s-05)
/root/.ssh/id_ed25519.pub  (public key - copied to Proxmox)
```

The authorized entry on Proxmox:
```
/root/.ssh/authorized_keys contains:
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIOZZdLsfDUUuZKo0k+QfJf8lU6ayLIZM0g/RE6CzL0j k3s-backup@k3s-05
```

---

## How the Backup Process Works

When the backup script runs, here is what happens step by step:

### Step 1: Create Snapshot

The script runs `k3s etcd-snapshot save --name k3s-homelab-TIMESTAMP`. This tells K3S to create a point-in-time copy of the etcd database. The snapshot is saved to `/var/lib/rancher/k3s/server/db/snapshots/` with a filename that includes the timestamp and node name.

The snapshot is about 19-20 MB in size for a typical cluster.

### Step 2: Transfer to Proxmox

The script finds the newest snapshot file (matching the k3s-homelab pattern) and uses SCP to copy it to the Proxmox host. The destination is `/var/backups/k3s-etcd/`.

The SCP command uses the root SSH key we set up earlier:
```
scp /var/lib/rancher/k3s/server/db/snapshots/k3s-homelab-... root@192.168.1.100:/var/backups/k3s-etcd/
```

### Step 3: Rotate Local Snapshots

The script counts how many k3s-homelab snapshots exist locally. If there are more than 3, it deletes the oldest ones. This prevents the local disk from filling up.

Note that K3S also creates its own automatic snapshots with names starting with `etcd-snapshot-`. The backup script does not touch those. They are managed by K3S itself.

### Step 4: Rotate Remote Snapshots

The script connects to Proxmox via SSH and counts the backup files. If there are more than 7, it deletes the oldest ones. This keeps about a week of backups on Proxmox without using excessive storage.

### Step 5: Report Status

The script logs a summary showing how many snapshots exist locally and remotely, along with the total size.

---

## Rotation Policy

The backup system maintains two sets of backups with different retention periods:

### Local Backups (on k3s-05)

- Location: `/var/lib/rancher/k3s/server/db/snapshots/`
- Retention: 3 backups
- Approximate size: 60 MB total (3 x 20 MB)
- Managed by: Our backup script (for k3s-homelab-* files)

Additionally, K3S maintains its own automatic snapshots:
- Pattern: etcd-snapshot-*
- Retention: 5 snapshots (K3S default)
- Frequency: Every 12 hours (K3S default)

### Remote Backups (on Proxmox)

- Location: `/var/backups/k3s-etcd/`
- Retention: 7 backups
- Approximate size: 140 MB total (7 x 20 MB)
- Managed by: Our backup script

This means you can restore from any point in the last 7 days using the Proxmox backups. The local backups are mainly for quick access and serve as a cache.

---

## File Locations

Here is a summary of all the important files:

### On k3s-05 (192.168.1.92)

| Path | Purpose |
|------|---------|
| `/opt/k3s-backup/etcd-backup.sh` | Main backup script |
| `/etc/cron.d/k3s-backup` | Cron job configuration |
| `/var/log/k3s-backup.log` | Backup log file |
| `/var/lib/rancher/k3s/server/db/snapshots/` | Snapshot storage |
| `/root/.ssh/id_ed25519` | SSH private key for Proxmox |
| `/root/.ssh/id_ed25519.pub` | SSH public key |

### On Proxmox (192.168.1.100)

| Path | Purpose |
|------|---------|
| `/var/backups/k3s-etcd/` | Backup file storage |
| `/root/.ssh/authorized_keys` | Contains k3s-05 public key |

### In the Git Repository

| Path | Purpose |
|------|---------|
| `scripts/etcd-backup.sh` | Source version of backup script |
| `scripts/setup-etcd-backup.sh` | One-time setup script |
| `docs/ETCD_BACKUP_GUIDE.md` | This documentation |

---

## Restoring from Backup

If you need to restore your cluster from a backup, here is the process:

### Step 1: Stop K3S on All Nodes

You must stop K3S on every node before restoring. On server nodes:
```bash
sudo systemctl stop k3s
```

On agent nodes:
```bash
sudo systemctl stop k3s-agent
```

### Step 2: Get the Backup File

If restoring from a local backup:
```bash
ls -la /var/lib/rancher/k3s/server/db/snapshots/
# Pick the snapshot you want to restore
```

If restoring from Proxmox:
```bash
# On k3s-05
sudo scp root@192.168.1.100:/var/backups/k3s-etcd/k3s-homelab-XXXXXXXX-XXXXXX-k3s-05-XXXXXXXXXX /tmp/
```

### Step 3: Restore the Snapshot

Run the restore command on the primary server node (k3s-05):
```bash
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/path/to/snapshot-file
```

This is a destructive operation. It resets the cluster to the state captured in the snapshot. Any changes made after that snapshot was taken will be lost.

### Step 4: Start K3S

Start K3S on the primary server:
```bash
sudo systemctl start k3s
```

Wait for it to become healthy, then start the other server nodes and finally the agent nodes.

### Step 5: Verify the Cluster

Check that all nodes have rejoined:
```bash
kubectl get nodes
```

Check that your workloads are running:
```bash
kubectl get pods --all-namespaces
```

---

## Troubleshooting

### Backup Not Running

Check if the cron job exists:
```bash
ssh tech@192.168.1.92 "cat /etc/cron.d/k3s-backup"
```

Check if cron is running:
```bash
ssh tech@192.168.1.92 "sudo systemctl status cron"
```

### SSH Connection Failing

Test the SSH connection from k3s-05 to Proxmox:
```bash
ssh tech@192.168.1.92 "sudo ssh root@192.168.1.100 hostname"
```

If this fails, check if the key is in place:
```bash
ssh tech@192.168.1.92 "sudo ls -la /root/.ssh/"
```

And verify the authorized_keys on Proxmox:
```bash
ssh root@192.168.1.100 "cat ~/.ssh/authorized_keys"
```

### Checking the Log

View recent backup activity:
```bash
ssh tech@192.168.1.92 "sudo tail -50 /var/log/k3s-backup.log"
```

### Running a Manual Backup

If you want to run a backup immediately:
```bash
ssh tech@192.168.1.92 "sudo /opt/k3s-backup/etcd-backup.sh"
```

### Disk Space Issues

Check local snapshot space:
```bash
ssh tech@192.168.1.92 "sudo du -sh /var/lib/rancher/k3s/server/db/snapshots/"
```

Check Proxmox backup space:
```bash
ssh root@192.168.1.100 "du -sh /var/backups/k3s-etcd/"
```

If space is an issue, you can reduce the retention by editing the script:
- `KEEP_LOCAL=3` controls local retention
- `KEEP_REMOTE=7` controls remote retention

---

## Configuration Reference

The backup script has these configurable values at the top:

```bash
# Proxmox host details
PROXMOX_HOST="192.168.1.100"
PROXMOX_USER="root"
PROXMOX_BACKUP_DIR="/var/backups/k3s-etcd"

# Retention settings
KEEP_LOCAL=3
KEEP_REMOTE=7

# Naming
CLUSTER_NAME="k3s-homelab"
```

If you need to change any of these, edit `/opt/k3s-backup/etcd-backup.sh` on k3s-05 and also update `scripts/etcd-backup.sh` in the git repository to keep them in sync.
