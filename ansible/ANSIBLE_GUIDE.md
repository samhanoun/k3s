# Complete Ansible Guide for Technical Interviews

This comprehensive guide explains Ansible from the ground up, using real examples from this K3S cluster project.

---

## Table of Contents

1. [What is Ansible?](#what-is-ansible)
2. [Why Use Ansible?](#why-use-ansible)
3. [Core Concepts](#core-concepts)
4. [Architecture](#architecture)
5. [Installation](#installation)
6. [Inventory Deep Dive](#inventory-deep-dive)
7. [Playbooks Explained](#playbooks-explained)
8. [Modules](#modules)
9. [Variables](#variables)
10. [Conditionals and Loops](#conditionals-and-loops)
11. [Handlers](#handlers)
12. [Roles](#roles)
13. [Ansible Galaxy](#ansible-galaxy)
14. [Best Practices](#best-practices)
15. [Common Interview Questions](#common-interview-questions)
16. [Our K3S Project Examples](#our-k3s-project-examples)

---

## What is Ansible?

**Ansible** is an open-source IT automation tool developed by Red Hat. It automates:

- **Configuration Management** - Ensure servers are configured consistently
- **Application Deployment** - Deploy apps across multiple servers
- **Orchestration** - Coordinate multi-tier deployments
- **Provisioning** - Set up new servers automatically

### Key Characteristics

| Feature | Description |
|---------|-------------|
| **Agentless** | No software needed on managed nodes - uses SSH |
| **Declarative** | You describe the desired state, Ansible figures out how |
| **Idempotent** | Running the same playbook multiple times = same result |
| **YAML-based** | Human-readable configuration files |
| **Push-based** | Control node pushes changes to managed nodes |

### Ansible vs Other Tools

| Tool | Agent Required | Language | Model |
|------|----------------|----------|-------|
| **Ansible** | No (SSH) | YAML | Push |
| Puppet | Yes | Ruby DSL | Pull |
| Chef | Yes | Ruby | Pull |
| SaltStack | Optional | YAML | Push/Pull |
| Terraform | No | HCL | Push |

**Interview Tip:** Ansible is often preferred for its simplicity and agentless architecture. No maintenance of agents on hundreds of servers!

---

## Why Use Ansible?

### The Problem It Solves

**Without Ansible:**
```bash
# You have 5 servers to configure...
ssh tech@192.168.1.46 "sudo apt update && sudo apt install -y htop"
ssh tech@192.168.1.198 "sudo apt update && sudo apt install -y htop"
ssh tech@192.168.1.92 "sudo apt update && sudo apt install -y htop"
ssh tech@192.168.1.113 "sudo apt update && sudo apt install -y htop"
ssh tech@192.168.1.171 "sudo apt update && sudo apt install -y htop"
# Tedious, error-prone, not documented
```

**With Ansible:**
```bash
ansible k3s_cluster -m apt -a "name=htop state=present"
# One command, all 5 servers, parallel execution, documented
```

### Benefits

1. **Consistency** - All servers configured identically
2. **Documentation** - Playbooks ARE your documentation
3. **Version Control** - Track changes in Git
4. **Reproducibility** - Recreate environments easily
5. **Scalability** - 5 servers or 5000, same effort
6. **Auditability** - Know exactly what's configured where

---

## Core Concepts

### 1. Control Node

The machine where Ansible is installed and playbooks are run FROM.

```
Your PC/Laptop (Windows WSL, macOS, Linux)
     |
     | Ansible installed here
     | Playbooks stored here
     | Runs commands FROM here
     v
```

### 2. Managed Nodes

The servers being managed. They need:
- SSH access
- Python installed (usually pre-installed on Ubuntu)
- No Ansible agent needed!

```
┌─────────────────────────────────────────────────────────┐
│  Managed Nodes (your K3S VMs)                           │
│                                                         │
│  k3s-01    k3s-02    k3s-03    k3s-04    k3s-05        │
│  .113      .171      .46       .198      .92           │
│                                                         │
│  Only need: SSH + Python                                │
└─────────────────────────────────────────────────────────┘
```

### 3. Inventory

A file listing all managed nodes and how to group them.

```yaml
# inventory/hosts.yaml
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 10.0.0.1
        web2:
          ansible_host: 10.0.0.2
    databases:
      hosts:
        db1:
          ansible_host: 10.0.0.3
```

### 4. Playbook

A YAML file containing a list of tasks to execute.

```yaml
# playbook.yaml
- name: Configure webservers
  hosts: webservers
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
```

### 5. Task

A single unit of work (install package, copy file, run command).

```yaml
- name: Install nginx    # Human-readable description
  apt:                    # Module to use
    name: nginx           # Module parameters
    state: present
```

### 6. Module

Pre-built functions for common tasks. Ansible has 3000+ modules!

```yaml
# Common modules
apt:        # Manage apt packages (Debian/Ubuntu)
yum:        # Manage yum packages (RHEL/CentOS)
copy:       # Copy files to remote
template:   # Copy with variable substitution
file:       # Manage files/directories
service:    # Manage services
command:    # Run shell commands
shell:      # Run shell commands with pipes
user:       # Manage users
```

### 7. Role

A reusable, shareable collection of tasks, handlers, files, and variables.

```
roles/
  webserver/
    tasks/main.yaml
    handlers/main.yaml
    templates/nginx.conf.j2
    files/index.html
    vars/main.yaml
    defaults/main.yaml
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      CONTROL NODE                                │
│                      (Your PC)                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  ansible.cfg     - Configuration                         │    │
│  │  inventory/      - List of servers                       │    │
│  │  playbooks/      - Automation scripts                    │    │
│  │  roles/          - Reusable components                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              │ SSH (Port 22)                     │
│                              │ No agent needed!                  │
│                              ▼                                   │
└─────────────────────────────────────────────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Managed Node 1 │  │  Managed Node 2 │  │  Managed Node N │
│  (k3s-01)       │  │  (k3s-02)       │  │  (k3s-05)       │
│                 │  │                 │  │                 │
│  Requirements:  │  │  Requirements:  │  │  Requirements:  │
│  - SSH access   │  │  - SSH access   │  │  - SSH access   │
│  - Python 3     │  │  - Python 3     │  │  - Python 3     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### How Ansible Executes Tasks

1. **Parse playbook** - Read YAML, validate syntax
2. **Build inventory** - Load list of target hosts
3. **Connect via SSH** - Establish connections to managed nodes
4. **Generate Python script** - Convert task to Python code
5. **Transfer script** - Copy to managed node via SSH
6. **Execute remotely** - Run the Python script
7. **Capture output** - Get results back
8. **Report status** - Show success/failure/changed

---

## Installation

### On Ubuntu/Debian

```bash
sudo apt update
sudo apt install ansible
```

### On macOS

```bash
brew install ansible
```

### On Windows (via WSL2)

```bash
# In WSL2 Ubuntu terminal
sudo apt update
sudo apt install ansible
```

### Via pip (any platform)

```bash
pip install ansible
```

### Verify Installation

```bash
ansible --version
# ansible [core 2.15.0]
#   config file = /etc/ansible/ansible.cfg
#   python version = 3.10.12
```

---

## Inventory Deep Dive

The inventory defines WHAT servers Ansible manages.

### INI Format (Traditional)

```ini
# inventory/hosts.ini
[webservers]
web1 ansible_host=10.0.0.1
web2 ansible_host=10.0.0.2

[databases]
db1 ansible_host=10.0.0.3

[production:children]
webservers
databases
```

### YAML Format (Modern - what we use)

```yaml
# inventory/hosts.yaml
all:
  vars:
    ansible_user: tech
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519
  
  children:
    control_plane:
      hosts:
        k3s-03:
          ansible_host: 192.168.1.46
        k3s-04:
          ansible_host: 192.168.1.198
        k3s-05:
          ansible_host: 192.168.1.92
    
    workers:
      hosts:
        k3s-01:
          ansible_host: 192.168.1.113
        k3s-02:
          ansible_host: 192.168.1.171
    
    k3s_cluster:
      children:
        control_plane:
        workers:
```

### Inventory Hierarchy

```
all                          # Every host
├── ungrouped                # Hosts not in any group
└── children
    ├── control_plane        # Group 1
    │   ├── k3s-03
    │   ├── k3s-04
    │   └── k3s-05
    ├── workers              # Group 2
    │   ├── k3s-01
    │   └── k3s-02
    └── k3s_cluster          # Group 3 (contains Group 1 + 2)
        ├── control_plane
        └── workers
```

### Special Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ansible_host` | IP or hostname to connect to | `192.168.1.46` |
| `ansible_user` | SSH username | `tech` |
| `ansible_ssh_private_key_file` | Path to SSH key | `~/.ssh/id_ed25519` |
| `ansible_port` | SSH port (default 22) | `2222` |
| `ansible_become` | Use sudo | `true` |
| `ansible_python_interpreter` | Python path | `/usr/bin/python3` |

### Dynamic Inventory

For cloud environments, Ansible can query AWS/Azure/GCP for current servers:

```bash
# AWS example
ansible-inventory -i aws_ec2.yaml --list
```

### Targeting Hosts

```bash
# All hosts
ansible all -m ping

# Specific group
ansible control_plane -m ping

# Multiple groups
ansible 'control_plane:workers' -m ping

# Exclude a group
ansible 'k3s_cluster:!workers' -m ping

# Specific host
ansible k3s-03 -m ping

# First host in group
ansible 'control_plane[0]' -m ping

# Pattern matching
ansible 'k3s-0*' -m ping
```

---

## Playbooks Explained

Playbooks are the heart of Ansible - they define WHAT to do.

### Basic Structure

```yaml
---                                    # YAML document start
- name: Playbook description           # Play 1
  hosts: webservers                    # Target hosts
  become: true                         # Use sudo
  
  vars:                                # Variables
    http_port: 80
  
  tasks:                               # List of tasks
    - name: Install nginx
      apt:
        name: nginx
        state: present
    
    - name: Start nginx
      service:
        name: nginx
        state: started

- name: Another play                   # Play 2
  hosts: databases
  tasks:
    - name: Install PostgreSQL
      apt:
        name: postgresql
        state: present
```

### Playbook Components

#### 1. Play

A play maps a group of hosts to tasks:

```yaml
- name: Configure web servers        # Play name (optional but recommended)
  hosts: webservers                  # Target hosts (required)
  become: true                       # Run as root
  gather_facts: true                 # Collect system info (default true)
  
  tasks:
    # ...
```

#### 2. Tasks

Individual actions to perform:

```yaml
tasks:
  - name: Install packages           # Description (shown in output)
    apt:                             # Module name
      name:                          # Module parameters
        - nginx
        - curl
      state: present
    become: true                     # Task-level sudo
    when: ansible_os_family == "Debian"  # Conditional
    register: install_result         # Save output to variable
    ignore_errors: yes               # Continue even if fails
    tags:                            # For selective execution
      - packages
      - nginx
```

#### 3. Handlers

Tasks that run only when notified:

```yaml
tasks:
  - name: Update nginx config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx            # Trigger handler

handlers:
  - name: Restart nginx              # Only runs if notified
    service:
      name: nginx
      state: restarted
```

**Why handlers?** If you update config in 5 places, nginx restarts only ONCE at the end, not 5 times.

### Execution Flow

```
Playbook Start
     │
     ▼
┌─────────────┐
│ Gather Facts │  ← Collect OS info, IP, memory, etc.
└─────────────┘
     │
     ▼
┌─────────────┐
│   Task 1    │  ← Execute in order
└─────────────┘
     │
     ▼
┌─────────────┐
│   Task 2    │
└─────────────┘
     │
     ▼
┌─────────────┐
│   Task N    │
└─────────────┘
     │
     ▼
┌─────────────┐
│  Handlers   │  ← Run notified handlers
└─────────────┘
     │
     ▼
Playbook End
```

### Running Playbooks

```bash
# Basic execution
ansible-playbook playbook.yaml

# With inventory file
ansible-playbook -i inventory/hosts.yaml playbook.yaml

# Limit to specific hosts
ansible-playbook playbook.yaml --limit k3s-03

# Dry run (check mode)
ansible-playbook playbook.yaml --check

# Verbose output
ansible-playbook playbook.yaml -v    # Basic
ansible-playbook playbook.yaml -vv   # More
ansible-playbook playbook.yaml -vvv  # Debug

# Run specific tags only
ansible-playbook playbook.yaml --tags "nginx,packages"

# Skip specific tags
ansible-playbook playbook.yaml --skip-tags "slow"

# Start at specific task
ansible-playbook playbook.yaml --start-at-task "Install nginx"

# Step through tasks one by one
ansible-playbook playbook.yaml --step

# Pass extra variables
ansible-playbook playbook.yaml -e "version=1.2.3"
```

---

## Modules

Modules are the units of work in Ansible. There are 3000+ built-in modules.

### Package Management

```yaml
# Debian/Ubuntu
- apt:
    name: nginx
    state: present        # present, absent, latest
    update_cache: yes

# RHEL/CentOS
- yum:
    name: httpd
    state: present

# Generic (auto-detects package manager)
- package:
    name: git
    state: present
```

### File Management

```yaml
# Copy file
- copy:
    src: files/app.conf
    dest: /etc/app/app.conf
    owner: root
    group: root
    mode: '0644'

# Template (with variables)
- template:
    src: templates/nginx.conf.j2
    dest: /etc/nginx/nginx.conf

# Create directory
- file:
    path: /opt/myapp
    state: directory
    mode: '0755'

# Create symlink
- file:
    src: /opt/myapp/current
    dest: /opt/myapp/v1.2.3
    state: link

# Delete file
- file:
    path: /tmp/garbage
    state: absent

# Download file
- get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    checksum: sha256:abcd1234...
```

### Service Management

```yaml
# Manage systemd service
- systemd:
    name: nginx
    state: started      # started, stopped, restarted, reloaded
    enabled: yes        # Start on boot

# Generic service module
- service:
    name: nginx
    state: started
    enabled: yes
```

### Command Execution

```yaml
# Simple command (no shell features)
- command: /usr/bin/uptime

# Shell command (supports pipes, redirects)
- shell: cat /etc/passwd | grep root

# Raw command (no Python required on remote)
- raw: apt install -y python3

# Script execution
- script: scripts/setup.sh
```

### User Management

```yaml
# Create user
- user:
    name: deploy
    groups: sudo,docker
    shell: /bin/bash
    create_home: yes
    state: present

# Add SSH key
- authorized_key:
    user: deploy
    key: "{{ lookup('file', '~/.ssh/id_rsa.pub') }}"
```

### System Configuration

```yaml
# Set hostname
- hostname:
    name: webserver01

# Configure timezone
- timezone:
    name: UTC

# Sysctl settings
- sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    state: present
    reload: yes

# Cron job
- cron:
    name: "Daily backup"
    minute: "0"
    hour: "2"
    job: "/opt/scripts/backup.sh"
```

### Cloud Modules

```yaml
# AWS EC2
- amazon.aws.ec2_instance:
    name: "web-server"
    instance_type: t3.micro
    image_id: ami-12345678

# Azure VM
- azure.azcollection.azure_rm_virtualmachine:
    resource_group: myResourceGroup
    name: myVM

# Kubernetes
- kubernetes.core.k8s:
    state: present
    src: deployment.yaml
```

---

## Variables

Variables make playbooks reusable and dynamic.

### Defining Variables

#### 1. In Playbook

```yaml
- hosts: webservers
  vars:
    http_port: 80
    app_name: myapp
  
  tasks:
    - debug:
        msg: "App {{ app_name }} runs on port {{ http_port }}"
```

#### 2. In Separate File

```yaml
# vars/main.yaml
http_port: 80
app_name: myapp
database:
  host: localhost
  port: 5432
  name: appdb
```

```yaml
# playbook.yaml
- hosts: webservers
  vars_files:
    - vars/main.yaml
```

#### 3. In Inventory

```yaml
# inventory/hosts.yaml
all:
  vars:
    ntp_server: time.google.com
  
  children:
    production:
      vars:
        environment: production
        debug: false
      hosts:
        prod1:
          ansible_host: 10.0.0.1
          app_port: 8080           # Host-specific variable
```

#### 4. Command Line

```bash
ansible-playbook playbook.yaml -e "version=1.2.3"
ansible-playbook playbook.yaml -e '{"users": ["alice", "bob"]}'
ansible-playbook playbook.yaml -e @vars.json
```

### Variable Precedence (Low to High)

1. Role defaults
2. Inventory file vars
3. Inventory group_vars
4. Inventory host_vars
5. Playbook group_vars
6. Playbook host_vars
7. Host facts
8. Play vars
9. Play vars_files
10. Role vars
11. Block vars
12. Task vars
13. Extra vars (`-e`)  ← **Highest priority**

**Interview Tip:** Extra vars (`-e`) always win!

### Using Variables

```yaml
# Simple variable
- debug:
    msg: "Hello {{ username }}"

# Dictionary access
- debug:
    msg: "DB: {{ database.host }}:{{ database.port }}"

# Alternative dictionary syntax
- debug:
    msg: "DB: {{ database['host'] }}"

# List access
- debug:
    msg: "First user: {{ users[0] }}"

# Default value
- debug:
    msg: "Port: {{ http_port | default(80) }}"
```

### Special Variables (Facts)

Ansible automatically collects system information:

```yaml
- debug:
    msg: |
      Hostname: {{ ansible_hostname }}
      OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
      IP: {{ ansible_default_ipv4.address }}
      Memory: {{ ansible_memtotal_mb }} MB
      CPUs: {{ ansible_processor_vcpus }}
```

View all facts:
```bash
ansible k3s-03 -m setup
```

### Registered Variables

Capture task output:

```yaml
- command: cat /etc/os-release
  register: os_info

- debug:
    msg: "Output: {{ os_info.stdout }}"

# Available properties:
# os_info.stdout      - Standard output
# os_info.stderr      - Standard error
# os_info.rc          - Return code
# os_info.changed     - Whether task changed anything
# os_info.failed      - Whether task failed
```

---

## Conditionals and Loops

### Conditionals (when)

```yaml
# Simple condition
- apt:
    name: apache2
  when: ansible_distribution == "Ubuntu"

# Multiple conditions (AND)
- apt:
    name: nginx
  when:
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version == "22.04"

# OR condition
- apt:
    name: httpd
  when: ansible_distribution == "CentOS" or ansible_distribution == "RedHat"

# Check variable exists
- debug:
    msg: "Variable is set"
  when: my_variable is defined

# Check if variable is true/false
- service:
    name: nginx
    state: started
  when: enable_nginx | bool

# Check registered variable
- command: which nginx
  register: nginx_check
  ignore_errors: yes

- apt:
    name: nginx
  when: nginx_check.rc != 0    # Install only if not found
```

### Loops

#### Simple Loop

```yaml
- apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - htop
```

#### Loop with Index

```yaml
- debug:
    msg: "{{ index }} - {{ item }}"
  loop:
    - apple
    - banana
    - cherry
  loop_control:
    index_var: index
```

#### Loop Over Dictionary

```yaml
- user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
  loop:
    - { name: 'alice', groups: 'admin' }
    - { name: 'bob', groups: 'developers' }
```

#### Loop with Conditional

```yaml
- apt:
    name: "{{ item }}"
  loop:
    - nginx
    - mysql
    - postgresql
  when: item != "mysql"    # Skip mysql
```

#### Nested Loops

```yaml
- debug:
    msg: "{{ item.0 }} - {{ item.1 }}"
  loop: "{{ ['a', 'b'] | product(['1', '2']) | list }}"
# Output: a-1, a-2, b-1, b-2
```

---

## Handlers

Handlers are tasks that run only when notified - typically for service restarts.

### Basic Handler

```yaml
tasks:
  - name: Update nginx config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx

  - name: Update SSL cert
    copy:
      src: cert.pem
      dest: /etc/ssl/cert.pem
    notify: Restart nginx

handlers:
  - name: Restart nginx
    service:
      name: nginx
      state: restarted
```

**Key points:**
- Handler runs ONCE at end of play, even if notified multiple times
- Handlers run in order defined, not order notified
- If play fails before handlers, handlers don't run (use `--force-handlers` to override)

### Multiple Handlers

```yaml
tasks:
  - name: Update config
    template:
      src: app.conf.j2
      dest: /etc/app/app.conf
    notify:
      - Validate config
      - Restart app

handlers:
  - name: Validate config
    command: /usr/bin/app --validate-config
  
  - name: Restart app
    service:
      name: app
      state: restarted
```

### Flush Handlers

Force handlers to run mid-play:

```yaml
tasks:
  - name: Update config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx

  - meta: flush_handlers      # Run handlers NOW

  - name: Verify nginx is running
    uri:
      url: http://localhost
```

---

## Roles

Roles are reusable, self-contained units of automation.

### Role Structure

```
roles/
  webserver/
    defaults/          # Default variables (lowest priority)
      main.yaml
    vars/              # Role variables (higher priority)
      main.yaml
    tasks/             # Task list
      main.yaml
    handlers/          # Handlers
      main.yaml
    files/             # Static files to copy
      index.html
    templates/         # Jinja2 templates
      nginx.conf.j2
    meta/              # Role metadata and dependencies
      main.yaml
```

### Creating a Role

```bash
ansible-galaxy role init roles/webserver
```

### Example Role

```yaml
# roles/webserver/defaults/main.yaml
---
http_port: 80
server_name: localhost
```

```yaml
# roles/webserver/tasks/main.yaml
---
- name: Install nginx
  apt:
    name: nginx
    state: present

- name: Configure nginx
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

- name: Start nginx
  service:
    name: nginx
    state: started
    enabled: yes
```

```yaml
# roles/webserver/handlers/main.yaml
---
- name: Restart nginx
  service:
    name: nginx
    state: restarted
```

```jinja2
# roles/webserver/templates/nginx.conf.j2
server {
    listen {{ http_port }};
    server_name {{ server_name }};
    
    location / {
        root /var/www/html;
    }
}
```

### Using Roles

```yaml
# playbook.yaml
- hosts: webservers
  roles:
    - webserver
    - { role: database, db_port: 5432 }
```

---

## Ansible Galaxy

Ansible Galaxy is a hub for sharing roles.

### Using Galaxy Roles

```bash
# Install a role
ansible-galaxy install geerlingguy.docker

# Install from requirements file
ansible-galaxy install -r requirements.yaml
```

```yaml
# requirements.yaml
roles:
  - name: geerlingguy.docker
    version: 6.1.0
  - name: geerlingguy.kubernetes
    version: 5.0.0
```

### Using in Playbook

```yaml
- hosts: all
  roles:
    - geerlingguy.docker
```

---

## Best Practices

### 1. Use Meaningful Names

```yaml
# Bad
- command: apt install nginx

# Good
- name: Install nginx web server
  apt:
    name: nginx
    state: present
```

### 2. Use Native Modules (Not command/shell)

```yaml
# Bad
- shell: apt-get install -y nginx

# Good
- apt:
    name: nginx
    state: present
```

**Why?** Modules are idempotent, command/shell are not.

### 3. Use Tags

```yaml
- name: Install packages
  apt:
    name: nginx
  tags:
    - packages
    - nginx

# Run only tagged tasks
ansible-playbook playbook.yaml --tags packages
```

### 4. Keep Secrets Safe

```bash
# Encrypt sensitive files
ansible-vault encrypt vars/secrets.yaml

# Use vault in playbook
ansible-playbook playbook.yaml --ask-vault-pass
```

### 5. Use Handlers for Restarts

```yaml
# Bad - restarts every time
- template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf

- service:
    name: nginx
    state: restarted    # Always restarts!

# Good - restarts only when changed
- template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

handlers:
  - name: Restart nginx
    service:
      name: nginx
      state: restarted
```

### 6. Directory Structure

```
ansible/
  ansible.cfg
  inventory/
    production/
      hosts.yaml
    staging/
      hosts.yaml
  group_vars/
    all.yaml
    webservers.yaml
  host_vars/
    web1.yaml
  playbooks/
    site.yaml
    webservers.yaml
  roles/
    common/
    webserver/
  files/
  templates/
```

---

## Common Interview Questions

### Q1: What is Ansible and why use it?

**Answer:** Ansible is an agentless IT automation tool that uses SSH to configure systems. Benefits:
- No agents to install/maintain
- YAML-based (human-readable)
- Idempotent (safe to re-run)
- Large module library
- Easy learning curve

### Q2: Explain idempotency in Ansible

**Answer:** Idempotency means running a playbook multiple times produces the same result. Example:

```yaml
- apt:
    name: nginx
    state: present
```

First run: Installs nginx (changed)
Second run: Nginx already installed, no action (ok)

This is why you should use modules instead of command/shell.

### Q3: What is the difference between command and shell?

**Answer:**
- `command`: Runs command directly, no shell features (no pipes, redirects, env vars)
- `shell`: Runs through shell (/bin/sh), supports pipes, redirects, variables

```yaml
# command - this fails
- command: cat /etc/passwd | grep root    # No pipes!

# shell - this works
- shell: cat /etc/passwd | grep root
```

### Q4: Explain variable precedence

**Answer:** From lowest to highest priority:
1. Role defaults
2. Inventory vars
3. Playbook vars
4. Role vars
5. Extra vars (-e) - **always wins**

### Q5: What are handlers?

**Answer:** Handlers are tasks that only run when notified. Useful for service restarts.

Key points:
- Run at end of play
- Run only once even if notified multiple times
- Run in order defined, not notified

### Q6: How do you manage secrets?

**Answer:** Use `ansible-vault`:
```bash
ansible-vault encrypt secrets.yaml
ansible-vault decrypt secrets.yaml
ansible-vault edit secrets.yaml
ansible-playbook playbook.yaml --ask-vault-pass
```

### Q7: Explain roles

**Answer:** Roles are reusable, self-contained automation units with:
- tasks/ - Task definitions
- handlers/ - Handler definitions
- vars/ - Variables
- defaults/ - Default variables
- files/ - Static files
- templates/ - Jinja2 templates
- meta/ - Dependencies

### Q8: How do you test Ansible playbooks?

**Answer:**
1. **Syntax check:** `ansible-playbook --syntax-check`
2. **Dry run:** `ansible-playbook --check`
3. **Verbose:** `ansible-playbook -vvv`
4. **Molecule:** Testing framework for roles
5. **Ansible-lint:** Static analysis

### Q9: What is the difference between import and include?

**Answer:**
- `import_*`: Static, processed at playbook parse time
- `include_*`: Dynamic, processed at runtime

```yaml
# Static - variables not available
- import_tasks: tasks.yaml

# Dynamic - can use variables
- include_tasks: "{{ task_file }}.yaml"
```

### Q10: How do you handle different environments?

**Answer:** Use separate inventory files:

```bash
ansible-playbook -i inventory/production playbook.yaml
ansible-playbook -i inventory/staging playbook.yaml
```

Or use group_vars:
```
group_vars/
  production.yaml
  staging.yaml
```

---

## Our K3S Project Examples

### Inventory

```yaml
# ansible/inventory/hosts.yaml
all:
  vars:
    ansible_user: tech
    ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    ansible_python_interpreter: /usr/bin/python3

  children:
    control_plane:
      hosts:
        k3s-03:
          ansible_host: 192.168.1.46
        k3s-04:
          ansible_host: 192.168.1.198
        k3s-05:
          ansible_host: 192.168.1.92

    workers:
      hosts:
        k3s-01:
          ansible_host: 192.168.1.113
        k3s-02:
          ansible_host: 192.168.1.171

    k3s_cluster:
      children:
        control_plane:
        workers:
```

### Health Check Playbook

```yaml
# ansible/playbooks/health-check.yaml
- name: K3S Cluster Health Check
  hosts: k3s_cluster
  become: true

  tasks:
    - name: Check disk space
      shell: df -h / | tail -1 | awk '{print $5}'
      register: disk_usage

    - name: Display health
      debug:
        msg: "{{ inventory_hostname }}: Disk {{ disk_usage.stdout }}"
```

### Rolling Upgrade Playbook

```yaml
# ansible/playbooks/upgrade.yaml
- name: Upgrade all K3S nodes
  hosts: k3s_cluster
  become: true
  serial: 1                   # One node at a time!

  tasks:
    - name: Upgrade packages
      apt:
        upgrade: dist
```

**`serial: 1`** ensures nodes upgrade one-by-one, maintaining cluster availability.

---

## Quick Reference

### Essential Commands

```bash
# Test connectivity
ansible all -m ping

# Run ad-hoc command
ansible all -a "uptime"

# Run playbook
ansible-playbook playbook.yaml

# Dry run
ansible-playbook playbook.yaml --check

# Limit to hosts
ansible-playbook playbook.yaml --limit k3s-03

# List hosts in inventory
ansible-inventory --list

# View host facts
ansible k3s-03 -m setup
```

### Common Modules

| Module | Purpose |
|--------|---------|
| `apt` | Manage Debian packages |
| `yum` | Manage RHEL packages |
| `copy` | Copy files |
| `template` | Copy with Jinja2 |
| `file` | Manage files/dirs |
| `service` | Manage services |
| `systemd` | Manage systemd units |
| `command` | Run commands |
| `shell` | Run shell commands |
| `user` | Manage users |
| `group` | Manage groups |
| `debug` | Print messages |

---

## Next Steps

1. **Practice locally:** Create a simple playbook
2. **Run against your cluster:** `ansible-playbook playbooks/health-check.yaml`
3. **Create a custom role:** Extract common tasks
4. **Learn Ansible Vault:** Encrypt secrets
5. **Explore Ansible Galaxy:** Use community roles

Good luck with your interview!
