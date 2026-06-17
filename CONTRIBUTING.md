<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg">
    <img src="https://github.com/telemetryflow/.github/raw/main/docs/assets/tfo-logo-light.svg" alt="TelemetryFlow Logo" width="80%">
  </picture>

  <h3>TelemetryFlow Deployment</h3>

[![Version](https://img.shields.io/badge/Version-1.4.0-orange.svg)](CHANGELOG.md)
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

# Contributing to TelemetryFlow Deployment

First off, thank you for considering contributing to TelemetryFlow! It's people
like you who make this project better.

## How to Contribute

### 1. Fork & Branch

```bash
git clone https://github.com/<your-username>/telemetryflow-deployment.git
cd telemetryflow-deployment
git checkout -b feat/my-new-feature
```

### 2. Make Your Changes

- Follow the code style guidelines below.
- Add or update documentation where relevant.
- Test your changes locally (see **Development Setup**).

### 3. Commit

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`, `ci`

Examples:

```
feat(helm): add PodDisruptionBudget template
fix(ansible): correct PostgreSQL socket path for Ubuntu 24.04
docs: update README quick-start section
```

### 4. Push & Open a Pull Request

```bash
git push origin feat/my-new-feature
```

Open a PR against the `main` branch. Fill in the PR template completely.

---

## Pull Request Process

1. Ensure your branch is up to date with `main`.
2. All CI checks must pass before review.
3. At least one maintainer approval is required.
4. Squash-merge is the preferred merge strategy.
5. Update `CHANGELOG.md` under the **[Unreleased]** section if applicable.

---

## Code Style Guidelines

### Ansible

- Use YAML with 2-space indentation.
- Name every task.
- Use FQCN for modules (e.g., `ansible.builtin.copy`).
- Run `ansible-lint` before committing — `make lint`.

### Helm

- Follow [Helm best practices](https://helm.sh/docs/chart_best_practices/).
- Keep `values.yaml` commented with sensible defaults.
- Run `helm lint` and `helm template` before committing.

### Go (Operator)

- Follow [Effective Go](https://go.dev/doc/effective_go).
- Run `gofmt`, `go vet`, and `golangci-lint`.
- Write table-driven tests for new controllers.

### General

- Do not commit secrets, credentials, or `.env` files.
- Use placeholders like `<CHANGE_ME>` for example configuration.

---

## Development Setup

```bash
# Clone and initialise
git clone https://github.com/telemetryflow/telemetryflow-deployment.git
cd telemetryflow-deployment
make init

# Verify prerequisites
make verify

# Generate secrets for local development
make secrets-generate

# Start local stack
make docker-up-core
```

---

## Reporting Security Vulnerabilities

**Do not** report security vulnerabilities through public GitHub issues.

Please report them to **security@telemetryflow.id**. See [SECURITY.md](./SECURITY.md)
for full details.

---

## License

By contributing, you agree that your contributions will be licensed under the
[Apache License 2.0](./LICENSE).
