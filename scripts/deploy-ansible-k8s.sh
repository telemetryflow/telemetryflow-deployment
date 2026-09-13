#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# deploy-ansible-k8s.sh
#   Run the RKE2 cluster build + TelemetryFlow deploy stages
#   (ansible-k8s/) in order, with the hold points intact.
#
#   site.yml imports 00→04 as one play and is fine for a lab, but it
#   gives no place to stop and no per-stage evidence. This drives the
#   NUMBERED playbooks instead — each stage is its own invocation, which
#   is what a staged rollout assumes: a RKE2 install that dies on worker
#   2 must not silently re-run the master bootstrap.
#
#   DRY-RUN is the default (--check --diff). --apply is required to
#   change anything.
#
#   Stage 03 delegates to scripts/deploy-<env>.sh (same path as manual
#   deploys): chart helm/telemetryflow + overlay helm/values/<env>/tfo-<env>.yaml.
#   On demo the previous release is uninstalled first for a clean run.
# =====================================================================
SCRIPT_NAME="deploy-ansible-k8s.sh"
SCRIPT_VERSION="1.0.0"

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ansible-k8s" && pwd)"

# ===== STAGE TABLE =====
# num | playbook | what it does
STAGES=(
  "00|00-prerequisites.yml|read-only-ish: packages, kernel modules, sysctl, swap off"
  "01|01-rke2-install.yml|CREATES RKE2 server (masters, serial 1) + agents (workers)"
  "02|02-post-install.yml|fetch kubeconfig, wait nodes Ready, apply labels/taints"
  "03|03-deploy-telemetryflow.yml|helm: local chart + values overlay (tfo-demo default)"
  "04|04-maintenance.yml|read-only: component status, etcd snapshot"
)

usage(){ cat <<USAGE_EOF
$SCRIPT_NAME $SCRIPT_VERSION

  Runs the RKE2 cluster build + TelemetryFlow deploy stages in order.
  Dry-run unless --apply is given. Each stage is a separate
  ansible-playbook invocation so failures leave a runnable prefix.

USAGE
  $0 [--apply] [--from NN] [--to NN] [--only NN[,NN...]] [--skip NN[,NN...]]
     [--list] [--limit PATTERN]
     [-- <extra ansible-playbook args>]

ENVIRONMENT
      The runner's <env> (demo default) selects the values overlay AND the
      deploy script for stage 03: deploy-demo.sh | deploy-staging.sh |
      deploy-production.sh. Pass a different one via -- -e telemetryflow_env=staging

MODES
      (default)   DRY-RUN. Every stage runs with --check --diff:
                  read-only tasks report would-be changes, but nothing
                  is installed. Note the RKE2 install script and helm
                  commands are shell tasks and cannot be fully
                  check-moded — stage 01/03 dry-runs are shallow.
      --apply     Actually run the playbooks.

SELECTING STAGES
      --from NN   Start at stage NN (inclusive).
      --to NN     Stop after stage NN (inclusive).
      --only NN   Run exactly these stages, comma-separated.
      --skip NN   Skip these stages, comma-separated.
      --list      Print the stage table and exit.

OPTIONS
      --limit     Host/group pattern passed to --limit
                  (e.g. workers, masters, worker-01).
      --values-file
                  Helm values overlay for stage 03 (relative to repo
                  root). Default: helm/values/demo/tfo-demo.yaml
      --          Everything after this is passed to every stage verbatim,
                  e.g. -- -e rke2_version=v1.36.4+rke2r1

LOGS
  Every run writes its own directory under artifacts/, so a long build
  can be read back instead of scrolled for. RUN is

    deploy-k8s-<yyyymmdd-hhmmss>

    artifacts/deploy/RUN/RUN.log                     everything, in order
    artifacts/deploy/RUN/RUN-summary.txt             stage, result, seconds
    artifacts/deploy/RUN/RUN-stage-NN-<name>.log     console, per stage

EXAMPLES
  $0 --list                        # what would run, in order
  $0                               # whole sequence, dry-run
  $0 --apply                       # whole build, for real
  $0 --only 03 --apply             # redeploy the helm chart only
  $0 --values-file helm/values/staging/tfo-staging.yaml --only 03 --apply
  $0 --from 02 --apply             # platform onward (cluster already up)
USAGE_EOF
}

