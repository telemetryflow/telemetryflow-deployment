# TelemetryFlow - TFO EC2 (node pools in zone-a, multi-AZ VPC)

Wires the **network** module (VPC, public/private subnets in **3 AZs** a/b/c,
IGW, optional NAT) with the **compute** module (EC2 node pools placed in
**zone-a** only by default).

Default topology: **1 master** (t3.medium, 30 GB) + **2 workers** (m5.xlarge,
100 GB). Adjust `node_pools` in tfvars for different counts, types, or storage.

## Prerequisites

1. The `_tfstate` stack must already be applied (S3 bucket + DynamoDB exist).
2. An EC2 key pair must exist in the target region (default name `tfo-ssh-key`).

## Deploy

```
cd environment/telemetryflow/tfo-ec2

cp backend.tf.example backend.tf   # edit bucket/key for your account
terraform init

terraform workspace new default    # or: lab / staging / prod
terraform plan
terraform apply
```

## What gets created

| Module  | Resource                                                                                              |
| ------- | ----------------------------------------------------------------------------------------------------- |
| network | VPC, public subnets a/b/c, private subnets a/b/c, IGW, public route tables                            |
| network | _(optional)_ NAT GW + EIP + private route table (a/b/c -> NAT)                                        |
| compute | Launch template, master+worker instances (zone-a), SGs, IAM role + profile, Instance Connect endpoint |

## Key toggles

| Variable                  | Default                                               | Effect                                      |
| ------------------------- | ----------------------------------------------------- | ------------------------------------------- |
| `node_pools`              | `master: 1×t3.medium 30GB, worker: 2×m5.xlarge 100GB` | Count, type, role, and storage per pool     |
| `enable_nat`              | `false`                                               | `true` creates NAT GW serving private a/b/c |
| `enable_access_public_ip` | `true`                                                | `false` places nodes in private subnet      |
| `create_rke2_sg`          | `true`                                                | RKE2 SG (API/etcd/kubelet/CNI/NodePort)     |
| `rke2_api_access_cidrs`   | `[]`                                                  | Extra CIDRs for kubectl (6443) access       |

## Cleanup

```
terraform workspace select default
terraform destroy
```

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
