variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "eu-west-1" # Ireland — closest European region with full service availability
}

variable "cluster_name" {
  description = "Name used for the EKS cluster and all related resources"
  type        = string
  default     = "cicd-k8s-cluster"
}
