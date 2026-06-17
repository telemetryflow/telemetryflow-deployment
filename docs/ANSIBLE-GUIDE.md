# Ansible Guide

Detailed guide for deploying TelemetryFlow using Ansible for both VM/bare-metal and Kubernetes (RKE2) environments.

## VM 3-Node Deployment

Deploys TelemetryFlow across three VMs with dedicated roles: platform, database, and analytics.

```mermaid
graph TB
    subgraph "VM Node 1 — Platform (tfo_platform_role: node)"
        B["TFO Backend :3000"]
        COL["TFO Collector :4317/:4318"]
        VIZ["TFO Viz :8080"]
        R["Redis :6379"]
        N["NATS :4222"]
        AG["TFO Agent (systemd)"]
        PT["Portainer :9100"]
    end

    subgraph "VM Node 2 — Database (tfo_platform_role: db)"
        PG[("PostgreSQL :5432")]
    end

    subgraph "VM Node 3 — Analytics (tfo_platform_role: clickhouse)"
        CH[("ClickHouse :8123/:9000")]
    end

    AG -->|"OTLP gRPC"| COL
    COL -->|"OTLP HTTP"| B
    B --> PG
    B --> CH
    B --> R
    B --> N
    VIZ -->|"/api"| B

    style B fill:#e8f5e9
    style COL fill:#fff3e0
    style PG fill:#fce4ec
    style CH fill:#fce4ec
```

## VM Multi-Node Deployment

Extends the 3-node layout with dedicated agent VMs for distributed host monitoring.

```mermaid
graph TB
    subgraph "VM Node 1 — Platform (tfo_platform_role: node)"
        B["TFO Backend :3000"]
        COL["TFO Collector :4317/:4318"]
        VIZ["TFO Viz :8080"]
        R["Redis :6379"]
        N["NATS :4222"]
        AG0["TFO Agent (systemd)"]
        PT["Portainer :9100"]
    end

    subgraph "VM Node 2 — Database (tfo_platform_role: db)"
        PG[("PostgreSQL :5432")]
    end

    subgraph "VM Node 3 — Analytics (tfo_platform_role: clickhouse)"
        CH[("ClickHouse :8123/:9000")]
    end

    subgraph "Agent VMs (tfo_agents group)"
        AG1["TFO Agent — VM 1<br/>systemd service"]
        AG2["TFO Agent — VM 2<br/>systemd service"]
        AG3["TFO Agent — VM N<br/>systemd service"]
    end

    AG0 & AG1 & AG2 & AG3 -->|"OTLP gRPC"| COL
    COL -->|"OTLP HTTP"| B
    B --> PG
    B --> CH
    B --> R
    B --> N
    VIZ -->|"/api"| B

    style B fill:#e8f5e9
    style COL fill:#fff3e0
    style PG fill:#fce4ec
    style CH fill:#fce4ec
    style AG1 fill:#f3e5f5
    style AG2 fill:#f3e5f5
    style AG3 fill:#f3e5f5
```

## VM Deployment Workflow

```mermaid
flowchart TD
    START(["ansible-playbook site.yml"]) --> PING["Ping all hosts"]
    PING --> PLATFORM["Deploy platform<br/>(hosts: tfo_platform)"]
    PING --> DOCKER_ROLE["Install Docker<br/>(hosts: tfo_agents + tfo_platform)"]
    PING --> AGENT_ROLE["Deploy agent binary<br/>(hosts: tfo_agents + tfo_platform)"]

    PLATFORM --> ROLE_DISPATCH{"tfo_platform_role?"}
    ROLE_DISPATCH -->|node| BACKEND["tfo-backend container"]
    ROLE_DISPATCH -->|node| COLLECTOR["tfo-collector container"]
    ROLE_DISPATCH -->|node| REDIS["tfo-redis container"]
    ROLE_DISPATCH -->|node| NATS["tfo-nats container"]
    ROLE_DISPATCH -->|node| VIZ["tfo-viz container"]
    ROLE_DISPATCH -->|node| PORTAINER["tfo-portainer (optional)"]
    ROLE_DISPATCH -->|db| POSTGRES["tfo-postgres container"]
    ROLE_DISPATCH -->|clickhouse| CLICKHOUSE["tfo-clickhouse container"]

    DOCKER_ROLE --> DOCKER_INSTALL["docker-install role"]
    AGENT_ROLE --> AGENT_BIN["tfo-agent-binary role<br/>systemd service"]

    BACKEND & COLLECTOR & REDIS & NATS & VIZ & PORTAINER & POSTGRES & CLICKHOUSE --> HEALTH["Health Checks"]
    AGENT_BIN --> HEALTH
    HEALTH --> DONE([Complete])

    style START fill:#e1f5fe
    style DONE fill:#c8e6c9
```