# ===== CONFIG =====
ENVIRONMENT="${ENVIRONMENT:-demo}"   # demo | staging | production
APPLY=0
LIST_ONLY=0
FROM=""; TO=""; ONLY=""; SKIP=""
LIMIT=""
VALUES_FILE=""
EXTRA=()

# ===== ARGUMENTS =====
while [[ $# -gt 0 ]]; do
  case "$1" in
    demo|staging|production) ENVIRONMENT="$1" ;;
    --apply)       APPLY=1 ;;
    --from)        FROM="${2:-}"; shift ;;
    --to)          TO="${2:-}";   shift ;;
    --only)        ONLY="${2:-}"; shift ;;
    --skip)        SKIP="${2:-}"; shift ;;
    --list)        LIST_ONLY=1 ;;
    --limit)       LIMIT="${2:-}"; shift ;;
    --)            shift; EXTRA=("$@"); break ;;
    -V|--version)  printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    -h|--help)     usage; exit 0 ;;
    *) printf '[X] Unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac; shift
done
cd "$ANSIBLE_DIR"

# ===== ENV → OVERLAY + DEPLOY SCRIPT (stage 03) =====
case "${ENVIRONMENT}" in
  demo)       OVERLAY="helm/values/demo/tfo-demo.yaml" ;;
  staging)    OVERLAY="helm/values/staging/tfo-staging.yaml" ;;
  production) OVERLAY="helm/values/production/tfo-production.yaml" ;;
  *) printf '[X] Unknown environment: %s (demo | staging | production)\n' "$ENVIRONMENT" >&2; exit 2 ;;
esac
VALUES_FILE="$ANSIBLE_DIR/../$OVERLAY"
[[ -f "$VALUES_FILE" ]] || { printf '[X] Values overlay not found: %s\n' "$VALUES_FILE" >&2; exit 2; }
DEPLOY_SCRIPT="$ANSIBLE_DIR/../scripts/deploy-${ENVIRONMENT}.sh"
[[ -f "$DEPLOY_SCRIPT" ]] || { printf '[X] Deploy script not found: %s\n' "$DEPLOY_SCRIPT" >&2; exit 2; }

# ===== STAGE SELECTION =====
in_csv(){ [[ -n "$2" ]] && [[ ",$2," == *",$1,"* ]]; }

SELECTED=()
for row in "${STAGES[@]}"; do
  IFS='|' read -r num pb note <<<"$row"
  [[ -n "$ONLY" ]] && { in_csv "$num" "$ONLY" || continue; }
  in_csv "$num" "$SKIP" && continue
  [[ -n "$FROM" && "$num" < "$FROM" ]] && continue
  [[ -n "$TO"   && "$num" > "$TO"   ]] && continue
  SELECTED+=("$num|$pb|$note")
done

