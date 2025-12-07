# K3S Best Practices Implementation Plan

This document tracks the implementation of K3S best practices for the homelab cluster. Each practice will be implemented one at a time, with full documentation created upon completion.

## Status Overview

| Priority | Practice | Status | Documentation |
|----------|----------|--------|---------------|
| 1 | Resource Limits | Pending | - |
| 2 | Pod Security Standards | Pending | - |
| 3 | Logging Aggregation | Pending | - |
| 4 | Regular HA Testing | Pending | - |

---

## Priority Order Rationale

### 1. Resource Limits (First Priority)

Starting with resource limits because:
- Prevents a single misbehaving pod from consuming all node resources
- Enables the Kubernetes scheduler to make better placement decisions
- Required foundation before adding monitoring or logging workloads
- Immediate impact on cluster stability
- Quick to implement with templates

### 2. Pod Security Standards (Second Priority)

Implementing security policies next because:
- Prevents privilege escalation attacks
- Blocks containers from running as root unnecessarily
- Enforces security at the namespace level
- Built into Kubernetes (Pod Security Admission) - no additional tools needed

### 3. Logging Aggregation (Third Priority)

Adding centralized logging because:
- Essential for troubleshooting issues across 5 nodes
- Currently logs are scattered across each node
- Loki is lightweight and integrates with existing Grafana
- Will consume resources, so needs limits in place first

### 4. Regular HA Testing (Fourth Priority)

Creating HA test procedures last because:
- Documentation and runbook creation
- Requires the cluster to be stable and monitored first
- Tests should be run after other practices are in place
- Non-disruptive to implement (just documentation and scripts)

---

## Implementation Details

### Practice 1: Resource Limits

**Scope:**
- Create resource quota templates for namespaces
- Create limit range defaults for pods
- Apply to existing namespaces
- Document how to set limits for new deployments

**Deliverable:** `docs/RESOURCE_LIMITS_GUIDE.md`

### Practice 2: Pod Security Standards

**Scope:**
- Enable Pod Security Admission in K3S
- Configure namespace labels for security profiles
- Test with baseline and restricted profiles
- Document how to apply security standards to namespaces

**Deliverable:** `docs/POD_SECURITY_GUIDE.md`

### Practice 3: Logging Aggregation

**Scope:**
- Deploy Loki for log storage
- Deploy Promtail for log collection from all nodes
- Configure Grafana dashboards for log viewing
- Set up log retention policies

**Deliverable:** `docs/LOGGING_SETUP_GUIDE.md`

### Practice 4: Regular HA Testing

**Scope:**
- Create test procedure for master node failure
- Create test procedure for worker node failure
- Create test procedure for etcd quorum loss
- Document expected behavior and recovery steps
- Create verification checklists

**Deliverable:** `docs/HA_TESTING_PROCEDURES.md`

---

## How to Continue

When resuming this work:

1. Open this file to see current status
2. Start with the first "Pending" practice
3. Implement the practice
4. Create the documentation
5. Update the status table above
6. Commit and push changes
7. Move to the next practice

---

## Session Notes

**December 8, 2025:** Plan created. Ready to begin with Resource Limits implementation.

---

## References

- K3S Documentation: https://docs.k3s.io
- Kubernetes Resource Management: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
- Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- Grafana Loki: https://grafana.com/oss/loki/
