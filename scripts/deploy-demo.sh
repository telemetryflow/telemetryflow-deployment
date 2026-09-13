#!/usr/bin/env bash
# =============================================================================
# deploy-demo.sh
# Deploy TelemetryFlow (TFO) to the demo environment
#
# Namespace : observability
# Domain    : platform-demo.telemetryflow.id    (frontend)
#             api-demo.telemetryflow.id         (backend)
#             bullboard-demo.telemetryflow.id   (queue monitor)
# Seeds     : enabled (demo users, workspace, sample telemetry)
# Secrets   : chart-managed (secrets.create: true in the demo overlay)
# Collectors: none — demo runs a single in-cluster collector from the platform
#             chart; there are no per-cluster collector releases for demo.
#
# Manifest  : helm/values/demo/tfo-demo.yaml  (self-contained, single file)
#
# Usage:
#   bash scripts/deploy-demo.sh
#   bash scripts/deploy-demo.sh --dry-run
#   bash scripts/deploy-demo.sh --set tfoBackend.image.tag=2.5.8
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
MANIFEST_DIR="$(cd "${SCRIPT_DIR}/../helm/values/demo" && pwd)"
MANIFEST="tfo-demo.yaml"
TIMEOUT="${TIMEOUT:-15m}"

DOMAIN="platform-demo.telemetryflow.id"
BACKEND_HOST="api-demo.telemetryflow.id"   # api-<env> scheme, not api.${DOMAIN}
VIZ_HOST="${DOMAIN}"
BULLBOARD_HOST="bullboard-demo.telemetryflow.id"

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
# ECR token refresh (imagePullSecrets.ecr)
# The dockerconfigjson token expires ~12h; fetch a fresh one at deploy time
# when the AWS CLI is available. The chart creates the secret from it.
# ---------------------------------------------------------------------------
if [[ -n "${ECR_PASSWORD:-}" ]]; then
  echo "==> Using ECR token from environment (injected by the deploy pipeline)."
  EXTRA_ARGS+=(--set "imagePullSecrets.ecr.password=${ECR_PASSWORD}")
elif command -v aws >/dev/null 2>&1; then
  echo "==> Refreshing ECR login token..."
  ECR_PASSWORD="$(aws ecr get-login-password --region "${AWS_REGION:-"{AWS_DEFAULT_REGION}"}" --profile "${AWS_PROFILE:-"{AWS_ACCOUNT_ID}_AdministratorAccess"}" 2>/dev/null || true)"
  if [[ -n "${ECR_PASSWORD}" ]]; then
    EXTRA_ARGS+=(--set "imagePullSecrets.ecr.password=${ECR_PASSWORD}")
    echo "==> ECR token injected (imagePullSecrets.ecr.password)"
  else
    echo "WARN: could not fetch ECR token — existing telemetryflow-ecr-secret will be reused (if any)."
  fi
else
  echo "WARN: aws CLI not found — cannot refresh ECR token."
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
# Demo credentials (seeded by initContainers.runSeeds)
# ---------------------------------------------------------------------------
echo "==> Demo credentials (seeded — change immediately if exposed):"
echo "    See helm/values/demo/tfo-demo.yaml (secrets + seed users)"
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
echo "==> Migration + seed logs:"
echo "    kubectl logs -l app.kubernetes.io/name=tfo-backend -n ${NAMESPACE} -c run-migrations --tail=50"
echo "    kubectl logs -l app.kubernetes.io/name=tfo-backend -n ${NAMESPACE} -c run-seeds --tail=50"
echo ""
echo "==> K8s collector (tfo-agent-k8s) status:"
echo "    kubectl get deployment tfo-agent-k8s -n ${NAMESPACE}"
echo "    kubectl logs -l app.kubernetes.io/component=k8s-collector -n ${NAMESPACE} --tail=50"
echo ""
echo "==> K8s cluster auto-registration result:"
echo "    kubectl logs -l app.kubernetes.io/component=k8s-collector -n ${NAMESPACE} --tail=30 | grep -i 'cluster\|register\|sync\|error'"
