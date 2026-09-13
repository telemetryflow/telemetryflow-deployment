#!/usr/bin/env bash
# =============================================================================
# deploy-production.sh
# Deploy TelemetryFlow (TFO) to the production environment
#
# Namespace : observability
# Domain    : telemetryflow.id           (frontend)
#             api.telemetryflow.id       (backend)
#             (BullMQ board via port-forward only)
# Replicas  : 2–8 (HPA), PDB enabled
# Seeds     : disabled
# TLS       : terminated at reverse proxy / LoadBalancer
#
# Manifest  : helm/values/production/tfo-production.yaml  (self-contained)
#
# IMPORTANT: Provision secrets before running this script.
#   Placeholder manifests (fill, then apply): helm/values/production/secrets/
#
#   Required secrets:
#     tfo-backend-secrets     — database passwords, JWT/session/encryption keys
#     tfo-agent-secret        — TELEMETRYFLOW_API_KEY_ID, TELEMETRYFLOW_API_KEY_SECRET
#     tfo-postgresql-secret   — PostgreSQL credentials
#     tfo-clickhouse-secret   — ClickHouse credentials
#     tfo-redis-secret        — Redis credentials
#     tfo-nats-secret         — NATS credentials
#
# Usage:
#   bash scripts/deploy-production.sh
#   bash scripts/deploy-production.sh --dry-run
#   bash scripts/deploy-production.sh --set tfoBackend.image.tag=2.5.8
#   SKIP_COLLECTORS=1 bash scripts/deploy-production.sh  # core stack only
#
# Ingress is rendered by the chart (className nginx, disabled by default in
# the overlay) — there is no separate Gateway API manifest step.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RELEASE="telemetryflow"
NAMESPACE="${NAMESPACE:-observability}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/../helm/telemetryflow" && pwd)"
MANIFEST_DIR="$(cd "${SCRIPT_DIR}/../helm/values/production" && pwd)"
MANIFEST="tfo-production.yaml"
TIMEOUT="${TIMEOUT:-20m}"   # allow time for HA replicas, migrations, agent registration

DOMAIN="platform.telemetryflow.id"
BACKEND_HOST="api.telemetryflow.id"
VIZ_HOST="${DOMAIN}"

# Pass through any extra arguments (e.g. --dry-run, --set image.tag=X)
EXTRA_ARGS=("$@")

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
echo "==> Checking prerequisites..."
command -v helm    >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }

echo "==> Cluster context : $(kubectl config current-context)"
echo "==> Chart directory : ${CHART_DIR}"
echo "==> Manifest        : ${MANIFEST_DIR}/${MANIFEST}"
echo "==> Release         : ${RELEASE}"
echo "==> Namespace       : ${NAMESPACE}"
echo "==> Backend host    : ${BACKEND_HOST}"
echo "==> Viz host        : ${VIZ_HOST}"
echo ""

for f in "${CHART_DIR}/values.yaml" "${CHART_DIR}/Chart.yaml" "${MANIFEST_DIR}/${MANIFEST}"; do
  [[ -f "$f" ]] || { echo "ERROR: required file not found: ${f}"; exit 1; }
done

# Verify namespace exists (production secrets must be pre-provisioned;
# the production overlay sets secrets.create: false)
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  echo "ERROR: Namespace '${NAMESPACE}' does not exist."
  echo "       Create it and provision secrets first:"
  echo "       kubectl create namespace ${NAMESPACE}"
  echo "       kubectl apply -f helm/values/production/secrets/   # fill placeholders first"
  exit 1
fi

# Verify required secrets exist
echo "==> Verifying required secrets..."
for SECRET in tfo-backend-secrets tfo-agent-secret tfo-postgresql-secret tfo-clickhouse-secret tfo-redis-secret tfo-nats-secret; do
  if ! kubectl get secret "${SECRET}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    echo "ERROR: Secret '${SECRET}' not found in namespace '${NAMESPACE}'."
    echo "       Fill and apply: helm/values/production/secrets/tfo-prod-secret-*.yaml"
    exit 1
  fi
done
echo "==> All required secrets verified."
echo ""

# Install / verify CRDs (Prometheus Operator ServiceMonitor etc.)
echo "==> Installing CRDs (Prometheus Operator)..."
bash "${SCRIPT_DIR}/install-crds.sh" || {
  echo "WARN: CRD installation failed or was skipped. ServiceMonitor resources will not be rendered."
  echo "      Run manually: bash scripts/install-crds.sh"
}
echo ""

# Check metrics-server (required for K8s CPU/Memory usage charts)
echo "==> Checking metrics-server availability..."
if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  echo "==> metrics-server: available"
else
  echo "WARN: metrics-server not found — Kubernetes CPU/Memory usage charts will be empty."
  echo "      Install metrics-server:"
  echo "      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  echo "      Proceeding (set metrics_api: false in the agent manifest to suppress warnings)."
fi
echo ""

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
echo "==> Running helm upgrade --install..."

helm upgrade --install "${RELEASE}" "${CHART_DIR}" \
  -f "${CHART_DIR}/values.yaml" \
  -f "${MANIFEST_DIR}/${MANIFEST}" \
  --namespace "${NAMESPACE}" \
  --set global.createNamespace=false \
  --timeout "${TIMEOUT}" \
  --wait \
  "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

echo ""
echo "==> Deployment complete."
echo ""

# ---------------------------------------------------------------------------
# Per-cluster TFO Collectors
# Separate Helm releases (tfo-collector-<cluster>) on this platform cluster.
# Skip with SKIP_COLLECTORS=1 when only the core stack needs redeploying.
# ---------------------------------------------------------------------------
if [[ "${SKIP_COLLECTORS:-0}" == "1" ]]; then
  echo "==> Skipping per-cluster TFO Collectors (SKIP_COLLECTORS=1)"
else
  echo "==> Installing per-cluster TFO Collectors..."
  bash "${SCRIPT_DIR}/deploy-tfo-collectors.sh" --env production || {
    echo "WARN: One or more collectors failed to install."
    echo "      Run manually: bash scripts/deploy-tfo-collectors.sh --env production --list"
  }
fi
echo ""

echo "    Frontend : https://${VIZ_HOST}"
echo "    API      : https://${BACKEND_HOST}"
echo "    BullMQ   : bullboard.telemetryflow.id (or) kubectl port-forward -n ${NAMESPACE} svc/tfo-bullboard 3000:3000"
echo ""

# ---------------------------------------------------------------------------
# Post-deploy status hints
# ---------------------------------------------------------------------------
echo "==> Verify deployment:"
echo "    kubectl get pods -n ${NAMESPACE}"
echo ""
echo "==> HPA status:"
echo "    kubectl get hpa -n ${NAMESPACE}"
echo ""
echo "==> PDB status:"
echo "    kubectl get pdb -n ${NAMESPACE}"
echo ""
echo "==> Migration logs:"
echo "    kubectl logs -l app.kubernetes.io/name=tfo-backend -n ${NAMESPACE} -c run-migrations --tail=50"
echo ""
echo "==> K8s collector (tfo-agent-k8s) status:"
echo "    kubectl get deployment tfo-agent-k8s -n ${NAMESPACE}"
echo "    kubectl logs -l app.kubernetes.io/component=k8s-collector -n ${NAMESPACE} --tail=50"
echo ""
echo "==> K8s cluster auto-registration result:"
echo "    kubectl logs -l app.kubernetes.io/component=k8s-collector -n ${NAMESPACE} --tail=30 | grep -i 'cluster\|register\|sync\|error'"
