#!/usr/bin/env bash
set -euo pipefail

# =====================================================================
# collect-cluster-info.sh
#   Snapshot per-node artifacts for the RKE2 cluster:
#     - EC2 instance documents (full describe-instances JSON) per node
#     - cluster summary (instances.json)
#     - kubeconfig copied from the first master (rewritten for local use)
#
#   Output: ansible-k8s/artifacts/cluster/cluster-info-<yyyymmdd-hhmmss>/
# =====================================================================
SCRIPT_NAME="collect-cluster-info.sh"
SCRIPT_VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_BASE="$ROOT_DIR/ansible-k8s/artifacts/cluster"

AWS_PROFILE="${AWS_PROFILE:-"{AWS_ACCOUNT_ID}_AdministratorAccess"}"
AWS_REGION="${AWS_REGION:-"{AWS_DEFAULT_REGION}"}"
SSH_KEY="${SSH_KEY:-$ROOT_DIR/ansible-k8s/keys/tfo-ec2-demo-key.pem}"
SSH_USER="${SSH_USER:-admin}"

info(){ echo "==> $*"; }
die(){  echo "ERROR: $*" >&2; exit 1; }

usage(){ cat <<USAGE_EOF
$SCRIPT_NAME $SCRIPT_VERSION

  Snapshot EC2 instance JSON per node + kubeconfig from the master.

USAGE
  $0 [--profile NAME] [--region NAME] [--key PATH] [--user NAME]

ENV
  AWS_PROFILE (default $AWS_PROFILE)
  AWS_REGION  (default $AWS_REGION)
  SSH_KEY     (default ansible-k8s/keys/tfo-ec2-demo-key.pem)
  SSH_USER    (default $SSH_USER)
USAGE_EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) AWS_PROFILE="${2:-}"; shift ;;
    --region)  AWS_REGION="${2:-}";  shift ;;
    --key)     SSH_KEY="${2:-}";     shift ;;
    --user)    SSH_USER="${2:-}";    shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf '[X] Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac; shift
done

