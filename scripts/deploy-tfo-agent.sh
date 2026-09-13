#!/usr/bin/env bash
# =============================================================================
# deploy-tfo-agent.sh
# Install the TFO Agent on a monitored source cluster.
#
# Runs ON THE SOURCE CLUSTER being monitored — not on the platform cluster.
# The platform cluster is provisioned by deploy-staging.sh / deploy-production.sh,
# which also install the per-cluster collectors (deploy-tfo-collectors.sh).
#
# Data flow this script completes:
#   source cluster: tfo-agent  --metrics/traces/logs-->  platform: tfo-collector-<cluster>
#                            --heartbeat/k8s-sync-->  platform: tfo-backend
#
# Deploys two workloads from the tfo-agent chart (helm/tfo-agent):
#   DaemonSet  tfo-agent      — per-node OS metrics (node_exporter, cAdvisor, Fluent Bit)
#   Deployment tfo-agent-k8s  — single-replica K8s state collector + cluster sync
#
# Release name is tfo-agent-<cluster> so it never collides with the platform
# release, and several clusters can be inspected side by side with `helm list`.
#
# Manifests (one per cluster, discovered automatically):
#   staging    : helm/values/staging/tfo-staging-tfo-agent-<cluster>.yaml
#   production : helm/values/production/tfo-prod-tfo-agent-<cluster>.yaml
#
# Secrets are NOT created from the manifest (secrets.create: false) —
# provision tfo-agent-secrets out of band:
#   kubectl -n observability create secret generic tfo-agent-secrets \
#     --from-literal=TELEMETRYFLOW_API_KEY_ID='<id from TFO Platform > API Keys>' \
#     --from-literal=TELEMETRYFLOW_API_KEY_SECRET='<secret>'
#
# This script is idempotent — safe to re-run on upgrades.
#
# Usage:
#   bash scripts/deploy-tfo-agent.sh --cluster telemetryflow
#   bash scripts/deploy-tfo-agent.sh --cluster telemetryflow --env production
#   bash scripts/deploy-tfo-agent.sh --list
#   bash scripts/deploy-tfo-agent.sh --cluster telemetryflow --dry-run
#   bash scripts/deploy-tfo-agent.sh --cluster telemetryflow --set tfoAgent.image.tag=1.2.3
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-observability}"
TIMEOUT="${TIMEOUT:-10m}"
ENVIRONMENT="${ENVIRONMENT:-staging}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/../helm/tfo-agent" && pwd)"

CLUSTER=""
DRY_RUN=false
LIST_ONLY=false
EXTRA_ARGS=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "==> $*"; }
warn()  { echo "WARN: $*"; }
error() { echo "ERROR: $*" >&2; exit 1; }

resolve_env_paths() {
  case "${ENVIRONMENT}" in
    staging)         MANIFEST_SUBDIR="staging";    MANIFEST_PREFIX="tfo-staging" ;;
    prod|production) MANIFEST_SUBDIR="production"; MANIFEST_PREFIX="tfo-prod" ;;
    *) error "Unknown environment '${ENVIRONMENT}' (expected: staging | production)" ;;
  esac
  MANIFEST_DIR="$(cd "${SCRIPT_DIR}/../helm/values/${MANIFEST_SUBDIR}" && pwd)"
}

manifest_for() { echo "${MANIFEST_DIR}/${MANIFEST_PREFIX}-tfo-agent-$1.yaml"; }

# Clusters are whatever manifests exist on disk — not a hardcoded list, so a
# new cluster only needs its manifest added.
discover_clusters() {
  local f base
  for f in "${MANIFEST_DIR}/${MANIFEST_PREFIX}-tfo-agent-"*.yaml; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    base="${base#"${MANIFEST_PREFIX}-tfo-agent-"}"
    echo "${base%.yaml}"
  done
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster|--tenant)  [[ $# -ge 2 ]] || error "$1 requires a value"; CLUSTER="$2"; shift 2 ;;
    --cluster=*|--tenant=*) CLUSTER="${1#*=}"; shift ;;
    --env)     [[ $# -ge 2 ]] || error "--env requires a value (staging | production)"; ENVIRONMENT="$2"; shift 2 ;;
    --env=*)   ENVIRONMENT="${1#*=}"; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --list)    LIST_ONLY=true; shift ;;
    -h|--help) sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
