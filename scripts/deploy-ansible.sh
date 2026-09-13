#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# deploy-ansible.sh
#   Run the TelemetryFlow VM deployment stages (ansible/) in order, with
#   hold points intact.
#
#   site.yml runs the whole stack as one play and is fine for a lab, but
#   it gives no place to stop. This drives the INDIVIDUAL playbooks
#   instead — each stage is its own ansible-playbook invocation, so a
#   failure leaves everything before it intact and runnable again.
#
#   DRY-RUN is the default (--check --diff). --apply is required to
#   change anything.
# =====================================================================
SCRIPT_NAME="deploy-ansible.sh"
SCRIPT_VERSION="1.0.0"

ANSIBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../ansible" && pwd)"

# ===== STAGE TABLE =====
# num | playbook | what it does
# Stages 31/32 are convenience subsets of 30; run either 30 or 31+32.
# Cleanup stages (90/91) are never selected by default: use --only.
STAGES=(
  "00|ping-all.yml|read-only: connectivity check to all hosts"
  "10|install-docker.yml|CREATES docker engine + compose on all hosts"
  "20|deploy-postgres.yml|CREATES postgres 18 container on tfo_db"
  "21|deploy-clickhouse.yml|CREATES clickhouse 26.7 container on tfo_clickhouse"
  "30|deploy-platform.yml|CREATES backend+collector+valkey+nats+viz on tfo_node"
  "31|deploy-backend.yml|backend only (subset of 30)"
  "32|deploy-collector.yml|collector only (subset of 30)"
  "40|deploy-agent.yml|CREATES tfo-agent binary + systemd on agents + platform nodes"
  "90|cleanup-agent.yml|DESTROYS agents (opt-in: --only 90)"
  "91|cleanup-platform.yml|DESTROYS platform stack (opt-in: --only 91)"
)

usage(){ cat <<USAGE_EOF
$SCRIPT_NAME $SCRIPT_VERSION

  Runs the TelemetryFlow VM deployment stages (ansible/) in order.
  Dry-run unless --apply is given. Each stage is a separate
  ansible-playbook invocation so failures leave a runnable prefix.

USAGE
  $0 [--apply] [--from NN] [--to NN] [--only NN[,NN...]] [--skip NN[,NN...]]
     [--list] [--limit PATTERN] [-- <extra ansible-playbook args>]

MODES
      (default)   DRY-RUN. Every stage runs with --check --diff:
                  facts are gathered and read-only tasks report their
                  would-be changes, but nothing is created. Note some
                  shell/command tasks cannot be fully check-moded.
      --apply     Actually run the playbooks.

SELECTING STAGES
      --from NN   Start at stage NN (inclusive).
      --to NN     Stop after stage NN (inclusive).
      --only NN   Run exactly these stages, comma-separated.
      --skip NN   Skip these stages, comma-separated.
      --list      Print the stage table and exit.

OPTIONS
      --limit     Host/group pattern passed to --limit
                  (e.g. tfo_db, tfo_agents, platform-node).
      --          Everything after this is passed to every stage verbatim,
                  e.g. -- -e tfo_backend_version=2.5.8 -t docker

LOGS
  Every run writes its own directory under artifacts/, so a long run can
  be read back instead of scrolled for. RUN is

    deploy-vm-<yyyymmdd-hhmmss>

    artifacts/deploy/RUN/RUN.log                     everything, in order
    artifacts/deploy/RUN/RUN-summary.txt             stage, result, seconds
    artifacts/deploy/RUN/RUN-stage-NN-<name>.log     console, per stage

EXAMPLES
  $0 --list                        # what would run, in order
  $0                               # whole sequence, dry-run
  $0 --apply                       # whole sequence, for real
  $0 --only 20,21 --apply          # just the databases
  $0 --from 30 --apply             # platform onward
  $0 --limit tfo_db --only 20 --apply
USAGE_EOF
}

# ===== CONFIG =====
APPLY=0
LIST_ONLY=0
FROM=""; TO=""; ONLY=""; SKIP=""
LIMIT=""
EXTRA=()

