# Variables Reference — TelemetryFlow Kubernetes Deployment

All configurable variables are defined in `inventory/group_vars/all.yml` and role `defaults/main.yml` files. Override them in inventory, on the command line, or in a separate vault file.

## Cluster Configuration

| Variable         | Default                   | Description                                        |
| ---------------- | ------------------------- | -------------------------------------------------- |
| `cluster_name`   | `telemetryflow-cluster`   | Logical name for the Kubernetes cluster            |
| `cluster_domain` | `cluster.local`           | Internal cluster DNS domain                        |
| `cluster_cidr`   | `10.42.0.0/16`           | Pod CIDR range                                     |
| `service_cidr`   | `10.43.0.0/16`           | Kubernetes Service CIDR range                      |
| `cluster_dns`    | `10.43.0.10`             | Cluster DNS service IP                             |

## RKE2 Configuration

| Variable                | Default                     | Description                                  |
| ----------------------- | --------------------------- | -------------------------------------------- |
| `rke2_version`          | `v1.31.4+rke2r1`           | RKE2 version to install                      |
| `rke2_channel`          | `stable`                    | RKE2 release channel                         |
| `rke2_server_ip`        | Auto-detected from masters  | First master IP for cluster join             |
| `rke2_token`            | `<CHANGE_ME>`               | Cluster join token (generate securely)       |
| `rke2_data_dir`         | `/var/lib/rancher/rke2`    | RKE2 data directory                          |
| `rke2_config_dir`       | `/etc/rancher/rke2`        | RKE2 configuration directory                 |
| `rke2_server_port`      | `9345`                      | RKE2 server port                             |
| `rke2_api_port`         | `6443`                      | Kubernetes API port                          |
| `rke2_install_script_url` | `https://get.rke2.io`    | RKE2 installation script URL                 |

## Helm / TelemetryFlow Deployment

| Variable                     | Default                                        | Description                               |
| ---------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `telemetryflow_namespace`    | `telemetryflow`                                | Kubernetes namespace for deployment       |
| `telemetryflow_chart_version` | `0.1.0`                                       | Helm chart version                        |
| `telemetryflow_repo_url`     | `https://charts.telemetryflow.example.com`      | Helm chart repository URL                |
| `telemetryflow_values_file`  | `{{ playbook_dir }}/../values/telemetryflow-values.yaml` | Values file path |
| `telemetryflow_chart_name`   | `telemetryflow`                                | Helm chart name                           |
| `telemetryflow_release_name` | `telemetryflow`                                | Helm release name                         |
| `telemetryflow_repo_name`    | `telemetryflow`                                | Helm repository alias                     |

## Post-Install

| Variable          | Default                            | Description                          |
| ----------------- | ---------------------------------- | ------------------------------------ |
| `node_labels`     | `[{key: node-role.kubernetes.io/worker, value: "true"}]` | Labels applied to worker nodes |
| `node_taints`     | `[]`                               | Taints applied to nodes              |
| `kubectl_timeout` | `120`                              | Timeout in seconds for kubectl waits |

## System Prerequisites

| Variable          | Default                                                        | Description                   |
| ----------------- | -------------------------------------------------------------- | ----------------------------- |
| `kernel_modules`  | `[br_netfilter, overlay, nf_conntrack]`                        | Kernel modules to load        |
| `sysctl_params`   | See `group_vars/all.yml`                                       | Sysctl parameters to apply    |
| `ntp_servers`     | `[pool.ntp.org]`                                               | NTP servers for time sync     |

## Proxy Configuration

| Variable     | Default | Description                        |
| ------------ | ------- | ---------------------------------- |
| `proxy_http` | `""`    | HTTP proxy URL (empty = disabled)  |
| `proxy_https`| `""`    | HTTPS proxy URL (empty = disabled) |
| `proxy_no`   | `127.0.0.1,localhost` | No-proxy entries          |

## Container Registry

| Variable           | Default | Description                                  |
| ------------------ | ------- | -------------------------------------------- |
| `registry_mirror`  | `""`    | Private registry mirror URL (empty = direct) |
| `registry_ca_cert` | `""`    | CA certificate for private registry          |

## Backup & Maintenance

| Variable                | Default              | Description                          |
| ----------------------- | -------------------- | ------------------------------------ |
| `backup_location`       | `/opt/rke2-backups`  | Directory for cluster backups        |
| `backup_retention_days` | `7`                  | Days to retain backups               |

## Common Role

| Variable          | Default | Description                       |
| ----------------- | ------- | --------------------------------- |
| `common_packages` | List    | Packages installed on all nodes   |
| `timezone`        | `UTC`   | System timezone                   |

## Secrets

> **Never commit secrets to the repository.** Use Ansible Vault for sensitive values.

| Variable      | Description                     | How to Secure            |
| ------------- | ------------------------------- | ------------------------ |
| `rke2_token`  | Cluster join token              | Ansible Vault            |
| `proxy_http`  | Proxy credentials (if any)      | Ansible Vault            |
| `proxy_https` | Proxy credentials (if any)      | Ansible Vault            |

### Using Ansible Vault

```bash
# Create encrypted vars file
ansible-vault create inventory/group_vars/vault.yml

# Edit encrypted file
ansible-vault edit inventory/group_vars/vault.yml

# Run playbook with vault
ansible-playbook playbooks/site.yml --ask-vault-pass
```