### Playbook Execution Order

| Playbook                | Hosts                     | Purpose                                   |
| ----------------------- | ------------------------- | ----------------------------------------- |
| `site.yml`              | all                       | Master playbook — orchestrates all others |
| `ping-all.yml`          | all                       | Connectivity test                         |
| `install-docker.yml`    | tfo_agents, tfo_platform  | Install Docker Engine + Compose           |
| `deploy-platform.yml`   | tfo_platform              | Dispatch sub-roles by `tfo_platform_role` |
| `deploy-postgres.yml`   | tfo_platform (db)         | PostgreSQL container                      |
| `deploy-clickhouse.yml` | tfo_platform (clickhouse) | ClickHouse container                      |
| `deploy-backend.yml`    | tfo_platform (node)       | Backend container                         |
| `deploy-collector.yml`  | tfo_platform (node)       | Collector container                       |
| `deploy-agent.yml`      | tfo_agents, tfo_platform  | Agent systemd service                     |
| `cleanup-platform.yml`  | tfo_platform              | Remove platform containers                |
| `cleanup-agent.yml`     | tfo_agents                | Remove agent binary and service           |

## K8s Deployment Workflow

Provisions an RKE2 Kubernetes cluster from bare-metal/VM nodes, then deploys TelemetryFlow via Helm.

```mermaid
flowchart TD
    START(["ansible-playbook site.yml"]) --> P0

    subgraph "Phase 0 — Prerequisites"
        P0["00-prerequisites.yml"] --> PKG["Install system packages"]
        PKG --> KERNEL["Load kernel modules"]
        KERNEL --> SYSCTL["Configure sysctl"]
        SYSCTL --> NTP["Configure NTP"]
    end

    P0 --> P1

    subgraph "Phase 1 — RKE2 Install"
        P1["01-rke2-install.yml"] --> DOWNLOAD["Download RKE2"]
        DOWNLOAD --> MASTERS{Node Type?}
        MASTERS -->|Master| SERVER["rke2-server"]
        MASTERS -->|Worker| AGENT["rke2-agent"]
        SERVER --> WAIT_API["Wait for API :6443"]
        AGENT --> WAIT_AGENT["Wait for agent :9345"]
    end

    P1 --> P2

    subgraph "Phase 2 — Post Install"
        P2["02-post-install.yml"] --> LABELS["Apply node labels"]
        LABELS --> TAINTS["Apply node taints"]
        TAINTS --> KUBECONFIG["Fetch kubeconfig"]
    end

    P2 --> P3

    subgraph "Phase 3 — Deploy TelemetryFlow"
        P3["03-deploy-telemetryflow.yml"] --> HELM_INSTALL["Install Helm"]
        HELM_INSTALL --> NS["Create namespace"]
        NS --> DEPLOY["helm upgrade --install<br/>-f manifest/tfo-staging.yaml"]
    end

    P3 --> P4

    subgraph "Phase 4 — Maintenance"
        P4["04-maintenance.yml"] --> VERIFY["Verify pod health"]
        VERIFY --> STATUS["Check Helm status"]
    end

    STATUS --> DONE([Complete])

    style START fill:#e1f5fe
    style DONE fill:#c8e6c9
```

## Inventory Configuration

### VM Inventory (`ansible/inventory.yml`)

