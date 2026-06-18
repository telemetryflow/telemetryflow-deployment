# Terraform Module: Network (Multi-AZ a, b, c)

Provisions the VPC, public + private subnets in **three** availability zones
(a, b, c), an Internet Gateway, an optional NAT Gateway, and a default
security group.

## Resources

| Resource                     | Description                            |
| ---------------------------- | -------------------------------------- |
| `aws_vpc`                    | VPC with DNS support                   |
| `aws_subnet` (public a/b/c)  | Public subnets, one per AZ             |
| `aws_subnet` (private a/b/c) | Private subnets, one per AZ            |
| `aws_internet_gateway`       | IGW attached to VPC                    |
| `aws_route_table` (public)   | `0.0.0.0/0 -> IGW`, one per AZ         |
| `aws_nat_gateway` _(opt)_    | Single NAT GW in public zone-a         |
| `aws_eip` _(opt)_            | EIP for the NAT GW                     |
| `aws_route_table` _(opt)_    | `0.0.0.0/0 -> NAT` for private a/b/c   |
| `aws_security_group`         | Default VPC SG (SSH from public CIDRs) |

## Key Variable: `enable_nat`

```
enable_nat = false  # (default) private subnets have no outbound internet
enable_nat = true   # creates NAT GW (zone-a) + routes private a/b/c -> NAT
```

## Outputs

- `vpc_id`, `vpc_cidr`, `vpc_name`
- `security_group_id`
- `ec2_private_1a/1b/1c`, `ec2_private_1a/1b/1c_cidr`
- `ec2_public_1a/1b/1c`, `ec2_public_1a/1b/1c_cidr`
- `nat_gateway_id`, `nat_eip` (when enabled)

> The module is multi-AZ capable. Environments choose which AZ(s) to place
> workloads in (e.g. `tfo-ec2` deploys 3 nodes only in **zone-a**).

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
