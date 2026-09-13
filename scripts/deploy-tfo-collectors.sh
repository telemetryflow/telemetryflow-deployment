#!/usr/bin/env bash
# =============================================================================
# deploy-tfo-collectors.sh
# Install the per-cluster TFO Collector Helm releases.
#
# Each monitored cluster gets a dedicated collector so telemetry stays
# isolated per tenant/cluster and each carries its own API credentials:
#
#   Release                       Manifest                                        Host
#   tfo-collector-telemetryflow   <env>/tfo-*-tfo-collector-telemetryflow.yaml   collector[.demo].telemetryflow.id
#
# Data flow:
#   tfo-agent (source cluster) --> tfo-collector-<cluster> --> tfo-backend:3100
#
# IMPORTANT: These are SEPARATE Helm releases from the main `telemetryflow`
# release. The chart enables every component by default (tfoBackend,
# postgresql, clickhouse, nats, tfoViz, bullmq, valkey), so each collector
# release explicitly disables them. Do NOT pass the platform overlay
# (tfo-staging.yaml / tfo-production.yaml) as a base values file — that
# would render a full duplicate stack per cluster.
#
# Clusters are whatever manifests exist on disk — not a hardcoded list, so
# adding a monitored cluster only needs its manifest added:
#   staging    : helm/values/staging/tfo-staging-tfo-collector-<cluster>.yaml
#   production : helm/values/production/tfo-prod-tfo-collector-<cluster>.yaml
#
# Secrets: each collector release expects
#   tfo-collector-<cluster>-secret (TELEMETRYFLOW_API_KEY_ID/_SECRET)
# provisioned out of band — see helm/values/production/secrets/.
#
# This script is idempotent — safe to re-run on upgrades.
#
# Usage:
#   bash scripts/deploy-tfo-collectors.sh --env staging            # all clusters
#   bash scripts/deploy-tfo-collectors.sh --env production
#   bash scripts/deploy-tfo-collectors.sh --env staging --list
#   bash scripts/deploy-tfo-collectors.sh --env staging --cluster telemetryflow
#   bash scripts/deploy-tfo-collectors.sh --env production --dry-run
#   TIMEOUT=15m bash scripts/deploy-tfo-collectors.sh --env production
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
NAMESPACE="${NAMESPACE:-observability}"
TIMEOUT="${TIMEOUT:-10m}"
ENVIRONMENT="${ENVIRONMENT:-staging}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHART_DIR="$(cd "${SCRIPT_DIR}/../helm/telemetryflow" && pwd)"

info()  { echo "==> $*"; }
warn()  { echo "WARN: $*" >&2; }
error() { echo "ERROR: $*" >&2; exit 1; }

# staging and production keep their collector manifests in different
# directories with different filename prefixes:
#   staging    : helm/values/staging/tfo-staging-tfo-collector-<cluster>.yaml
#   production : helm/values/production/tfo-prod-tfo-collector-<cluster>.yaml
resolve_env_paths() {
  case "${ENVIRONMENT}" in
    staging)             MANIFEST_SUBDIR="staging";    MANIFEST_PREFIX="tfo-staging" ;;
    prod|production)     MANIFEST_SUBDIR="production"; MANIFEST_PREFIX="tfo-prod" ;;
    *) error "Unknown environment '${ENVIRONMENT}' (expected: staging | production)" ;;
  esac
  MANIFEST_DIR="$(cd "${SCRIPT_DIR}/../helm/values/${MANIFEST_SUBDIR}" && pwd)"
}

manifest_for() { echo "${MANIFEST_DIR}/${MANIFEST_PREFIX}-tfo-collector-$1.yaml"; }
release_for()  { echo "tfo-collector-$1"; }

# Clusters are whatever manifests exist on disk — not a hardcoded list.
discover_clusters() {
  local f base
  for f in "${MANIFEST_DIR}/${MANIFEST_PREFIX}-tfo-collector-"*.yaml; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    base="${base#"${MANIFEST_PREFIX}-tfo-collector-"}"
    echo "${base%.yaml}"
  done
}

