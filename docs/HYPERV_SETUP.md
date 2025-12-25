# Adding K3S Worker Nodes via Hyper-V

This guide walks you through creating Ubuntu VMs in Hyper-V and adding them as worker nodes to your existing K3S cluster.

## Overview

| Current Cluster     | New Nodes to Add    |
| ------------------- | ------------------- |
| 3 Masters (Proxmox) | 2 Workers (Hyper-V) |
| 2 Workers (Proxmox) | k3s-06, k3s-07      |

## Prerequisites

1. **Hyper-V enabled** on your Windows machine
2. **Ubuntu 24.04 Server ISO** downloaded
3. **Network access** to your 192.168.1.x subnet
4. **Available IP addresses** for the new VMs

---

## Step 1: Download Ubuntu Server ISO

Download from: https://ubuntu.com/download/server

Save to: `C:\Hyper-V\ISO\ubuntu-24.04-live-server-amd64.iso`

---

## Step 2: Create External Virtual Switch

You need an **External Switch** so VMs can be on the same network as your K3S cluster.

### Open PowerShell as Administrator:

```powershell
# Find your network adapter name
Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, Status, MacAddress

# Create external switch (replace "Ethernet" with your adapter name)
New-VMSwitch -Name "K3S-External" -NetAdapterName "Ethernet" -AllowManagementOS $true
```

**Note:** This may briefly disconnect your network connection.

---

## Step 3: Plan Your IP Addresses

Choose 2 unused IP addresses in your 192.168.1.x range:

| Node   | Planned IP    | Role   |
| ------ | ------------- | ------ |
| k3s-06 | 192.168.1.??? | Worker |
| k3s-07 | 192.168.1.??? | Worker |

**Avoid these IPs (already in use):**

- 192.168.1.46 (k3s-03)
- 192.168.1.92 (k3s-05)
- 192.168.1.113 (k3s-01)
- 192.168.1.171 (k3s-02)
- 192.168.1.198 (k3s-04)
- 192.168.1.50 (VIP)
- 192.168.1.60-80 (MetalLB range)
- 192.168.1.100 (Proxmox)

---

## Step 4: Create VMs

Run the provided script or create manually:

### Option A: Use the Script

```powershell
# Run as Administrator
cd "C:\Users\harry\Documents\Nouveau dossier\k3s\scripts"
.\create-hyperv-vms.ps1
```

### Option B: Create via Hyper-V Manager

1. Open **Hyper-V Manager**
2. Click **New → Virtual Machine**
3. Configure:
   - Name: `k3s-06`
   - Generation: **2**
   - Memory: **4096 MB** (Dynamic)
   - Network: **K3S-External**
   - Create virtual hard disk: **30 GB**
   - Install from ISO: Select Ubuntu ISO
4. Before starting, edit settings:
   - Processors: **4**
   - Security: **Disable Secure Boot**
5. Repeat for `k3s-07`

---

## Step 5: Install Ubuntu

Start each VM and install Ubuntu Server:

### Network Configuration (During Install)

Use **Manual** network configuration:

| Setting    | k3s-06               | k3s-07               |
| ---------- | -------------------- | -------------------- |
| IP Address | 192.168.1.???        | 192.168.1.???        |
| Subnet     | 255.255.255.0        | 255.255.255.0        |
| Gateway    | 192.168.1.1          | 192.168.1.1          |
| DNS        | 192.168.1.1, 8.8.8.8 | 192.168.1.1, 8.8.8.8 |

### User Configuration

| Setting         | Value              |
| --------------- | ------------------ |
| Hostname        | k3s-06 (or k3s-07) |
| Username        | **tech**           |
| Password        | Your choice        |
| Install OpenSSH | **Yes** ✓          |

---

## Step 6: Add Your SSH Key

After Ubuntu is installed and running, add your SSH key:

### From Proxmox Shell:

```bash
# For k3s-06 (replace IP)
ssh tech@192.168.1.??? "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
ssh tech@192.168.1.??? "echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEX4NRJcOM4BvF30qiwkehkoH/vux7rvUIzV65313lqA harry@k3s-cluster' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Repeat for k3s-07
```

### Or from Windows (if password auth works):

```powershell
ssh tech@192.168.1.??? "mkdir -p ~/.ssh && echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEX4NRJcOM4BvF30qiwkehkoH/vux7rvUIzV65313lqA harry@k3s-cluster' >> ~/.ssh/authorized_keys"
```

---

## Step 7: Get K3S Join Token

SSH into your master node and get the token:

```powershell
ssh tech@192.168.1.92 "sudo cat /var/lib/rancher/k3s/server/node-token"
```

Copy the token output.

---

## Step 8: Join Nodes to K3S Cluster

SSH into each new node and run:

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.1.50:6443 K3S_TOKEN=<YOUR_TOKEN> sh -s - --node-label "worker=true" --node-label "longhorn=true"
```

Replace `<YOUR_TOKEN>` with the token from Step 7.

---

## Step 9: Verify Nodes Joined

From your Windows machine:

```powershell
kubectl get nodes
```

You should see k3s-06 and k3s-07 with status **Ready**.

---

## Step 10: Update Ansible Inventory (Optional)

Add the new nodes to `ansible/inventory/hosts.yaml`:

```yaml
workers:
  hosts:
    k3s-01:
      ansible_host: 192.168.1.113
    k3s-02:
      ansible_host: 192.168.1.171
    k3s-06:
      ansible_host: 192.168.1.??? # New node
    k3s-07:
      ansible_host: 192.168.1.??? # New node
```

---

## Troubleshooting

### VM Can't Get IP Address

- Check that the External Switch is connected to the correct network adapter
- Verify your router's DHCP is working (or use static IP)

### Can't SSH to New Node

- Verify OpenSSH was installed during Ubuntu setup
- Check firewall: `sudo ufw status` (should be inactive or allow SSH)

### Node Not Joining Cluster

- Check network connectivity: `ping 192.168.1.50`
- Verify the token is correct
- Check K3S service logs: `sudo journalctl -u k3s-agent -f`

---

## Quick Reference

| Item           | Value                     |
| -------------- | ------------------------- |
| K3S VIP        | 192.168.1.50              |
| K3S API        | https://192.168.1.50:6443 |
| SSH User       | tech                      |
| K3S Version    | v1.26.10+k3s2             |
| Ubuntu Version | 24.04 LTS                 |
