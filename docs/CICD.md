# CI/CD Pipeline Documentation

This document describes the GitHub Actions CI/CD pipeline for the K3S infrastructure repository, including the issues encountered and how they were resolved.

## Overview

The repository uses three GitHub Actions workflows to validate changes before they are merged:

1. **Lint YAML** - Validates YAML syntax and formatting using yamllint
2. **Security Scan** - Scans Kubernetes manifests for security issues using Kubescape
3. **Validate K8s Manifests** - Validates that manifests are valid Kubernetes resources using kubeconform

## Workflow Files

All workflow files are located in `.github/workflows/`:

- `lint.yaml` - YAML linting workflow
- `security.yaml` - Security scanning workflow
- `validate.yaml` - Kubernetes manifest validation workflow

## Workflow Details

### Lint YAML Workflow

This workflow runs yamllint on all YAML files in the `apps/` and `argocd/` directories. It uses a relaxed configuration with line-length checks disabled.

**Trigger:** Push or pull request to master/main branches

**Configuration:**
```yaml
yamllint -d "{extends: relaxed, rules: {line-length: disable}}" apps/ argocd/
```

### Security Scan Workflow

This workflow uses Kubescape to scan Kubernetes manifests for security vulnerabilities and misconfigurations. Results are uploaded as SARIF format for GitHub Security tab integration.

**Trigger:** Push or pull request to master/main branches

**Note:** The workflow uses `continue-on-error: true` to prevent security findings from blocking merges while still providing visibility into issues.

### Validate K8s Manifests Workflow

This workflow validates that all Kubernetes manifest files are syntactically correct and conform to Kubernetes API schemas.

**Trigger:** Push or pull request to master/main branches when files in `apps/**`, `infrastructure/**`, or `.github/workflows/validate.yaml` are modified

**Tools Used:**
- kubeconform - Offline Kubernetes manifest validator

## Issues Encountered and Resolutions

### Issue 1: Trailing Spaces in YAML Files

**Problem:** The yamllint check failed with multiple trailing-spaces errors in the n8n deployment files.

**Error Messages:**
```
apps/n8n/deployment.yaml:82:1 [trailing-spaces] trailing spaces
apps/n8n/deployment.yaml:78:1 [trailing-spaces] trailing spaces
apps/n8n/secret.yaml:10:1 [trailing-spaces] trailing spaces
```

**Root Cause:** When YAML files were created or edited, invisible whitespace characters were left at the end of some lines. While Kubernetes accepts this, yamllint flags it as bad practice.

**Resolution:** Removed all trailing whitespace from the affected files. In PowerShell, this was done using:
```powershell
Get-ChildItem -Path "apps/n8n" -Filter *.yaml | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $fixed = $content -replace ' +(\r?\n)', '$1'
    Set-Content $_.FullName -Value $fixed -NoNewline
}
```

**Prevention:** Use an editor with trailing whitespace highlighting or automatic removal on save.

### Issue 2: Validating Kustomization Files as K8s Resources

**Problem:** The validate workflow was treating `kustomization.yaml` files as standalone Kubernetes resources, which caused validation failures.

**Error:** kubectl could not recognize kustomization.yaml as a valid Kubernetes resource type.

**Root Cause:** The original workflow used a simple find command that included all YAML files, but Kustomize configuration files are not valid Kubernetes API resources - they are Kustomize-specific configuration files.

**Resolution:** Modified the find command to exclude files named `kustomization.yaml`:
```bash
find apps -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml"
```

Added a separate validation step for Kustomize overlays:
```bash
for dir in $(find apps -name "kustomization.yaml" -exec dirname {} \;); do
    kubectl kustomize "$dir" > /dev/null || exit 1
done
```

### Issue 3: Find Command Syntax with Exclusions

**Problem:** After adding the exclusion for kustomization.yaml, the find command was still not working correctly.

**Root Cause:** The original command had operator precedence issues:
```bash
# Wrong - the ! -name only applies to *.yml
find apps -name "*.yaml" -o -name "*.yml" ! -name "kustomization.yaml"
```

**Resolution:** Added parentheses to properly group the OR conditions:
```bash
# Correct - exclusion applies to both *.yaml and *.yml
find apps -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml"
```

### Issue 4: Workflow Not Triggering on Workflow File Changes

**Problem:** After fixing the validate workflow, pushing the changes did not trigger a new workflow run.

**Root Cause:** The workflow had path filters that only triggered on changes to `apps/**` and `infrastructure/**`. Changes to the workflow file itself did not match these patterns.

