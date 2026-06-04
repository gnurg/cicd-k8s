variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the cluster will be created"
  type        = string
}

variable "vpc_id" {                       # received from the VPC module output
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "private_subnets" {             # received from the VPC module output
  description = "List of private subnet IDs where Fargate pods will run"
  type        = list(string)             # list type — accepts multiple subnet IDs
}

variable "cluster_role_arn" {            # received from the IAM module output
  description = "ARN of the IAM role for the EKS control plane"
  type        = string
}

variable "fargate_role_arn" {            # received from the IAM module output
  description = "ARN of the IAM role for Fargate pod execution"
  type        = string
}
