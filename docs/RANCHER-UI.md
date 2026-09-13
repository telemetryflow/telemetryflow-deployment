# Rancher UI Access

How to install and reach the Rancher management UI on the TelemetryFlow RKE2
cluster. RKE2 ships the engine only — the Rancher UI is a separate Helm chart
(`rancher-stable/rancher`) that also requires **cert-manager**.

## Overview

| Item             | Value                                                        |
| ---------------- | ------------------------------------------------------------ |
| Chart            | `rancher-stable/rancher` (replicas 1 for demo)               |
| Prerequisite     | cert-manager (Rancher's default TLS issuer needs its CRDs)   |
| Hostname         | demo `rancher-demo` · staging `rancher-staging` · prod `rancher.telemetryflow.id` |
| Access           | `kubectl port-forward` → `https://…:8443` (no DNS/LB needed) |
| Credentials      | `bootstrapPassword` set at install; changed on first login   |

## 0. Cluster access (prerequisite)

kubectl must reach the cluster — see [CLUSTER-ACCESS.md](./CLUSTER-ACCESS.md):

```bash
ssh -i ansible-k8s/keys/tfo-ec2-demo-key.pem \
    -N -L 6443:127.0.0.1:6443 admin@54.179.48.79 &
export KUBECONFIG=$(ls -t ansible-k8s/artifacts/cluster/*/kubeconfig | head -1)
kubectl get nodes
```

## 1. Install cert-manager (once per cluster)

Rancher's chart renders an `Issuer`/`Certificate` — without cert-manager CRDs
the install fails with `no matches for kind "Issuer" in version
"cert-manager.io/v1"`:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set crds.enabled=true \
  --wait --timeout 5m
```

## 2. Install Rancher

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update rancher-stable

kubectl create namespace cattle-system

helm upgrade --install rancher rancher-stable/rancher \
  -n cattle-system \
  --set hostname=rancher-demo.telemetryflow.id \
  --set replicas=1 \
  --set ingress.enabled=false \
  --set bootstrapPassword=<CHANGE_ME> \
  --set 'nodeSelector.telemetryflow\.io/role=workload' \
  --wait --timeout 8m
```

Notes:

- `ingress.enabled=false` — no DNS/LoadBalancer in the demo; access is via
  port-forward. Rancher serves its own self-signed TLS (browser warning is
  expected).
- `nodeSelector.telemetryflow.io/role=workload` keeps Rancher off the master
  (`t3.medium` runs the control plane; Rancher wants ±1 GB RAM).
- Change `bootstrapPassword` before anything shared.

## 3. Reach the UI from the browser

```bash
# 1. Forward the service (leave running)
kubectl -n cattle-system port-forward svc/rancher 8443:443 &

# 2. Laptop /etc/hosts — Rancher validates the hostname
#    127.0.0.1 rancher-demo.telemetryflow.id
```

Browse: **<https://rancher-demo.telemetryflow.id:8443>**
Login: `admin` / your `bootstrapPassword` (you are prompted to set a new one).

## Production path

For a permanent UI on staging/production:

1. DNS `rancher[-staging|-demo].telemetryflow.id` pointing at the cluster entrypoint.
2. `ingress.enabled=true` with the cluster's ingress (traefik ships with RKE2)
   — note a `type: LoadBalancer` Service stays `Pending` on plain EC2 without
   the AWS Load Balancer Controller; expose via NodePort or install
   aws-load-balancer-controller first.
3. `replicas=3`, `ingress.tls.source=letsEncrypt` (or your issuer).

## Troubleshooting

| Symptom                                                    | Fix                                                          |
| ---------------------------------------------------------- | ------------------------------------------------------------ |
| `no matches for kind "Issuer"` during helm install         | Install cert-manager first (step 1), then retry              |
| `port-forward` dies with `connection refused`              | Rancher pod not ready — `kubectl -n cattle-system get pods`   |
| Browser `404 host not found` / cert warning loops          | `/etc/hosts` entry missing or hostname typo                   |
| `kubectl` errors while port-forwarding Rancher             | API tunnel down — restart the SSH tunnel (step 0)             |
| Rancher pod Pending                                        | Worker CPU full — check `kubectl describe pod`, free capacity |

## Related

- [CLUSTER-ACCESS.md](./CLUSTER-ACCESS.md) — kubeconfig + API tunnel
- [DEPLOYMENT.md](./DEPLOYMENT.md) — deployment pipeline overview
