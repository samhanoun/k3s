# Docker MCP Gateway Kubernetes Issue

## Overview

This document describes a bug discovered in the Docker MCP Gateway when using the Kubernetes MCP server on Windows. The issue prevents the Kubernetes tools from working due to a file permission error caused by incorrect volume mount paths.

**Bug Report:** https://github.com/docker/mcp-gateway/issues/284

---

## Table of Contents

1. [Background Concepts](#background-concepts)
   - [What is Containerization?](#what-is-containerization)
   - [What is Docker?](#what-is-docker)
   - [What is MCP (Model Context Protocol)?](#what-is-mcp-model-context-protocol)
   - [What is Docker MCP Gateway?](#what-is-docker-mcp-gateway)
   - [Container Users and Permissions](#container-users-and-permissions)
   - [Volume Mounts](#volume-mounts)
2. [The Issue](#the-issue)
3. [Root Cause Analysis](#root-cause-analysis)
4. [Proof of Concept](#proof-of-concept)
5. [Current Status](#current-status)

---

## Background Concepts

### What is Containerization?

Containerization is a lightweight form of virtualization that packages an application and its dependencies into a single, portable unit called a **container**.

```
┌─────────────────────────────────────────────────────────────┐
│                      HOST OPERATING SYSTEM                   │
├─────────────────────────────────────────────────────────────┤
│                      CONTAINER RUNTIME                       │
│                    (Docker, containerd)                      │
├─────────────┬─────────────┬─────────────┬─────────────────── │
│  Container  │  Container  │  Container  │                    │
│  ┌───────┐  │  ┌───────┐  │  ┌───────┐  │                    │
│  │  App  │  │  │  App  │  │  │  App  │  │                    │
│  ├───────┤  │  ├───────┤  │  ├───────┤  │                    │
│  │ Libs  │  │  │ Libs  │  │  │ Libs  │  │                    │
│  └───────┘  │  └───────┘  │  └───────┘  │                    │
└─────────────┴─────────────┴─────────────┴────────────────────┘
```

**Key Benefits:**
- **Isolation**: Each container runs in its own isolated environment
- **Portability**: Containers run the same way on any system
- **Lightweight**: Containers share the host OS kernel, unlike VMs
- **Reproducibility**: Same container image = same behavior everywhere

**Containers vs Virtual Machines:**

| Aspect | Containers | Virtual Machines |
|--------|-----------|------------------|
| Boot Time | Seconds | Minutes |
| Size | MBs | GBs |
| OS | Shares host kernel | Full OS per VM |
| Isolation | Process-level | Hardware-level |
| Performance | Near-native | Overhead from hypervisor |

---

### What is Docker?

Docker is the most popular containerization platform. It provides:

1. **Docker Engine**: The runtime that runs containers
2. **Docker CLI**: Command-line interface to manage containers
3. **Docker Desktop**: GUI application for Windows/Mac (includes Docker Engine)
4. **Docker Hub**: Public registry for container images

**Basic Docker Commands:**

```bash
# Run a container
docker run -it ubuntu bash

# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# Pull an image
docker pull nginx

# Build an image
docker build -t myapp:latest .

# Mount a volume (host path : container path)
docker run -v /host/path:/container/path myimage
```

---

### What is MCP (Model Context Protocol)?

MCP (Model Context Protocol) is an open protocol that allows AI assistants (like GitHub Copilot, Claude, Cursor) to interact with external tools and services.

```
┌─────────────────┐     MCP Protocol      ┌─────────────────┐
│   AI Assistant  │ ◄──────────────────►  │   MCP Server    │
│   (Copilot,     │                       │   (Tools like   │
│    Claude)      │                       │   Kubernetes,   │
│                 │                       │   GitHub, etc)  │
└─────────────────┘                       └─────────────────┘
```

**MCP enables AI assistants to:**
- Query Kubernetes clusters
- Manage GitHub repositories
- Access databases
- Control cloud resources
- And much more...

---

### What is Docker MCP Gateway?

Docker MCP Gateway is Docker's solution for running MCP servers in containers. It acts as a bridge between AI clients (VS Code, Cursor) and containerized MCP servers.

```
┌─────────────────────────────────────────────────────────────┐
│                     YOUR COMPUTER                            │
│                                                              │
│   ┌─────────────┐         ┌────────────────────────────┐    │
│   │   VS Code   │         │    Docker MCP Gateway      │    │
│   │   with      │◄───────►│                            │    │
│   │   Copilot   │  stdio  │  ┌──────────────────────┐  │    │
│   └─────────────┘         │  │ mcp/kubernetes       │  │    │
│                           │  │ container            │  │    │
│                           │  │                      │  │    │
│                           │  │ Runs as: appuser     │──┼────┼──► K3S Cluster
│                           │  │ (uid 1001)           │  │    │    192.168.1.92
│                           │  └──────────────────────┘  │    │
│                           └────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Docker MCP Commands:**

```bash
# List available MCP servers
docker mcp server ls

# Enable a server
docker mcp server enable kubernetes

# Configure a server
docker mcp config set kubernetes.config_path "C:\Users\harry\.kube\config"

# Connect to VS Code
docker mcp client connect vscode

# Run the gateway
docker mcp gateway run
```

---

### Container Users and Permissions

Containers can run as different users. This is a **security best practice** - running as root inside containers is discouraged.

```
┌────────────────────────────────────────┐
│            CONTAINER                    │
│                                         │
│   User: appuser (uid 1001)              │
│   Home: /home/appuser                   │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │  /root/           ← FORBIDDEN   │   │
│   │  (only root can access)         │   │
│   └─────────────────────────────────┘   │
│                                         │
│   ┌─────────────────────────────────┐   │
│   │  /home/appuser/   ← ALLOWED     │   │
│   │  (appuser can read/write)       │   │
│   └─────────────────────────────────┘   │
│                                         │
└────────────────────────────────────────┘
```

**Check container user:**
```bash
docker run --rm mcp/kubernetes id
# Output: uid=1001(appuser) gid=1001(appuser) groups=1001(appuser)
```

**Why non-root?**
- **Security**: If container is compromised, attacker has limited privileges
- **Best Practice**: Many container registries require non-root images
- **Kubernetes**: Many clusters enforce non-root via PodSecurityPolicies

---

### Volume Mounts

Volume mounts allow you to share files between the host and the container.

```
HOST SYSTEM                          CONTAINER
┌────────────────┐                   ┌────────────────┐
│                │                   │                │
│ C:\Users\harry │                   │ /home/appuser  │
│ └─.kube        │    -v mount       │ └─.kube        │
│   └─config ────┼───────────────────┼───►config      │
│                │                   │                │
└────────────────┘                   └────────────────┘
```

**Mount Syntax:**
```bash
docker run -v "HOST_PATH:CONTAINER_PATH" image

# Example - CORRECT for mcp/kubernetes:
docker run -v "$HOME/.kube/config:/home/appuser/.kube/config" mcp/kubernetes

# Example - WRONG (permission denied):
docker run -v "$HOME/.kube/config:/root/.kube/config" mcp/kubernetes
```

---

## The Issue

### Problem Statement

When using the Kubernetes MCP server via Docker MCP Gateway on Windows, the server fails silently. No Kubernetes tools work, and no data is returned.

### Environment

| Component | Version |
|-----------|---------|
| OS | Windows 11 |
| Docker Desktop | 29.1.2 |
| Docker MCP | v0.28.0 |
| K3S Cluster | v1.26.10+k3s2 (5 nodes) |

### Symptoms

1. Enable kubernetes MCP server - appears successful
2. Configure kubeconfig path - appears successful  
3. Connect to VS Code - connection established
4. Try to use kubernetes tools - **FAILS SILENTLY**

---

## Root Cause Analysis

### The Discovery

After extensive debugging, the issue was traced to **incorrect volume mount paths**.

### Step-by-Step Analysis

**1. Check what user the container runs as:**
```bash
$ docker run --rm mcp/kubernetes id
uid=1001(appuser) gid=1001(appuser) groups=1001(appuser)
```
The container runs as `appuser` (uid 1001), **NOT root**.

**2. Test mounting to /root (what the gateway does):**
```bash
$ docker run --rm -v "$HOME/.kube/config:/root/.kube/config" mcp/kubernetes cat /root/.kube/config
cat: /root/.kube/config: Permission denied
```
**FAILS** - `appuser` cannot access `/root` directory.

**3. Test mounting to /home/appuser (correct path):**
```bash
$ docker run --rm -v "$HOME/.kube/config:/home/appuser/.kube/config" mcp/kubernetes kubectl get nodes
NAME     STATUS   ROLES                       AGE   VERSION
k3s-01   Ready    control-plane,etcd,master   9d    v1.26.10+k3s2
k3s-02   Ready    <none>                      9d    v1.26.10+k3s2
k3s-03   Ready    <none>                      9d    v1.26.10+k3s2
k3s-04   Ready    <none>                      9d    v1.26.10+k3s2
k3s-05   Ready    <none>                      9d    v1.26.10+k3s2
```
**SUCCESS** - All 5 nodes are visible!

### Root Cause Diagram

```
WHAT DOCKER MCP GATEWAY DOES (WRONG):

Host: C:\Users\harry\.kube\config
              │
              ▼ mounts to
Container: /root/.kube/config  ◄─── appuser CANNOT access /root
              │
              ▼
Result: Permission Denied


WHAT IT SHOULD DO (CORRECT):

Host: C:\Users\harry\.kube\config
              │
              ▼ mounts to
Container: /home/appuser/.kube/config  ◄─── appuser CAN access this
              │
              ▼
Result: Success!
```

---

## Proof of Concept

### Test Script

```powershell
# Test 1: Verify container user
Write-Host "Container user:"
docker run --rm mcp/kubernetes id

# Test 2: Wrong path (what gateway uses)
Write-Host "`nTest /root path:"
docker run --rm -v "$env:USERPROFILE\.kube\config:/root/.kube/config" mcp/kubernetes cat /root/.kube/config

# Test 3: Correct path
Write-Host "`nTest /home/appuser path:"
docker run --rm -v "$env:USERPROFILE\.kube\config:/home/appuser/.kube/config" mcp/kubernetes kubectl get nodes
```

### Expected Output

```
Container user:
uid=1001(appuser) gid=1001(appuser) groups=1001(appuser)

Test /root path:
cat: /root/.kube/config: Permission denied

Test /home/appuser path:
NAME     STATUS   ROLES                       AGE   VERSION
k3s-01   Ready    control-plane,etcd,master   9d    v1.26.10+k3s2
k3s-02   Ready    <none>                      9d    v1.26.10+k3s2
k3s-03   Ready    <none>                      9d    v1.26.10+k3s2
k3s-04   Ready    <none>                      9d    v1.26.10+k3s2
k3s-05   Ready    <none>                      9d    v1.26.10+k3s2
```

---

## Current Status

### Bug Reports Filed

| Repository | Issue | Status |
|------------|-------|--------|
| docker/mcp-gateway | [#284](https://github.com/docker/mcp-gateway/issues/284) | Open |
| Flux159/mcp-server-kubernetes | [#243](https://github.com/Flux159/mcp-server-kubernetes/issues/243) | Closed (not a bug here) |

### Workaround

**None available** - The Docker MCP Gateway internally handles container startup and mount paths. Users cannot override the mount paths.

### Expected Fix

The Docker MCP Gateway should:
1. Detect the container's running user (via `id` command or image inspection)
2. Mount config files to the user's home directory, not `/root`

Or alternatively:
1. Read mount path specifications from the MCP server's catalog entry
2. Allow users to override mount paths in configuration

---

## Related Links

- [Docker MCP Gateway Documentation](https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/)
- [MCP Server Kubernetes ADVANCED_README](https://github.com/Flux159/mcp-server-kubernetes/blob/main/ADVANCED_README.md)
- [Model Context Protocol Specification](https://modelcontextprotocol.io/)
- [K3S Documentation](https://docs.k3s.io/)

---

## Author

Bug discovered and documented by the K3S cluster maintainer during integration testing of Docker MCP with VS Code Copilot.

**Date:** December 7, 2025
