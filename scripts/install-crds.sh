#!/usr/bin/env bash
# =============================================================================
# install-crds.sh
# Install Kubernetes CRDs required by TelemetryFlow before Helm deploy.
#
# CRDs installed:
#   Prometheus Operator CRDs (monitoring.coreos.com/v1):
#     - ServiceMonitor   — exporter scrape targets for tfo-collector
#     - PodMonitor       — pod-level scrape targets
#     - PrometheusRule   — alerting/recording rules
#     - Prometheus       — Prometheus instance spec
#     - Alertmanager     — Alertmanager instance spec
#
# These CRDs are cluster-scoped and only need to be installed once.
# This script is idempotent — safe to re-run on upgrades.
#
# Usage:
#   bash _infra/scripts/install-crds.sh
#   bash _infra/scripts/install-crds.sh --skip-prometheus    # skip if already installed
#   PROMETHEUS_OPERATOR_VERSION=v0.75.0 bash _infra/scripts/install-crds.sh
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
PROMETHEUS_OPERATOR_VERSION="${PROMETHEUS_OPERATOR_VERSION:-v0.91.0}"
PROMETHEUS_OPERATOR_CRD_BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/${PROMETHEUS_OPERATOR_VERSION}/example/prometheus-operator-crd"

SKIP_PROMETHEUS=false
for arg in "$@"; do
  case $arg in
    --skip-prometheus) SKIP_PROMETHEUS=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "==> $*"; }
warn()  { echo "WARN: $*"; }
error() { echo "ERROR: $*" >&2; exit 1; }

crd_exists() {
  kubectl get crd "$1" >/dev/null 2>&1
}

apply_crd() {
  local url="$1"
  local name="$2"
  if crd_exists "${name}"; then
    info "CRD already installed: ${name} — applying update..."
  else
    info "Installing CRD: ${name}"
  fi
  kubectl apply --server-side --force-conflicts -f "${url}" || {
    warn "server-side apply failed, falling back to client-side apply for ${name}"
    kubectl apply -f "${url}"
  }
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"
command -v curl    >/dev/null 2>&1 || error "curl not found"

info "Cluster context : $(kubectl config current-context)"
info "Prometheus Operator version: ${PROMETHEUS_OPERATOR_VERSION}"
echo ""

# ---------------------------------------------------------------------------
# Optional monitoring namespace
# Only needed if monitoring.serviceMonitor.namespace is explicitly set to
# a dedicated namespace (e.g. "monitoring") in your manifest.
# By default, manifests leave serviceMonitor.namespace blank so ServiceMonitors
# are created in the same namespace as the release (nusametric / telemetryflow).
# Set MONITORING_NAMESPACE=monitoring to create the namespace here.
# ---------------------------------------------------------------------------
if [[ -n "${MONITORING_NAMESPACE:-}" ]]; then
  MONITORING_NS="${MONITORING_NAMESPACE}"
  if kubectl get namespace "${MONITORING_NS}" >/dev/null 2>&1; then
    info "Namespace '${MONITORING_NS}' already exists."
  else
    info "Creating namespace '${MONITORING_NS}'..."
    kubectl create namespace "${MONITORING_NS}"
  fi
  echo ""
fi

# ---------------------------------------------------------------------------
# Prometheus Operator CRDs
# Required for ServiceMonitor resources in exporter templates.
# Helm Capabilities.APIVersions.Has check in templates silently skips
# ServiceMonitor resources if these CRDs are not installed.
# ---------------------------------------------------------------------------
if [[ "${SKIP_PROMETHEUS}" == "true" ]]; then
  info "Skipping Prometheus Operator CRDs (--skip-prometheus)"
else
  info "Installing Prometheus Operator CRDs..."

  # Verify the version URL is reachable before proceeding
  if ! curl -fsS --head "${PROMETHEUS_OPERATOR_CRD_BASE}/monitoring.coreos.com_servicemonitors.yaml" >/dev/null 2>&1; then
    warn "Cannot reach prometheus-operator CRD URL. Check network or PROMETHEUS_OPERATOR_VERSION."
    warn "Falling back to 'latest' release tag..."
    PROMETHEUS_OPERATOR_CRD_BASE="https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd"
  fi

  # Only list the resource plural names — CRD name and filename are derived:
  #   CRD  : {resource}.monitoring.coreos.com
  #   File : monitoring.coreos.com_{resource}.yaml
  PROMETHEUS_CRD_RESOURCES=(
    servicemonitors
    podmonitors
    prometheusrules
    probes
    prometheuses
    alertmanagers
    alertmanagerconfigs
    scrapeconfigs
  )

  for resource in "${PROMETHEUS_CRD_RESOURCES[@]}"; do
    crd_name="${resource}.monitoring.coreos.com"
    crd_file="monitoring.coreos.com_${resource}.yaml"
    apply_crd "${PROMETHEUS_OPERATOR_CRD_BASE}/${crd_file}" "${crd_name}"
  done

  info "Waiting for CRDs to be established..."
  for resource in "${PROMETHEUS_CRD_RESOURCES[@]}"; do
    crd_name="${resource}.monitoring.coreos.com"
    kubectl wait --for=condition=Established crd/"${crd_name}" --timeout=30s 2>/dev/null || \
      warn "Timeout waiting for ${crd_name} — it may still be propagating"
  done

  info "Prometheus Operator CRDs installed successfully."
fi

echo ""
info "All CRDs ready."
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
info "Installed CRDs:"
kubectl get crd | grep -E "monitoring.coreos.com" | awk '{printf "    %-60s %s\n", $1, $2}' || \
  warn "No monitoring.coreos.com CRDs found"
echo ""
info "Helm will now render ServiceMonitor resources automatically when"
info "monitoring.enabled=true and monitoring.serviceMonitor.enabled=true."
