# Networking Guide

Network architecture for TelemetryFlow across Docker Compose and Kubernetes deployments.

## Docker Network Diagram

All Docker Compose services share a bridge network (`telemetryflow_platform_net`) with fixed IPs in the `172.151.0.0/16` subnet.

```mermaid
graph LR
    subgraph "Docker Bridge: telemetryflow_platform_net (172.151.0.0/16)"
        direction TB

        subgraph "Infrastructure"
            PG["PostgreSQL<br/>172.151.151.20<br/>:5432"]
            CH["ClickHouse<br/>172.151.151.40<br/>:8123 HTTP<br/>:9000 Native"]
            RD["Redis<br/>172.151.151.50<br/>:6379"]
            NT["NATS<br/>172.151.151.55<br/>:4222 Client<br/>:8222 Management"]
        end

        subgraph "Application"
            BE["Backend<br/>172.151.151.10<br/>:3000"]
            FE["Frontend<br/>172.151.151.15<br/>:80"]
        end

        subgraph "Monitoring"
            COL["Collector<br/>172.151.151.30<br/>:4317 gRPC<br/>:4318 HTTP<br/>:8889 Metrics<br/>:13133 Health"]
            AG["Agent<br/>172.151.151.35<br/>:2025"]
        end

        subgraph "Tools"
            PT["Portainer<br/>172.151.151.5<br/>:9000 HTTP<br/>:9443 HTTPS"]
        end
    end

    subgraph "Host"
        H3000["localhost:3000"]
        H8080["localhost:8080"]
        H4317["localhost:4317"]
        H4318["localhost:4318"]
        H5432["localhost:5432"]
        H8123["localhost:8123"]
        H9000["localhost:9000"]
    end

    H3000 -->|"Port Map"| BE
    H8080 -->|"Port Map"| FE
    H4317 -->|"Port Map"| COL
    H4318 -->|"Port Map"| COL
    H5432 -->|"Port Map"| PG
    H8123 -->|"Port Map"| CH
    H9000 -->|"Port Map"| PT
```

## Kubernetes Networking Diagram

```mermaid
graph TB
    subgraph "External"
        USERS["Users / Browsers"]
        AGENTS["Remote TFO Agents"]
        DNS_EXT["External DNS"]
    end

    subgraph "Cluster Ingress"
        ING["Ingress Controller<br/>:80 :443"]
    end

    subgraph "Namespace: telemetryflow"
        subgraph "Services (ClusterIP)"
            SVC_VIZ["tfo-viz<br/>ClusterIP :8080"]
            SVC_BE["tfo-backend<br/>ClusterIP :8080"]
            SVC_COL["tfo-collector<br/>ClusterIP :4317 :4318"]
            SVC_PG["postgresql<br/>ClusterIP :5432"]
            SVC_CH["clickhouse<br/>ClusterIP :8123 :9000"]
            SVC_RD_CACHE["cache-redis<br/>ClusterIP :6379"]
            SVC_RD_BULL["redis-master<br/>ClusterIP :6379"]
            SVC_NT["nats<br/>ClusterIP :4222"]
        end

        subgraph "Pods"
            POD_VIZ["tfo-viz pods"]
            POD_BE["tfo-backend pods"]
            POD_COL["tfo-collector pods"]
            DS_AGENT["tfo-agent DaemonSet<br/>hostNetwork: true"]
            STS_PG["postgresql StatefulSet"]
            STS_CH["clickhouse StatefulSet"]
        end
    end

    USERS --> ING
    AGENTS -->|OTLP + TLS| SVC_COL
    DNS_EXT --> ING
    ING --> SVC_VIZ
    ING --> SVC_BE
    SVC_VIZ --> POD_VIZ
    SVC_BE --> POD_BE
    SVC_COL --> POD_COL
    DS_AGENT -->|"OTLP"| SVC_COL
    POD_COL -->|"OTLP HTTP"| SVC_BE
    POD_BE --> SVC_PG & SVC_CH & SVC_RD_CACHE & SVC_RD_BULL & SVC_NT
    SVC_PG --> STS_PG
    SVC_CH --> STS_CH

    style USERS fill:#f3e5f5
    style AGENTS fill:#f3e5f5
    style SVC_COL fill:#fff3e0
    style SVC_BE fill:#e8f5e9
    style SVC_PG fill:#fce4ec
    style SVC_CH fill:#fce4ec
```

