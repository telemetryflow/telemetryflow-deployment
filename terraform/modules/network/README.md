# Terraform Module: Network (Multi-AZ a, b, c)

Provisions the VPC, public + private subnets in **three** availability zones
(a, b, c), an Internet Gateway, an optional NAT Gateway, and a default
security group.

---

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | >= 5.72  |
| <a name="requirement_random"></a> [random](#requirement_random)          | >= 2.0   |
| <a name="requirement_tls"></a> [tls](#requirement_tls)                   | >= 3.0   |

## Providers

| Name                                                                                 | Version |
| ------------------------------------------------------------------------------------ | ------- |
| <a name="provider_aws.destination"></a> [aws.destination](#provider_aws.destination) | >= 5.72 |

## Modules

No modules.

## Resources

| Name                                                                                                                                                    | Type     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_eip.ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip)                                                          | resource |
| [aws_internet_gateway.igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway)                                | resource |
| [aws_nat_gateway.ec2_ngw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway)                                      | resource |
| [aws_route_table.igw_ec2_rt_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)                            | resource |
| [aws_route_table.nat_ec2_rt_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table)                           | resource |
| [aws_route_table_association.igw_ec2_rt_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association)    | resource |
| [aws_route_table_association.nat_ec2_rt_private_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.nat_ec2_rt_private_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.nat_ec2_rt_private_c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                | resource |
| [aws_subnet.ec2_private_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                          | resource |
| [aws_subnet.ec2_private_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                          | resource |
| [aws_subnet.ec2_private_c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                          | resource |
| [aws_subnet.ec2_public_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                           | resource |
| [aws_subnet.ec2_public_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                           | resource |
| [aws_subnet.ec2_public_c](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                           | resource |
| [aws_vpc.infra_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)                                                    | resource |

## Inputs

| Name                                                                                                                           | Description                                                           | Type          | Default | Required |
| ------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- | ------------- | ------- | :------: |
| <a name="input_aws_account_id_destination"></a> [aws_account_id_destination](#input_aws_account_id_destination)                | The AWS Account ID to deploy resources in                             | `string`      | n/a     |   yes    |
| <a name="input_aws_account_profile_destination"></a> [aws_account_profile_destination](#input_aws_account_profile_destination) | The AWS Profile to deploy resources in                                | `string`      | n/a     |   yes    |
| <a name="input_aws_region"></a> [aws_region](#input_aws_region)                                                                | The AWS region to deploy the VPC in                                   | `string`      | n/a     |   yes    |
| <a name="input_coreinfra"></a> [coreinfra](#input_coreinfra)                                                                   | Core Infrastructure Name Prefix                                       | `string`      | n/a     |   yes    |
| <a name="input_department"></a> [department](#input_department)                                                                | Department Owner                                                      | `string`      | n/a     |   yes    |
| <a name="input_ec2_prefix"></a> [ec2_prefix](#input_ec2_prefix)                                                                | EC2 Prefix Name                                                       | `string`      | n/a     |   yes    |
| <a name="input_ec2_private_a"></a> [ec2_private_a](#input_ec2_private_a)                                                       | Private Subnet for EC2 Zone A                                         | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_private_b"></a> [ec2_private_b](#input_ec2_private_b)                                                       | Private Subnet for EC2 Zone B                                         | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_private_c"></a> [ec2_private_c](#input_ec2_private_c)                                                       | Private Subnet for EC2 Zone C                                         | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_public_a"></a> [ec2_public_a](#input_ec2_public_a)                                                          | Public Subnet for EC2 Zone A                                          | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_public_b"></a> [ec2_public_b](#input_ec2_public_b)                                                          | Public Subnet for EC2 Zone B                                          | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_public_c"></a> [ec2_public_c](#input_ec2_public_c)                                                          | Public Subnet for EC2 Zone C                                          | `map(string)` | n/a     |   yes    |
| <a name="input_ec2_rt_prefix"></a> [ec2_rt_prefix](#input_ec2_rt_prefix)                                                       | EC2 Routing Table Prefix Name                                         | `string`      | n/a     |   yes    |
| <a name="input_enable_nat"></a> [enable_nat](#input_enable_nat)                                                                | Set to true to create a NAT Gateway serving private subnets (a, b, c) | `bool`        | `false` |    no    |
| <a name="input_environment"></a> [environment](#input_environment)                                                             | Target Environment (tags)                                             | `map(string)` | n/a     |   yes    |
| <a name="input_igw_prefix"></a> [igw_prefix](#input_igw_prefix)                                                                | IGW Prefix Name                                                       | `string`      | n/a     |   yes    |
| <a name="input_nat_ec2_prefix"></a> [nat_ec2_prefix](#input_nat_ec2_prefix)                                                    | NAT EC2 Prefix Name                                                   | `string`      | n/a     |   yes    |
| <a name="input_vpc_cidr"></a> [vpc_cidr](#input_vpc_cidr)                                                                      | Core Infrastructure CIDR Block                                        | `map(string)` | n/a     |   yes    |
| <a name="input_workspace_env"></a> [workspace_env](#input_workspace_env)                                                       | Workspace Environment Selection                                       | `map(string)` | n/a     |   yes    |
| <a name="input_workspace_name"></a> [workspace_name](#input_workspace_name)                                                    | Workspace Environment Name                                            | `string`      | n/a     |   yes    |

## Outputs

| Name                                                                                         | Description                                |
| -------------------------------------------------------------------------------------------- | ------------------------------------------ |
| <a name="output_ec2_private_1a"></a> [ec2_private_1a](#output_ec2_private_1a)                | Private Subnet EC2 Zone A                  |
| <a name="output_ec2_private_1a_cidr"></a> [ec2_private_1a_cidr](#output_ec2_private_1a_cidr) | Private Subnet EC2 CIDR Block of Zone A    |
| <a name="output_ec2_private_1b"></a> [ec2_private_1b](#output_ec2_private_1b)                | Private Subnet EC2 Zone B                  |
| <a name="output_ec2_private_1b_cidr"></a> [ec2_private_1b_cidr](#output_ec2_private_1b_cidr) | Private Subnet EC2 CIDR Block of Zone B    |
| <a name="output_ec2_private_1c"></a> [ec2_private_1c](#output_ec2_private_1c)                | Private Subnet EC2 Zone C                  |
| <a name="output_ec2_private_1c_cidr"></a> [ec2_private_1c_cidr](#output_ec2_private_1c_cidr) | Private Subnet EC2 CIDR Block of Zone C    |
| <a name="output_ec2_public_1a"></a> [ec2_public_1a](#output_ec2_public_1a)                   | Public Subnet EC2 Zone A                   |
| <a name="output_ec2_public_1a_cidr"></a> [ec2_public_1a_cidr](#output_ec2_public_1a_cidr)    | Public Subnet EC2 CIDR Block of Zone A     |
| <a name="output_ec2_public_1b"></a> [ec2_public_1b](#output_ec2_public_1b)                   | Public Subnet EC2 Zone B                   |
| <a name="output_ec2_public_1b_cidr"></a> [ec2_public_1b_cidr](#output_ec2_public_1b_cidr)    | Public Subnet EC2 CIDR Block of Zone B     |
| <a name="output_ec2_public_1c"></a> [ec2_public_1c](#output_ec2_public_1c)                   | Public Subnet EC2 Zone C                   |
| <a name="output_ec2_public_1c_cidr"></a> [ec2_public_1c_cidr](#output_ec2_public_1c_cidr)    | Public Subnet EC2 CIDR Block of Zone C     |
| <a name="output_nat_eip"></a> [nat_eip](#output_nat_eip)                                     | NAT Gateway Elastic IP (zone-a) if enabled |
| <a name="output_nat_gateway_id"></a> [nat_gateway_id](#output_nat_gateway_id)                | NAT Gateway ID (zone-a) if enabled         |
| <a name="output_security_group_id"></a> [security_group_id](#output_security_group_id)       | Security Group of VPC Id's                 |
| <a name="output_summary"></a> [summary](#output_summary)                                     | Summary Core Infrastructure Configuration  |
| <a name="output_vpc_cidr"></a> [vpc_cidr](#output_vpc_cidr)                                  | VPC CIDR Block                             |
| <a name="output_vpc_id"></a> [vpc_id](#output_vpc_id)                                        | VPC Identity                               |
| <a name="output_vpc_name"></a> [vpc_name](#output_vpc_name)                                  | VPC Name                                   |

<!-- END_TF_DOCS -->
