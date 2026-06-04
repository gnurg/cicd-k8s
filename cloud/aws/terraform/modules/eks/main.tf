# -----------------------------------------------------------------------
# EKS Cluster
# The control plane — manages scheduling, networking, and state of pods
# -----------------------------------------------------------------------

resource "aws_eks_cluster" "main" {       # "aws_eks_cluster" is the Terraform resource type
                                          # "main" is our internal name
  name     = var.cluster_name             # name of the cluster in AWS
  role_arn = var.cluster_role_arn         # IAM role the control plane assumes — created by the IAM module

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"  # required to use access entries (aws eks create-access-entry)
                                                # API_AND_CONFIG_MAP supports both the modern API-based access entries
                                                # and the legacy aws-auth ConfigMap approach
  }

  vpc_config {
    subnet_ids              = var.private_subnets      # subnets where the control plane places network interfaces
    endpoint_private_access = true                     # allows kubectl access from within the VPC (e.g. from CI/CD runners inside VPC)
    endpoint_public_access  = true                     # allows kubectl access from the internet (needed for local development)
  }

  tags = {
    Name = var.cluster_name
  }

  depends_on = [var.cluster_role_arn]     # ensure the IAM role exists before creating the cluster
}

# -----------------------------------------------------------------------
# Fargate Profile — kube-system namespace
# Runs the core Kubernetes system pods (coredns, etc.) on Fargate
# -----------------------------------------------------------------------

resource "aws_eks_fargate_profile" "kube_system" {  # "aws_eks_fargate_profile" defines which pods run on Fargate
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = var.fargate_role_arn       # IAM role Fargate assumes to run pods — created by the IAM module
  subnet_ids             = var.private_subnets        # Fargate pods always run in private subnets

  selector {                                          # defines which pods this profile applies to
    namespace = "kube-system"                         # match pods in the kube-system namespace
  }
}

# -----------------------------------------------------------------------
# Fargate Profile — dev namespace
# Runs application pods for the dev environment on Fargate
# -----------------------------------------------------------------------

resource "aws_eks_fargate_profile" "dev" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "dev"
  pod_execution_role_arn = var.fargate_role_arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "dev"                                 # match pods in the dev namespace
  }
}

# -----------------------------------------------------------------------
# Fargate Profile — staging namespace
# Runs application pods for the staging environment on Fargate
# -----------------------------------------------------------------------

resource "aws_eks_fargate_profile" "staging" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "staging"
  pod_execution_role_arn = var.fargate_role_arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "staging"                             # match pods in the staging namespace
  }
}
