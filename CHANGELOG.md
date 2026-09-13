<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg">
    <img src="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg" alt="TelemetryFlow Logo" width="80%">
  </picture>

  <h3>TelemetryFlow Deployment</h3>

[![Version](https://img.shields.io/badge/Version-2.0.0-orange.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)](https://hub.docker.com/r/telemetryflow/telemetryflow-platform)
[![Go](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&style=flat-square)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&style=flat-square)](https://www.postgresql.org/)
[![ClickHouse](https://img.shields.io/badge/ClickHouse-26.7-FFCC00?logo=clickhouse&style=flat-square)](https://clickhouse.com/)
[![Valkey](https://img.shields.io/badge/Valkey-9-DC382D?logo=valkey&style=flat-square)](https://valkey.io/)
[![NATS](https://img.shields.io/badge/NATS-2-27AAE1?logo=nats.io&style=flat-square)](https://nats.io/)
[![RKE2](https://img.shields.io/badge/RKE2-%3E%3D1.36-orange?style=flat-square)](https://docs.rke2.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%3E%3D1.36-326CE5?logo=kubernetes&style=flat-square)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm%20Chart-v2.1.0-0F1689?logo=helm&style=flat-square)](https://helm.sh/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.16-000000?logo=ansible&style=flat-square)](https://www.ansible.com/)

<center>Production-Ready Infrastructure & Deployment Standards for the
<br><strong>TelemetryFlow Observability Platform</strong></center>

</div>

---

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-09-12

### ⚠️ Breaking Changes

- **Namespace**: all Kubernetes resources now default to **`observability`** (was `telemetryflow`) — chart default, all values overlays, deploy scripts, and docs. Release name stays `telemetryflow`.
- **Valkey replaces Redis (VM stack)**: `ansible` role `tfo_redis` → `tfo_valkey` (`valkey/valkey:9-alpine`), env `VALKEY_*`/`BULLMQ_VALKEY_*`/`CACHE_L2_PROVIDER=valkey`. Existing deployments get a fresh valkey dataset — flush BullMQ queues before migrating.
- **Helm values layout**: overlays moved from `helm/values/tfo-<env>.yaml` to **`helm/values/<env>/tfo-<env>.yaml`** (`demo/`, `staging/`, `production/`), following the per-environment manifest pattern.
- **ansible-k8s chart source**: deploys the **local umbrella chart** (`helm/telemetryflow`, chart 2.x) — the placeholder remote repo `charts.telemetryflow.example.com` and chart `0.1.0` pin are removed.
- **Terraform single-AZ**: network module provisions **zone-a only** (subnets/route tables/NAT associations for b/c removed).

### Added

- **Helm chart 2.1.0 (appVersion 2.5.8)** — synced from the platform monolith chart, minus KubeSphere:
  - New components: `cache-valkey`, `queue-valkey`, PostgreSQL 18-alpine (initdb scripts, wal config, backup CronJob + retention), ClickHouse 26.7-alpine (system-log TTLs, users/readonly profiles), collector `telemetryflow-collector:1.3.0` (v2 authenticated OTLP, span-metrics/service-graph connectors, remote-write), tfo-agent 1.2.1 (pinned; 1.3.1 regression documented), PDB/HPA per component, RKE2-compatible scheduling
  - `templates/image-pull-secrets.yaml` — chart-created `dockerconfigjson` secrets for **DockerHub and ECR**, auto-injected into all workloads via the merged `telemetryflow.imagePullSecrets` helper
  - Values overlays per environment incl. standalone per-cluster manifests: `tfo-{staging,prod}-tfo-agent-telemetryflow.yaml`, `tfo-{staging,prod}-tfo-collector-telemetryflow.yaml`
  - `helm/values/production/secrets/` — 7 placeholder Secret manifests (backend, agent, postgresql, clickhouse, redis, nats, collector) mirroring the staging chart-managed set, ESO/Vault-ready
- **Stage-runner scripts** (`scripts/`, pattern from LGCNS deploy.sh):
  - `deploy-ansible-k8s.sh` — runs playbooks 00–04 as separate stages; DRY-RUN (`--check --diff`) default, `--apply` confirmation, `--from/--to/--only/--skip/--limit/--values-file`, per-run log dirs with summary
  - `deploy-ansible.sh` — same for the VM stack (ping → docker → postgres/clickhouse → platform → agent; destructive cleanup stages opt-in via `--only`)
  - `generate-secrets.sh` 2.0.0 — refactored with the same conventions; `--apply` fills the `REPLACE_ME` placeholders in `production/secrets/` in place (headers preserved) + writes `secrets.env` (chmod 600); `tfk_`/`tfs_` API-key prefixes; NATS password added

### Changed

- **RKE2** pinned to **v1.36.4+rke2r1** (stable channel); `kubectl_version` synced 1.36.4
- **Helm CLI** pinned to **v3.19.0** (was unpinned latest via get-helm-3)
- **VM images**: PostgreSQL 18-alpine, ClickHouse 26.7-alpine, backend `telemetryflow/telemetryflow-platform`, viz `telemetryflow/telemetryflow-viz`, backend port **3100** (`/health`)
- **Terraform**: default AMI **Debian 13 (Trixie)** official (`debian-13-amd64-*`, owner 136693071363); user_data handles Debian (user `admin`, valkey repos, cloudwatch agent via official .deb); DynamoDB state-lock table gets `deletion_protection_enabled` (toggle `dynamodb_deletion_protection`)
- Badges/docs refreshed: Valkey 9, PostgreSQL 18, ClickHouse 26.7, RKE2/K8s ≥1.36, chart v2.1.0

### Fixed

- **Compute module provider** — resources were using the implied default provider (no region/profile): IAM/AMI calls went to the right account but VPC-scoped calls (SG, EC2 Instance Connect) hit the wrong region → `InvalidVpcID.NotFound`. All compute resources now pinned to `aws.destination` + module-level provider config
- **Per-instance hostname** — shared launch template gave every node the same hostname (`tfo-staging`), which breaks RKE2 node registration; `aws_instance` now overrides `user_data` with the unique node name (live nodes fixed via `hostnamectl`)
- Ubuntu AMI filter (`hvm-ssd` → `hvm-ssd*`) and unused AMI data sources no longer evaluated during plan (conditional `count`)
- Security-group descriptions rejected by AWS (em-dash) → ASCII
- ansible-k8s: `service-ccidr` typo in RKE2 config template; `roles/common/vars/main.yml` silently overriding role defaults; `tfo-agent-secret` pre-check for production deploys
- ansible (VM): undefined `{{ environment }}` in ~10 templates — now aliases `deployment_environment`
- Inventory (ansible-k8s): duplicate worker-01 IP, non-existent worker-03, password auth → key auth (`keys/tfo-example-demo.pem`, `{{ inventory_dir }}`-relative), Debian user `admin`; SSH key unstaged from git and ignored (`*.pem`, `keys/`)

## [1.5.0] - 2026-06-19

### Added

- **Terraform EKS module** (`terraform/modules/eks/`) — observability EKS cluster (Kubernetes 1.35):
  - `aws_eks_cluster` (1.35) with OIDC provider + control-plane logs
  - Worker node group defaulting to **3 × t3.large** (prod `m5.large`), autoscaler-tagged
  - Managed add-ons: kube-proxy `v1.35.1-eksbuild.1`, vpc-cni `v1.21.0-eksbuild.1`, coredns `v1.13.1-eksbuild.1`, snapshot-controller `v8.4.0-eksbuild.1`
  - CSI drivers via **EKS Pod Identity**: `eks-pod-identity-agent` `v1.4.0-eksbuild.1`, `aws-ebs-csi-driver` `v1.50.0-eksbuild.1`, `aws-efs-csi-driver` `v2.2.5-eksbuild.1`
  - IAM roles: cluster, nodes, EBS/EFS CSI (Pod Identity), cluster-autoscaler (OIDC/IRSA), AWS Load Balancer Controller, Route53 cert-manager
  - EKS security group (SSH, PostgreSQL, Redis, OTLP 4317/4318, NATS, node-to-node, egress) + private S3 bucket (versioned, TLS-only)
- **Terraform EKS environment** (`terraform/environment/telemetryflow/tfo-eks/`) — workspace-driven wiring (`lab`/`staging`/`prod`) reading VPC/subnet/SG outputs from the `tfo-ec2` stack via `terraform_remote_state`; includes `backend.tf.example`, `terraform.tfvars.example`, HOW-TO.md, README.md
- **Operator CRD extensions** for EKS manifest helm values:
  - `SchedulingSpec` (`nodeSelector`, `tolerations`, `topologySpreadConstraints`, `affinity`) on backend, frontend, collector, agent (node + k8s), postgresql, clickhouse, redis, nats
  - `ComponentServiceSpec` (per-component Service `type` + `annotations`, e.g. `service.beta.kubernetes.io/aws-load-balancer-type: nlb`) on collector and backend
  - `ComponentIngressSpec` (per-component Ingress with `host`, `annotations`, `tls`, `tlsSecretName`, `className`, `paths`) on backend and frontend
  - `AutoscalingSpec` (HPA: min/max replicas, CPU/memory utilization targets) on backend
  - `ServiceAccountSpec.Annotations` (IRSA `eks.amazonaws.com/role-arn`) on collector and agent
  - `AgentSpec.ClusterProvider` (`eks`), `NATSSpec.JetStream` (`maxSize`/`maxMemory`)
- **Operator controller wiring** — `applyScheduling` helper, `buildDeploymentFull`/`buildStatefulSetFull`, `buildServiceFull`/`buildMultiPortServiceFull`, `reconcileBackendIngress`/`reconcileFrontendIngress` (Ingress), `reconcileBackendHPA` (HPA); SetupWithManager now `Owns` Ingress + HPA; RBAC role + kubebuilder markers for `rbac.authorization.k8s.io`, `networking.k8s.io`, `autoscaling`

### Changed

- Version bumped to **1.5.0**
- Operator sample CR (`config/samples/`) rewritten to mirror the EKS production manifest (gp3 storageClass, EKS nodegroup selectors, topology spread, NLB service annotations, IRSA serviceAccount annotations, backend HPA + ingress)

### Fixed

- Operator pre-existing build break: invalid `rbacv1` import path corrected to `k8s.io/api/rbac/v1`
- Operator pre-existing build break: non-existent `sigs.k8s.io/yaml v1.4.2` pinned to `v1.4.0` in `go.mod`/`go.sum`

## [1.4.2] - 2026-06-17

### Added

- **Kubernetes Operator** — full 14-component reconciler with tfo-agent and tfo-collector integration:
  - Agent split into DaemonSet (node mode: hostPath /proc, /sys, /, /var/log, node_exporter, runs as root with SYS_PTRACE) and Deployment (K8s mode: cluster-wide state, non-root 65534)
  - Collector Deployment with ConfigMap, emptyDir queue volume (500Mi), health probes on :13133, dedicated ServiceAccount + ClusterRole + ClusterRoleBinding
  - Agent RBAC: 13 policy rules covering core, apps, batch, autoscaling, networking, discovery, storage, policy, events, metrics API groups + non-resource URLs
  - Collector RBAC: 3 policy rules for core resources, apps workloads, non-resource /metrics URLs
  - Enriched CRD types: `SecurityContextSpec`, `ContainerPortSpec`, `EnvVar`, `ServiceAccountSpec`, `AgentNodeSpec`, `AgentK8sSpec`, `CollectorSpec` (with config/serviceAccount/security), `AgentSpec` (with node/kubernetes split)
  - Controller owns: Deployments, StatefulSets, DaemonSets, Services, ConfigMaps, Secrets, ServiceAccounts, ClusterRoles, ClusterRoleBindings
- **Operator test suite** — restructured to match tfo-agent/tfo-collector patterns:
  - `tests/unit/controller_test.go` — envtest-based unit tests using `stretchr/testify` (replaces ginkgo/gomega)
  - `tests/e2e/startup_test.go` — binary build + startup validation
  - `tests/e2e/shutdown_test.go` — SIGTERM/SIGINT graceful shutdown
  - `tests/e2e/pipeline_test.go` — full reconciliation pipeline with envtest
  - `tests/e2e/collection_test.go` — health/metrics endpoint validation + concurrent requests
  - `tests/e2e/testdata/minimal.yaml` — test CR fixture
- **Operator go.mod** — refactored to tfo-agent style: `toolchain go1.26.3`, section banners with `// ===` delimiters, per-dependency comments, switched from `onsi/ginkgo` + `onsi/gomega` to `stretchr/testify v1.11.1`
- **Operator Dockerfile** — multi-stage (golang:1.26-alpine → alpine:3.21), OCI labels, dumb-init, health check on :8081/healthz, non-root operator:10001
- **Operator Makefile** — refactored to collector/deployment style with colored help, `version`/`info` targets, `test` (unit envtest) and `test-e2e` targets
- **Ansible/** — 54 files: 13 roles, 11 playbooks, inventory.yml, group_vars, host_vars for VM (non-K8s) deployment
- **Ansible-k8s/** — 31 files: 5 roles, 6 playbooks, hosts.yml, group_vars, host_vars for RKE2 cluster deployment
- **Helm chart** (`helm/telemetryflow/`) — 25 files: Chart.yaml, values.yaml (770 lines), 4 manifest overlays (`tfo-staging.yaml`, `tfo-production.yaml`, `tfo-eks-staging.yaml`, `tfo-eks-production.yaml`), 20 templates across 11 subdirectories, NOTES.txt with ASCII banner
- **Docker Compose** — 12 services across profiles, no Jaeger
- **.env.example** — 936 lines, 26 sections, all secrets empty (`<CHANGE_ME>`)
- **CI/CD** — GitHub Actions (6 workflows with environment approval) + GitLab CI/CD (6 stages, 11 jobs, manual approval)
- **Docs** — 12 files: ARCHITECTURE, DEPLOYMENT, ANSIBLE-GUIDE, HELM-GUIDE, OPERATOR-GUIDE (with e2e test structure), DOCKER-COMPOSE-GUIDE, SECURITY-GUIDE, MONITORING, NETWORKING, CI-CD-GUIDE
- **Scripts** — 5 deployment/utility scripts
- **Root files** — README.md (TFO logo with dark/light mode, 13 badges, 3 Mermaid diagrams), Makefile (collector style), CONTRIBUTING.md, SECURITY.md, .gitignore
- **Sample CR** (`config/samples/`) — full rich spec example with agent node/kubernetes split, collector config/RBAC, all component configs

### Changed

- Kubernetes minimum version raised to >= 1.33 (RKE2 >= 1.33, EKS >= 1.33)
- Operator `go.mod` switched from `onsi/ginkgo/v2` + `onsi/gomega` to `stretchr/testify v1.11.1`
- Operator tests moved from `internal/controller/suite_test.go` + `test/e2e/` to `tests/unit/` + `tests/e2e/` (testify-based)
- Controller default collector ports fixed from `[]corev1.ContainerPort` to `[]telemetryflowv1alpha1.ContainerPortSpec` type match
- Removed unused `fmt` import from `main.go`

### Removed

- `internal/controller/suite_test.go` — replaced by `tests/unit/controller_test.go` (testify)
- `test/e2e/` (old ginkgo-based e2e suite) — replaced by `tests/e2e/` (testify)

## [1.0.0] - 2026-05-30

### Added

- Initial standard deployment templates for TelemetryFlow observability platform.
- Ansible playbooks for VM and Kubernetes deployment.
- Helm chart with staging and production value overrides.
- Kubernetes Operator scaffold (Kubebuilder).
- Docker Compose configuration for local development.
- Makefile with automation targets for all deployment methods.
- Contributing guide, security policy, and code of conduct.
- CI/CD pipelines for automated testing and deployment.

### Changed

- Updated project structure and documentation to match best practices.
- Improved code quality and readability.
- Fixed bugs and issues reported by users.

### Removed

- Deprecated features and components.
- Unused code and documentation.

## [0.1.0] - 2026-05-30

### Added

- Initial version of TelemetryFlow observability platform.
- Basic deployment templates for VM and Kubernetes.
- Documentation for installation and usage.
- Basic monitoring and logging capabilities.

### Changed

- Improved performance and scalability.