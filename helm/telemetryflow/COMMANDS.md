# TelemetryFlow - Command Reference

Quick reference untuk command-command yang sering digunakan saat manage deployment TelemetryFlow di RKE2 / EKS.

## Values File Structure

| File                     | Purpose                                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| `values.yaml`            | Base defaults (all environments)                                         |
| `values-staging.yaml`    | Staging overrides — AZ pinning to us-west-2c, reduced replicas, OTEL off |
| `values-production.yaml` | Production overrides — podAffinity co-location, HA, autoscaling          |

Values are layered: `values.yaml` → `values-<env>.yaml`. The overlay only needs to specify what differs from base.

## 🚀 Deployment Commands

### Deploy menggunakan script otomatis

```bash
cd _infra/helm

# Demo environment (base values only)
./deploy.sh demo

# Staging environment (values.yaml + values-staging.yaml)
./deploy.sh staging

# Production environment (values.yaml + values-production.yaml)
./deploy.sh prod
```

### Deploy manual dengan Helm

```bash
# Demo deployment (base only)
helm install telemetryflow . \
  --namespace telemetryflow \
  --create-namespace \
  --values values.yaml \
  --timeout 15m \
  --wait

# Staging deployment (base + staging overlay)
helm install telemetryflow . \
  --namespace telemetryflow \
  --create-namespace \
  --values values.yaml \
  --values values-staging.yaml \
  --timeout 15m \
  --wait

# Production deployment (base + production overlay)
helm install telemetryflow . \
  --namespace telemetryflow \
  --create-namespace \
  --values values.yaml \
  --values values-production.yaml \
  --timeout 15m \
  --wait
```

### Upgrade deployment

```bash
# Upgrade staging
helm upgrade telemetryflow . \
  --namespace telemetryflow \
  --values values.yaml \
  --values values-staging.yaml \
  --timeout 15m \
  --wait

# Upgrade production
helm upgrade telemetryflow . \
  --namespace telemetryflow \
  --values values.yaml \
  --values values-production.yaml \
  --timeout 15m \
  --wait

# Upgrade dengan reuse values
helm upgrade telemetryflow . \
  --namespace telemetryflow \
  --reuse-values \
  --timeout 15m
```

### Dry run sebelum deploy

```bash
# Test template generation — staging
helm template telemetryflow . \
  --values values.yaml \
  --values values-staging.yaml

# Test install without actually deploying — production
helm install telemetryflow . \
  --namespace telemetryflow \
  --values values.yaml \
  --values values-production.yaml \
  --dry-run --debug

# Generate manifests to file — staging
helm template telemetryflow . \
  --namespace telemetryflow \
  --values values.yaml \
  --values values-staging.yaml \
  > manifests-staging.yaml
```

## 🔧 Cross-AZ Cost Fix Commands

### Verify AZ placement after deploy

```bash
# Check all pods and their nodes/AZs
kubectl get po -n observability -o wide

# Check node AZ labels
kubectl get nodes --show-labels | grep topology.kubernetes.io/zone

# Confirm core services co-located in same AZ
# Expected (staging): backend, collector, postgresql, redis-master, cache-redis → us-west-2c
kubectl get po -n observability -o custom-columns=\
NAME:.metadata.name,\
NODE:.spec.nodeName,\
STATUS:.status.phase \
  | grep -E "backend|collector|postgres|redis|clickhouse|cache"
```

### Ad-hoc fix (without Helm) — if quick patch needed

```bash
# Pin backend to us-west-2c immediately
kubectl patch deployment tfo-backend -n observability --patch '{
  "spec": {"template": {"spec": {
    "nodeSelector": {"topology.kubernetes.io/zone": "us-west-2c"}
  }}}
}'

# Disable redis-replica in staging
kubectl scale statefulset redis-replica -n observability --replicas=0

# Scale viz to 1 replica
kubectl scale deployment tfo-viz -n observability --replicas=1

# Watch rollout
kubectl rollout status deployment/tfo-backend -n observability
```

### Verify cross-AZ traffic reduced (after fix)

```bash
# Check AWS Cost Explorer after 24h:
# Service = EC2-Other
# Usage Type = USW2-DataTransfer-Regional-Bytes

# Meanwhile check queue health (bullboard restart count should be 0)
kubectl get po -n observability | grep bullboard
```

## 🔍 Monitoring & Debugging

### Check deployment status

```bash
# Helm release status
helm status telemetryflow -n observability

# List all releases
helm list -n observability

# Get release values
helm get values telemetryflow -n observability

# Get all manifest
helm get manifest telemetryflow -n observability
```

### Check pods