command -v helm    >/dev/null 2>&1 || error "helm not found"
command -v kubectl >/dev/null 2>&1 || error "kubectl not found"

resolve_env_paths

if [[ "${LIST_ONLY}" == "true" ]]; then
  info "Agent manifests available for '${ENVIRONMENT}':"
  found=false
  while read -r c; do
    [[ -n "$c" ]] || continue
    found=true
    printf "    %-16s %s\n" "$c" "$(manifest_for "$c")"
  done < <(discover_clusters)
  [[ "${found}" == "true" ]] || warn "None found in ${MANIFEST_DIR}"
  exit 0
fi

[[ -n "${CLUSTER}" ]] || error "--cluster is required (see --list)"

MANIFEST="$(manifest_for "${CLUSTER}")"
[[ -f "${MANIFEST}" ]] || error "No agent manifest for cluster '${CLUSTER}' in ${ENVIRONMENT}: ${MANIFEST}"

RELEASE="tfo-agent-${CLUSTER}"

info "Cluster context : $(kubectl config current-context)"
info "Environment     : ${ENVIRONMENT}"
info "Cluster         : ${CLUSTER}"
info "Release         : ${RELEASE}"
info "Namespace       : ${NAMESPACE}"
info "Chart directory : ${CHART_DIR}"
info "Manifest        : ${MANIFEST}"
[[ "${DRY_RUN}" == "true" ]] && info "Mode            : dry-run (no changes applied)"
echo ""

# The agent scrapes kubelet and the metrics API; without metrics-server the
# Kubernetes CPU/Memory charts stay empty but the agent still runs.
info "Checking metrics-server availability..."
if kubectl get apiservice v1beta1.metrics.k8s.io >/dev/null 2>&1; then
  info "metrics-server: available"
else
  warn "metrics-server not found — Kubernetes CPU/Memory usage charts will be empty."
  warn "Set collectors.kubernetes.metrics_api: false in the manifest to suppress warnings."
fi
echo ""

# Agent credentials must exist before the workloads start.
if [[ "${DRY_RUN}" != "true" ]]; then
  info "Verifying agent credentials..."
  if ! kubectl get secret tfo-agent-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
    error "Secret 'tfo-agent-secrets' not found in namespace '${NAMESPACE}'.
       Provision it first:
         kubectl -n ${NAMESPACE} create secret generic tfo-agent-secrets \\
           --from-literal=TELEMETRYFLOW_API_KEY_ID='<id from TFO Platform > API Keys>' \\
           --from-literal=TELEMETRYFLOW_API_KEY_SECRET='<secret>'"
  fi
  info "Agent credentials verified."
  echo ""
fi

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
info "Running helm upgrade --install..."

helm_args=(
  upgrade --install "${RELEASE}" "${CHART_DIR}"
  -f "${CHART_DIR}/values.yaml"
  -f "${MANIFEST}"
  --namespace "${NAMESPACE}"
  --create-namespace
  --set global.createNamespace=false
  --timeout "${TIMEOUT}"
)

if [[ "${DRY_RUN}" == "true" ]]; then
  helm_args+=(--dry-run)
else
  helm_args+=(--wait)
fi

helm "${helm_args[@]}" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"

echo ""
info "Deployment complete."
echo ""

if [[ "${DRY_RUN}" == "true" ]]; then
  info "Dry-run complete — nothing was applied."
  exit 0
fi

# ---------------------------------------------------------------------------
# Post-deploy verification
# ---------------------------------------------------------------------------
info "Verify agent workloads:"
echo "    kubectl -n ${NAMESPACE} get daemonset tfo-agent"
echo "    kubectl -n ${NAMESPACE} get deployment tfo-agent-k8s"
echo ""
info "Agent logs (DaemonSet):"
echo "    kubectl -n ${NAMESPACE} logs ds/tfo-agent --tail=50"
echo ""
info "Confirm telemetry is being exported (no OTLP export failures):"
echo "    kubectl -n ${NAMESPACE} logs ds/tfo-agent --tail=50 | grep -E 'OTLP export|forwarded'"
echo ""
info "Confirm cluster auto-registration and K8s state sync:"
echo "    kubectl -n ${NAMESPACE} logs deploy/tfo-agent-k8s --tail=30 | grep -iE 'cluster|register|sync|error'"
