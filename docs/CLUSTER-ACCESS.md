# Cluster Access & Kubeconfig

How to reach the TelemetryFlow RKE2 cluster from your workstation — kubeconfig
retrieval, the SSH tunnel (default), and the requirements for direct access.

## Overview

| Item              | Value                                                              |
| ----------------- | ------------------------------------------------------------------ |
| Cluster           | `telemetryflow-cluster` (RKE2 v1.36.4+rke2r1, single-AZ demo)       |
| Master            | `tfo-master-01` — `54.179.48.79` (public) / `10.41.90.81` (VPC)    |
| API server        | `:6443` — SG `tfo-rke2-sg` allows **VPC CIDR only** (`10.41.0.0/16`) |
| Cert SANs         | `127.0.0.1`, `10.41.90.81`, `10.43.0.1`, `localhost`, `tfo-master-01`, `telemetryflow-cluster.cluster.local` — **no public IP** |
| Namespace         | `observability`                                                    |
| Artifacts         | `ansible-k8s/artifacts/cluster/<run>/` (git-ignored)              |

Two things block a plain `KUBECONFIG=... kubectl get nodes` from a laptop:

1. **Security group** — 6443 is open to the VPC CIDR only, not the internet.
2. **Serving certificate** — the API server cert does not include the public
   IP, so even with the SG open you would get an x509 hostname mismatch.

The SSH tunnel solves both: the packet enters via SSH (port 22, key auth) and
kubectl talks to `https://127.0.0.1:6443`, which IS in the cert SANs.

## Collect the artifacts

`scripts/collect-cluster-info.sh` snapshots everything per run:

```bash
scripts/collect-cluster-info.sh
```

Output (under `ansible-k8s/artifacts/cluster/cluster-info-<timestamp>/`):

| File                       | Content                                              |
| -------------------------- | ---------------------------------------------------- |
| `ec2-tfo-<node>.json`      | Full EC2 instance document per node (master/worker)  |
| `instances.json`           | Summary: IPs, type, AZ, SGs, volumes, tags           |
| `kubeconfig`               | Admin kubeconfig (`chmod 600`), server `127.0.0.1`   |
| `nodes.txt`                | `kubectl get nodes` or access hints                  |

## Access via SSH tunnel (default)

```bash
# 1. Start the tunnel (leave it running in the background)
ssh -i ansible-k8s/keys/tfo-example-demo.pem \
    -N -L 6443:127.0.0.1:6443 admin@54.179.48.79 &

# 2. Point kubectl at the collected kubeconfig
export KUBECONFIG=$(ls -t ansible-k8s/artifacts/cluster/*/kubeconfig | head -1)

# 3. Verify
kubectl get nodes
kubectl -n observability get pods
```

The tunnel forwards local `6443` to the master's loopback, so kubectl's
`https://127.0.0.1:6443` hits the API server with a cert SAN that matches.
Nothing is exposed to the internet.

## Direct access (optional)

If you need kubectl without a tunnel (CI, dashboards), the API endpoint must
be reachable AND present in the serving cert SANs:

1. **Open the SG** to your IP — the intended Terraform knob:
   `terraform/environment/telemetryflow/tfo-demo/tfo-ec2-rke2` variable
   `rke2_api_access_cidrs = ["<your-ip>/32"]` (rule lives in `tfo-rke2-sg`).
2. **Add the endpoint to `tls-san`** in the RKE2 server config
   (`ansible-k8s` role `rke2`, `rke2_server_ip` + tls-san list) and let RKE2
   regenerate the serving cert, then collect a fresh kubeconfig:

   ```bash
   KUBECONFIG_ENDPOINT=public scripts/collect-cluster-info.sh
   ```

   (`KUBECONFIG_ENDPOINT=private` rewrites to the VPC IP — VPN/peering only.)

> Out-of-band SG edits (`aws ec2 authorize-security-group-ingress`) work
> immediately but drift from Terraform — prefer the variable.

## Troubleshooting

| Symptom                                    | Cause / fix                                            |
| ------------------------------------------ | ------------------------------------------------------ |
| `connection refused 127.0.0.1:6443`        | Tunnel not running — start the `ssh -L` command        |
| `i/o timeout` to `54.179.48.79:6443`       | SG blocks 6443 (VPC-only) — use the tunnel             |
| `x509: certificate is valid for ...`       | Endpoint not in cert SANs — use tunnel, or add tls-san |
| `Unauthorized` from helm/agent             | Wrong join token — see `inventory/group_vars/all/token.yml` notes |
| `error: You must be logged in` via tunnel  | `KUBECONFIG` not pointing at the collected kubeconfig  |

## Related

- [DEPLOYMENT.md](./DEPLOYMENT.md) — stage-runner pipeline (`scripts/deploy-ansible-k8s.sh`)
- [NETWORKING.md](./NETWORKING.md) — port reference and DNS layout
- [ANSIBLE-GUIDE.md](./ANSIBLE-GUIDE.md) — inventory, SSH key and group_vars layout
