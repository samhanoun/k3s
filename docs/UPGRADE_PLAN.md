# K3S Cluster Upgrade Plan

## Objective
Upgrade all K3S nodes from v1.26.10+k3s2 to v1.33.6+k3s1

## Current State

| Node | Role | IP | Current Version | Target Version |
|------|------|-----|-----------------|----------------|
| k3s-05 | Master (Primary) | 192.168.1.92 | v1.26.10+k3s2 | v1.33.6+k3s1 |
| k3s-04 | Master | 192.168.1.198 | v1.26.10+k3s2 | v1.33.6+k3s1 |
| k3s-03 | Master | 192.168.1.46 | v1.26.10+k3s2 | v1.33.6+k3s1 |
| k3s-01 | Worker | 192.168.1.113 | v1.26.10+k3s2 | v1.33.6+k3s1 |
| k3s-02 | Worker | 192.168.1.171 | v1.26.10+k3s2 | v1.33.6+k3s1 |
| k3s-06 | Worker | 192.168.1.200 | v1.33.6+k3s1 | ✅ Already done |
| k3s-07 | Worker | 192.168.1.201 | v1.33.6+k3s1 | ✅ Already done |

---

## Pre-Upgrade Checklist

- [ ] **Backup etcd** - Critical! Run backup before upgrading
- [ ] **Check cluster health** - All nodes Ready, no failing pods
- [ ] **Review release notes** - Check for breaking changes between versions
- [ ] **Test workloads** - Ensure applications are stable
- [ ] **Schedule maintenance window** - Notify users if needed
- [ ] **Have rollback plan** - Know how to restore from backup

---

## Upgrade Order (IMPORTANT!)

K3S upgrades must follow this order:

1. **Control Plane nodes first** (one at a time)
   - k3s-05 → k3s-04 → k3s-03
   
2. **Worker nodes second** (can be parallel or sequential)
   - k3s-01, k3s-02

**Never upgrade workers before control plane!**

---

## Step-by-Step Upgrade Procedure

### Phase 0: Pre-Upgrade Backup

```bash
# SSH to k3s-05 and create etcd backup
ssh tech@192.168.1.92 "sudo /opt/k3s-backup/etcd-backup.sh"

# Verify backup was created
ssh tech@192.168.1.92 "ls -la /var/lib/rancher/k3s/server/db/snapshots/"
```

### Phase 1: Upgrade Primary Master (k3s-05)

```bash
# 1. Check current version
ssh tech@192.168.1.92 "k3s --version"

# 2. Upgrade k3s to specific version
ssh tech@192.168.1.92 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.6+k3s1 sh -s - server"

# 3. Wait for node to be Ready (may take 1-2 minutes)
kubectl get nodes -w

# 4. Verify version
ssh tech@192.168.1.92 "k3s --version"
```

### Phase 2: Upgrade Secondary Masters (k3s-04, k3s-03)

```bash
# Upgrade k3s-04
ssh tech@192.168.1.198 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.6+k3s1 sh -s - server"

# Wait and verify
kubectl get nodes
ssh tech@192.168.1.198 "k3s --version"

# Upgrade k3s-03
ssh tech@192.168.1.46 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.6+k3s1 sh -s - server"

# Wait and verify
kubectl get nodes
ssh tech@192.168.1.46 "k3s --version"
```

### Phase 3: Upgrade Workers (k3s-01, k3s-02)

```bash
# Upgrade k3s-01
ssh tech@192.168.1.113 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.6+k3s1 sh -s - agent"

# Upgrade k3s-02
ssh tech@192.168.1.171 "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.6+k3s1 sh -s - agent"

# Verify all nodes
kubectl get nodes
```

---

## Post-Upgrade Verification

```bash
# 1. Check all nodes are Ready with correct version
kubectl get nodes

# 2. Check system pods are running
kubectl get pods -n kube-system

# 3. Check workload pods
kubectl get pods -A

# 4. Test a sample service
curl http://192.168.1.65  # whoami service

# 5. Check Grafana/Prometheus
curl http://192.168.1.64  # Grafana
```

---

## Rollback Procedure (If Something Goes Wrong)

### Option A: Downgrade K3S Version
```bash
# On the problematic node
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.26.10+k3s2 sh -s - server
```

### Option B: Restore from etcd Backup
```bash
# 1. Stop K3S on all nodes
# On servers:
sudo systemctl stop k3s
# On agents:
sudo systemctl stop k3s-agent

# 2. Restore on primary server (k3s-05)
sudo k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-name>

# 3. Start K3S and wait for it to be healthy
sudo systemctl start k3s

# 4. Start other nodes one by one
```

---

## Ansible Automation (Alternative)

You can also use the Ansible upgrade playbook:

```bash
# From WSL2
cd ~/k3s/ansible
ansible-playbook playbooks/upgrade.yaml -e "k3s_version=v1.33.6+k3s1"
```

---

## Timeline Estimate

| Phase | Duration | Nodes |
|-------|----------|-------|
| Pre-backup | 5 min | - |
| Phase 1: Primary master | 5 min | k3s-05 |
| Phase 2: Secondary masters | 10 min | k3s-04, k3s-03 |
| Phase 3: Workers | 5 min | k3s-01, k3s-02 |
| Verification | 5 min | - |
| **Total** | **~30 min** | 5 nodes |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| etcd corruption | Low | Critical | Backup before upgrade |
| API incompatibility | Low | Medium | Test in phases |
| Workload disruption | Medium | Medium | Rolling upgrade, one node at a time |
| Network issues | Low | High | Have console access ready |

---

## Decision

**When do you want to perform this upgrade?**

- [ ] Now (Christmas evening)
- [ ] Tomorrow
- [ ] Later this week
- [ ] Create a reminder/task for later

---

*Created: December 25, 2025*
