output "cluster_role_arn" {                                  # "cluster_role_arn" is our chosen output name — invented, can be anything
                                                             # referenced in main.tf as module.iam.cluster_role_arn
  description = "ARN of the EKS cluster role — passed to the EKS module"
  value       = aws_iam_role.eks_cluster_role.arn            # "aws_iam_role" = resource type, "eks_cluster_role" = our internal name, "arn" = AWS attribute returned after creation
}

output "fargate_role_arn" {                                  # "fargate_role_arn" is our chosen output name — invented, can be anything
                                                             # referenced in main.tf as module.iam.fargate_role_arn
  description = "ARN of the Fargate pod execution role — passed to the EKS module"
  value       = aws_iam_role.fargate_pod_execution_role.arn  # "fargate_pod_execution_role" = our internal name defined in main.tf, "arn" = AWS attribute
}
