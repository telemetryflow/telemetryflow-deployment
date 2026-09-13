# tfo-agent — TelemetryFlow Agent chart

Agent-only chart for **monitored source clusters**. Deploys:

- `tfo-agent` DaemonSet — per-node OS metrics (node_exporter, cAdvisor, Fluent Bit)
- `tfo-agent-k8s` Deployment — single-replica K8s state collector + cluster auto-registration

The platform stack (backend, collector, databases) is the separate
[`../telemetryflow`](../telemetryflow) chart, deployed on the platform cluster.

## Usage

```bash
helm upgrade --install tfo-agent-<cluster> helm/tfo-agent \
  -f helm/tfo-agent/values.yaml \
  -f helm/values/<env>/tfo-<env>-tfo-agent-<cluster>.yaml \
  -n observability --create-namespace
```

Or via the runner: `scripts/deploy-tfo-agent.sh --env <staging|production> --cluster <name>`

Secrets are NOT created from the chart in staging/production agent manifests
(`secrets.create: false`) — provision `tfo-agent-secrets`
(TELEMETRYFLOW_API_KEY_ID / _SECRET from TFO Platform > API Keys) out of band.