```bash
# List all pods
kubectl get pods -n observability

# Watch pods
kubectl get pods -n observability -w

# Pods with labels
kubectl get pods -l app.kubernetes.io/part-of=telemetryflow -n observability

# Pod details
kubectl describe pod <pod-name> -n observability

# Pod logs
kubectl logs -f <pod-name> -n observability
kubectl logs --tail=100 <pod-name> -n observability

# Previous crashed pod logs
kubectl logs --previous <pod-name> -n observability
```

### Check services

```bash
# List services
kubectl get svc -n observability

# Service details
kubectl describe svc tfo-backend -n observability

# Port forward to local
kubectl port-forward svc/tfo-backend 3100:3100 -n observability
```

## 🌐 Ingress Management

### Check ingress

```bash
# List all ingress
kubectl get ingress -n observability

# Ingress details
kubectl describe ingress tfo-backend -n observability
kubectl describe ingress tfo-viz -n observability

# Watch ingress
kubectl get ingress -n observability -w

# Get ingress YAML
kubectl get ingress tfo-backend -n observability -o yaml
```

### Test ingress endpoints

```bash
# Health check
curl -k https://api.telemetryflow.co.id/health
curl -k https://demo.telemetryflow.co.id/

# With headers
curl -k -H "Host: api.telemetryflow.co.id" https://<CLUSTER-IP>/health

# Verbose output
curl -kv https://api.telemetryflow.co.id/health

# Test with specific DNS
curl -k --resolve api.telemetryflow.co.id:443:<INGRESS-IP> https://api.telemetryflow.co.id/health
```

### Check NGINX Ingress Controller

```bash
# List ingress controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=ingress-nginx

# Ingress controller logs
kubectl logs -f -n kube-system -l app.kubernetes.io/name=ingress-nginx

# Ingress controller config
kubectl get cm -n kube-system nginx-configuration -o yaml

# Check ingress class
kubectl get ingressclass

# Describe ingress class
kubectl describe ingressclass nginx
```

## 🔐 TLS/Certificate Management

### Manual TLS certificate

```bash
# Create TLS secret from files
kubectl create secret tls tfo-tls-secret \
  --cert=tls.crt \
  --key=tls.key \
  -n observability

# Create from Let's Encrypt files
kubectl create secret tls tfo-tls-secret \
  --cert=/etc/letsencrypt/live/telemetryflow.co.id/fullchain.pem \
  --key=/etc/letsencrypt/live/telemetryflow.co.id/privkey.pem \
  -n observability

# Check certificate
kubectl get secret tfo-tls-secret -n observability -o yaml

# Extract certificate
kubectl get secret tfo-tls-secret -n observability -o jsonpath='{.data.tls\.crt}' | base64 -d > tls.crt

# View certificate details
kubectl get secret tfo-tls-secret -n observability -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Check certificate expiry
kubectl get secret tfo-tls-secret -n observability -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -dates
```

### Cert-Manager (automated)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Check cert-manager pods
kubectl get pods -n cert-manager

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@telemetryflow.co.id
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Check ClusterIssuer
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod

# Check certificates
kubectl get certificate -n observability
kubectl describe certificate -n observability

# Check certificate requests
kubectl get certificaterequest -n observability

# Cert-manager logs
kubectl logs -f -n cert-manager -l app=cert-manager
```

### Test TLS connection

```bash
# Test SSL/TLS handshake
openssl s_client -connect api.telemetryflow.co.id:443 -servername api.telemetryflow.co.id

# Check certificate chain
echo | openssl s_client -showcerts -servername api.telemetryflow.co.id -connect api.telemetryflow.co.id:443 2>/dev/null

# Test specific TLS version
openssl s_client -connect api.telemetryflow.co.id:443 -tls1_2
openssl s_client -connect api.telemetryflow.co.id:443 -tls1_3

# Using nmap
nmap --script ssl-enum-ciphers -p 443 api.telemetryflow.co.id
```

## 🔄 Update & Rollback

### Helm history

```bash
# View release history
helm history telemetryflow -n observability

# View specific revision
helm get values telemetryflow --revision 2 -n observability

# Compare revisions
diff <(helm get values telemetryflow --revision 1 -n observability) \
     <(helm get values telemetryflow --revision 2 -n observability)
```

### Rollback

```bash
# Rollback to previous version
helm rollback telemetryflow -n observability

# Rollback to specific revision
helm rollback telemetryflow 2 -n observability

# Rollback with wait
helm rollback telemetryflow 2 -n observability --wait --timeout 10m

# Dry run rollback
helm rollback telemetryflow 2 -n observability --dry-run
```

### Restart deployments

```bash
# Restart backend
kubectl rollout restart deployment/tfo-backend -n observability