command -v aws >/dev/null 2>&1 || die "aws not found"
command -v jq >/dev/null 2>&1 || die "jq not found"
[[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"
chmod -600 "$SSH_KEY" 2>/dev/null || true

RUN_ID="cluster-info-$(date -u +%Y%m%d-%H%M%S)"
OUT_DIR="$OUT_BASE/$RUN_ID"
mkdir -p "$OUT_DIR"

info "region $AWS_REGION, profile $AWS_PROFILE"
info "output $OUT_DIR"

# ---------------------------------------------------------------------------
# 1. Per-node EC2 documents (full JSON) + summary
# ---------------------------------------------------------------------------
info "collecting EC2 instance documents..."
aws ec2 describe-instances --profile "$AWS_PROFILE" --region "$AWS_REGION" \
  --filters "Name=tag:Terraform,Values=true" "Name=instance-state-name,Values=running,stopped" \
  > "$OUT_DIR/describe-instances-raw.json"

jq '[.Reservations[].Instances[] | {
  name: (.Tags // [] | map(select(.Key=="Name")) | .[0].Value // "unnamed"),
  id: .InstanceId,
  state: .State.Name,
  instance_type: .InstanceType,
  az: .Placement.AvailabilityZone,
  private_ip: .PrivateIpAddress,
  public_ip: .PublicIpAddress,
  key_name: .KeyName,
  security_groups: [.SecurityGroups[].GroupName],
  root_volume: (.BlockDeviceMappings[0].Ebs // {}),
  tags: (.Tags // [])
}]' "$OUT_DIR/describe-instances-raw.json" > "$OUT_DIR/instances.json"

NODE_COUNT=$(jq 'length' "$OUT_DIR/instances.json")
info "found $NODE_COUNT instance(s)"

jq -r '.[] | .id + "\t" + .name' "$OUT_DIR/instances.json" | while IFS=$'\t' read -r id name; do
  jq --arg id "$id" '[.Reservations[].Instances[] | select(.InstanceId==$id)]' \
    "$OUT_DIR/describe-instances-raw.json" > "$OUT_DIR/ec2-${name}.json"
  info "  ec2-${name}.json ($(jq -r '.[0].State.Name' "$OUT_DIR/ec2-${name}.json"))"
done

rm -f "$OUT_DIR/describe-instances-raw.json"

# ---------------------------------------------------------------------------
# 2. kubeconfig from the first master (rewritten for local use)
# ---------------------------------------------------------------------------
MASTER_NAME=$(jq -r '[.[] | select(.name | test("master"))][0].name // empty' "$OUT_DIR/instances.json")
MASTER_PRIV=$(jq -r --arg n "$MASTER_NAME" '[.[] | select(.name==$n)][0].private_ip // empty' "$OUT_DIR/instances.json")
MASTER_PUB=$(jq -r --arg n "$MASTER_NAME" '[.[] | select(.name==$n)][0].public_ip // empty' "$OUT_DIR/instances.json")
[[ -n "$MASTER_NAME" ]] || die "no master node found in instances.json"

# RKE2's API cert SANs cover 127.0.0.1, the node IP and cluster DNS names —
# NOT the public IP. From a laptop the reliable path is an SSH tunnel to the
# master, so the kubeconfig keeps server https://127.0.0.1:6443 and you run:
#   ssh -i $SSH_KEY -N -L 6443:127.0.0.1:6443 $SSH_USER@$MASTER_PUB &
# KUBECONFIG_ENDPOINT=public|private rewrites the server instead (requires
# the API SG open to your IP AND the endpoint present in the serving cert SANs).
SSH_HOST="${MASTER_PUB}"
[[ -n "$SSH_HOST" ]] || SSH_HOST="$MASTER_PRIV"

info "fetching kubeconfig from $MASTER_NAME ($SSH_HOST)..."
SSH_OPTS=(-i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
ssh "${SSH_OPTS[@]}" "$SSH_USER@$SSH_HOST" "sudo cat /etc/rancher/rke2/rke2.yaml" \
  > "$OUT_DIR/kubeconfig" || die "could not fetch kubeconfig"

case "${KUBECONFIG_ENDPOINT:-tunnel}" in
  tunnel)
    KUBE_SERVER="https://127.0.0.1:6443"
    ;;
  public)   [[ -n "$MASTER_PUB" ]]  || die "master has no public IP";  KUBE_SERVER="https://${MASTER_PUB}:6443"  ;;
  private)  [[ -n "$MASTER_PRIV" ]] || die "master has no private IP"; KUBE_SERVER="https://${MASTER_PRIV}:6443" ;;
  *) die "KUBECONFIG_ENDPOINT must be tunnel | public | private" ;;
esac
sed -i '' "s|https://127.0.0.1:6443|${KUBE_SERVER}|" "$OUT_DIR/kubeconfig"
chmod 600 "$OUT_DIR/kubeconfig"
info "kubeconfig saved (server: ${KUBE_SERVER}, chmod 600)"
[[ "${KUBECONFIG_ENDPOINT:-tunnel}" == "tunnel" ]] && info "tunnel: ssh -i $SSH_KEY -N -L 6443:127.0.0.1:6443 $SSH_USER@$SSH_HOST &"

# ---------------------------------------------------------------------------
# 3. Cluster snapshot via kubectl (best effort — 6443 may be VPC-only)
# ---------------------------------------------------------------------------
if [[ "${KUBECONFIG_ENDPOINT:-tunnel}" != "tunnel" ]] && KUBECONFIG="$OUT_DIR/kubeconfig" kubectl get nodes --request-timeout=10s > "$OUT_DIR/nodes.txt" 2>&1; then
  info "nodes.txt saved"
else
  { echo "# kubectl could not reach https://127.0.0.1:6443 from this machine."
    echo "# The RKE2 SG restricts 6443 to the VPC CIDR. Options:"
    echo "#   - open your IP: terraform tfo-ec2-rke2 var rke2_api_access_cidrs=[\"<your-ip>/32\"]"
    echo "#   - or tunnel:    ssh -i $SSH_KEY -L 6443:127.0.0.1:6443 $SSH_USER@$SSH_HOST"
    echo "#    then:          sed -i '' 's|https://127.0.0.1:6443|https://127.0.0.1:6443|' kubeconfig"
  } > "$OUT_DIR/nodes.txt"
  info "kubectl needs the tunnel (see hint above) — nodes.txt contains access hints"
fi

# ---------------------------------------------------------------------------
echo
info "artifacts in $OUT_DIR:"
ls -la "$OUT_DIR" | tail -n +2
echo
info "done ($NODE_COUNT nodes, master: $MASTER_NAME)"
