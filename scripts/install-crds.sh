#!/usr/bin/env bash
set -euo pipefail

PROMETHEUS_OPERATOR_CRD_VERSION="v0.72.0"
PROMETHEUS_OPERATOR_CRD_BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_CRD_VERSION}/example/prometheus-operator-crd"

CRD_URLS=(
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_prometheusrules.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_podmonitors.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_servicemonitors.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_probes.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_alertmanagerconfigs.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_alertmanagers.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_prometheuses.yaml"
  "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_thanosrulers.yaml"
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OPERATOR_DIR="${ROOT_DIR}/operator"

echo "=== Installing CRDs ==="

if command -v kubectl &>/dev/null; then
  echo "--- Installing Prometheus Operator CRDs (v${PROMETHEUS_OPERATOR_CRD_VERSION#v}) ---"
  for url in "${CRD_URLS[@]}"; do
    crd_name="$(basename "$url" .yaml)"
    if kubectl get crd "${crd_name}.monitoring.coreos.com" &>/dev/null; then
      echo "  CRD ${crd_name} already exists, applying update"
    else
      echo "  Installing CRD ${crd_name}"
    fi
    kubectl apply --server-side -f "$url" 2>/dev/null || kubectl apply -f "$url"
  done
  echo "  Prometheus Operator CRDs installed"
else
  echo "WARNING: kubectl not found, skipping Prometheus Operator CRDs"
fi

if [ -d "$OPERATOR_DIR" ] && [ -f "${OPERATOR_DIR}/Makefile" ]; then
  echo "--- Installing TelemetryFlow Operator CRDs ---"
  make -C "$OPERATOR_DIR" install
  echo "  TelemetryFlow Operator CRDs installed"
else
  echo "--- Operator directory not found, skipping operator CRDs ---"
fi

echo "=== CRD installation complete ==="
