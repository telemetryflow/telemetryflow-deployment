# Runbook — TelemetryFlow Kubernetes Deployment

## Prerequisites

- Ansible >= 2.16
- Python >= 3.10
- SSH access to all target nodes
- Sudo privileges on all target nodes

## Pre-Deployment Checklist

1. Update `inventory/hosts.yml` with actual node IPs and hostnames
2. Set `rke2_token` in `inventory/group_vars/all.yml` (generate with `openssl rand -hex 32`)
3. Set `rke2_server_ip` or verify auto-detection from inventory
4. Review and customize `inventory/group_vars/all.yml` values
5. Ensure DNS resolution between all nodes
6. Ensure NTP synchronization on all nodes
7. Verify firewall rules allow required ports

## Required Ports

| Port  | Protocol | Direction | Purpose              |
| ----- | -------- | --------- | -------------------- |
| 6443  | TCP      | Inbound   | Kubernetes API       |
| 9345  | TCP      | Inbound   | RKE2 Server          |
| 2379  | TCP      | Intra     | etcd client          |
| 2380  | TCP      | Intra     | etcd peer            |
| 30000 | TCP      | Intra     | etcd metrics         |
| 10250 | TCP      | Intra     | kubelet              |
| 8472  | UDP      | Intra     | Canal/VXLAN          |
| 51820 | UDP      | Intra     | WireGuard (Cilium)   |
| 80    | TCP      | Inbound   | HTTP ingress         |
| 443   | TCP      | Inbound   | HTTPS ingress        |

## Deployment Procedures

### Full Deployment

```bash
cd ansible-k8s
ansible-playbook playbooks/site.yml
```

### Step-by-Step Deployment

```bash
ansible-playbook playbooks/00-prerequisites.yml
ansible-playbook playbooks/01-rke2-install.yml
ansible-playbook playbooks/02-post-install.yml
ansible-playbook playbooks/03-deploy-telemetryflow.yml
ansible-playbook playbooks/04-maintenance.yml
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/site.yml --check
```

### Deploy to Specific Nodes

```bash
ansible-playbook playbooks/01-rke2-install.yml --limit masters
ansible-playbook playbooks/01-rke2-install.yml --limit workers
```

### Deploy with Verbose Output

```bash
ansible-playbook playbooks/site.yml -vv
```

## Verification

After deployment, verify cluster health:

```bash
export KUBECONFIG=kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
kubectl get namespaces
```

## Rollback Procedures

### Rollback Helm Release

```bash
helm history telemetryflow -n telemetryflow
helm rollback telemetryflow <REVISION> -n telemetryflow
```

### Rollback RKE2 on a Worker

```bash
systemctl stop rke2-agent
rke2-agent uninstall
# Re-run the install playbook targeting only that node
ansible-playbook playbooks/01-rke2-install.yml --limit worker-03
```

### Rollback RKE2 on a Master

> **Warning**: Rolling back a master requires extra caution. Ensure etcd quorum is maintained.

1. Verify remaining masters form quorum: `etcdctl member list`
2. Stop RKE2 server: `systemctl stop rke2-server`
3. Re-run install: `ansible-playbook playbooks/01-rke2-install.yml --limit master-03`

### Full Cluster Rebuild

```bash
# Stop everything on all nodes
ansible all -m shell -a "systemctl stop rke2-server rke2-agent || true"
ansible all -m shell -a "/usr/local/bin/rke2-uninstall.sh || true"
ansible all -m shell -a "rm -rf /var/lib/rancher/rke2 /etc/rancher/rke2"

# Re-run full deployment
ansible-playbook playbooks/site.yml
```

## Troubleshooting

### Node Not Joining Cluster

1. Check RKE2 agent logs: `journalctl -u rke2-agent -f`
2. Verify connectivity to server: `curl -k https://<server-ip>:9345`
3. Verify token matches on all nodes
4. Check firewall rules

### Pods Stuck in Pending

1. Check node resources: `kubectl describe node <node>`
2. Check events: `kubectl get events -A --sort-by='.lastTimestamp'`
3. Verify CNI is running: `kubectl get pods -n kube-system -l app=canal`

### Helm Deployment Failing

1. Check Helm release status: `helm status telemetryflow -n telemetryflow`
2. Review pod events: `kubectl describe pod <pod> -n telemetryflow`
3. Check values: `helm get values telemetryflow -n telemetryflow --all`

### etcd Issues

1. Check etcd health: `etcdctl endpoint health`
2. Check etcd members: `etcdctl member list`
3. Check disk space: `df -h /var/lib/rancher/rke2/server/db`

### Common Commands

```bash
# View RKE2 server logs
journalctl -u rke2-server -f

# View RKE2 agent logs
journalctl -u rke2-agent -f

# Restart RKE2
systemctl restart rke2-server  # on masters
systemctl restart rke2-agent   # on workers

# Check container runtime
crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock ps
```

## Scaling

### Add a Worker Node

1. Add the host to `inventory/hosts.yml` under `workers`
2. Run prerequisites: `ansible-playbook playbooks/00-prerequisites.yml --limit <new-worker>`
3. Run install: `ansible-playbook playbooks/01-rke2-install.yml --limit <new-worker>`

### Remove a Worker Node

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl delete node <node>
# On the node:
systemctl stop rke2-agent
/usr/local/bin/rke2-uninstall.sh
```
