output "vpc_id" {                              # our chosen name — referenced in main.tf as module.vpc.vpc_id
  description = "ID of the VPC — passed to the EKS module"
  value       = aws_vpc.main.id              # "aws_vpc.main" = our resource, "id" = AWS attribute assigned after creation
}

output "private_subnets" {                    # our chosen name — referenced in main.tf as module.vpc.private_subnets
  description = "List of private subnet IDs — Fargate pods run in these subnets"
  value       = aws_subnet.private[*].id     # [*] returns all subnet IDs as a list (both private subnets)
}

output "public_subnets" {                     # our chosen name — referenced in main.tf as module.vpc.public_subnets
  description = "List of public subnet IDs — load balancers are placed in these subnets"
  value       = aws_subnet.public[*].id      # [*] returns all subnet IDs as a list (both public subnets)
}