```yaml
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no"

  tfo_agents:
    hosts:
      agent-01:
        ansible_host: 10.0.0.10
        ansible_user: "<CHANGE_ME>"

  tfo_platform:
    children:
      tfo_node:
        hosts:
          platform-node:
            ansible_host: 10.0.1.10
            ansible_user: "<CHANGE_ME>"
            tfo_platform_role: node
      tfo_db:
        hosts:
          platform-db:
            ansible_host: 10.0.1.20
            ansible_user: "<CHANGE_ME>"
            tfo_platform_role: db
      tfo_clickhouse:
        hosts:
          platform-clickhouse:
            ansible_host: 10.0.1.30
            ansible_user: "<CHANGE_ME>"
            tfo_platform_role: clickhouse
```

### K8s Inventory (`ansible-k8s/inventory/hosts.yml`)

```yaml
all:
  children:
    masters:
      hosts:
        master-01:
          ansible_host: 10.0.1.10
    workers:
      hosts:
        worker-01:
          ansible_host: 10.0.2.10
  vars:
    ansible_python_interpreter: /usr/bin/python3
    ansible_user: ubuntu
```

### host_vars Configuration

Per-host variables override group_vars for node-specific settings:

```yaml
# ansible/host_vars/platform-node.yml
ansible_host: 10.0.1.10
tfo_platform_role: node
tfo_backend_port: 3000
tfo_collector_grpc_port: 4317

# ansible/host_vars/platform-db.yml
ansible_host: 10.0.1.20
tfo_platform_role: db
tfo_postgres_port: 5432

# ansible/host_vars/agent-01.yml
ansible_host: 10.0.0.10
tfo_collector_host: "10.0.1.10"
tfo_collector_grpc_port: 4317
```

## Variable Hierarchy

```mermaid
graph TD
    subgraph "VM Deployment"
        GV_ALL["group_vars/all.yml<br/>Versions, collector host,<br/>API keys, environment"]
        GV_PLAT["group_vars/tfo_platform.yml<br/>Container IPs, DB credentials,<br/>network config, secrets"]
        GV_AGENTS["group_vars/tfo_agents.yml<br/>Agent install dirs, log level"]
        HV["host_vars/<host>.yml<br/>Per-host overrides"]
        ROLE_DEFAULTS["Role defaults/<br/>Per-role defaults"]

        GV_ALL --> GV_PLAT
        GV_ALL --> GV_AGENTS
        GV_PLAT --> HV
        GV_AGENTS --> HV
        HV --> ROLE_DEFAULTS
    end

    subgraph "K8s Deployment"
        K8S_ALL["inventory/group_vars/all.yml<br/>RKE2 version, cluster CIDR,<br/>Helm config, DNS"]
        K8S_ROLES["Role defaults/<br/>Common packages, RKE2 paths"]

        K8S_ALL --> K8S_ROLES
    end

    style GV_ALL fill:#e1f5fe
    style GV_PLAT fill:#fff3e0
    style GV_AGENTS fill:#e8f5e9
    style HV fill:#f3e5f5
    style K8S_ALL fill:#e1f5fe
```

### Priority Order (highest to lowest)

1. **CLI extra vars** (`-e "key=value"`)
2. **host_vars** (by host)
3. **group_vars** (by group)
4. **Role defaults** (`roles/<role>/defaults/main.yml`)

## Role Descriptions

### VM Roles (`ansible/roles/`)

| Role               | Purpose                                                               | Key Defaults                                                        |
| ------------------ | --------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `docker-install`   | Installs Docker Engine and Compose plugin                             | `docker_engine_version: "25.0"`, `docker_compose_version: "2.24.5"` |
| `net-tools`        | Installs network diagnostic utilities                                 | curl, wget, iproute2                                                |
| `tfo-platform`     | Orchestrator role — dispatches sub-roles based on `tfo_platform_role` | —                                                                   |
| `tfo-postgres`     | Deploys PostgreSQL container                                          | Image: `postgres:16-alpine`, Port: 5432                             |
| `tfo-clickhouse`   | Deploys ClickHouse container                                          | Image: `clickhouse/clickhouse-server:24-alpine`                     |
| `tfo-redis`        | Deploys Redis container                                               | Image: `redis:7-alpine`                                             |
| `tfo-nats`         | Deploys NATS JetStream container                                      | Image: `nats:2-alpine`                                              |
| `tfo-backend`      | Deploys TFO Backend container                                         | Health check on `:3000`                                             |
| `tfo-collector`    | Deploys OTel Collector container                                      | Image: `otel/opentelemetry-collector-contrib:latest`                |
| `tfo-viz`          | Deploys TFO Viz frontend container                                    | HTTP port 80                                                        |
| `tfo-agent-binary` | Installs TFO Agent as systemd service                                 | Binary from releases.telemetryflow.io                               |
| `tfo-portainer`    | Deploys Portainer CE container (optional)                             | Controlled by `tfo_portainer_enabled`                               |
| `cleanup-platform` | Removes platform containers and data                                  | —                                                                   |
| `cleanup-agent`    | Removes agent binary and systemd service                              | —                                                                   |

