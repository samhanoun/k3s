# K3S High Availability Cluster Setup Guide

A comprehensive guide for beginners to understand and deploy a production-ready Kubernetes cluster using K3S.

## Table of Contents

1. [Introduction](#introduction)
   - [What is Kubernetes](#what-is-kubernetes)
   - [What is K3S](#what-is-k3s)
   - [What is High Availability](#what-is-high-availability-ha)
   - [Why Use Containers](#why-use-containers)
2. [Deep Dive: Kubernetes Components](#deep-dive-kubernetes-components)
   - [Control Plane Components](#control-plane-components)
   - [Node Components](#node-components)
   - [Networking Components](#networking-components)
   - [Add-on Components](#add-on-components)
3. [Architecture Overview](#architecture-overview)
4. [Prerequisites](#prerequisites)
5. [Network Configuration](#network-configuration)
6. [SSH Key Setup](#ssh-key-setup)
7. [Understanding the Script](#understanding-the-script)
8. [Step-by-Step Installation](#step-by-step-installation)
9. [Post-Installation](#post-installation)
10. [Managing Your Cluster](#managing-your-cluster)
11. [Kubernetes Objects Explained](#kubernetes-objects-explained)
12. [Deploying Applications](#deploying-applications)
13. [Networking In Depth](#networking-in-depth)
14. [Storage Concepts](#storage-concepts)
15. [Security Concepts](#security-concepts)
16. [Troubleshooting](#troubleshooting)
17. [Glossary](#glossary)

---

## Introduction

### What is Kubernetes?

Kubernetes (often abbreviated as K8s - the 8 represents the eight letters between 'K' and 's') is a container orchestration platform originally developed by Google and now maintained by the Cloud Native Computing Foundation (CNCF).

**The Problem Kubernetes Solves:**

Before Kubernetes, deploying applications was challenging:

```
Traditional Approach:
- Application runs on a server
- Server fails = Application is down
- Need more capacity? Buy more servers, manually configure them
- Updates require downtime
- Scaling is slow and manual
```

```
With Kubernetes:
- Application runs in containers across multiple servers
- Server fails = Kubernetes automatically moves containers to healthy servers
- Need more capacity? Tell Kubernetes to add more replicas
- Updates happen with zero downtime (rolling updates)
- Scaling is automatic based on demand
```

**Simple Analogy:** Imagine you run a restaurant chain. Instead of personally managing each restaurant (hiring staff, handling equipment failures, managing busy hours), you hire a regional manager (Kubernetes) who:
- Decides which restaurant needs more staff (scheduling pods to nodes)
- Handles equipment failures by moving staff to working equipment (pod restart/rescheduling)
- Ensures all restaurants operate smoothly (health checks)
- Opens new restaurants when demand increases (scaling)

**What Kubernetes Actually Does:**

1. **Container Orchestration**: Manages thousands of containers across many machines
2. **Self-Healing**: Automatically restarts failed containers
3. **Load Balancing**: Distributes traffic across containers
4. **Rolling Updates**: Updates applications without downtime
5. **Secret Management**: Stores sensitive data securely
6. **Configuration Management**: Separates configuration from code
7. **Storage Orchestration**: Automatically mounts storage systems
8. **Batch Execution**: Manages batch and CI workloads

### What is K3S?

K3S is a lightweight, certified Kubernetes distribution created by Rancher Labs (now part of SUSE). The name "K3S" is a play on "K8s" - it is half the size (8/2 = ~3, plus marketing).

**K3S vs Standard Kubernetes (K8s):**

| Aspect | K8s (Standard) | K3S (Lightweight) |
|--------|----------------|-------------------|
| Binary Size | ~1 GB+ | ~60 MB |
| Memory Usage | 2+ GB per node | 512 MB per node |
| Installation | Complex, many components | Single binary |
| Default Database | etcd (separate) | SQLite or embedded etcd |
| Target Environment | Enterprise, Cloud | Edge, IoT, Home Lab, ARM |
| Certification | CNCF Certified | CNCF Certified |

**What K3S Removes/Replaces:**

- Legacy and alpha features removed
- In-tree cloud providers removed (use external)
- In-tree storage drivers removed (use CSI)
- Docker replaced with containerd (lighter)
- etcd replaced with SQLite (for single node) or embedded etcd (for HA)

**What K3S Adds:**

- Flannel for networking (included)
- CoreDNS (included)
- Traefik ingress controller (included, but we disable it)
- Local-path storage provisioner (included)
- Embedded load balancer (included, but we use MetalLB)
- Helm controller

**When to Use K3S:**

- Home lab and learning environments (your case)
- Edge computing and IoT devices
- Development and testing
- CI/CD pipelines
- ARM devices (Raspberry Pi)
- Resource-constrained environments
- Small to medium production workloads

### What is High Availability (HA)?

High Availability is a system design approach that ensures a certain level of operational performance (usually uptime) for a higher-than-normal period.

**Key Concepts:**

**Single Point of Failure (SPOF):**
A component whose failure will cause the entire system to fail.

```
Without HA (SPOF exists):

    [Single Master]  <-- If this dies, cluster is DEAD
          |
    [Workers x 5]    <-- These become orphans, cannot be managed
```

**With HA (No SPOF):**

```
    [Master 1] [Master 2] [Master 3]
         \         |         /
          \        |        /
           [  Virtual IP  ]  <-- Single entry point
                  |
           [Workers x 2]
           
If Master 1 dies:
- Master 2 and Master 3 continue operating
- Virtual IP moves to a healthy master
- Workers continue running and can be managed
- You can replace the failed master at your convenience
```

**Why 3 Masters? The Quorum Concept:**

In distributed systems, nodes must agree on the state of the system. This is done through voting (consensus).

**Quorum** = More than half of the nodes must agree

| Total Nodes | Quorum Needed | Can Survive Failures |
|-------------|---------------|---------------------|
| 1 | 1 | 0 (no HA) |
| 2 | 2 | 0 (both must agree) |
| 3 | 2 | 1 failure |
| 4 | 3 | 1 failure |
| 5 | 3 | 2 failures |
| 7 | 4 | 3 failures |

Notice that 2 nodes is NOT better than 1 for HA - both must be running. That is why we use odd numbers (3, 5, 7).

**Your Setup:**
- 3 masters = can survive 1 failure
- If 2 masters fail, cluster loses quorum and becomes read-only (cannot make changes)

### Why Use Containers?

Before understanding Kubernetes, you need to understand containers.

**The Evolution:**

```
1. Physical Servers (1990s-2000s)
   [Server 1: App A] [Server 2: App B] [Server 3: App C]
   Problems: Expensive, wasteful, slow to provision

2. Virtual Machines (2000s-2010s)
   [Server 1]
     [VM1: App A] [VM2: App B] [VM3: App C]
   Better: Share hardware, isolated
   Problems: Each VM has full OS (heavy), slow to start

3. Containers (2010s-Present)
   [Server 1]
     [Container: App A] [Container: App B] [Container: App C]
   Best: Share OS kernel, lightweight, fast, portable
```

**Containers vs Virtual Machines:**

```
Virtual Machine:                    Container:
+------------------+               +------------------+
|   Application    |               |   Application    |
+------------------+               +------------------+
| Binaries/Libs    |               | Binaries/Libs    |
+------------------+               +------------------+
|   Guest OS       |               | (Shares Host OS) |
|   (Full Linux)   |               +------------------+
+------------------+                        |
|   Hypervisor     |               +------------------+
+------------------+               | Container Runtime|
|   Host OS        |               +------------------+
+------------------+               |   Host OS        |
|   Hardware       |               +------------------+
+------------------+               |   Hardware       |
                                   +------------------+

Size: 1-10 GB                      Size: 10-500 MB
Start time: Minutes                Start time: Seconds
```

**Container Benefits:**

1. **Portability**: "Works on my machine" problem solved - container runs the same everywhere
2. **Isolation**: Containers are isolated from each other
3. **Efficiency**: Share OS kernel, use less resources
4. **Speed**: Start in seconds, not minutes
5. **Consistency**: Dev, test, and production use identical containers
6. **Microservices**: Enable breaking large applications into small, manageable services

---

## Deep Dive: Kubernetes Components

Understanding each component is crucial for troubleshooting and proper cluster management.

### Control Plane Components

The control plane makes global decisions about the cluster (scheduling) and detects/responds to cluster events. These run on master nodes.

#### 1. kube-apiserver

**What it is:** The front door to Kubernetes. All communication goes through here.

**What it does:**
- Exposes the Kubernetes API (REST interface)
- Validates and processes API requests
- The only component that talks directly to etcd
- Handles authentication and authorization

**How it works:**

```
User runs: kubectl get pods
    |
    v
[kubectl] --> HTTPS Request --> [kube-apiserver]
                                      |
                                      v
                                [Authenticate user]
                                      |
                                      v
                                [Authorize action]
                                      |
                                      v
                                [Query etcd]
                                      |
                                      v
                                [Return response]
```

**Example Interaction:**

When you run `kubectl get pods`, this happens:
1. kubectl reads your kubeconfig file
2. kubectl sends HTTPS request to API server
3. API server verifies your certificate/token
4. API server checks if you have permission to list pods
5. API server queries etcd for pod data
6. API server returns JSON response
7. kubectl formats and displays the output

**Port:** 6443 (HTTPS)

#### 2. etcd

**What it is:** A distributed key-value store that holds all cluster data.

**What it stores:**
- All cluster configuration
- Current state of all resources (pods, services, etc.)
- Secrets and ConfigMaps
- Service account details

**Key Characteristics:**
- Distributed: Runs on multiple nodes for redundancy
- Consistent: All nodes see the same data
- Highly Available: Survives node failures (with quorum)
- Append-only: Changes are logged, not overwritten

**How Data is Stored:**

```
etcd stores data as key-value pairs:

Key: /registry/pods/default/nginx-abc123
Value: {
  "metadata": { "name": "nginx-abc123", "namespace": "default" },
  "spec": { "containers": [...] },
  "status": { "phase": "Running" }
}

Key: /registry/services/default/my-service
Value: { ... service definition ... }
```

**Why Quorum Matters:**

```
3-node etcd cluster:

[etcd-1]  [etcd-2]  [etcd-3]
   |         |         |
   +---------+---------+
             |
       [Raft Consensus]

Write operation:
1. Client writes to leader
2. Leader proposes to followers
3. Majority (2/3) must acknowledge
4. Write is committed
5. All nodes apply the change
```

#### 3. kube-scheduler

**What it is:** Decides which node should run a new pod.

**What it considers:**
- Resource requirements (CPU, memory)
- Hardware/software constraints
- Affinity and anti-affinity rules
- Taints and tolerations
- Data locality

**Scheduling Process:**

```
New Pod Created --> [Scheduler Watches for Unscheduled Pods]
                              |
                              v
                    [Filter: Which nodes CAN run this pod?]
                    - Has enough CPU? Memory?
                    - Matches node selector?
                    - Tolerates node taints?
                              |
                              v
                    [Score: Which node is BEST?]
                    - Least loaded
                    - Affinity preferences
                    - Spread across zones
                              |
                              v
                    [Bind: Assign pod to node]
                              |
                              v
                    [Update etcd with node assignment]
```

**Example Scenario:**

You deploy an app that needs:
- 1 CPU
- 2 GB RAM
- SSD storage
- Cannot run with database pod (anti-affinity)

```
Available Nodes:
  Node A: 4 CPU, 8 GB RAM, SSD, has database pod
  Node B: 2 CPU, 4 GB RAM, HDD
  Node C: 4 CPU, 8 GB RAM, SSD, no database pod

Scheduler Decision:
  Node A: Filtered out (anti-affinity with database)
  Node B: Filtered out (no SSD)
  Node C: Selected (meets all requirements)
```

#### 4. kube-controller-manager

**What it is:** Runs controller processes that regulate cluster state.

**Key Controllers:**

| Controller | What it Does |
|------------|--------------|
| Node Controller | Monitors node health, removes unresponsive nodes |
| Replication Controller | Ensures correct number of pod replicas |
| Endpoints Controller | Populates service endpoints |
| Service Account Controller | Creates default accounts and tokens |
| Deployment Controller | Manages deployment rollouts |
| StatefulSet Controller | Manages stateful applications |
| DaemonSet Controller | Ensures pods run on all/selected nodes |
| Job Controller | Manages one-off tasks |
| CronJob Controller | Manages scheduled tasks |

**How Controllers Work (Control Loop):**

```
Desired State: 3 replicas of nginx
                    |
                    v
[Controller] --> [Check Current State] --> Actually running: 2 pods
                    |
                    v
            [Difference Detected]
            Desired: 3, Actual: 2
                    |
                    v
            [Take Action: Create 1 more pod]
                    |
                    v
            [Wait and Repeat]
```

This "reconciliation loop" runs continuously:
1. Read desired state from etcd
2. Observe current state
3. Calculate difference
4. Take action to match desired state
5. Repeat forever

#### 5. cloud-controller-manager

**What it is:** Interfaces with cloud provider APIs (AWS, GCP, Azure).

**What it does:**
- Manages cloud load balancers
- Manages cloud routes
- Manages cloud instances (node lifecycle)

**In your setup:** Not used (bare metal/VM environment). This is why we use MetalLB and Kube-VIP instead.

### Node Components

These run on every node (masters and workers).

#### 1. kubelet

**What it is:** The "node agent" that ensures containers are running.

**What it does:**
- Receives pod specifications from API server
- Ensures containers are running as specified
- Reports node and pod status
- Executes liveness and readiness probes
- Manages container lifecycle

**How it Works:**

```
[API Server] --> Pod assigned to this node
                        |
                        v
[kubelet] --> [Download container image]
                        |
                        v
              [Create and start container]
                        |
                        v
              [Monitor container health]
                        |
                        v
              [Report status back to API server]
```

**Probes:**

kubelet uses probes to check container health:

```yaml
livenessProbe:       # Is the container alive?
  httpGet:           # Check by HTTP request
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
  
# If liveness probe fails: Container is restarted

readinessProbe:      # Is the container ready for traffic?
  httpGet:
    path: /ready
    port: 8080
    
# If readiness probe fails: Container removed from service
```

#### 2. kube-proxy

**What it is:** Network proxy that implements Kubernetes services.

**What it does:**
- Maintains network rules on nodes
- Enables service discovery and load balancing
- Handles iptables/IPVS rules

**How Services Work with kube-proxy:**

```
Pod A wants to reach "my-service" (ClusterIP: 10.96.0.100)
                        |
                        v
[kube-proxy] --> [iptables/IPVS rules]
                        |
                        v
            [Load balance to actual pod IPs]
            - Pod B: 10.244.1.5
            - Pod C: 10.244.2.3
            - Pod D: 10.244.1.8
                        |
                        v
            [Select one (round-robin)]
                        |
                        v
            [Route traffic to Pod C]
```

**Modes:**

| Mode | Description |
|------|-------------|
| iptables (default) | Uses Linux iptables rules |
| IPVS | Uses Linux IPVS for better performance |
| userspace | Legacy, not recommended |

#### 3. Container Runtime

**What it is:** Software that runs containers.

**K3S uses:** containerd (lightweight, Kubernetes-native)

**Container Runtime Options:**

| Runtime | Description |
|---------|-------------|
| containerd | Default for K3S, lightweight |
| CRI-O | Alternative, focused on Kubernetes |
| Docker | Used to be default, now deprecated in K8s |

**Relationship:**

```
[kubelet] --> [Container Runtime Interface (CRI)]
                        |
                        v
              [containerd / CRI-O]
                        |
                        v
              [runc - actually runs container]
                        |
                        v
              [Linux namespaces and cgroups]
```

### Networking Components

#### 1. CNI (Container Network Interface) - Flannel

**What it is:** Provides pod-to-pod networking across nodes.

**The Problem:**
```
Node 1: Pod A (10.244.1.5)     Node 2: Pod B (10.244.2.3)
        |                               |
How can Pod A reach Pod B if they are on different hosts?
```

**Flannel Solution:**

```
Node 1                           Node 2
[Pod A: 10.244.1.5]             [Pod B: 10.244.2.3]
        |                               |
[flannel.1 interface]           [flannel.1 interface]
        |                               |
[VXLAN encapsulation]           [VXLAN decapsulation]
        |                               |
[eth0: 192.168.1.92] --------> [eth0: 192.168.1.198]
        |                               |
        +-------[Physical Network]------+
```

**Pod CIDR:**
- Each node gets a subnet (e.g., Node1: 10.244.1.0/24, Node2: 10.244.2.0/24)
- Pods on that node get IPs from that subnet
- Flannel routes between subnets

#### 2. CoreDNS

**What it is:** DNS server for the cluster.

**What it provides:**
- Service discovery by name
- Pod DNS records
- External DNS forwarding

**How it works:**

```
Pod wants to reach "my-service" in "default" namespace:
                        |
                        v
[Pod DNS query] --> "my-service.default.svc.cluster.local"
                        |
                        v
[CoreDNS] --> [Look up Service IP]
                        |
                        v
[Return] --> 10.96.0.100 (ClusterIP)
```

**DNS Names:**

| Type | Format | Example |
|------|--------|---------|
| Service | svc-name.namespace.svc.cluster.local | nginx.default.svc.cluster.local |
| Pod | pod-ip.namespace.pod.cluster.local | 10-244-1-5.default.pod.cluster.local |

#### 3. Kube-VIP

**What it is:** Provides a virtual IP for control plane high availability.

**The Problem:**

```
Without Kube-VIP:
- Master 1: 192.168.1.92:6443
- Master 2: 192.168.1.198:6443
- Master 3: 192.168.1.46:6443

Which one should clients connect to? What if it fails?
```

**The Solution:**

```
With Kube-VIP:
- Virtual IP: 192.168.1.50:6443 (clients connect here)
- VIP is hosted by the leader master
- If leader fails, VIP moves to another master

[Client] --> [192.168.1.50:6443] --> [Current Leader Master]
                                            |
                                     [Leader Election]
                                            |
                              [Master 1 / Master 2 / Master 3]
```

**How Kube-VIP Works:**

1. Uses leader election to choose one master
2. Leader advertises the VIP using ARP (Layer 2)
3. All traffic to VIP goes to leader
4. If leader fails, new leader is elected
5. New leader advertises VIP
6. Traffic seamlessly switches

#### 4. MetalLB

**What it is:** Load balancer implementation for bare metal Kubernetes.

**The Problem:**

In cloud providers (AWS, GCP):
```yaml
apiVersion: v1
kind: Service
spec:
  type: LoadBalancer  # Cloud provider creates load balancer
```

On bare metal:
```
No cloud provider = No automatic load balancer
Service stays in "Pending" state forever
```

**MetalLB Solution:**

```
MetalLB watches for LoadBalancer services:

1. [New LoadBalancer Service Created]
              |
              v
2. [MetalLB Controller] assigns IP from pool (192.168.1.60-80)
              |
              v
3. [MetalLB Speaker] advertises IP via ARP (Layer 2)
              |
              v
4. [External Traffic] --> [Assigned IP] --> [Service] --> [Pods]
```

**Modes:**

| Mode | How it Works | Use Case |
|------|--------------|----------|
| Layer 2 (your setup) | ARP advertisement | Simple, single node handles traffic |
| BGP | BGP routing protocol | Production, multi-router |

### Add-on Components

#### 1. Metrics Server

**What it is:** Collects resource usage metrics from nodes and pods.

**Used by:**
- `kubectl top nodes` / `kubectl top pods`
- Horizontal Pod Autoscaler
- Vertical Pod Autoscaler

#### 2. Dashboard

**What it is:** Web UI for managing cluster.

**Provides:**
- Visual representation of resources
- Create/edit/delete resources
- View logs
- Monitor resource usage

---

## Architecture Overview

### Your Cluster Layout

```
                    +-------------------+
                    |   Virtual IP      |
                    |   192.168.1.50    |
                    +-------------------+
                            |
            +---------------+---------------+
            |               |               |
    +-------+-------+ +-----+-----+ +-------+-------+
    |   Master 1    | |  Master 2 | |   Master 3    |
    | 192.168.1.92  | |192.168.1.198| | 192.168.1.46 |
    | (k3s-05)      | | (k3s-04)  | | (k3s-03)      |
    +---------------+ +-----------+ +---------------+
            |               |               |
            +---------------+---------------+
                            |
                +-----------+-----------+
                |                       |
        +-------+-------+       +-------+-------+
        |   Worker 1    |       |   Worker 2    |
        | 192.168.1.171 |       | 192.168.1.113 |
        | (k3s-02)      |       | (k3s-01)      |
        +---------------+       +---------------+
```

### Component Explanation

| Component | Purpose | Your Value |
|-----------|---------|------------|
| Master Nodes | Run the control plane (API server, scheduler, etcd database) | 3 nodes |
| Worker Nodes | Run your applications (pods) | 2 nodes |
| Virtual IP (VIP) | Single entry point for the cluster, moves between masters | 192.168.1.50 |
| etcd | Distributed database storing cluster state | Built into K3S masters |
| Kube-VIP | Provides the Virtual IP failover mechanism | Running on masters |
| MetalLB | Provides external IPs for LoadBalancer services | 192.168.1.60-80 range |

### What Runs Where

**On Master Nodes:**
- K3S server (control plane)
- etcd (database)
- Kube-VIP (for VIP failover)
- CoreDNS (cluster DNS)
- Metrics Server

**On Worker Nodes:**
- K3S agent
- Your applications (Nginx, Portainer, etc.)
- MetalLB speakers

---

## Prerequisites

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU per node | 1 core | 2 cores |
| RAM per node | 1 GB | 2-4 GB |
| Disk per node | 10 GB | 20+ GB |
| Network | 100 Mbps | 1 Gbps |

### Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| Ubuntu | 24.04 LTS | Operating system on VMs |
| Proxmox | Any recent | Hypervisor for VMs |
| WSL or Git Bash | Latest | Run bash scripts on Windows |

### Network Requirements

- All nodes must be on the same network subnet
- All nodes must be able to communicate with each other
- Firewall must allow traffic between nodes
- You need available IP addresses for:
  - 5 VM nodes
  - 1 Virtual IP
  - LoadBalancer range (approximately 20 IPs)

---

## Network Configuration

### IP Address Planning

Before installation, plan your IP addresses:

```
Network: 192.168.1.0/24

Reserved for VMs:
  - 192.168.1.92   : Master 1 (k3s-05)
  - 192.168.1.198  : Master 2 (k3s-04)
  - 192.168.1.46   : Master 3 (k3s-03)
  - 192.168.1.171  : Worker 1 (k3s-02)
  - 192.168.1.113  : Worker 2 (k3s-01)

Reserved for Kubernetes:
  - 192.168.1.50   : Virtual IP (Kube-VIP)
  - 192.168.1.60-80: LoadBalancer range (MetalLB)

Make sure these IPs are NOT in your DHCP range!
```

### Why Static IPs?

Kubernetes needs stable IP addresses. If a node's IP changes, it cannot rejoin the cluster properly. Always use static IPs or DHCP reservations.

### Verifying Network Connectivity

Before running the script, verify all nodes can communicate:

```bash
# From your laptop, ping each node
ping 192.168.1.92
ping 192.168.1.198
ping 192.168.1.46
ping 192.168.1.171
ping 192.168.1.113

# Each should respond with replies
```

---

## SSH Key Setup

### What are SSH Keys?

SSH keys are a pair of cryptographic keys used for secure authentication:
- **Private Key** (id_ed25519): Stays on your laptop. Never share this.
- **Public Key** (id_ed25519.pub): Goes on the servers you want to access.

Think of it like a house key:
- Private key = Your physical key
- Public key = The lock on the door

### Generating SSH Keys

On your Windows laptop, open PowerShell or Git Bash:

```bash
# Generate a new SSH key pair
ssh-keygen -t ed25519 -C "your-email@example.com"

# When prompted for location, press Enter for default (~/.ssh/id_ed25519)
# When prompted for passphrase, you can leave empty or set one
```

This creates two files:
```
C:\Users\YourUsername\.ssh\id_ed25519      (private key)
C:\Users\YourUsername\.ssh\id_ed25519.pub  (public key)
```

### Deploying Public Key to VMs

The public key must be on each VM. There are several methods:

**Method 1: Cloud-Init (Done during VM creation in Proxmox)**

When creating the VM template, add your public key to cloud-init configuration. This automatically places the key in ~/.ssh/authorized_keys for the specified user.

**Method 2: Manual Copy (After VM creation)**

```bash
# Copy public key to each VM
ssh-copy-id -i ~/.ssh/id_ed25519.pub tech@192.168.1.92
ssh-copy-id -i ~/.ssh/id_ed25519.pub tech@192.168.1.198
ssh-copy-id -i ~/.ssh/id_ed25519.pub tech@192.168.1.46
ssh-copy-id -i ~/.ssh/id_ed25519.pub tech@192.168.1.171
ssh-copy-id -i ~/.ssh/id_ed25519.pub tech@192.168.1.113
```

### Testing SSH Connection

```bash
# Test connection to each node (should not ask for password)
ssh -i ~/.ssh/id_ed25519 tech@192.168.1.92

# If successful, you will see the Ubuntu welcome message
# Type 'exit' to disconnect
```

---

## Understanding the Script

### Script Overview (k3s.sh)

The script automates the entire K3S cluster installation. Here is a breakdown of each section:

### Section 1: Configuration Variables

```bash
# Version of Kube-VIP to deploy
KVVERSION="v0.6.3"

# K3S Version
k3sVersion="v1.26.10+k3s2"
```

**Explanation:** These variables define which versions of software to install. Using specific versions ensures reproducibility.

```bash
# Set the IP addresses of the master and work nodes
master1=192.168.1.92
master2=192.168.1.198
master3=192.168.1.46
worker1=192.168.1.171
worker2=192.168.1.113
```

**Explanation:** IP addresses of your VMs. Change these to match your network.

```bash
# User of remote machines
user=tech
```

**Explanation:** The username on your VMs. The script uses this for SSH connections.

```bash
# Interface used on remotes
interface=eth0
```

**Explanation:** The network interface name on your VMs. Check with `ip a` command on a VM.

```bash
# Set the virtual IP address (VIP)
vip=192.168.1.50
```

**Explanation:** This IP will float between master nodes. Use an unused IP in your network.

```bash
# Loadbalancer IP range
lbrange=192.168.1.60-192.168.1.80
```

**Explanation:** MetalLB will assign IPs from this range to LoadBalancer services.

```bash
# SSH certificate name variable
certName=id_ed25519
```

**Explanation:** The name of your SSH private key file.

### Section 2: Prerequisites Installation

```bash
# Install k3sup to local machine if not already present
if ! command -v k3sup version &> /dev/null
then
    echo -e " \033[31;5mk3sup not found, installing\033[0m"
    curl -sLS https://get.k3sup.dev | sh
    sudo install k3sup /usr/local/bin/
fi
```

**Explanation:** 
- `command -v k3sup` checks if k3sup is installed
- `&> /dev/null` hides output
- If not found, downloads and installs k3sup

**What is k3sup?**
k3sup (pronounced "ketchup") is a tool that simplifies K3S installation over SSH. Instead of manually running commands on each node, k3sup handles everything remotely.

### Section 3: SSH Configuration

```bash
# Check for SSH config file, create if needed
if [ ! -f "$config_file" ]; then
  echo "StrictHostKeyChecking no" > "$config_file"
  chmod 600 "$config_file"
fi
```

**Explanation:**
- Creates SSH config file if it does not exist
- `StrictHostKeyChecking no` prevents SSH from asking to verify host fingerprints
- `chmod 600` sets permissions so only you can read/write the file

**Security Note:** This setting is convenient for automation but not recommended for production. It prevents the "Are you sure you want to continue connecting?" prompt.

### Section 4: PolicyCoreUtils Installation

```bash
for newnode in "${all[@]}"; do
  ssh $user@$newnode -i ~/.ssh/$certName sudo su <<EOF
  NEEDRESTART_MODE=a apt-get install policycoreutils -y
  exit
EOF
done
```

**Explanation:**
- Loops through all nodes
- Installs policycoreutils package (required for SELinux)
- `NEEDRESTART_MODE=a` prevents interactive prompts

### Section 5: Bootstrap First Master Node

```bash
k3sup install \
  --ip $master1 \
  --user $user \
  --tls-san $vip \
  --cluster \
  --k3s-version $k3sVersion \
  --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$master1 --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
  --merge \
  --sudo \
  --local-path $HOME/.kube/config \
  --ssh-key $HOME/.ssh/$certName \
  --context k3s-ha
```

**Explanation of each flag:**

| Flag | Purpose |
|------|---------|
| `--ip $master1` | Target node IP address |
| `--user $user` | SSH username |
| `--tls-san $vip` | Add VIP to TLS certificate (allows connecting via VIP) |
| `--cluster` | Initialize as HA cluster with etcd |
| `--k3s-version` | Specific K3S version to install |
| `--disable traefik` | Do not install default ingress controller |
| `--disable servicelb` | Do not install default load balancer (we use MetalLB) |
| `--flannel-iface=$interface` | Network interface for pod networking |
| `--node-ip=$master1` | Explicitly set node IP |
| `--node-taint` | Prevent workloads from running on master |
| `--merge` | Merge config into existing kubeconfig |
| `--sudo` | Use sudo for installation |
| `--local-path` | Where to save kubeconfig |
| `--ssh-key` | Path to SSH private key |
| `--context` | Name for this cluster context |

### Section 6: Kube-VIP Installation

```bash
kubectl apply -f https://kube-vip.io/manifests/rbac.yaml
```

**Explanation:** Creates RBAC (Role-Based Access Control) permissions for Kube-VIP to interact with the Kubernetes API.

```bash
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/kube-vip
cat kube-vip | sed 's/$interface/'$interface'/g; s/$vip/'$vip'/g' > $HOME/kube-vip.yaml
```

**Explanation:**
- Downloads Kube-VIP manifest template
- Uses `sed` to replace variables with actual values
- Creates customized kube-vip.yaml file

### Section 7: Join Additional Masters

```bash
for newnode in "${masters[@]}"; do
  k3sup join \
    --ip $newnode \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server \
    --server-ip $master1 \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--disable traefik --disable servicelb --flannel-iface=$interface --node-ip=$newnode --node-taint node-role.kubernetes.io/master=true:NoSchedule" \
    --server-user $user
done
```

**Explanation:**
- Loops through remaining master nodes (master2, master3)
- `--server` flag indicates this is a server (master) node
- `--server-ip $master1` tells it to join the existing cluster via master1

### Section 8: Join Workers

```bash
for newagent in "${workers[@]}"; do
  k3sup join \
    --ip $newagent \
    --user $user \
    --sudo \
    --k3s-version $k3sVersion \
    --server-ip $master1 \
    --ssh-key $HOME/.ssh/$certName \
    --k3s-extra-args "--node-label \"longhorn=true\" --node-label \"worker=true\""
done
```

**Explanation:**
- Loops through worker nodes
- No `--server` flag means this is an agent (worker) node
- `--node-label` adds labels for identifying worker nodes

### Section 9: MetalLB Installation

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml
```

**Explanation:** Installs MetalLB components (controller and speakers).

**What is MetalLB?**
In cloud environments (AWS, GCP), LoadBalancer services automatically get external IPs. On bare metal or VMs, there is no such mechanism. MetalLB fills this gap by assigning IPs from a configured pool.

```bash
curl -sO https://raw.githubusercontent.com/JamesTurland/JimsGarage/main/Kubernetes/K3S-Deploy/ipAddressPool
cat ipAddressPool | sed 's/$lbrange/'$lbrange'/g' > $HOME/ipAddressPool.yaml
kubectl apply -f $HOME/ipAddressPool.yaml
```

**Explanation:** Creates IP address pool configuration for MetalLB with your specified range.

### Section 10: Test Deployment

```bash
kubectl apply -f https://raw.githubusercontent.com/inlets/inlets-operator/master/contrib/nginx-sample-deployment.yaml -n default
kubectl expose deployment nginx-1 --port=80 --type=LoadBalancer -n default
```

**Explanation:**
- Deploys a simple Nginx container
- Exposes it as a LoadBalancer service
- MetalLB assigns an external IP (192.168.1.60)

---

## Step-by-Step Installation

### Step 1: Prepare Your VMs in Proxmox

1. Create 5 Ubuntu 24.04 VMs
2. Configure each with:
   - 2 CPU cores
   - 2-4 GB RAM
   - 20 GB disk
   - Static IP or cloud-init with your SSH public key

### Step 2: Verify VM Accessibility

From your Windows laptop (PowerShell):

```powershell
# Test SSH to each node
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92
# Type 'exit' after successful connection

# Repeat for all nodes
```

### Step 3: Expand Disk (If Needed)

If your VMs have small disks, expand them:

```bash
# On each VM
sudo apt update
sudo apt install cloud-guest-utils -y
sudo growpart /dev/sda 1
sudo resize2fs /dev/sda1
df -h  # Verify new size
```

### Step 4: Copy Script to Master 1

```powershell
# From Windows PowerShell
scp -i $env:USERPROFILE\.ssh\id_ed25519 "C:\Users\harry\Documents\k3s\k3s.sh" tech@192.168.1.92:~/k3s.sh
```

### Step 5: Copy SSH Keys to Master 1

```powershell
scp -i $env:USERPROFILE\.ssh\id_ed25519 $env:USERPROFILE\.ssh\id_ed25519 $env:USERPROFILE\.ssh\id_ed25519.pub tech@192.168.1.92:~/.ssh/
```

### Step 6: Run the Script

```powershell
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "chmod 600 ~/.ssh/id_ed25519 && chmod +x ~/k3s.sh && ~/k3s.sh"
```

The script takes approximately 5-10 minutes to complete.

### Step 7: Copy Kubeconfig to Windows

```powershell
New-Item -ItemType Directory -Path "$env:USERPROFILE\.kube" -Force
scp -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92:~/.kube/config $env:USERPROFILE\.kube\config
```

### Step 8: Verify Installation

```powershell
kubectl get nodes
```

Expected output:
```
NAME     STATUS   ROLES                       AGE   VERSION
k3s-01   Ready    <none>                      5m    v1.26.10+k3s2
k3s-02   Ready    <none>                      5m    v1.26.10+k3s2
k3s-03   Ready    control-plane,etcd,master   5m    v1.26.10+k3s2
k3s-04   Ready    control-plane,etcd,master   5m    v1.26.10+k3s2
k3s-05   Ready    control-plane,etcd,master   5m    v1.26.10+k3s2
```

---

## Post-Installation

### Accessing Services

After installation, you have these services running:

| Service | URL | Notes |
|---------|-----|-------|
| Nginx (test) | http://192.168.1.60 | Simple test deployment |
| Portainer | https://192.168.1.61:9443 | Kubernetes management UI |
| Kubernetes Dashboard | https://192.168.1.62 | Official K8s dashboard |

### First Login to Portainer

1. Open https://192.168.1.61:9443 in your browser
2. Accept the self-signed certificate warning
3. Create an admin password (minimum 12 characters)
4. Select "Get Started"
5. Click on "local" environment
6. You can now manage your cluster visually

### Getting Dashboard Token

The Kubernetes Dashboard requires a token for login. There are two methods:

**Method 1: Permanent Token (Recommended)**

A permanent token secret has been created. To retrieve it:

```bash
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d"
```

This token does not expire and is stored as a Kubernetes secret.

**Method 2: Temporary Token**

Generate a temporary token (expires in 1 hour by default):

```bash
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl -n kubernetes-dashboard create token admin-user"
```

Or generate a token valid for 24 hours:

```bash
ssh -i $env:USERPROFILE\.ssh\id_ed25519 tech@192.168.1.92 "kubectl -n kubernetes-dashboard create token admin-user --duration=24h"
```

**Using the Token:**

1. Go to https://192.168.1.62
2. Accept the self-signed certificate warning
3. Select "Token" option
4. Paste the token
5. Click "Sign in"

**Troubleshooting "Unauthorized (401)" Error:**

If you get "Unauthorized (401): Invalid credentials provided", use the permanent token from Method 1. The temporary tokens from Method 2 may not work correctly with some Dashboard versions.

---

## Managing Your Cluster

### Essential kubectl Commands

**Viewing Resources:**

```bash
# List all nodes
kubectl get nodes

# List all pods in all namespaces
kubectl get pods -A

# List all services
kubectl get svc -A

# List all deployments
kubectl get deployments -A

# Get detailed information about a node
kubectl describe node k3s-01

# Get detailed information about a pod
kubectl describe pod nginx-1-xxxxx -n default
```

**Working with Pods:**

```bash
# View pod logs
kubectl logs nginx-1-xxxxx -n default

# Follow logs in real-time
kubectl logs -f nginx-1-xxxxx -n default

# Execute command in pod
kubectl exec -it nginx-1-xxxxx -n default -- /bin/bash

# Delete a pod (it will be recreated by deployment)
kubectl delete pod nginx-1-xxxxx -n default
```

**Working with Deployments:**

```bash
# Scale a deployment
kubectl scale deployment nginx-1 --replicas=3 -n default

# View rollout status
kubectl rollout status deployment nginx-1 -n default

# Rollback a deployment
kubectl rollout undo deployment nginx-1 -n default
```

**Working with Namespaces:**

```bash
# List namespaces
kubectl get namespaces

# Create namespace
kubectl create namespace my-app

# Delete namespace (and all resources in it)
kubectl delete namespace my-app
```

---

## Understanding Namespaces

Namespaces are virtual clusters within your physical cluster. They help organize and isolate resources.

**Why Use Namespaces:**

1. **Organization**: Group related resources together
2. **Isolation**: Separate environments (dev, staging, prod)
3. **Resource Quotas**: Limit resources per namespace
4. **Access Control**: Different permissions per namespace

**Default Namespaces:**

| Namespace | Purpose | What Runs There |
|-----------|---------|-----------------|
| default | Default for user resources | Your applications if you do not specify a namespace |
| kube-system | Kubernetes system components | CoreDNS, kube-proxy, metrics-server, Flannel |
| kube-public | Publicly readable resources | Cluster info (rarely used) |
| kube-node-lease | Node heartbeat leases | Node health tracking |
| metallb-system | MetalLB components | MetalLB controller and speakers |
| portainer | Portainer components | Portainer server |
| kubernetes-dashboard | Dashboard components | Dashboard web UI |

**Namespace Scope:**

Some resources are namespaced, others are cluster-wide:

| Namespaced Resources | Cluster-Wide Resources |
|---------------------|------------------------|
| Pods | Nodes |
| Services | Namespaces |
| Deployments | PersistentVolumes |
| ConfigMaps | ClusterRoles |
| Secrets | StorageClasses |
| ServiceAccounts | IngressClasses |

**Example: Creating and Using Namespace:**

```bash
# Create namespace
kubectl create namespace my-app

# List namespaces
kubectl get namespaces

# Create deployment in specific namespace
kubectl create deployment my-web --image=nginx -n my-app

# List pods only in my-app namespace
kubectl get pods -n my-app

# List pods in ALL namespaces
kubectl get pods -A

# Set default namespace for kubectl
kubectl config set-context --current --namespace=my-app
```

## Deploying Applications

### How Kubernetes Runs Applications

Understanding the relationship between Kubernetes objects:

```
[You] --> create --> [Deployment]
                          |
                          | manages
                          v
                     [ReplicaSet]
                          |
                          | creates
                          v
        [Pod 1] [Pod 2] [Pod 3]    (replicas: 3)
           |       |       |
           | contains (1 or more)
           v       v       v
      [Container] [Container] [Container]
```

**Why This Hierarchy?**

- **Deployment**: Declarative updates, rolling updates, rollback
- **ReplicaSet**: Ensures N pods are running
- **Pod**: Runs containers, shares network/storage
- **Container**: Actual application

### Example 1: Deploy a Simple Web Application

Create a file called `my-app.yaml`:

```yaml
# This is a Deployment - it manages ReplicaSets which manage Pods
apiVersion: apps/v1           # API version - apps/v1 is for Deployments
kind: Deployment              # Resource type
metadata:
  name: my-web-app            # Name of this Deployment
  namespace: default          # Namespace to create in (optional, default is 'default')
  labels:                     # Labels for this Deployment (for organization)
    app: my-web-app
    environment: production
spec:                         # Specification - what we want
  replicas: 2                 # Run 2 copies of the pod
  
  selector:                   # How the Deployment finds its Pods
    matchLabels:              # Pods with these labels belong to this Deployment
      app: my-web-app
      
  template:                   # Template for creating Pods
    metadata:
      labels:                 # Labels for the Pods (MUST match selector)
        app: my-web-app
    spec:                     # Pod specification
      containers:             # List of containers in the Pod
      - name: nginx           # Container name
        image: nginx:1.21     # Docker image (from Docker Hub)
        ports:
        - containerPort: 80   # Port the container listens on
        
        resources:            # Resource requests and limits
          requests:           # Minimum resources needed
            memory: "64Mi"    # 64 megabytes of RAM
            cpu: "100m"       # 100 millicores (0.1 CPU)
          limits:             # Maximum resources allowed
            memory: "128Mi"
            cpu: "200m"
            
        livenessProbe:        # Check if container is alive
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5   # Wait 5s before first check
          periodSeconds: 10        # Check every 10s
          
        readinessProbe:       # Check if container is ready for traffic
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

---
# This is a Service - it exposes Pods to network traffic
apiVersion: v1
kind: Service
metadata:
  name: my-web-app-service
  namespace: default
spec:
  type: LoadBalancer          # Type: ClusterIP, NodePort, or LoadBalancer
  
  selector:                   # Which Pods to send traffic to
    app: my-web-app           # Pods with this label
    
  ports:
  - name: http
    port: 80                  # Port the Service listens on
    targetPort: 80            # Port on the Pod to forward to
    protocol: TCP
```

**Understanding Each Field:**

| Field | Purpose | Example Value |
|-------|---------|---------------|
| apiVersion | API group and version | apps/v1, v1, networking.k8s.io/v1 |
| kind | Type of resource | Deployment, Service, Pod |
| metadata.name | Resource identifier | my-web-app |
| metadata.labels | Key-value pairs for organization | app: my-web-app |
| spec.replicas | Number of pod copies | 2 |
| spec.selector | How to find related resources | matchLabels: app: my-web-app |
| spec.template | Template for creating pods | Contains pod spec |
| containers[].image | Docker image to run | nginx:1.21 |
| containers[].ports | Ports the container uses | containerPort: 80 |
| resources.requests | Minimum guaranteed resources | cpu: 100m, memory: 64Mi |
| resources.limits | Maximum allowed resources | cpu: 200m, memory: 128Mi |

**Apply and Monitor:**

```bash
# Apply the configuration
kubectl apply -f my-app.yaml

# Watch pods being created
kubectl get pods -w

# Check the deployment status
kubectl get deployment my-web-app

# Check the service and get external IP
kubectl get svc my-web-app-service

# View detailed information
kubectl describe deployment my-web-app
kubectl describe service my-web-app-service

# View pod logs
kubectl logs -l app=my-web-app

# Access the application (use the EXTERNAL-IP from service)
curl http://<EXTERNAL-IP>
```

### Example 2: Deploy Application with ConfigMap and Secret

Real applications need configuration. Here is a more complete example:

```yaml
# ConfigMap - stores non-sensitive configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # Simple key-value pairs
  APP_ENV: "production"
  LOG_LEVEL: "info"
  
  # File-like content
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;
        location / {
            root /usr/share/nginx/html;
        }
    }

---
# Secret - stores sensitive data (base64 encoded)
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  # Values are base64 encoded
  # echo -n "mypassword" | base64 = bXlwYXNzd29yZA==
  DB_PASSWORD: bXlwYXNzd29yZA==
  API_KEY: c2VjcmV0YXBpa2V5MTIz

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: configured-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: configured-app
  template:
    metadata:
      labels:
        app: configured-app
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
        
        # Environment variables from ConfigMap
        env:
        - name: APP_ENVIRONMENT        # Variable name in container
          valueFrom:
            configMapKeyRef:
              name: app-config         # ConfigMap name
              key: APP_ENV             # Key in ConfigMap
              
        - name: DATABASE_PASSWORD      # Variable name in container
          valueFrom:
            secretKeyRef:
              name: app-secrets        # Secret name
              key: DB_PASSWORD         # Key in Secret
              
        # Mount all ConfigMap keys as environment variables
        envFrom:
        - configMapRef:
            name: app-config
            
        # Mount ConfigMap as file
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d
          
      volumes:
      - name: config-volume
        configMap:
          name: app-config
          items:
          - key: nginx.conf
            path: default.conf
```

### Example 3: StatefulSet for Databases

For applications that need stable identity and storage:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres          # Headless service name
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
          
  volumeClaimTemplates:          # Creates PVC for each pod
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 10Gi
```

**StatefulSet vs Deployment:**

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| Pod Names | Random (nginx-abc123) | Ordered (postgres-0, postgres-1) |
| Startup | All at once | One at a time, in order |
| Storage | Shared or none | Unique persistent volume per pod |
| DNS | Via Service | Stable DNS per pod (postgres-0.postgres) |
| Use Case | Stateless apps | Databases, clustered apps |

---

## Kubernetes Objects Explained

### The Object Model

Every Kubernetes object has this structure:

```yaml
apiVersion: <group/version>   # Which API to use
kind: <ResourceType>          # What type of resource
metadata:                     # Information about the object
  name: <name>                # Required: unique identifier
  namespace: <namespace>      # Optional: which namespace
  labels: {}                  # Optional: key-value tags
  annotations: {}             # Optional: non-identifying metadata
spec:                         # Desired state (what you want)
  ...
status:                       # Current state (managed by Kubernetes)
  ...
```

### Core Resources

#### Pods

The smallest deployable unit. Contains one or more containers.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx
    ports:
    - containerPort: 80
  - name: sidecar              # Multiple containers in one pod
    image: busybox
    command: ["sh", "-c", "while true; do echo hello; sleep 10; done"]
```

**When to use multiple containers in a pod:**
- Sidecar pattern: Logging agent, proxy
- Adapter pattern: Transform data format
- Ambassador pattern: Proxy to external service

**Pod Lifecycle:**

```
Pending --> Running --> Succeeded/Failed
   |           |
   |           v
   |       Terminating
   |
   v
Failed (scheduling error)
```

#### Services

Provide stable network endpoint for pods.

**Service Types:**

```
ClusterIP (default):
  - Internal IP only
  - Accessible only within cluster
  
     [Client Pod] --> [ClusterIP: 10.96.0.100] --> [Backend Pods]
                      (internal only)


NodePort:
  - Exposes on each node's IP at a static port
  - Accessible from outside cluster
  
     [External] --> [NodeIP:30080] --> [ClusterIP] --> [Backend Pods]
                    (any node)


LoadBalancer:
  - Creates external load balancer (cloud or MetalLB)
  - Accessible from outside with dedicated IP
  
     [External] --> [192.168.1.60:80] --> [NodePort] --> [ClusterIP] --> [Backend Pods]
                    (MetalLB IP)


ExternalName:
  - Maps to external DNS name
  - No proxying, just DNS alias
  
     [Pod] --> [my-service] --> CNAME --> [database.example.com]
```

**Example of each type:**

```yaml
# ClusterIP - internal only
apiVersion: v1
kind: Service
metadata:
  name: internal-service
spec:
  type: ClusterIP              # Optional, this is default
  selector:
    app: backend
  ports:
  - port: 80

---
# NodePort - external via node ports
apiVersion: v1
kind: Service
metadata:
  name: nodeport-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080            # Optional, auto-assigned if not specified (30000-32767)

---
# LoadBalancer - external with dedicated IP (your setup uses this)
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80

---
# ExternalName - DNS alias
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

#### Deployments

Manage ReplicaSets and provide declarative updates.

**Update Strategies:**

```yaml
spec:
  strategy:
    type: RollingUpdate        # or Recreate
    rollingUpdate:
      maxSurge: 1              # Max pods above desired during update
      maxUnavailable: 0        # Max unavailable during update
```

**RollingUpdate Example:**

```
Desired: 3 replicas
Update: v1 --> v2

Step 1: [v1] [v1] [v1]           (start with 3 v1)
Step 2: [v1] [v1] [v1] [v2]      (add 1 v2, maxSurge=1)
Step 3: [v1] [v1] [v2]           (remove 1 v1)
Step 4: [v1] [v1] [v2] [v2]      (add 1 v2)
Step 5: [v1] [v2] [v2]           (remove 1 v1)
Step 6: [v1] [v2] [v2] [v2]      (add 1 v2)
Step 7: [v2] [v2] [v2]           (remove last v1, done!)
```

**Recreate Example:**

```
Step 1: [v1] [v1] [v1]           (3 v1 running)
Step 2: [-]  [-]  [-]            (all v1 terminated - DOWNTIME)
Step 3: [v2] [v2] [v2]           (3 v2 started)
```

#### ConfigMaps and Secrets

Store configuration separately from container images.

**ConfigMap - Non-sensitive data:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: game-config
data:
  # Property-like keys
  player_initial_lives: "3"
  ui_properties_file_name: "user-interface.properties"
  
  # File-like keys
  game.properties: |
    enemy.types=aliens,monsters
    player.maximum-lives=5
```

**Secret - Sensitive data:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  # Base64 encoded (NOT encrypted!)
  username: YWRtaW4=           # "admin" in base64
  password: c2VjcmV0MTIz       # "secret123" in base64
```

**Important:** Secrets are only base64 encoded, NOT encrypted. For real security:
- Enable encryption at rest in etcd
- Use external secret management (Vault, AWS Secrets Manager)
- Apply RBAC to limit secret access

**Using ConfigMaps and Secrets:**

```yaml
# Method 1: As environment variables
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: db-config
      key: host
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password

# Method 2: Mount as files
volumeMounts:
- name: config-vol
  mountPath: /etc/config
volumes:
- name: config-vol
  configMap:
    name: app-config
```

---

## Networking In Depth

### The Kubernetes Networking Model

Kubernetes networking has these fundamental rules:

1. **Pod-to-Pod**: Every pod can communicate with every other pod without NAT
2. **Node-to-Pod**: Every node can communicate with every pod without NAT
3. **Pod Identity**: The IP a pod sees for itself is the same IP others see

### Network Types in Your Cluster

```
                    Internet
                        |
                        v
            +-------------------+
            |    Router/Modem   |
            |   192.168.1.1     |
            +-------------------+
                        |
        +---------------+---------------+
        |                               |
        v                               v
[Your Laptop]                    [VM Network]
192.168.1.xxx                    
                                 Physical IPs (Node IPs):
                                 - 192.168.1.92 (Master 1)
                                 - 192.168.1.198 (Master 2)
                                 - 192.168.1.46 (Master 3)
                                 - 192.168.1.171 (Worker 1)
                                 - 192.168.1.113 (Worker 2)
                                        |
                                        v
                                 Virtual IP (Kube-VIP):
                                 - 192.168.1.50 (floats between masters)
                                        |
                                        v
                                 LoadBalancer IPs (MetalLB):
                                 - 192.168.1.60-80
                                        |
                                        v
                                 Pod Network (Flannel):
                                 - 10.42.0.0/16 (pod IPs)
                                        |
                                        v
                                 Service Network:
                                 - 10.43.0.0/16 (ClusterIPs)
```

### How Traffic Flows

**External to Application:**

```
Browser: http://192.168.1.60
        |
        v
[MetalLB Speaker] - announces IP via ARP
        |
        v
[Worker Node] - receives traffic (could be any worker)
        |
        v
[kube-proxy/iptables] - applies service rules
        |
        v
[Load Balance] - selects target pod
        |
        v
[Pod on same or different node]
```

**Pod to Service:**

```
[Pod A] wants to reach "my-service"
        |
        v
[DNS Query] - CoreDNS returns ClusterIP
        |
        v
[Pod A] connects to ClusterIP (10.43.x.x)
        |
        v
[kube-proxy/iptables] - intercepts, load balances
        |
        v
[Backend Pod B]
```

### Service Discovery

Pods find services two ways:

**1. DNS (Preferred):**

```
# Full DNS name
my-service.my-namespace.svc.cluster.local

# Within same namespace, just use service name
my-service

# Example in code
db_host = "postgres"  # Resolves to postgres.default.svc.cluster.local
```

**2. Environment Variables:**

```
# Kubernetes injects these into every pod
MY_SERVICE_SERVICE_HOST=10.43.0.100
MY_SERVICE_SERVICE_PORT=80
```

---

## Storage Concepts

### The Storage Problem

Containers are ephemeral - when they restart, data is lost.

```
Pod starts --> Container writes data --> Pod restarts --> Data GONE!
```

### Volumes

Kubernetes volumes provide persistent storage.

**Volume Types:**

| Type | Description | Use Case |
|------|-------------|----------|
| emptyDir | Empty directory, deleted with pod | Temp files, cache |
| hostPath | File/directory on host node | Testing, single-node |
| persistentVolumeClaim | Claim to PersistentVolume | Production storage |
| configMap | Mount ConfigMap as files | Configuration files |
| secret | Mount Secret as files | Certificates, keys |
| nfs | NFS mount | Shared storage |

### PersistentVolume (PV) and PersistentVolumeClaim (PVC)

```
[Administrator creates]     [User creates]        [Pod uses]
         |                        |                    |
         v                        v                    v
[PersistentVolume]  <--Binds--> [PVC] <--Mounts--> [Pod]
  - 100GB                       - Request 50GB         |
  - ReadWriteOnce               - ReadWriteOnce        v
  - NFS                         - Any                [Volume mounted]
```

**Example:**

```yaml
# PersistentVolume (admin creates, or dynamic provisioning)
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce            # Can be mounted by one node
  persistentVolumeReclaimPolicy: Retain    # Keep data after PVC deleted
  storageClassName: local-path
  hostPath:
    path: /data/pv

---
# PersistentVolumeClaim (user creates)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: local-path

---
# Pod using the PVC
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: my-storage
  volumes:
  - name: my-storage
    persistentVolumeClaim:
      claimName: my-data-claim
```

**Access Modes:**

| Mode | Short | Description |
|------|-------|-------------|
| ReadWriteOnce | RWO | Single node read-write |
| ReadOnlyMany | ROX | Many nodes read-only |
| ReadWriteMany | RWX | Many nodes read-write |

### Storage Classes

Define types of storage with different properties.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/gce-pd    # Cloud specific
parameters:
  type: pd-ssd
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**K3S Default:** `local-path` provisioner creates storage on node's local disk.

---

## Security Concepts

### RBAC (Role-Based Access Control)

Controls who can do what in the cluster.

**Components:**

```
[User/ServiceAccount]
        |
        v
[RoleBinding/ClusterRoleBinding] --> binds user to role
        |
        v
[Role/ClusterRole] --> defines permissions
        |
        v
[API Resources] --> what can be accessed
```

**Example:**

```yaml
# Role - permissions in a specific namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: my-app
  name: pod-reader
rules:
- apiGroups: [""]              # "" = core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]

---
# RoleBinding - grants Role to user
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: my-app
subjects:
- kind: User
  name: jane
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**ClusterRole vs Role:**

| Type | Scope | Use Case |
|------|-------|----------|
| Role | Single namespace | App-specific permissions |
| ClusterRole | Entire cluster | Cluster-wide permissions, or reusable |

### Service Accounts

Identity for pods to access the Kubernetes API.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: default

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      serviceAccountName: my-app-sa    # Use this service account
      containers:
      - name: app
        image: my-app
```

### Network Policies

Control traffic between pods.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: my-app
spec:
  podSelector: {}              # Apply to all pods in namespace
  policyTypes:
  - Ingress
  - Egress
  ingress: []                  # No ingress allowed
  egress: []                   # No egress allowed
```

**Default Behavior:** All traffic is allowed. NetworkPolicies add restrictions.

---

## Troubleshooting

### Understanding Kubernetes Events

Events are the first place to look when something goes wrong.

```bash
# Get events in current namespace, sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Get events for a specific pod
kubectl describe pod <pod-name>

# Watch events in real-time
kubectl get events -w
```

**Common Events and Meanings:**

| Event | Meaning | Solution |
|-------|---------|----------|
| Pulling | Downloading container image | Wait, check image name |
| Pulled | Image downloaded successfully | None needed |
| Created | Container created | None needed |
| Started | Container started | None needed |
| Scheduled | Pod assigned to node | None needed |
| FailedScheduling | No node available for pod | Check resources, taints |
| BackOff | Container crashed, retrying | Check logs, fix app |
| Unhealthy | Health check failed | Check probe, fix app |
| FailedMount | Volume mount failed | Check PVC, storage |
| ImagePullBackOff | Cannot download image | Check image name, credentials |

### Pod Status Reference

| Status | Description | Action |
|--------|-------------|--------|
| Pending | Pod accepted but not running | Check scheduling events |
| ContainerCreating | Pulling image, mounting volumes | Wait, or check events |
| Running | Pod is running | None needed |
| Succeeded | Pod completed successfully | For Jobs only |
| Failed | Pod failed | Check logs |
| Unknown | Cannot determine state | Check node health |
| CrashLoopBackOff | Container keeps crashing | Check logs, fix app |
| ImagePullBackOff | Cannot pull image | Check image name, registry auth |
| ErrImagePull | Error pulling image | Same as above |
| CreateContainerError | Cannot create container | Check events for details |
| InvalidImageName | Image name is invalid | Fix image name |
| OOMKilled | Out of memory | Increase memory limit |

### Debugging Workflow

**Step 1: Check Pod Status**

```bash
kubectl get pods -A
kubectl get pods <name> -o wide
```

**Step 2: Check Events**

```bash
kubectl describe pod <pod-name>
# Look at Events section at bottom
```

**Step 3: Check Logs**

```bash
# Current logs
kubectl logs <pod-name>

# Previous container logs (if crashed)
kubectl logs <pod-name> --previous

# Follow logs
kubectl logs -f <pod-name>

# Logs for specific container in multi-container pod
kubectl logs <pod-name> -c <container-name>
```

**Step 4: Interactive Debugging**

```bash
# Execute command in running container
kubectl exec -it <pod-name> -- /bin/bash

# If bash is not available
kubectl exec -it <pod-name> -- /bin/sh

# Run specific command
kubectl exec <pod-name> -- cat /etc/config/app.conf
```

**Step 5: Check Cluster Components**

```bash
# Node status
kubectl get nodes
kubectl describe node <node-name>

# System pods
kubectl get pods -n kube-system

# Check kubelet on node (SSH to node)
ssh tech@<node-ip> "sudo systemctl status k3s"
ssh tech@<node-ip> "sudo journalctl -u k3s -f"
```

### Common Issues and Solutions

**Issue: Pod stuck in Pending state**

```bash
kubectl describe pod <pod-name>
```

Possible causes:
- **Insufficient resources**: Node does not have enough CPU/memory
  ```
  Solution: Scale down other workloads, add nodes, or reduce pod requests
  ```
- **No matching node**: Node selector or affinity not satisfied
  ```
  Solution: Check nodeSelector and affinity rules
  ```
- **Taint not tolerated**: Node has taint pod does not tolerate
  ```
  Solution: Add toleration to pod or remove taint from node
  ```
- **PVC not bound**: PersistentVolumeClaim cannot find matching volume
  ```
  Solution: Create PV or check StorageClass
  ```

**Issue: Pod in CrashLoopBackOff**

```bash
kubectl logs <pod-name> --previous
```

Possible causes:
- Application error (check logs)
- Missing configuration
- Missing dependencies
- Wrong command or args
- Permission issues

**Issue: Service has no endpoints**

```bash
kubectl get endpoints <service-name>
kubectl get pods -l <selector-from-service>
```

Possible causes:
- Labels do not match (check selector vs pod labels)
- Pods not running
- Pods not ready (readiness probe failing)

**Issue: Cannot connect to service externally**

```bash
kubectl get svc <service-name>
kubectl describe svc <service-name>
```

For LoadBalancer:
```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl logs -n metallb-system -l app=metallb

# Check IP pool
kubectl get ipaddresspool -n metallb-system
```

**Issue: Node shows NotReady**

```bash
kubectl describe node <node-name>
ssh tech@<node-ip> "sudo systemctl status k3s"
ssh tech@<node-ip> "sudo journalctl -u k3s --since '10 minutes ago'"
```

Possible causes:
- Kubelet not running
- Network issues
- Disk full
- Memory exhausted

**Issue: Cannot pull image**

```bash
kubectl describe pod <pod-name>
```

Possible causes:
- Image name typo
- Image does not exist
- Private registry needs credentials

```yaml
# For private registries, create secret
kubectl create secret docker-registry my-registry \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password

# Use in pod
spec:
  imagePullSecrets:
  - name: my-registry
```

### Useful Diagnostic Commands

```bash
# Cluster health overview
kubectl cluster-info
kubectl get componentstatuses

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A

# Check all resources in a namespace
kubectl get all -n <namespace>

# Get YAML of any resource (useful for debugging)
kubectl get deployment <name> -o yaml

# Compare actual state vs what you applied
kubectl diff -f my-app.yaml

# Check API resources available
kubectl api-resources

# Check which API versions are available
kubectl api-versions

# Test network connectivity from a pod
kubectl run test --rm -it --image=busybox -- wget -O- http://service-name

# DNS debugging
kubectl run test --rm -it --image=busybox -- nslookup kubernetes.default
```

### Resetting the Cluster

If you need to completely reset and start over:

```bash
# On each WORKER node first
ssh tech@192.168.1.171 "sudo /usr/local/bin/k3s-agent-uninstall.sh"
ssh tech@192.168.1.113 "sudo /usr/local/bin/k3s-agent-uninstall.sh"

# On each MASTER node (do master1 last)
ssh tech@192.168.1.46 "sudo /usr/local/bin/k3s-uninstall.sh"
ssh tech@192.168.1.198 "sudo /usr/local/bin/k3s-uninstall.sh"
ssh tech@192.168.1.92 "sudo /usr/local/bin/k3s-uninstall.sh"

# Then you can run the installation script again
```

---

## Glossary

This glossary provides detailed explanations of all Kubernetes and related terms.

### Core Kubernetes Concepts

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Pod** | Smallest deployable unit in Kubernetes. Contains one or more containers that share storage and network. All containers in a pod run on the same node. | A pod with nginx container: nginx-abc123 |
| **Container** | A lightweight, standalone executable package that includes everything needed to run: code, runtime, libraries, settings. Isolated from other containers. | nginx:1.21, postgres:14, redis:latest |
| **Node** | A worker machine in Kubernetes (VM or physical). Runs pods and is managed by the control plane. Has kubelet, kube-proxy, and container runtime. | k3s-01 (192.168.1.113) |
| **Cluster** | A set of nodes running containerized applications managed by Kubernetes. Consists of control plane and worker nodes. | Your 5-node cluster |
| **Namespace** | Virtual cluster within a physical cluster. Provides scope for names and can have resource quotas and access control. | default, kube-system, my-app |
| **Label** | Key-value pair attached to objects for identification and selection. Used by selectors to find objects. | app: nginx, environment: production |
| **Selector** | Used to filter and select objects based on labels. Essential for services to find pods. | matchLabels: app: nginx |
| **Annotation** | Key-value pair for attaching non-identifying metadata. Used for tools, libraries, or human-readable notes. | description: "Main web server" |

### Workload Resources

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Deployment** | Manages ReplicaSets and provides declarative updates for Pods. Supports rolling updates, rollbacks, and scaling. | nginx-deployment with 3 replicas |
| **ReplicaSet** | Ensures a specified number of pod replicas are running at any time. Managed by Deployments. Rarely used directly. | nginx-deployment-abc123 |
| **StatefulSet** | Like Deployment but for stateful apps. Provides stable pod names, ordered deployment, and persistent storage per pod. | postgres-0, postgres-1, postgres-2 |
| **DaemonSet** | Ensures all (or some) nodes run a copy of a pod. Used for node-level services like log collectors or monitoring agents. | fluentd on every node |
| **Job** | Creates pods that run to completion. Used for batch processing. Pod is terminated after successful completion. | data-migration-job |
| **CronJob** | Creates Jobs on a time-based schedule. Like cron in Linux. | nightly-backup at 2:00 AM |
| **Replica** | A copy of a pod. Multiple replicas provide high availability and load distribution. | replicas: 3 means 3 pod copies |

### Networking Resources

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Service** | Abstraction that defines a logical set of pods and a policy to access them. Provides stable IP and DNS name. | my-service (ClusterIP: 10.43.0.100) |
| **ClusterIP** | Default service type. Internal IP only accessible within the cluster. No external access. | Type: ClusterIP |
| **NodePort** | Exposes service on each node's IP at a static port (30000-32767). Accessible externally via NodeIP:NodePort. | NodePort: 30080 |
| **LoadBalancer** | Creates external load balancer (cloud) or uses MetalLB (bare metal). Gets dedicated external IP. | EXTERNAL-IP: 192.168.1.60 |
| **Ingress** | Manages external HTTP/HTTPS access to services. Provides URL routing, SSL termination, name-based hosting. | Route /api to api-service |
| **IngressController** | Implements the Ingress resource. Examples: nginx-ingress, traefik, HAProxy. | Traefik (disabled in K3S) |
| **Endpoint** | IP addresses of pods that a service routes to. Automatically managed by Endpoints controller. | 10.42.0.5, 10.42.1.3 |
| **NetworkPolicy** | Specification of how pods communicate with each other and other network endpoints. Like firewall rules. | Allow only frontend to reach backend |
| **CNI** | Container Network Interface. Plugin that provides networking for pods. Flannel is K3S default. | Flannel, Calico, Cilium, Weave |

### Configuration Resources

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **ConfigMap** | Stores non-confidential configuration data as key-value pairs. Can be mounted as files or environment variables. | database-config: host=db.local |
| **Secret** | Stores sensitive data (passwords, tokens, keys). Base64 encoded (not encrypted by default). | db-password: c2VjcmV0 |
| **Environment Variable** | Variable passed to container at runtime. Can come from ConfigMap, Secret, or direct value. | DB_HOST=postgres |

### Storage Resources

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Volume** | Directory accessible to containers in a pod. Outlives individual containers but may not outlive pod. | emptyDir, configMap, secret |
| **PersistentVolume (PV)** | Cluster resource representing storage. Exists independently of pods. Provisioned by admin or dynamically. | pv-data: 100Gi NFS |
| **PersistentVolumeClaim (PVC)** | Request for storage by a user. Bound to a PV. Used by pods to access persistent storage. | my-claim: 50Gi |
| **StorageClass** | Defines types of storage available. Used for dynamic provisioning. Has provisioner and parameters. | local-path, fast-ssd, slow-hdd |
| **AccessModes** | How volume can be mounted. RWO (one node read-write), ROX (many read-only), RWX (many read-write). | ReadWriteOnce |

### Control Plane Components

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **kube-apiserver** | Frontend for Kubernetes control plane. All communication goes through API server. RESTful interface. | https://192.168.1.50:6443 |
| **etcd** | Distributed key-value store for all cluster data. Stores desired state, actual state, configuration. | Runs on master nodes |
| **kube-scheduler** | Decides which node should run new pods. Considers resources, constraints, affinity. | Assigns pod to k3s-01 |
| **kube-controller-manager** | Runs controller processes (Node, Replication, Endpoints, etc.). Watches for changes, takes action. | Ensures 3 replicas running |
| **cloud-controller-manager** | Interfaces with cloud provider APIs. Manages cloud-specific resources. Not used in bare metal. | Creates AWS load balancer |

### Node Components

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **kubelet** | Agent on each node. Ensures containers are running in pods. Reports to API server. | Runs on every node |
| **kube-proxy** | Network proxy on each node. Implements Service networking rules (iptables/IPVS). | Handles ClusterIP routing |
| **Container Runtime** | Software that runs containers. K3S uses containerd. Handles image pull, container lifecycle. | containerd, CRI-O |

### Security Concepts

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **RBAC** | Role-Based Access Control. Manages permissions based on roles. Who can do what on which resources. | Role: pod-reader, can get pods |
| **Role** | Set of permissions within a namespace. Defines allowed actions on resources. | Can get, list, watch pods |
| **ClusterRole** | Set of permissions cluster-wide. Can be used across namespaces. | Can get nodes (cluster-wide) |
| **RoleBinding** | Binds a Role to users/groups in a namespace. Grants permissions. | Bind pod-reader to user jane |
| **ClusterRoleBinding** | Binds ClusterRole to users/groups cluster-wide. | Bind cluster-admin to admin user |
| **ServiceAccount** | Identity for processes running in pods. Used for API access. | my-app-sa for my-app pods |
| **Token** | Authentication credential. Used to access API server. Can be short-lived or persistent. | JWT token for dashboard login |

### High Availability Concepts

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Control Plane** | Master components that make global decisions. API server, scheduler, controller-manager, etcd. | 3 masters in your cluster |
| **Data Plane** | Worker nodes that run application workloads. Run pods and handle traffic. | 2 workers in your cluster |
| **VIP (Virtual IP)** | Floating IP address shared by multiple nodes. Moves between nodes for failover. | 192.168.1.50 |
| **Kube-VIP** | Provides Virtual IP for control plane HA. Uses leader election and ARP. | Runs on master nodes |
| **MetalLB** | Load balancer for bare metal Kubernetes. Assigns external IPs to LoadBalancer services. | IP pool: 192.168.1.60-80 |
| **Quorum** | Minimum number of nodes that must agree for cluster to function. Majority (n/2 + 1). | 2 of 3 masters must be up |
| **Leader Election** | Process of choosing one node to act as leader. Others are followers ready to take over. | Kube-VIP elects VIP holder |
| **Failover** | Automatic switching to backup when primary fails. VIP moves to healthy node. | Master 1 fails, VIP moves to Master 2 |

### Scheduling Concepts

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Taint** | Mark on a node that repels pods. Prevents scheduling unless pod has matching toleration. | node-role.kubernetes.io/master:NoSchedule |
| **Toleration** | Allows pod to schedule onto nodes with matching taints. Overrides taint repulsion. | Tolerate master taint |
| **Affinity** | Rules for pod placement based on labels. Prefer or require certain nodes. | preferredDuringScheduling |
| **Anti-Affinity** | Rules to spread pods apart. Avoid co-location with certain pods. | Database not with cache |
| **NodeSelector** | Simple way to constrain pods to nodes with specific labels. | nodeSelector: disktype: ssd |

### Operations Concepts

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **kubectl** | Command-line tool for Kubernetes. Used to deploy, inspect, and manage cluster. | kubectl get pods |
| **kubeconfig** | Configuration file with cluster connection details. Contains server address, credentials. | ~/.kube/config |
| **Context** | Combination of cluster, user, and namespace. Stored in kubeconfig. Switch between clusters. | k3s-ha context |
| **Helm** | Package manager for Kubernetes. Uses charts (packages) to deploy complex applications. | helm install nginx nginx-chart |
| **Rolling Update** | Update strategy that replaces pods gradually. Zero downtime updates. | maxSurge: 1, maxUnavailable: 0 |
| **Rollback** | Revert to previous version after failed update. Uses revision history. | kubectl rollout undo |

### Probes and Health Checks

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **Liveness Probe** | Check if container is alive. Failure causes container restart. | HTTP GET /health every 10s |
| **Readiness Probe** | Check if container is ready for traffic. Failure removes from service endpoints. | HTTP GET /ready every 5s |
| **Startup Probe** | Check if container has started. Disables other probes until success. For slow-starting apps. | TCP check on port 8080 |

### Tools and Utilities

| Term | Definition | Example/Details |
|------|------------|-----------------|
| **k3sup** | Tool to install K3S over SSH. Bootstraps clusters remotely. Pronounced "ketchup". | k3sup install --ip 192.168.1.92 |
| **Flannel** | CNI plugin for pod networking. Creates overlay network. K3S default. | VXLAN mode |
| **CoreDNS** | DNS server for cluster service discovery. Resolves service names to IPs. | my-svc.default.svc.cluster.local |
| **Traefik** | Ingress controller and reverse proxy. K3S includes it (disabled in your setup). | Routes HTTP traffic |
| **containerd** | Container runtime used by K3S. Lighter than Docker. CRI-compliant. | Runs containers |

---

## Quick Reference Card

### Kubectl Command Structure

Understanding the command pattern:

```
kubectl <verb> <resource-type> <resource-name> <options>

Verbs (actions):
  get       - List resources
  describe  - Show detailed info
  create    - Create from file or command
  apply     - Create or update from file
  delete    - Remove resource
  edit      - Modify resource in editor
  logs      - View container logs
  exec      - Execute command in container
  scale     - Change replica count
  rollout   - Manage deployments

Resource Types:
  pods (po)              - Running containers
  services (svc)         - Network endpoints
  deployments (deploy)   - Manages pods
  replicasets (rs)       - Ensures pod count
  configmaps (cm)        - Configuration data
  secrets                - Sensitive data
  nodes (no)             - Cluster machines
  namespaces (ns)        - Virtual clusters
  persistentvolumes (pv) - Storage
  persistentvolumeclaims (pvc) - Storage requests

Options:
  -n <namespace>         - Specify namespace
  -A                     - All namespaces
  -o wide                - More columns
  -o yaml                - YAML output
  -o json                - JSON output
  -l <label>=<value>     - Filter by label
  -w                     - Watch for changes
  --all                  - Apply to all resources
```

### Most Used Commands

```bash
# Cluster status
kubectl cluster-info
kubectl get nodes
kubectl get nodes -o wide              # Shows IP addresses

# View resources
kubectl get pods                        # Pods in default namespace
kubectl get pods -A                     # Pods in ALL namespaces
kubectl get pods -n kube-system         # Pods in specific namespace
kubectl get pods -o wide                # More details
kubectl get pods -w                     # Watch for changes

kubectl get svc                         # Services
kubectl get deploy                      # Deployments
kubectl get all                         # Pods, services, deployments

# Detailed information
kubectl describe pod <name>
kubectl describe node <name>
kubectl describe svc <name>

# Deploy application
kubectl apply -f app.yaml               # Create or update from file
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# View logs
kubectl logs <pod-name>                 # Current logs
kubectl logs <pod-name> --previous      # Previous container logs
kubectl logs -f <pod-name>              # Follow logs
kubectl logs -l app=nginx               # Logs for all pods with label

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash
kubectl exec -it <pod-name> -- /bin/sh
kubectl exec <pod-name> -- ls /app

# Delete resources
kubectl delete -f app.yaml              # Delete from file
kubectl delete pod <name>               # Delete specific pod
kubectl delete pod --all                # Delete all pods
kubectl delete ns <namespace>           # Delete namespace and all contents

# Scale application
kubectl scale deployment <name> --replicas=3

# Update and rollback
kubectl set image deployment/<name> container=image:tag
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
kubectl rollout history deployment/<name>

# Resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods
```

### Useful Short Aliases

Add these to your shell profile for faster typing:

```bash
# PowerShell (add to $PROFILE)
Set-Alias -Name k -Value kubectl
function kgp { kubectl get pods @args }
function kgs { kubectl get svc @args }
function kgn { kubectl get nodes @args }
function kgd { kubectl get deploy @args }
function kga { kubectl get all @args }
function kd { kubectl describe @args }
function kl { kubectl logs @args }
function ke { kubectl exec -it @args }

# Bash (add to ~/.bashrc)
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kgd='kubectl get deploy'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
```

### File Locations

| File | Windows Location | Linux Location | Purpose |
|------|------------------|----------------|---------|
| Kubeconfig | %USERPROFILE%\.kube\config | ~/.kube/config | Cluster connection settings |
| SSH Private Key | %USERPROFILE%\.ssh\id_ed25519 | ~/.ssh/id_ed25519 | Authentication to nodes |
| SSH Public Key | %USERPROFILE%\.ssh\id_ed25519.pub | ~/.ssh/id_ed25519.pub | Deployed to nodes |
| K3S Script | N/A | ~/k3s.sh (on master1) | Installation script |
| K3S Binary | N/A | /usr/local/bin/k3s | K3S executable |
| K3S Config | N/A | /etc/rancher/k3s/ | K3S configuration |

### Your Cluster Information

**Nodes:**

| Node Name | Role | IP Address | Purpose |
|-----------|------|------------|---------|
| k3s-05 | Master | 192.168.1.92 | Control plane, etcd |
| k3s-04 | Master | 192.168.1.198 | Control plane, etcd |
| k3s-03 | Master | 192.168.1.46 | Control plane, etcd |
| k3s-02 | Worker | 192.168.1.171 | Application workloads |
| k3s-01 | Worker | 192.168.1.113 | Application workloads |

**Service URLs:**

| Service | URL | Description |
|---------|-----|-------------|
| Kubernetes API | https://192.168.1.50:6443 | Cluster API (via VIP) |
| Nginx (test) | http://192.168.1.60 | Test deployment |
| Portainer | https://192.168.1.61:9443 | Kubernetes management UI |
| Kubernetes Dashboard | https://192.168.1.62 | Official Kubernetes dashboard |

**Network Ranges:**

| Range | Purpose |
|-------|---------|
| 192.168.1.0/24 | Physical network |
| 192.168.1.50 | Virtual IP (Kube-VIP) |
| 192.168.1.60-80 | MetalLB LoadBalancer range |
| 10.42.0.0/16 | Pod network (Flannel) |
| 10.43.0.0/16 | Service network (ClusterIP) |

---

## Additional Resources

### Understanding the Learning Path

Here is a suggested order to learn Kubernetes concepts:

```
Level 1 - Basics (Start Here):
  1. Understand Pods (smallest unit)
  2. Create Deployments (manage pods)
  3. Expose with Services (networking)
  4. Use kubectl commands

Level 2 - Configuration:
  5. ConfigMaps (configuration)
  6. Secrets (sensitive data)
  7. Namespaces (organization)
  8. Labels and Selectors

Level 3 - Storage and State:
  9. Volumes and PVCs
  10. StatefulSets (databases)
  11. Jobs and CronJobs

Level 4 - Advanced Networking:
  12. Ingress (HTTP routing)
  13. Network Policies
  14. Service mesh concepts

Level 5 - Operations:
  15. RBAC (security)
  16. Resource limits
  17. Monitoring and logging
  18. Helm (package management)
```

### Recommended Learning Exercises

**Exercise 1: Deploy and Scale**

```bash
# Create a deployment
kubectl create deployment hello --image=nginx

# Check the pod
kubectl get pods

# Scale to 3 replicas
kubectl scale deployment hello --replicas=3

# Verify 3 pods running
kubectl get pods

# Expose as LoadBalancer
kubectl expose deployment hello --port=80 --type=LoadBalancer

# Get external IP
kubectl get svc hello

# Access in browser
# http://<EXTERNAL-IP>

# Clean up
kubectl delete deployment hello
kubectl delete svc hello
```

**Exercise 2: Configuration Management**

```bash
# Create ConfigMap from literal
kubectl create configmap app-config --from-literal=APP_COLOR=blue

# View the ConfigMap
kubectl get configmap app-config -o yaml

# Create pod using ConfigMap
kubectl run test --image=busybox --dry-run=client -o yaml > pod.yaml
# Edit pod.yaml to add env from ConfigMap
kubectl apply -f pod.yaml

# Clean up
kubectl delete pod test
kubectl delete configmap app-config
```

**Exercise 3: Troubleshooting**

```bash
# Deploy a broken application (wrong image)
kubectl create deployment broken --image=nginx:nonexistent

# Check status (will show ImagePullBackOff)
kubectl get pods

# Describe to see error
kubectl describe pod -l app=broken

# Fix by updating image
kubectl set image deployment/broken broken=nginx:latest

# Watch pods update
kubectl get pods -w

# Clean up
kubectl delete deployment broken
```

### Official Documentation

| Resource | URL | Description |
|----------|-----|-------------|
| Kubernetes Docs | https://kubernetes.io/docs/ | Official Kubernetes documentation |
| K3S Docs | https://docs.k3s.io/ | K3S specific documentation |
| kubectl Reference | https://kubernetes.io/docs/reference/kubectl/ | Complete command reference |
| kubectl Cheat Sheet | https://kubernetes.io/docs/reference/kubectl/cheatsheet/ | Quick command reference |
| API Reference | https://kubernetes.io/docs/reference/kubernetes-api/ | API documentation |

### Tutorial Resources

| Resource | URL | Description |
|----------|-----|-------------|
| Kubernetes Basics | https://kubernetes.io/docs/tutorials/kubernetes-basics/ | Official interactive tutorial |
| Kubernetes The Hard Way | https://github.com/kelseyhightower/kubernetes-the-hard-way | Deep dive into internals |
| K3S GitHub | https://github.com/k3s-io/k3s | K3S source and issues |
| Jim's Garage | https://www.youtube.com/@yourjimmygarage | Source of original script |

### Tools and Extensions

| Tool | Purpose | URL |
|------|---------|-----|
| Lens | Desktop Kubernetes IDE | https://k8slens.dev/ |
| k9s | Terminal UI for Kubernetes | https://k9scli.io/ |
| Helm | Kubernetes package manager | https://helm.sh/ |
| Kustomize | Configuration customization | https://kustomize.io/ |
| Longhorn | Distributed block storage | https://longhorn.io/ |
| Prometheus | Monitoring | https://prometheus.io/ |
| Grafana | Visualization | https://grafana.com/ |

### Community

| Resource | URL | Description |
|----------|-----|-------------|
| Kubernetes Slack | https://slack.k8s.io/ | Community chat |
| Rancher Community | https://rancher.com/community | K3S community |
| Stack Overflow | https://stackoverflow.com/questions/tagged/kubernetes | Q&A |
| Reddit | https://www.reddit.com/r/kubernetes/ | Discussion |

---

## Document History

| Date | Version | Changes |
|------|---------|---------|
| November 27, 2025 | 1.0 | Initial comprehensive guide |

**Cluster Details:**
- K3S Version: v1.26.10+k3s2
- Kube-VIP Version: v0.6.3
- MetalLB Version: v0.13.12
- Ubuntu Version: 24.04 LTS

**Author:** Generated with assistance from GitHub Copilot

**Source:** Based on Jim's Garage YouTube tutorial with extensive additions for beginners

---

*This document is intended for educational purposes. Always refer to official documentation for production deployments.*
