# Terraform Module: Compute (Node Pools in zone-a)

Provisions EC2 instances grouped into **node pools** (master / worker), each
with its own count and instance type. All instances are placed in the same
availability zone (**zone-a**), via a shared launch template.

---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.72 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 2.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws.destination"></a> [aws.destination](#provider\_aws.destination) | 6.64.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_ec2_instance_connect_endpoint.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_connect_endpoint) | resource |
| [aws_iam_instance_profile.ec2_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cloudwatch_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_launch_template.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.instance_connect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rke2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.debian](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_ami_os"></a> [ami\_os](#input\_ami\_os) | OS for the AMI: 'debian' (13 Trixie, latest stable), 'ubuntu' (24.04 LTS) or 'amazon\_linux\_2023' | `string` | `"ubuntu"` | no |
| <a name="input_aws_account_profile_destination"></a> [aws\_account\_profile\_destination](#input\_aws\_account\_profile\_destination) | The AWS Profile to deploy the Budget in | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region | `string` | n/a | yes |
| <a name="input_create_instance_connect"></a> [create\_instance\_connect](#input\_create\_instance\_connect) | Whether to create EC2 Instance Connect endpoint | `bool` | `true` | no |
| <a name="input_create_rke2_sg"></a> [create\_rke2\_sg](#input\_create\_rke2\_sg) | Create the RKE2 cluster security group (API, etcd, kubelet, CNI, NodePort). Set false for non-K8s workloads. | `bool` | `true` | no |
| <a name="input_department"></a> [department](#input\_department) | Department Owner | `string` | n/a | yes |
| <a name="input_enable_access_public_ip"></a> [enable\_access\_public\_ip](#input\_enable\_access\_public\_ip) | Set to true to place instances in the public subnet with a public IP | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Target Environment (tags) | `map(string)` | n/a | yes |
| <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name) | Name of the SSH key pair to use for the EC2 instances | `string` | n/a | yes |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Node pools keyed by pool name. Each pool defines its own count, instance type,<br/>RKE2 role, and root EBS storage. Instances are named "{prefix}-{pool}-{NN}".<br/><br/>Default: 1 master (t3.medium, 30 GB) + 2 workers (m5.xlarge, 100 GB).<br/>Set worker count to 3 for a 4-node cluster. | <pre>map(object({<br/>    count                  = number<br/>    instance_type          = string<br/>    role                   = string<br/>    root_volume_size       = number # GB<br/>    root_volume_type       = string # gp3 | gp2 | io2 | io1 | st1 | sc1 | standard<br/>    root_volume_iops       = number # only for gp3 / io*<br/>    root_volume_throughput = number # MB/s, only for gp3<br/>  }))</pre> | <pre>{<br/>  "master": {<br/>    "count": 1,<br/>    "instance_type": "t3.medium",<br/>    "role": "master",<br/>    "root_volume_iops": 3000,<br/>    "root_volume_size": 30,<br/>    "root_volume_throughput": 125,<br/>    "root_volume_type": "gp3"<br/>  },<br/>  "worker": {<br/>    "count": 2,<br/>    "instance_type": "m5.xlarge",<br/>    "role": "worker",<br/>    "root_volume_iops": 6000,<br/>    "root_volume_size": 100,<br/>    "root_volume_throughput": 250,<br/>    "root_volume_type": "gp3"<br/>  }<br/>}</pre> | no |
| <a name="input_prefix_name"></a> [prefix\_name](#input\_prefix\_name) | Global Prefix Name | `string` | n/a | yes |
| <a name="input_private_subnet_id"></a> [private\_subnet\_id](#input\_private\_subnet\_id) | Private subnet ID (zone-a) for instances without public IP | `string` | n/a | yes |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | Public subnet ID (zone-a) for instances with public IP | `string` | n/a | yes |
| <a name="input_rke2_api_access_cidrs"></a> [rke2\_api\_access\_cidrs](#input\_rke2\_api\_access\_cidrs) | Extra CIDRs allowed to reach the Kubernetes API (6443), in addition to the VPC CIDR. Example: ["203.0.113.10/32"] for your office IP. | `list(string)` | `[]` | no |
| <a name="input_spot_price"></a> [spot\_price](#input\_spot\_price) | Maximum spot price | `string` | `null` | no |
| <a name="input_use_spot_instances"></a> [use\_spot\_instances](#input\_use\_spot\_instances) | Whether to use spot instances | `bool` | `false` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC CIDR block | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC Id to deploy the EC2 instances | `string` | n/a | yes |
| <a name="input_workspace_env"></a> [workspace\_env](#input\_workspace\_env) | Workspace Environment Selection | `map(string)` | n/a | yes |
| <a name="input_workspace_name"></a> [workspace\_name](#input\_workspace\_name) | Workspace Environment Name | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_instance_connect_endpoint_arn"></a> [instance\_connect\_endpoint\_arn](#output\_instance\_connect\_endpoint\_arn) | ARN of the Instance Connect endpoint |
| <a name="output_instance_connect_endpoint_id"></a> [instance\_connect\_endpoint\_id](#output\_instance\_connect\_endpoint\_id) | ID of the Instance Connect endpoint |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | Map of instance Name → instance ID |
| <a name="output_instance_private_ips"></a> [instance\_private\_ips](#output\_instance\_private\_ips) | Map of instance Name → private IP |
| <a name="output_instance_public_ips"></a> [instance\_public\_ips](#output\_instance\_public\_ips) | Map of instance Name → public IP |
| <a name="output_latest_ami_id"></a> [latest\_ami\_id](#output\_latest\_ami\_id) | ID of the latest AMI being used |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template |
| <a name="output_launch_template_version"></a> [launch\_template\_version](#output\_launch\_template\_version) | Latest version of the launch template |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Flat list of all nodes (name, role, pool, instance\_id, private\_ip, public\_ip) — use for Ansible inventory generation |
| <a name="output_nodes_by_pool"></a> [nodes\_by\_pool](#output\_nodes\_by\_pool) | Map of pool name → list of instance Names |
| <a name="output_security_group_ec2_ids"></a> [security\_group\_ec2\_ids](#output\_security\_group\_ec2\_ids) | IDs of the security groups applied to instances |
| <a name="output_security_group_rke2_id"></a> [security\_group\_rke2\_id](#output\_security\_group\_rke2\_id) | ID of the RKE2 security group (null when create\_rke2\_sg=false) |
<!-- END_TF_DOCS -->
