output "cluster_name" {
  description = "EKS cluster name — use this with kubectl and eksctl commands"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint — used by kubectl to communicate with the cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate" {
  description = "Certificate authority data for authenticating kubectl to the cluster"
  value       = module.eks.cluster_certificate
  sensitive   = true # marked sensitive so it is not printed in plain text in the terminal
}

output "kubeconfig_command" {
  description = "Run this command after apply to configure kubectl to connect to the cluster"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile cicd-k8s"
}
