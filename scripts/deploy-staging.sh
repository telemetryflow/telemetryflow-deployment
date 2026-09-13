#!/usr/bin/env bash
# =============================================================================
# deploy-staging.sh
# Deploy TelemetryFlow (TFO) to the staging environment
#
# Namespace : observability
# Domain    : demo.telemetryflow.id            (frontend)
#             api-staging.telemetryflow.id     (backend)
#             bullboard.demo.telemetryflow.id  (queue monitor)
# Seeds     : enabled (demo users, workspace, sample telemetry)
# Secrets   : chart-managed (secrets.create: true in the staging overlay)
#
# Manifest  : helm/values/staging/tfo-staging.yaml  (self-contained, single file)
#
# Usage:
#   bash scripts/deploy-staging.sh
#   bash scripts/deploy-staging.sh --dry-run
#   bash scripts/deploy-staging.sh --set tfoBackend.image.tag=2.5.8
#   SKIP_COLLECTORS=1 bash scripts/deploy-staging.sh   # core stack only
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
MANIFEST_DIR="$(cd "${SCRIPT_DIR}/../helm/values/staging" && pwd)"
MANIFEST="tfo-staging.yaml"
TIMEOUT="${TIMEOUT:-15m}"

DOMAIN="platform-staging.telemetryflow.id"
BACKEND_HOST="api-staging.telemetryflow.id"
VIZ_HOST="${DOMAIN}"
BULLBOARD_HOST="bullboard-staging.telemetryflow.id"

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
  --create-namespace \
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
  bash "${SCRIPT_DIR}/deploy-tfo-collectors.sh" --env staging || {
    echo "WARN: One or more collectors failed to install."
    echo "      Run manually: bash scripts/deploy-tfo-collectors.sh --env staging --list"
  }
fi
echo ""

echo "    Frontend : https://${VIZ_HOST}"
echo "    API      : https://${BACKEND_HOST}"
echo "    BullMQ   : https://${BULLBOARD_HOST}"
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
