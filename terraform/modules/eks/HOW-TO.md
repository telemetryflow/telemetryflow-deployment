# Terraform Module: EKS Observability Cluster

Provisions an **EKS 1.35 observability cluster** for the TelemetryFlow platform,
with managed EKS add-ons, EBS/EFS CSI drivers via Pod Identity, an OIDC provider,
cluster-autoscaler + AWS Load Balancer Controller IAM roles, a worker node group
(default **3 × t3.large**), and an S3 bucket for logs/assets.

## How-to-Use

- Create `provider.tf`, add this line:

  ```hcl
  terraform {
    required_version = ">= 1.9.8"

    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = ">= 5.72"
      }
      tls = {
        source  = "hashicorp/tls"
        version = ">= 3.0"
      }
      random = ">= 2.0"
    }
  }
  ```

- Setup AWS Credentials & Config

  ```
  $HOME/.aws/credentials
  ---
  [TFO-TF-User-Executor]
  aws_access_key_id     =
  aws_secret_access_key =

  $HOME/.aws/config
  ---
  [profile TFO-TF-User-Executor]
  region = ap-southeast-3
  output = json
  ```

- Change AWS Profile and Region

  ```bash
  unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID

  export AWS_PROFILE=TFO-TF-User-Executor
  export AWS_DEFAULT_REGION=ap-southeast-3

  aws sts get-caller-identity --profile $AWS_PROFILE
  ```

- Run `terraform init`

## How-to-Deploy

- Terraform Initialize

  ```bash
  terraform init
  ```

- List Existing Workspace

  ```bash
  terraform workspace list
  ```

- Create Workspace

  ```bash
  terraform workspace new staging
  terraform workspace new prod
  ```

- Use Workspace

  ```bash
  terraform workspace select staging
  ```

- Terraform Planning / Provisioning

  ```bash
  terraform plan
  terraform apply
  ```

## Migrate State

- Rename Backend

  ```bash
  cp backend.tf.example backend.tf
  ```

- Initiate Migrate

  ```bash
  terraform init --migrate-state
  ```

## Cleanup Environment

```bash
terraform destroy
```

## Inputs (EKS-specific)

| Name                          | Description                            | Default                      |
| ----------------------------- | -------------------------------------- | ---------------------------- |
| `k8s_version`                 | EKS version per env                    | `1.35`                       |
| `eks_node_type`               | Worker node instance type              | `t3.large` (prod `m5.large`) |
| `eks_node_storage`            | Worker node disk (GB)                  | `50` (prod `100`)            |
| `node_counts`                 | `worker` / `worker_max` / `worker_min` | `3` / `10` / `1`             |
| `pod_identity_agent_version`  | eks-pod-identity-agent                 | `v1.4.0-eksbuild.1`          |
| `ebs_csi_driver_version`      | aws-ebs-csi-driver                     | `v1.50.0-eksbuild.1`         |
| `efs_csi_driver_version`      | aws-efs-csi-driver                     | `v2.2.5-eksbuild.1`          |
| `kube_proxy_version`          | kube-proxy                             | `v1.35.1-eksbuild.1`         |
| `vpc_cni_version`             | vpc-cni                                | `v1.21.0-eksbuild.1`         |
| `coredns_version`             | coredns                                | `v1.13.1-eksbuild.1`         |
| `snapshot_controller_version` | snapshot-controller                    | `v8.4.0-eksbuild.1`          |

See `LIST-ADDONS.md` for the full addon version discovery commands.

## Copyright

- Author: **Telemetri Data Indonesia Team (support@telemetryflow.id)**
- License: **Apache v2**
