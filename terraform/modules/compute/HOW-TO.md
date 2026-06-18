# Terraform Module: Compute (Node Pools in zone-a)

Provisions EC2 instances grouped into **node pools** (master / worker), each
with its own count and instance type. All instances are placed in the same
availability zone (**zone-a**), via a shared launch template.

## Resources

| Resource                                    | Description                                    |
| ------------------------------------------- | ---------------------------------------------- |
| `aws_launch_template`                       | Reusable LT (AMI, volume, user_data — no type) |
| `aws_instance` (for_each over node_pools)   | Master + Worker nodes in `${region}a`          |
| `aws_ec2_instance_connect_endpoint`         | SSH access to private instances (opt)          |
| `aws_security_group` (main)                 | SSH/HTTP/HTTPS + ICMP                          |
| `aws_security_group` (instance_connect)     | Instance Connect SG                            |
| `aws_iam_role` + `aws_iam_instance_profile` | SSM + S3 RO + CloudWatch                       |

## Security Groups

| Security Group        | Scope        | Ports                                                                                                                |
| --------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------- |
| `main`                | Public + VPC | 22 (SSH), 80/443 (ingress), ICMP (VPC), all egress                                                                   |
| `instance_connect`    | VPC          | 22 (for EC2 Instance Connect endpoint)                                                                               |
| `rke2` _(default on)_ | VPC          | 6443 API, 9345 supervisor, 2379-2380 etcd, 10250 kubelet, 179/5473 Calico, 4789/8472 CNI VXLAN, 30000-32767 NodePort |

Disable the RKE2 SG for non-Kubernetes workloads:

```
create_rke2_sg = false
```

Add your workstation IP for external `kubectl` access:

```
rke2_api_access_cidrs = ["203.0.113.10/32"]
```

## Key Variables

| Variable                  | Default                                                 | Description                             |
| ------------------------- | ------------------------------------------------------- | --------------------------------------- |
| `node_pools`              | `{master: 1×t3.medium 30GB, worker: 2×m5.xlarge 100GB}` | Per-pool count, type, role, and storage |
| `ami_os`                  | `ubuntu`                                                | `ubuntu` or `amazon_linux_2023`         |
| `enable_access_public_ip` | `true`                                                  | Public subnet + EIP, else private       |
| `key_pair_name`           | _(required)_                                            | SSH key pair name                       |

### Node pools example

```
# 1 master + 3 workers, each with custom storage
node_pools = {
  master = {
    count                 = 1
    instance_type         = "t3.medium"
    role                  = "master"
    root_volume_size      = 30      # GB
    root_volume_type      = "gp3"
    root_volume_iops      = 3000
    root_volume_throughput = 125     # MB/s
  }
  worker = {
    count                 = 3
    instance_type         = "m5.xlarge"
    role                  = "worker"
    root_volume_size      = 100     # GB
    root_volume_type      = "gp3"
    root_volume_iops      = 6000
    root_volume_throughput = 250     # MB/s
  }
}
```

## Outputs

- `launch_template_id`, `launch_template_version`
- `latest_ami_id`
- `instance_ids` — map Name → ID
- `instance_private_ips` — map Name → private IP
- `instance_public_ips` — map Name → public IP
- `nodes` — flat list of `{name, role, pool, instance_id, private_ip, public_ip}` (for Ansible inventory generation)
- `nodes_by_pool` — map pool → list of Names
- `security_group_ec2_ids`
- `instance_connect_endpoint_id`, `instance_connect_endpoint_arn`

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
