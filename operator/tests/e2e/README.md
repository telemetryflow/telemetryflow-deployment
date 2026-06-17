# E2E Tests

End-to-end tests for the TelemetryFlow Operator that run against a real Kubernetes cluster.

## Overview

Unlike the unit/envtest suite in `internal/controller/suite_test.go` (which uses `envtest` with mocked API server), these e2e tests verify the full operator lifecycle against an actual cluster with the operator deployed.

### Test separation

| Suite          | Location                            | Runner          | Target                              |
| -------------- | ----------------------------------- | --------------- | ----------------------------------- |
| Unit / envtest | `internal/controller/suite_test.go` | `make test`     | CI (no cluster needed)              |
| E2E            | `test/e2e/`                         | `make test-e2e` | Real cluster with operator deployed |

## Test Cases

| Test                      | Description                                                                                                                              |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| Full platform deployment  | Deploys all components (PostgreSQL, ClickHouse, Redis, BullMQ Redis, NATS, Collector, Backend, Frontend, Agent) and verifies Ready phase |
| Minimal deployment        | Deploys only backend + PostgreSQL, verifies agent DaemonSet is not created                                                               |
| Deletion and cleanup      | Deletes CR and verifies all managed resources (Deployments, StatefulSets, Secrets) are garbage collected                                 |
| Update and reconciliation | Updates `spec.backend.replicas` from 1 to 3 and verifies the Deployment reflects the change                                              |

## Prerequisites

- A running Kubernetes cluster (RKE2, EKS, kind, minikube, etc.)
- `kubectl` configured with cluster access
- Operator CRDs installed (`make install`)
- Operator controller running (`make run` or `make deploy`)
- Go >= 1.26

## Running E2E Tests

```bash
# Install CRDs
make install

# Run the operator (in a separate terminal)
make run

# Run e2e tests
make test-e2e

# Or directly with Go flags
go test ./test/e2e/ -v -timeout 30m
```

### With kind (local development)

```bash
# Create a kind cluster
kind create cluster --name tfo-e2e

# Install CRDs and deploy operator
make install
make deploy IMG=telemetryflow/operator:latest

# Run e2e tests
make test-e2e

# Cleanup
kind delete cluster --name tfo-e2e
```

### With a remote cluster

```bash
# Point kubeconfig to your cluster
export KUBECONFIG=/path/to/kubeconfig

# Install CRDs
make install

# Deploy operator
make deploy IMG=your-registry/telemetryflow/operator:v1.4.0

# Run e2e tests
make test-e2e
```

## Environment Variables

| Variable     | Default          | Description             |
| ------------ | ---------------- | ----------------------- |
| `KUBECONFIG` | `~/.kube/config` | Path to kubeconfig file |

## Test Namespace

All e2e test resources are created in the `telemetryflow-e2e` namespace, which is automatically created at the start of the test suite and deleted after all tests finish.

## Timeouts

| Constant             | Value | Description                                            |
| -------------------- | ----- | ------------------------------------------------------ |
| `e2eTimeout`         | 300s  | Maximum wait time for resource creation/status changes |
| `e2ePollingInterval` | 2s    | Polling interval for assertions                        |

Adjust these in `e2e_suite_test.go` if your cluster is slower.
