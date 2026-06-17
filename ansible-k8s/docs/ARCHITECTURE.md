# Architecture — TelemetryFlow Kubernetes Cluster

## Overview

TelemetryFlow is deployed on an RKE2 (Rancher) Kubernetes cluster provisioned via Ansible. The architecture follows a control-plane / worker-node pattern suitable for on-premises and edge deployments.

## Cluster Topology

```mermaid
graph TB
    subgraph "Control Plane — Masters"
        M1["master-01<br/>RKE2 Server<br/>etcd + API + Scheduler"]
        M2["master-02<br/>RKE2 Server<br/>etcd + API + Scheduler"]
        M3["master-03<br/>RKE2 Server<br/>etcd + API + Scheduler"]
    end

    subgraph "Worker Nodes"
        W1["worker-01<br/>RKE2 Agent"]
        W2["worker-02<br/>RKE2 Agent"]
        W3["worker-03<br/>RKE2 Agent"]
    end

    M1 --- W1
    M1 --- W2
    M1 --- W3
    M2 --- W1
    M2 --- W2
    M2 --- W3
    M3 --- W1
    M3 --- W2
    M3 --- W3
```

## Deployment Pipeline

```mermaid
flowchart LR
    A["00-prerequisites"] --> B["01-rke2-install"]
    B --> C["02-post-install"]
    C --> D["03-deploy-telemetryflow"]
    D --> E["04-maintenance"]
```

## Ansible Role Interaction

```mermaid
flowchart TD
    Site["site.yml"] --> P0["00-prerequisites"]
    Site --> P1["01-rke2-install"]
    Site --> P2["02-post-install"]
    Site --> P3["03-deploy-telemetryflow"]
    Site --> P4["04-maintenance"]

    P0 --> R_Common["roles/common"]
    P1 --> R_RKE2["roles/rke2"]
    P2 --> R_Post["roles/post-install"]
    P3 --> R_Helm["roles/helm"]
    P4 --> R_Maint["roles/maintenance"]
```

## Network Layout

```mermaid
graph LR
    subgraph "Cluster Network"
        direction TB
        CP["Control Plane CIDR<br/>10.0.1.0/24"]
        WK["Worker CIDR<br/>10.0.2.0/24"]
    end

    subgraph "Overlay Networks"
        Pod["Pod CIDR<br/>10.42.0.0/16<br/>(Canal / Cilium)"]
        Svc["Service CIDR<br/>10.43.0.0/16"]
    end

    subgraph "External"
        LB["Load Balancer / VIP"]
        DNS["External DNS"]
    end

    LB --> CP
    DNS --> CP
    CP --> WK
    WK --> Pod
    CP --> Svc
```

## Component Stack

| Layer         | Component            | Purpose                                   |
| ------------- | -------------------- | ----------------------------------------- |
| OS            | Ubuntu 22.04/24.04   | Base operating system                     |
| Container     | containerd (RKE2)    | Container runtime                         |
| Orchestration | RKE2 v1.31.x         | Kubernetes distribution                   |
| CNI           | Canal / Cilium       | Pod networking                            |
| DNS           | CoreDNS              | Cluster DNS resolution                    |
| Ingress       | NGINX / Traefik      | HTTP/HTTPS traffic routing                |
| Storage       | Local / NFS / CSI    | Persistent volume provisioning            |
| Deploy        | Helm                 | TelemetryFlow application deployment      |
| Monitoring    | TelemetryFlow Agent  | Observability data collection             |

## Directory Structure

```
ansible-k8s/
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       └── all.yml
├── playbooks/
│   ├── 00-prerequisites.yml
│   ├── 01-rke2-install.yml
│   ├── 02-post-install.yml
│   ├── 03-deploy-telemetryflow.yml
│   ├── 04-maintenance.yml
│   └── site.yml
├── roles/
│   ├── common/
│   ├── rke2/
│   ├── helm/
│   ├── post-install/
│   └── maintenance/
└── docs/
    ├── ARCHITECTURE.md
    ├── RUNBOOK.md
    └── VARIABLES.md
```