# ===== ARGUMENTS =====
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)   APPLY=1 ;;
    --from)    FROM="${2:-}"; shift ;;
    --to)      TO="${2:-}";   shift ;;
    --only)    ONLY="${2:-}"; shift ;;
    --skip)    SKIP="${2:-}"; shift ;;
    --list)    LIST_ONLY=1 ;;
    --limit)   LIMIT="${2:-}"; shift ;;
    --)        shift; EXTRA=("$@"); break ;;
    -V|--version) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) printf '[X] Unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac; shift
done
cd "$ANSIBLE_DIR"

# ===== STAGE SELECTION =====
in_csv(){ [[ -n "$2" ]] && [[ ",$2," == *",$1,"* ]]; }

SELECTED=()
for row in "${STAGES[@]}"; do
  IFS='|' read -r num pb note <<<"$row"
  # Cleanup stages (90/91) only ever run when asked for by number —
  # they are destructive and must never ride along with a deploy run.
  if [[ "$num" == 9* ]]; then
    [[ -n "$ONLY" ]] && in_csv "$num" "$ONLY" && SELECTED+=("$num|$pb|$note")
    continue
  fi
  [[ -n "$ONLY" ]] && { in_csv "$num" "$ONLY" || continue; }
  in_csv "$num" "$SKIP" && continue
  [[ -n "$FROM" && "$num" < "$FROM" ]] && continue
  [[ -n "$TO"   && "$num" > "$TO"   ]] && continue
  SELECTED+=("$num|$pb|$note")
done

[[ ${#SELECTED[@]} -gt 0 ]] || { printf '[X] No stages selected with those filters.\n\n' >&2; usage >&2; exit 2; }

# ===== RUN IDENTITY AND LOGS =====
RUN_ID="deploy-vm-$(date -u +%Y%m%d-%H%M%S)"
LOG_DIR="$ANSIBLE_DIR/artifacts/deploy/$RUN_ID"
SUMMARY="$LOG_DIR/${RUN_ID}-summary.txt"
RUN_LOG="$LOG_DIR/${RUN_ID}.log"

# ===== PLAN =====
MODE=$([[ "$APPLY" == "1" ]] && echo "APPLY — changes WILL be made" || echo "DRY-RUN — --check --diff, nothing is changed")
cat <<PLAN
=====================================================================
 $SCRIPT_NAME $SCRIPT_VERSION — TelemetryFlow VM deployment
=====================================================================
 inventory   inventory.yml (from ansible.cfg)
 mode        $MODE
 limit       ${LIMIT:-<none>}
 stages      ${#SELECTED[@]} selected
 logs        artifacts/deploy/$RUN_ID/
=====================================================================
PLAN
for s in "${SELECTED[@]}"; do
  IFS='|' read -r num pb note <<<"$s"
  printf '   %-3s %-24s %s\n' "$num" "$pb" "$note"
done
echo "====================================================================="

[[ "$LIST_ONLY" == "1" ]] && exit 0

if [[ "$APPLY" == "1" ]]; then
  printf '\nThis will CHANGE hosts in the VM inventory (install packages, containers, services).\n'
  printf 'Type "apply" to continue: '
  read -r answer
  [[ "$answer" == "apply" ]] || { printf 'Not confirmed — nothing ran.\n' >&2; exit 1; }
fi

# ===== RUN =====
mkdir -p "$LOG_DIR"

PLAY_ARGS=()
[[ "$APPLY" != "1" ]] && PLAY_ARGS+=(--check --diff)
[[ -n "$LIMIT" ]] && PLAY_ARGS+=(--limit "$LIMIT")

{
  echo "run       $RUN_ID"
  echo "script    $SCRIPT_NAME $SCRIPT_VERSION"
  echo "mode      $MODE"
  echo "args      ${PLAY_ARGS[*]-} ${EXTRA[*]-}"
  echo
  printf '%-5s %-24s %-9s %-9s %s\n' "STAGE" "PLAYBOOK" "RESULT" "SECONDS" "LOG"
} > "$SUMMARY"

FAILED=""
STAGE_LOGS=()
for s in "${SELECTED[@]}"; do
  IFS='|' read -r num pb note <<<"$s"
  stage_name="${pb%.yml}"
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
  printf '%-5s %-24s %-9s %-9s %s\n' \
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
