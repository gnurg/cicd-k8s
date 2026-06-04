# -----------------------------------------------------------------------
# EKS Cluster Role
# The role assumed by the EKS control plane to manage AWS resources
# on behalf of the cluster (load balancers, networking, storage, etc.)
# -----------------------------------------------------------------------

resource "aws_iam_role" "eks_cluster_role" {    # "aws_iam_role" is the Terraform resource type — creates an IAM role in AWS
                                                # "eks_cluster_role" is our internal name for this resource — used to reference it elsewhere in Terraform
  name = "${var.cluster_name}-cluster-role"     # the actual name of the role in AWS — uses the cluster_name variable as prefix

  # trust policy — a JSON document that defines who is allowed to assume this role
  # without this, no one can use the role
  assume_role_policy = jsonencode({             # jsonencode() converts a Terraform object to a JSON string (required by AWS)
    Version = "2012-10-17"                      # IAM policy language version — always this value
    Statement = [{
      Effect = "Allow"                          # allow the action below
      Principal = {
        Service = "eks.amazonaws.com"           # only the EKS service can assume this role (not a user or another service)
      }
      Action = "sts:AssumeRole"                 # the action being allowed — assuming this role
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {  # attaches a managed policy to the role
                                                                   # "eks_cluster_policy" is our internal name
  role       = aws_iam_role.eks_cluster_role.name                  # references the role we created above by its Terraform name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"   # ARN of the AWS managed policy — this is a fixed AWS value, not invented
}

# -----------------------------------------------------------------------
# Fargate Pod Execution Role
# The role assumed by Fargate to run pods — needed to pull container
# images from ECR and write logs to CloudWatch
# -----------------------------------------------------------------------

resource "aws_iam_role" "fargate_pod_execution_role" {  # "fargate_pod_execution_role" is our internal Terraform name
  name = "${var.cluster_name}-fargate-role"             # actual name in AWS

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"      # only the Fargate service can assume this role
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_policy" {  # attaches a managed policy to the Fargate role
  role       = aws_iam_role.fargate_pod_execution_role.name                  # references the Fargate role above
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"  # fixed AWS managed policy ARN
}
