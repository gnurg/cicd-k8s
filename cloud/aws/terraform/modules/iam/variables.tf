variable "cluster_name" {                        # "cluster_name" is our chosen variable name — referenced as var.cluster_name in main.tf
  description = "Name of the EKS cluster — used to prefix IAM role names for easy identification"
  type        = string                           # Terraform type — enforces that only strings are accepted
}
