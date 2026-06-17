#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

HELM_CHART="${ROOT_DIR}/helm/telemetryflow"
RELEASE_NAME="${RELEASE_NAME:-telemetryflow}"
NAMESPACE="${NAMESPACE:-telemetryflow}"
VALUES_FILE="${ROOT_DIR}/manifest/tfo-production.yaml"
TIMEOUT="${HELM_TIMEOUT:-10m}"

echo "=== TelemetryFlow Production Deployment ==="

echo "--- Pre-flight Checks ---"
command -v helm &>/dev/null || { echo "ERROR: helm not found"; exit 1; }
command -v kubectl &>/dev/null || { echo "ERROR: kubectl not found"; exit 1; }
kubectl cluster-info || { echo "ERROR: Cannot reach Kubernetes cluster"; exit 1; }

echo "--- Verifying Required Secrets ---"
REQUIRED_SECRETS=(
  "JWT_SECRET"
  "SESSION_SECRET"
  "ENCRYPTION_KEY"
  "POSTGRES_PASSWORD"
  "CLICKHOUSE_PASSWORD"
  "REDIS_PASSWORD"
)
MISSING=0
for secret_name in "${REQUIRED_SECRETS[@]}"; do
  if ! kubectl get secret telemetryflow-secrets -n "$NAMESPACE" -o jsonpath="{.data.${secret_name}}" &>/dev/null; then
    echo "  MISSING: $secret_name"
    MISSING=1
  else
    echo "  OK: $secret_name"
  fi
done
if [ "$MISSING" -eq 1 ]; then
  echo ""
  echo "ERROR: Required secrets are missing."
  echo "Run scripts/generate-secrets.sh and apply the Kubernetes secret first."
  exit 1
fi

echo "--- Checking for values file ---"
if [ ! -f "$VALUES_FILE" ]; then
  echo "WARNING: ${VALUES_FILE} not found, using default values"
  VALUES_FILE=""
fi

echo "--- Confirming Production Deployment ---"
if [ -t 0 ]; then
  read -r -p "Deploy to PRODUCTION? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
  fi
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
  --history-max 5
)
if [ -n "$VALUES_FILE" ]; then
  HELM_ARGS+=(-f "$VALUES_FILE")
fi
helm "${HELM_ARGS[@]}"

echo "--- Verifying Deployment ---"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" -o wide

echo ""
echo "=== Production deployment complete ==="
echo "Namespace : $NAMESPACE"
echo "Release   : $RELEASE_NAME"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f -n $NAMESPACE -l app.kubernetes.io/component=tfo-backend"
echo "  helm rollback $RELEASE_NAME -n $NAMESPACE"
echo "  helm history $RELEASE_NAME -n $NAMESPACE"
