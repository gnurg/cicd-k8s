terraform {
  required_version = ">= 1.0" # minimum Terraform version required

  required_providers {
    aws = {
      source  = "hashicorp/aws" # official AWS provider maintained by HashiCorp
      version = "~> 5.0"        # use any 5.x version — the ~ means minor updates are allowed
    }
  }

  # Remote state configuration — stores terraform.tfstate in S3 instead of locally
  # S3 bucket must exist before running terraform init (see TERRAFORM.md)
  backend "s3" {
    bucket       = "cicd-k8s-terraform-state"  # S3 bucket created during bootstrap
    key          = "eks/terraform.tfstate"      # path inside the bucket where state is stored
    region       = "eu-west-1"                  # NOTE: variables are not supported in backend blocks — must be hardcoded
    use_lockfile = true  # uses a lock file in S3 instead of DynamoDB — the modern approach (dynamodb_table is deprecated)
    encrypt      = true  # encrypt state file at rest
    # locally: set AWS_PROFILE=cicd-k8s
    # CI/CD:   set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
  }
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region # region is defined in variables.tf
  # locally: credentials are read from AWS_PROFILE=cicd-k8s
  # CI/CD:   credentials are read from AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
}

# Call the VPC module — creates the network infrastructure
module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  aws_region   = var.aws_region
}

# Call the IAM module — creates roles required by EKS and Fargate
module "iam" {
  source = "./modules/iam"

  cluster_name = var.cluster_name
}

# Call the EKS module — creates the cluster and Fargate profiles
module "eks" {
  source = "./modules/eks"

  cluster_name     = var.cluster_name
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id            # output from the VPC module
  private_subnets  = module.vpc.private_subnets   # output from the VPC module
  cluster_role_arn = module.iam.cluster_role_arn  # output from the IAM module
  fargate_role_arn = module.iam.fargate_role_arn  # output from the IAM module
}