## Port Reference Table

### Application Ports

| Port  | Protocol | Service                         | Internal/External                  | Description             |
| ----- | -------- | ------------------------------- | ---------------------------------- | ----------------------- |
| 80    | HTTP     | TFO Viz (via Ingress)           | External                           | Frontend dashboard      |
| 443   | HTTPS    | TFO Viz / Backend (via Ingress) | External                           | TLS frontend + API      |
| 3000  | HTTP     | TFO Backend                     | External (Docker) / Internal (K8s) | REST API server         |
| 8080  | HTTP     | TFO Backend (K8s)               | Internal                           | Container port (K8s)    |
| 80    | HTTP     | TFO Viz container               | Internal                           | Frontend container port |
| 2025  | HTTP     | TFO Agent                       | External (Docker)                  | Agent status/metrics    |
| 4317  | gRPC     | TFO Collector                   | Agents                             | OTLP gRPC receiver      |
| 4318  | HTTP     | TFO Collector                   | Agents                             | OTLP HTTP receiver      |
| 8889  | HTTP     | TFO Collector                   | Internal                           | Prometheus metrics      |
| 13133 | HTTP     | TFO Collector / Agent           | Internal                           | Health check            |

### Infrastructure Ports

| Port | Protocol | Service    | Internal/External | Description              |
| ---- | -------- | ---------- | ----------------- | ------------------------ |
| 5432 | TCP      | PostgreSQL | Internal          | PostgreSQL wire protocol |
| 8123 | HTTP     | ClickHouse | Internal          | HTTP interface           |
| 9000 | TCP      | ClickHouse | Internal          | Native protocol          |
| 6379 | TCP      | Redis      | Internal          | Redis protocol           |
| 4222 | TCP      | NATS       | Internal          | Client connections       |
| 8222 | HTTP     | NATS       | Internal          | Management/monitoring    |

### Tooling Ports

| Port | Protocol | Service   | Internal/External | Description              |
| ---- | -------- | --------- | ----------------- | ------------------------ |
| 9000 | HTTP     | Portainer | External (Docker) | Container management UI  |
| 9443 | HTTPS    | Portainer | External (Docker) | Container management TLS |

### Kubernetes Cluster Ports

| Port  | Protocol | Service            | Direction     | Description               |
| ----- | -------- | ------------------ | ------------- | ------------------------- |
| 6443  | TCP      | Kubernetes API     | Inbound       | API server                |
| 9345  | TCP      | RKE2 Server        | Inbound       | RKE2 server communication |
| 2379  | TCP      | etcd               | Intra-cluster | etcd client               |
| 2380  | TCP      | etcd               | Intra-cluster | etcd peer                 |
| 10250 | TCP      | kubelet            | Intra-cluster | Kubelet API               |
| 8472  | UDP      | Canal/VXLAN        | Intra-cluster | Pod overlay network       |
| 51820 | UDP      | WireGuard (Cilium) | Intra-cluster | Encrypted overlay         |

## Ingress Configuration

### Basic Ingress (Staging)

```yaml
# Helm values override
tfoViz:
  ingress:
    enabled: true
    className: "nginx"
    host: telemetryflow.staging.example.com
    tls: false
```

### TLS Ingress (Production)