# Restart all deployments
kubectl rollout restart deployment -n observability

# Check rollout status
kubectl rollout status deployment/tfo-backend -n observability

# Check rollout history
kubectl rollout history deployment/tfo-backend -n observability

# Undo rollout
kubectl rollout undo deployment/tfo-backend -n observability
```

## 🔧 Configuration Management

### Secrets

```bash
# List secrets
kubectl get secrets -n observability

# View secret (base64 encoded)
kubectl get secret tfo-backend-secrets -n observability -o yaml

# Decode secret value
kubectl get secret tfo-backend-secrets -n observability -o jsonpath='{.data.DATABASE_PASSWORD}' | base64 -d

# Edit secret
kubectl edit secret tfo-backend-secrets -n observability

# Delete and recreate secret
kubectl delete secret tfo-backend-secrets -n observability
kubectl create secret generic tfo-backend-secrets \
  --from-literal=DATABASE_PASSWORD="new-password" \
  -n observability
```

### ConfigMaps

```bash
# List configmaps
kubectl get cm -n observability

# View configmap
kubectl get cm tfo-backend-env -n observability -o yaml

# Edit configmap
kubectl edit cm tfo-backend-env -n observability

# Describe configmap
kubectl describe cm tfo-backend-env -n observability
```

## 🗑️ Cleanup

### Uninstall

```bash
# Uninstall helm release (keeps PVCs)
helm uninstall telemetryflow -n observability

# Delete PVCs
kubectl delete pvc -l app.kubernetes.io/instance=telemetryflow -n observability

# Delete namespace
kubectl delete namespace telemetryflow

# Force delete stuck resources
kubectl delete pod <pod-name> -n observability --grace-period=0 --force
```

### Clean up stuck resources

```bash
# Remove finalizers from stuck namespace
kubectl get namespace telemetryflow -o json \
  | jq '.spec.finalizers = []' \
  | kubectl replace --raw "/api/v1/namespaces/telemetryflow/finalize" -f -

# Delete stuck PVCs
kubectl patch pvc <pvc-name> -n observability -p '{"metadata":{"finalizers":null}}'

# Delete all failed pods
kubectl delete pods --field-selector status.phase=Failed -n observability
```

## 📊 Resource Usage

### Check resource usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n observability

# Specific pod resource
kubectl top pod tfo-backend-<pod-id> -n observability --containers

# Sort by CPU
kubectl top pods -n observability --sort-by=cpu

# Sort by memory
kubectl top pods -n observability --sort-by=memory
```

### Check limits and requests

```bash
# View pod resources
kubectl get pods -n observability -o custom-columns=NAME:.metadata.name,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory

# Describe node allocations
kubectl describe node | grep -A 5 "Allocated resources"
```

## 🔍 Troubleshooting

### Common issues

```bash
# Pods not starting
kubectl get events -n observability --sort-by='.lastTimestamp'
kubectl describe pod <pod-name> -n observability

# Ingress not working
kubectl logs -f -n kube-system -l app.kubernetes.io/name=ingress-nginx
kubectl describe ingress tfo-backend -n observability

# Database connection issues
kubectl exec -it tfo-backend-<pod-id> -n observability -- env | grep DATABASE
kubectl exec -it postgresql-0 -n observability -- psql -U tfo_admin -d telemetryflow -c "SELECT 1"

# Certificate issues
kubectl describe certificate -n observability
kubectl logs -f -n cert-manager -l app=cert-manager

# DNS issues
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup api.telemetryflow.co.id
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -kv https://api.telemetryflow.co.id/health
```

### Debug pods

```bash
# Run debug pod
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -n observability -- /bin/bash

# Test connectivity from debug pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n observability -- curl http://tfo-backend:3100/health

# Copy files from pod
kubectl cp tfo-backend-<pod-id>:/path/to/file ./local-file -n observability

# Execute command in pod
kubectl exec -it tfo-backend-<pod-id> -n observability -- /bin/sh
kubectl exec -it tfo-backend-<pod-id> -n observability -- cat /etc/hosts
```

## 📝 Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Kubectl aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgi='kubectl get ingress'
alias kdp='kubectl describe pod'
alias kds='kubectl describe svc'
alias kdi='kubectl describe ingress'
alias kl='kubectl logs -f'
alias kex='kubectl exec -it'

# TelemetryFlow specific
alias tfo='kubectl -n observability'
alias tfop='kubectl get pods -n observability'
alias tfol='kubectl logs -f -n observability'
alias tfoi='kubectl get ingress -n observability'

# Helm aliases
alias h='helm'
alias hls='helm list'
alias hs='helm status'
alias hh='helm history'
```
