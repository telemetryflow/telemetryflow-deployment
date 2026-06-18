<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg">
    <img src="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg" alt="TelemetryFlow Logo" width="80%">
  </picture>

  <h3>TelemetryFlow Deployment</h3>

[![Version](https://img.shields.io/badge/Version-1.5.0-orange.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Docker Ready](https://img.shields.io/badge/Docker-Ready-2496ED?style=flat&logo=docker)](https://hub.docker.com/r/telemetryflow/telemetryflow-platform)
[![Go](https://img.shields.io/badge/Go-1.26+-00ADD8?logo=go&style=flat-square)](https://go.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&style=flat-square)](https://www.postgresql.org/)
[![ClickHouse](https://img.shields.io/badge/ClickHouse-latest-FFCC00?logo=clickhouse&style=flat-square)](https://clickhouse.com/)
[![Redis](https://img.shields.io/badge/Redis-7-DC382D?logo=redis&style=flat-square)](https://redis.io/)
[![NATS](https://img.shields.io/badge/NATS-2.10-27AAE1?logo=nats.io&style=flat-square)](https://nats.io/)
[![RKE2](https://img.shields.io/badge/RKE2-%3E%3D1.33-orange?style=flat-square)](https://docs.rke2.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-%3E%3D1.33-326CE5?logo=kubernetes&style=flat-square)](https://kubernetes.io/)
[![Helm](https://img.shields.io/badge/Helm%20Chart-v1.0.0-0F1689?logo=helm&style=flat-square)](https://helm.sh/)
[![Ansible](https://img.shields.io/badge/Ansible-%3E%3D2.16-000000?logo=ansible&style=flat-square)](https://www.ansible.com/)

<center>Production-Ready Infrastructure & Deployment Standards for the
<br><strong>TelemetryFlow Observability Platform</strong></center>

</div>

---

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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