### K8s Roles (`ansible-k8s/roles/`)

| Role           | Purpose                                                    |
| -------------- | ---------------------------------------------------------- |
| `common`       | System packages, kernel modules, sysctl configuration      |
| `rke2`         | Download, install, and configure RKE2 server/agent         |
| `post-install` | Node labels, taints, and kubeconfig retrieval              |
| `helm`         | Install Helm, create namespace, deploy TelemetryFlow chart |
| `maintenance`  | Post-deployment health verification                        |

## Common Operations

### Deploy

```bash
# Full VM deployment
ansible-playbook ansible/playbooks/site.yml -i ansible/inventory.yml

# Full K8s deployment
cd ansible-k8s && ansible-playbook playbooks/site.yml

# Specific component only
ansible-playbook ansible/playbooks/deploy-backend.yml -i ansible/inventory.yml --tags backend
```

### Update

```bash
# Update a single component image
ansible-playbook ansible/playbooks/deploy-backend.yml -i ansible/inventory.yml \
  -e "tfo_backend_version=1.5.0"

# Update K8s via Helm
cd ansible-k8s
ansible-playbook playbooks/03-deploy-telemetryflow.yml \
  -e "telemetryflow_chart_version=1.1.0"
```

### Rollback

```bash
# VM — redeploy previous version
ansible-playbook ansible/playbooks/deploy-backend.yml -i ansible/inventory.yml \
  -e "tfo_backend_version=1.4.2"

# K8s — Helm rollback
helm rollback telemetryflow <REVISION> -n telemetryflow
```

### Scale

```bash
# Add a new agent host — add to inventory, then:
ansible-playbook ansible/playbooks/deploy-agent.yml -i ansible/inventory.yml --limit agent-03

# Add a K8s worker — add to inventory, then:
cd ansible-k8s
ansible-playbook playbooks/00-prerequisites.yml --limit worker-04
ansible-playbook playbooks/01-rke2-install.yml --limit worker-04
```

## Troubleshooting

### VM Deployment

| Issue                 | Diagnosis                                           | Resolution                                     |
| --------------------- | --------------------------------------------------- | ---------------------------------------------- |
| Host unreachable      | `ansible all -m ping`                               | Check SSH access, firewall, inventory IPs      |
| Docker not installed  | `ssh host "docker --version"`                       | Run `install-docker.yml` playbook              |
| Container won't start | `docker logs <container>`                           | Check environment variables and ports          |
| Network conflict      | `docker network inspect telemetryflow_platform_net` | Adjust subnet in `group_vars/tfo_platform.yml` |
| Agent not reporting   | `systemctl status tfo-agent`                        | Verify collector host and port                 |

### K8s Deployment

| Issue                   | Diagnosis                                    | Resolution                                   |
| ----------------------- | -------------------------------------------- | -------------------------------------------- |
| RKE2 server won't start | `journalctl -u rke2-server -f`               | Check `rke2_token`, firewall ports 6443/9345 |
| Worker not joining      | `journalctl -u rke2-agent -f`                | Verify token, server IP, port 9345           |
| Helm install fails      | `helm status telemetryflow -n telemetryflow` | Check manifest file, chart version           |
| Pods pending            | `kubectl describe pod <name>`                | Check node resources, PVC binding            |
| etcd issues             | `etcdctl endpoint health`                    | Check disk space, quorum                     |

### Useful Commands

```bash
# Verbose Ansible output
ansible-playbook site.yml -vvv

# Dry run (check mode)
ansible-playbook site.yml --check

# Limit to specific hosts
ansible-playbook site.yml --limit platform-node

# Tags only
ansible-playbook site.yml --tags backend
```