[[ ${#SELECTED[@]} -gt 0 ]] || { printf '[X] No stages selected with those filters.\n\n' >&2; usage >&2; exit 2; }

# ===== RUN IDENTITY AND LOGS =====
RUN_ID="deploy-k8s-$(date -u +%Y%m%d-%H%M%S)"
LOG_DIR="$ANSIBLE_DIR/artifacts/deploy/$RUN_ID"
SUMMARY="$LOG_DIR/${RUN_ID}-summary.txt"
RUN_LOG="$LOG_DIR/${RUN_ID}.log"

# ===== PLAN =====
MODE=$([[ "$APPLY" == "1" ]] && echo "APPLY — changes WILL be made" || echo "DRY-RUN — --check --diff, nothing is changed")
cat <<PLAN
=====================================================================
 $SCRIPT_NAME $SCRIPT_VERSION — RKE2 + TelemetryFlow
=====================================================================
 inventory   inventory/hosts.yml (from ansible.cfg)
 chart       ../helm/telemetryflow (local)
 overlay     ${VALUES_FILE#"$ANSIBLE_DIR"/../}
 deploy via  scripts/deploy-${ENVIRONMENT}.sh
 mode        $MODE
 limit       ${LIMIT:-<none>}
 stages      ${#SELECTED[@]} selected
 logs        artifacts/deploy/$RUN_ID/
=====================================================================
PLAN
for s in "${SELECTED[@]}"; do
  IFS='|' read -r num pb note <<<"$s"
  printf '   %-3s %-28s %s\n' "$num" "$pb" "$note"
done
echo "====================================================================="

[[ "$LIST_ONLY" == "1" ]] && exit 0

if [[ "$APPLY" == "1" ]]; then
  printf '\nThis will CHANGE cluster hosts (install RKE2, deploy TelemetryFlow).\n'
  printf 'Type "apply" to continue: '
  read -r answer
  [[ "$answer" == "apply" ]] || { printf 'Not confirmed — nothing ran.\n' >&2; exit 1; }
fi

# ===== RUN =====
mkdir -p "$LOG_DIR"

PLAY_ARGS=()
[[ "$APPLY" != "1" ]] && PLAY_ARGS+=(--check --diff)
[[ -n "$LIMIT" ]] && PLAY_ARGS+=(--limit "$LIMIT")
# Stage 03 selects the deploy script + overlay from this variable.
PLAY_ARGS+=(-e "telemetryflow_env=$ENVIRONMENT")

{
  echo "run       $RUN_ID"
  echo "script    $SCRIPT_NAME $SCRIPT_VERSION"
  echo "mode      $MODE"
  echo "overlay   $VALUES_FILE"
  echo "deploy    $DEPLOY_SCRIPT"
  echo "args      ${PLAY_ARGS[*]-} ${EXTRA[*]-}"
  echo
  printf '%-5s %-28s %-9s %-9s %s\n' "STAGE" "PLAYBOOK" "RESULT" "SECONDS" "LOG"
} > "$SUMMARY"

FAILED=""
STAGE_LOGS=()
for s in "${SELECTED[@]}"; do
  IFS='|' read -r num pb note <<<"$s"
  stage_name="${pb#*-}"; stage_name="${stage_name%.yml}"
  stage_log="$LOG_DIR/${RUN_ID}-stage-${num}-${stage_name}.log"
  STAGE_LOGS+=("$stage_log")
  echo
  echo "---------------------------------------------------------------------"
  echo "==> stage $num — $pb   ->  $(basename "$stage_log")"
  echo "---------------------------------------------------------------------"
  started="$(date -u +%s)"

  if ansible-playbook "playbooks/$pb" ${PLAY_ARGS[@]+"${PLAY_ARGS[@]}"} \
       ${EXTRA[@]+"${EXTRA[@]}"} 2>&1 | tee "$stage_log"; then
    result="OK"
  else
    result="FAILED"
  fi
  elapsed=$(( $(date -u +%s) - started ))
  printf '%-5s %-28s %-9s %-9s %s\n' \
    "$num" "$pb" "$result" "$elapsed" "$(basename "$stage_log")" >> "$SUMMARY"

  if [[ "$result" == "OK" ]]; then
    echo "==> stage $num complete (${elapsed}s)"
  else
    FAILED="$num"
    echo "WARN: stage $num FAILED after ${elapsed}s — stopping. Later stages were not attempted." >&2
    break
  fi
done

if [[ ${#STAGE_LOGS[@]} -gt 0 ]]; then
  cat "${STAGE_LOGS[@]}" > "$RUN_LOG" 2>/dev/null || true
fi

echo
echo "--------------------------- summary ---------------------------------"
cat "$SUMMARY"
echo "---------------------------------------------------------------------"
echo "  full log   $RUN_LOG"
echo

if [[ -n "$FAILED" ]]; then
  printf 'Sequence stopped at stage %s. Read %s, then resume:\n  %s --from %s %s\n' \
    "$FAILED" "$LOG_DIR/${RUN_ID}-stage-${FAILED}-"*.log "$0" "$FAILED" "$([[ "$APPLY" == "1" ]] && echo '--apply')" >&2
  exit 1
fi

echo "==> all ${#SELECTED[@]} stage(s) complete"
if [[ "$APPLY" != "1" ]]; then
  cat <<'NEXT'

That was a DRY-RUN — nothing was changed. To apply:
  add --apply
NEXT
fi
