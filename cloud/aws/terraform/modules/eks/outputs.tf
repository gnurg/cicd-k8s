output "cluster_name" {                          # our chosen name — referenced in root outputs.tf as module.eks.cluster_name
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name        # "aws_eks_cluster.main" = our resource, "name" = AWS attribute
}

output "cluster_endpoint" {                      # our chosen name — referenced in root outputs.tf as module.eks.cluster_endpoint
  description = "EKS cluster API endpoint — used by kubectl"
  value       = aws_eks_cluster.main.endpoint    # "endpoint" = the HTTPS URL kubectl uses to talk to the cluster
}

output "cluster_certificate" {                   # our chosen name — referenced in root outputs.tf as module.eks.cluster_certificate
  description = "Certificate authority data for kubectl authentication"
  value       = aws_eks_cluster.main.certificate_authority[0].data  # [0] because it's a list with one element
}
