# TelemetryFlow - TFO EKS (Observability Cluster)

Provisions the **TelemetryFlow observability EKS cluster** (Kubernetes 1.35)
with managed add-ons, EBS/EFS CSI drivers (Pod Identity), and a worker node
group defaulting to **3 × t3.large**.

## Prerequisites

1. The `_tfstate` stack must be applied (S3 bucket + DynamoDB exist).
2. The `tfo-ec2` stack must be applied (VPC + subnets + SG outputs exist) —
   `tfo-eks` reads them via `terraform_remote_state`.
3. Your AWS profile must have EKS / IAM / S3 permissions.

## Deploy

```bash
cd environment/telemetryflow/tfo-eks

cp backend.tf.example backend.tf      # edit bucket/key for your account
cp terraform.tfvars.example terraform.tfvars  # edit account / SSH key / DNS zone
terraform init

terraform workspace new staging       # or: lab / prod
terraform plan
terraform apply
```

## What gets created

| Module | Resource                                                                           |
| ------ | ---------------------------------------------------------------------------------- |
| eks    | `aws_eks_cluster` (1.35) + OIDC provider                                           |
| eks    | `aws_eks_node_group` (3 × t3.large workers)                                        |
| eks    | `aws_eks_addon` (kube-proxy, vpc-cni, coredns, snapshot-controller)                |
| eks    | `aws_eks_addon` (pod-identity-agent, ebs-csi, efs-csi) + Pod Identity associations |
| eks    | IAM roles + policies (cluster, nodes, CSI, cluster-autoscaler, ALB controller)     |
| eks    | `aws_security_group` (EKS)                                                         |
| eks    | S3 bucket (private, versioned, TLS-only)                                           |

## Connecting to the cluster

```bash
aws eks update-kubeconfig \
  --region ap-southeast-3 \
  --name tfo-eks-staging
```

## Key toggles

| Variable                 | Default                      | Effect                           |
| ------------------------ | ---------------------------- | -------------------------------- |
| `k8s_version`            | `1.35`                       | EKS cluster + node version       |
| `eks_node_type`          | `t3.large` (prod `m5.large`) | Worker instance type             |
| `node_counts.worker`     | `3`                          | Desired worker count             |
| `node_counts.worker_max` | `10`                         | Max workers (cluster-autoscaler) |
| `ssh_key_pair`           | `tfo-ssh-key`                | SSH access to worker nodes       |

## Upgrade add-ons

See `terraform/modules/eks/LIST-ADDONS.md` for the
`aws eks describe-addon-versions` commands, then update the version maps in
`variable.tf` / `terraform.tfvars`.

## Cleanup

```bash
terraform workspace select staging
terraform destroy
```

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
