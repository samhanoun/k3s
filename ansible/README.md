# Ansible for K3S Cluster Management

This directory contains Ansible playbooks and configuration for managing the K3S cluster.

## Prerequisites

### Windows Users (WSL2 Required)

Ansible does not run natively on Windows. You must use WSL2 (Windows Subsystem for Linux):

```bash
# 1. Install WSL2 if not already installed (run in PowerShell as Admin)
wsl --install

# 2. Open WSL terminal and install Ansible
sudo apt update
sudo apt install ansible

# 3. Copy your SSH key to WSL (one-time setup)
mkdir -p ~/.ssh
cp /mnt/c/Users/<YOUR_USERNAME>/Documents/k3s/id_ed25519 ~/.ssh/id_ed25519_k3s
chmod 600 ~/.ssh/id_ed25519_k3s

# 4. Copy Ansible files to WSL home (avoids Windows permission issues)
mkdir -p ~/k3s-ansible
cp -r /mnt/c/Users/<YOUR_USERNAME>/Documents/k3s/ansible/* ~/k3s-ansible/

# 5. Update the key path in inventory (already done if you copied from repo)
# The inventory references ~/.ssh/id_ed25519_k3s
```

### macOS / Linux

```bash
# macOS
brew install ansible

# Ubuntu/Debian
sudo apt install ansible

# Ensure your SSH key is at ~/.ssh/id_ed25519_k3s or update inventory/hosts.yaml
```

## Directory Structure

```
ansible/
  ansible.cfg           # Ansible configuration
  inventory/
    hosts.yaml          # Cluster inventory (all 5 nodes)
  playbooks/
    common.yaml         # Common configuration for all nodes
    upgrade.yaml        # Upgrade Ubuntu packages (rolling)
    health-check.yaml   # Check cluster and node health
    secrets-encrypt.yaml # Enable K3S secrets encryption
    backup-etcd.yaml    # Backup etcd to local machine
    deploy-apps.yaml    # Deploy apps via Kustomize
```

## Quick Start

### Windows (WSL2)

```bash
# Open WSL terminal
wsl

# Navigate to Ansible directory
cd ~/k3s-ansible

# Test connectivity to all nodes
ansible all -m ping

# Check cluster health
ansible-playbook playbooks/health-check.yaml

# Apply common configuration
ansible-playbook playbooks/common.yaml
```

### macOS / Linux

```bash
cd ansible

# Test connectivity to all nodes
ansible all -m ping

# Check cluster health
ansible-playbook playbooks/health-check.yaml

# Apply common configuration
ansible-playbook playbooks/common.yaml
```

## Playbooks

### Health Check

Check all nodes and cluster status:

```bash
ansible-playbook playbooks/health-check.yaml
```

### Upgrade Nodes

Rolling upgrade of all nodes (one at a time):

```bash
ansible-playbook playbooks/upgrade.yaml
```

### Enable Secrets Encryption

Enable K3S secrets encryption at rest:

```bash
ansible-playbook playbooks/secrets-encrypt.yaml
```

### Backup etcd

Create and download an etcd snapshot:

```bash
ansible-playbook playbooks/backup-etcd.yaml
```

### Deploy Applications

Deploy a specific app:

```bash
ansible-playbook playbooks/deploy-apps.yaml -e "app=n8n"
```

Deploy all apps:

```bash
ansible-playbook playbooks/deploy-apps.yaml
```

## Inventory

The inventory defines 5 nodes:

| Group | Nodes | Purpose |
|-------|-------|---------|
| control_plane | k3s-03, k3s-04, k3s-05 | Run K3S server (etcd, API, scheduler) |
| workers | k3s-01, k3s-02 | Run workloads only |
| k3s_cluster | All nodes | Convenience group for all nodes |

## Ad-hoc Commands

```bash
# Run command on all nodes
ansible k3s_cluster -a "uptime"

# Run command on control plane only
ansible control_plane -a "k3s kubectl get nodes"

# Run command on workers only
ansible workers -a "free -h"

# Check disk space on all nodes
ansible k3s_cluster -a "df -h /"

# Restart K3S service on a specific node
ansible k3s-03 -m systemd -a "name=k3s state=restarted"
```

## SSH Configuration

Ensure your SSH key is set up:

```bash
# Copy SSH key to all nodes (if not already done)
for ip in 192.168.1.46 192.168.1.198 192.168.1.92 192.168.1.113 192.168.1.171; do
  ssh-copy-id tech@$ip
done
```

## Troubleshooting

### Windows: Ansible won't run

Ansible doesn't run natively on Windows. Use WSL2:

```bash
# Open WSL terminal and run from there
wsl
cd ~/k3s-ansible
ansible all -m ping
```

### Windows: "world writable directory" warning

This happens when running from Windows directories. Copy files to WSL home:

```bash
cp -r /mnt/c/Users/<YOUR_USERNAME>/Documents/k3s/ansible/* ~/k3s-ansible/
cd ~/k3s-ansible
ansible all -m ping
```

### Connection refused

```bash
# Test SSH manually
ssh tech@192.168.1.46

# Verify inventory
ansible-inventory --list
```

### Permission denied

```bash
# Verify SSH key fingerprint matches
ssh-keygen -lf ~/.ssh/id_ed25519_k3s

# Test SSH with verbose output
ansible all -m ping -vvv

# Ensure key has correct permissions
chmod 600 ~/.ssh/id_ed25519_k3s
```

### Python not found

Ensure Python 3 is installed on all nodes:

```bash
ansible all -m raw -a "apt install -y python3"
```
