#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HELM_CHART="${ROOT_DIR}/helm/telemetryflow"
RELEASE_NAME="${RELEASE_NAME:-telemetryflow}"
NAMESPACE="${NAMESPACE:-telemetryflow}"
VALUES_FILE="${ROOT_DIR}/manifest/tfo-staging.yaml"
TIMEOUT="${HELM_TIMEOUT:-5m}"

echo "=== TelemetryFlow Staging Deployment ==="

echo "--- Pre-flight Checks ---"
command -v helm &>/dev/null || { echo "ERROR: helm not found"; exit 1; }
command -v kubectl &>/dev/null || { echo "ERROR: kubectl not found"; exit 1; }
kubectl cluster-info || { echo "ERROR: Cannot reach Kubernetes cluster"; exit 1; }

echo "--- Checking for values file ---"
if [ ! -f "$VALUES_FILE" ]; then
  echo "WARNING: ${VALUES_FILE} not found, using default values"
  VALUES_FILE=""
fi

echo "--- Installing CRDs ---"
bash "${SCRIPT_DIR}/install-crds.sh"

echo "--- Creating namespace (if needed) ---"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "--- Helm Upgrade/Install ---"
HELM_ARGS=(
  upgrade "$RELEASE_NAME" "$HELM_CHART"
  --install
  --namespace "$NAMESPACE"
  --timeout "$TIMEOUT"
  --wait
  --history-max 10
)
if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=(-f "$VALUES_FILE")
fi
helm "${HELM_ARGS[@]}"

echo "--- Verifying Deployment ---"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide

echo ""
echo "=== Staging deployment complete ==="
echo "Namespace : $NAMESPACE"
echo "Release   : $RELEASE_NAME"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/component=tfo-backend"
echo "  helm status $RELEASE_NAME -n $NAMESPACE"