```yaml
tfoViz:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/rate-limit: "100"
    tls: true
    tlsSecretName: telemetryflow-viz-tls
    host: telemetryflow.example.com

tfoBackend:
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    tls: true
    tlsSecretName: telemetryflow-backend-tls
    host: api.telemetryflow.example.com
```

### Collector Ingress (Agent Traffic)

```yaml
# Separate ingress for OTLP receiver
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tfo-collector
  namespace: telemetryflow
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - otlp.telemetryflow.example.com
      secretName: telemetryflow-collector-tls
  rules:
    - host: otlp.telemetryflow.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tfo-collector
                port:
                  number: 4317
```

## DNS Configuration

### Kubernetes Internal

CoreDNS resolves services within the cluster:

```
tfo-backend.telemetryflow.svc.cluster.local
tfo-collector.telemetryflow.svc.cluster.local
tfo-viz.telemetryflow.svc.cluster.local
postgresql.telemetryflow.svc.cluster.local
clickhouse.telemetryflow.svc.cluster.local
cache-redis.telemetryflow.svc.cluster.local
redis-master.telemetryflow.svc.cluster.local
nats.telemetryflow.svc.cluster.local
```

Short names work within the same namespace:

```
tfo-backend:8080
tfo-collector:4317
postgresql:5432
clickhouse:8123
```

### External DNS

For production, configure external DNS to resolve ingress hosts:

```
telemetryflow.example.com       → Ingress LB IP
api.telemetryflow.example.com   → Ingress LB IP
otlp.telemetryflow.example.com  → Ingress LB IP
```

## Firewall Requirements

### Docker Compose (VM)

| Direction | Port | Source | Destination | Purpose            |
| --------- | ---- | ------ | ----------- | ------------------ |
| Inbound   | 80   | All    | Host        | Frontend HTTP      |
| Inbound   | 443  | All    | Host        | Frontend/API HTTPS |
| Inbound   | 3000 | Admin  | Host        | Backend API (dev)  |
| Inbound   | 4317 | Agents | Host        | OTLP gRPC          |
| Inbound   | 4318 | Agents | Host        | OTLP HTTP          |
| Inbound   | 22   | Admin  | Host        | SSH (Ansible)      |

### Kubernetes Cluster

| Direction | Port       | Source         | Destination | Purpose             |
| --------- | ---------- | -------------- | ----------- | ------------------- |
| Inbound   | 6443       | Admin, Masters | Masters     | Kubernetes API      |
| Inbound   | 9345       | Workers        | Masters     | RKE2 server         |
| Inbound   | 80         | All            | LB/Ingress  | HTTP                |
| Inbound   | 443        | All            | LB/Ingress  | HTTPS               |
| Intra     | 2379, 2380 | Masters        | Masters     | etcd                |
| Intra     | 10250      | All nodes      | All nodes   | kubelet             |
| Intra     | 8472/UDP   | All nodes      | All nodes   | Canal VXLAN overlay |
| Intra     | 30000      | Masters        | Masters     | etcd metrics        |

### Network Isolation Recommendations

```mermaid
flowchart TD
    INTERNET["Internet"] -->|:80 :443| LB["Load Balancer"]
    LB --> ING["Ingress Controller"]

    ING -->|HTTP| VIZ_NS["Namespace: telemetryflow<br/>tfo-viz, tfo-backend"]
    ING -->|HTTP| API_NS["Namespace: telemetryflow<br/>tfo-backend API"]

    AGENTS_EXT["External Agents"] -->|:4317 :4318 TLS+Auth| COL_NS["Namespace: telemetryflow<br/>tfo-collector"]

    COL_NS --> VIZ_NS
    VIZ_NS --> DATA_NS["Namespace: telemetryflow<br/>PostgreSQL, ClickHouse, Redis, NATS"]

    DATA_NS -.->|No external access| BLOCKED["Blocked"]

    style DATA_NS fill:#fce4ec
    style BLOCKED fill:#ffcdd2
    style COL_NS fill:#fff3e0
```
