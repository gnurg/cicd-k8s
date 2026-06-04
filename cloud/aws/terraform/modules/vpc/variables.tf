variable "cluster_name" {              # used to prefix all resource names for easy identification in AWS console
  description = "Name of the EKS cluster — used to tag and name all VPC resources"
  type        = string
}

variable "aws_region" {               # needed to look up availability zones in the correct region
  description = "AWS region where the VPC will be created"
  type        = string
}