**Resolution:** Added the workflow file path to the trigger configuration:
```yaml
on:
  push:
    branches: [master, main]
    paths:
      - 'apps/**'
      - 'infrastructure/**'
      - '.github/workflows/validate.yaml'
```

### Issue 5: kubectl Requires API Server Connection

**Problem:** The validate step failed with connection refused errors when trying to reach localhost:8080.

**Error Messages:**
```
E1211 21:55:16.206912 2120 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"http://localhost:8080/api?timeout=32s\": dial tcp [::1]:8080: connect: connection refused"
unable to recognize "apps/whoami/deployment.yaml": Get "http://localhost:8080/api?timeout=32s": dial tcp [::1]:8080: connect: connection refused
```

**Root Cause:** Even with `--dry-run=client`, kubectl needs to connect to a Kubernetes API server to discover available resource types and validate against the correct API schemas. In GitHub Actions runners, there is no Kubernetes cluster available.

**Resolution:** Replaced kubectl with kubeconform, which is specifically designed for offline validation in CI/CD pipelines. Kubeconform downloads and caches JSON schemas for Kubernetes resources and validates manifests against them without requiring any cluster connection.

Updated workflow:
```yaml
- name: Install kubeconform
  run: |
    curl -sL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
    sudo mv kubeconform /usr/local/bin/

- name: Validate Kubernetes manifests
  run: |
    find apps -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml" | while read file; do
      echo "Validating $file"
      kubeconform -strict -summary "$file" || exit 1
    done
```

## Current Workflow Configuration

The final validate.yaml workflow:

```yaml
name: Validate K8s Manifests

on:
  push:
    branches: [master, main]
    paths:
      - 'apps/**'
      - 'infrastructure/**'
      - '.github/workflows/validate.yaml'
  pull_request:
    branches: [master, main]
    paths:
      - 'apps/**'
      - 'infrastructure/**'
      - '.github/workflows/validate.yaml'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install kubeconform
        run: |
          curl -sL https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz | tar xz
          sudo mv kubeconform /usr/local/bin/

      - name: Validate Kubernetes manifests
        run: |
          find apps -type f \( -name "*.yaml" -o -name "*.yml" \) ! -name "kustomization.yaml" | while read file; do
            echo "Validating $file"
            kubeconform -strict -summary "$file" || exit 1
          done

      - name: Validate Kustomize builds
        run: |
          for dir in $(find apps -name "kustomization.yaml" -exec dirname {} \;); do
            echo "Validating kustomization in $dir"
            kubectl kustomize "$dir" > /dev/null || exit 1
          done
```

## Commit History

The following commits were made to fix the CI/CD pipeline:

1. `99dc3c5` - fix(ci): Remove trailing spaces and fix validate workflow for Kustomize
2. `d4558b7` - fix(ci): Correct find command syntax for kustomization exclusion
3. `8657fbf` - fix(ci): Add workflow file to validate trigger paths
4. `70ac0e9` - fix(ci): Use kubeconform for offline manifest validation

## Lessons Learned

1. **Trailing whitespace matters** - Configure your editor to show or automatically remove trailing whitespace to avoid lint failures.

2. **Kustomize files are not K8s resources** - When validating Kubernetes manifests, exclude kustomization.yaml files from direct resource validation and validate them separately using kubectl kustomize.

3. **Shell command syntax is critical** - When using find with multiple conditions and exclusions, use parentheses to ensure proper operator precedence.

4. **Workflow path filters need maintenance** - If you want workflows to run when the workflow file itself changes, include the workflow path in the trigger paths.

5. **Offline validation tools are essential for CI/CD** - Tools like kubeconform are designed for CI/CD environments where no Kubernetes cluster is available. They validate manifests against downloaded schemas without requiring API server connectivity.

## Tools Reference

### yamllint

A linter for YAML files that checks syntax and formatting.

- Documentation: https://yamllint.readthedocs.io/
- Used configuration: relaxed with line-length disabled

### Kubescape

A security scanner for Kubernetes that checks for misconfigurations and vulnerabilities.

- Documentation: https://github.com/kubescape/kubescape
- Output format: SARIF (Static Analysis Results Interchange Format)

### kubeconform

A fast Kubernetes manifest validator that works offline by using JSON schemas.

- Documentation: https://github.com/yannh/kubeconform
- Key flags:
  - `-strict` - Fail on unknown properties
  - `-summary` - Print summary of validation results
