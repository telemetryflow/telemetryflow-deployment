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

# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do not** report security vulnerabilities through public GitHub issues, discussions,
or pull requests.

Instead, please report them to:

> **security@telemetryflow.id**

We aim to respond within **72 hours** and will keep you updated throughout the
remediation process. Please include:

- A description of the vulnerability.
- Steps to reproduce (if applicable).
- Affected versions and deployment method (Ansible / Helm / Operator).
- Any suggested mitigations.

We ask that you:

- Do not publicly disclose the issue before a fix is released.
- Allow a reasonable timeframe for remediation before disclosure.
- Make a good-faith effort to avoid privacy destruction and data loss.

---

## Security Best Practices for Deployment

### Secret Management

- **Never** commit secrets, credentials, API keys, or tokens to this repository.
- Use `.env` files (already `.gitignore`d) for local development.
- In production, use a dedicated secrets manager:
  - Kubernetes: [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets), [External Secrets Operator](https://external-secrets.io/), or [Vault](https://www.vaultproject.io/).
  - VM: HashiCorp Vault, AWS Secrets Manager, or GCP Secret Manager.
- Generate strong, unique secrets with `make secrets-generate`.
- Rotate secrets regularly and after any personnel change.

### Network Security

- Enable TLS for all inter-service communication.
- Use network policies to restrict pod-to-pod traffic in Kubernetes.
- Place the OTel Collector behind an authenticated ingress.
- Do not expose datastore ports (PostgreSQL, ClickHouse, Redis, NATS) to the public internet.

### Container Security

- Use minimal base images (distroless / Chainguard).
- Run containers as non-root users.
- Pin image digests instead of floating tags in production.
- Scan images for CVEs before deployment (Trivy, Grype).

### Access Control

- Follow the principle of least privilege for all service accounts.
- Use Kubernetes RBAC to restrict operator and controller permissions.
- Require signed commits on protected branches.
- Enable audit logging on all critical endpoints.

---

## Production Deployment Security Checklist

- [ ] All secrets are stored in a secrets manager (not in files, env vars, or ConfigMaps).
- [ ] TLS is enabled on every external and inter-service endpoint.
- [ ] Network policies are applied to all namespaces.
- [ ] Containers run as non-root with read-only root filesystems.
- [ ] Image digests are pinned (no floating tags).
- [ ] Pod security standards are enforced (baseline or restricted).
- [ ] RBAC is configured with least-privilege service accounts.
- [ ] Database credentials are rotated and not shared across environments.
- [ ] Audit logging is enabled and logs are shipped to a secure destination.
- [ ] Backups are configured and tested for PostgreSQL and ClickHouse.
- [ ] The `.env` file is **not** present on any production host.
- [ ] All default passwords have been replaced with strong, generated values.

---

## Contact

For non-security questions, open a [GitHub Issue](https://github.com/telemetryflow/telemetryflow-deployment/issues).
For security concerns, email **security@telemetryflow.id**.