# Everything owned by the main `telemetryflow` release must be switched off
# here, or Helm either stands up a duplicate platform or refuses the install
# with "invalid ownership metadata" for shared objects.
#
# global.createNamespace=false — the Namespace belongs to the primary release.
# <component>.enabled=false    — also suppresses that component's Secret
#                                (secrets.yaml gates blocks on the same flag).
# exporters.*                  — sidecar exporter Services are shared, not
#                                per-cluster.
DISABLE_COMPONENTS=(
  global.createNamespace=false
  tfoAgent.enabled=false
  tfoBackend.enabled=false
  tfoViz.enabled=false
  cacheRedis.enabled=false
  cacheValkey.enabled=false
  queueValkey.enabled=false
  bullmq.enabled=false
  nats.enabled=false
  postgresql.enabled=false
  clickhouse.enabled=false
  exporters.redis.enabled=false
  exporters.nats.enabled=false
  exporters.postgresql.enabled=false
  exporters.clickhouse.enabled=false
  monitoring.enabled=false
)

CLUSTERS=()
DRY_RUN=false
LIST_ONLY=false
EXTRA_ARGS=()

usage() { sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || error "--env requires a value (staging | production)"
      ENVIRONMENT="$2"; shift 2 ;;
    --env=*) ENVIRONMENT="${1#*=}"; shift ;;
    --cluster|--tenant)
      [[ $# -ge 2 ]] || error "$1 requires a value"
      CLUSTERS+=("$2"); shift 2 ;;
    --cluster=*|--tenant=*)
      CLUSTERS+=("${1#*=}"); shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --list)    LIST_ONLY=true; shift ;;
    -h|--help) usage ;;
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
  info "Collector manifests available for '${ENVIRONMENT}':"
  found=false
  while read -r c; do
    [[ -n "$c" ]] || continue
    found=true
    printf "    %-16s %s\n" "$c" "$(manifest_for "$c")"
  done < <(discover_clusters)
  [[ "${found}" == "true" ]] || warn "None found in ${MANIFEST_DIR}"
  exit 0
fi

if [[ ${#CLUSTERS[@]} -eq 0 ]]; then
  while read -r c; do
    [[ -n "$c" ]] && CLUSTERS+=("$c")
  done < <(discover_clusters)
fi
[[ ${#CLUSTERS[@]} -gt 0 ]] || error "No collector manifests found in ${MANIFEST_DIR}"

# ---------------------------------------------------------------------------
# Deploy each cluster's collector release
# ---------------------------------------------------------------------------
for CLUSTER in "${CLUSTERS[@]}"; do
  MANIFEST="$(manifest_for "${CLUSTER}")"
  RELEASE="$(release_for "${CLUSTER}")"

  [[ -f "${MANIFEST}" ]] || { warn "No collector manifest for cluster '${CLUSTER}' — skipping"; continue; }

  info "Cluster           : ${CLUSTER}"
  info "Release           : ${RELEASE}"
  info "Manifest          : ${MANIFEST}"
  [[ "${DRY_RUN}" == "true" ]] && info "Mode              : dry-run (no changes applied)"
  echo ""

  SECRET="${RELEASE}-secret"
  if [[ "${DRY_RUN}" != "true" ]]; then
    if ! kubectl get secret "${SECRET}" -n "${NAMESPACE}" >/dev/null 2>&1; then
      warn "Secret '${SECRET}' not found in namespace '${NAMESPACE}' — the collector will fail to start."
      warn "Provision it first (see helm/values/production/secrets/ for the pattern):"
      warn "  kubectl -n ${NAMESPACE} create secret generic ${SECRET} \\"
      warn "    --from-literal=TELEMETRYFLOW_API_KEY_ID='<id>' \\"
      warn "    --from-literal=TELEMETRYFLOW_API_KEY_SECRET='<secret>'"
      error "Refusing to deploy without credentials."
    fi
  fi

  helm_args=(
    upgrade --install "${RELEASE}" "${CHART_DIR}"
    -f "${CHART_DIR}/values.yaml"
    -f "${MANIFEST}"
    --namespace "${NAMESPACE}"
    --timeout "${TIMEOUT}"
  )
  for gating in "${DISABLE_COMPONENTS[@]}"; do
    helm_args+=(--set "${gating}")
  done

  if [[ "${DRY_RUN}" == "true" ]]; then
    helm_args+=(--dry-run)
  else
    helm_args+=(--wait)
  fi

  info "Running helm upgrade --install..."
  helm "${helm_args[@]}" "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
  echo ""
done

info "Deployment complete."
[[ "${DRY_RUN}" == "true" ]] && info "Dry-run complete — nothing was applied."
exit 0
