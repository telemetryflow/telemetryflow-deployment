# Terraform Module: Network (Single-AZ a)

Provisions the VPC, public + private subnets in a **single** availability zone
(a), an Internet Gateway, an optional NAT Gateway, and a default security group.

## Resources

| Resource                     | Description                            |
| ---------------------------- | -------------------------------------- |
| `aws_vpc`                    | VPC with DNS support                   |
| `aws_subnet` (public a)      | Public subnet, zone-a                  |
| `aws_subnet` (private a)     | Private subnet, zone-a                 |
| `aws_internet_gateway`       | IGW attached to VPC                    |
| `aws_route_table` (public)   | `0.0.0.0/0 -> IGW` (zone-a)            |
| `aws_nat_gateway` _(opt)_    | Single NAT GW in public zone-a         |
| `aws_eip` _(opt)_            | EIP for the NAT GW                     |
| `aws_route_table` _(opt)_    | `0.0.0.0/0 -> NAT` for private a       |
| `aws_security_group`         | Default VPC SG (SSH from public CIDR)  |

## Key Variable: `enable_nat`

```
enable_nat = false  # (default) private subnet has no outbound internet
enable_nat = true   # creates NAT GW (zone-a) + routes private a -> NAT
```

## Outputs

- `vpc_id`, `vpc_cidr`, `vpc_name`
- `security_group_id`
- `ec2_private_1a`, `ec2_private_1a_cidr`
- `ec2_public_1a`, `ec2_public_1a_cidr`
- `nat_gateway_id`, `nat_eip` (when enabled)

> The module is single-AZ (zone-a). All workloads deploy to **zone-a**.

## Copyright

- Author: **Telemetri Data Indonesia Team**
- License: **Apache v2**
