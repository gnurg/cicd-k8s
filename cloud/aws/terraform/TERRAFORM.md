# Terraform — EKS Infrastructure

Terraform manages all AWS infrastructure for this project. It provisions the EKS cluster, VPC, subnets, and IAM roles required to run the `cicd-k8s-webapp` on AWS.

---

## Structure

```
terraform/
  main.tf           ← entry point, calls all modules
  variables.tf      ← global input variables (region, cluster name, etc.)
  outputs.tf        ← values exposed after apply (cluster endpoint, kubeconfig, etc.)
  terraform.tfvars  ← actual variable values — NOT committed to git (contains sensitive data)
  modules/
    vpc/            ← VPC, subnets, internet gateway, routing
      main.tf
      variables.tf
      outputs.tf
    eks/            ← EKS cluster, Fargate profile, node configuration
      main.tf
      variables.tf
      outputs.tf
    iam/            ← IAM roles for the cluster control plane and Fargate pods
      main.tf
      variables.tf
      outputs.tf
```

### Why modules?

Each module is a self-contained unit responsible for one layer of the infrastructure. This mirrors how Terraform is used in professional environments:
- Modules can be developed and tested independently
- Changes to the VPC don't require touching the EKS configuration
- Modules can be reused across environments or projects

---

## Remote State

By default Terraform saves state in a local `terraform.tfstate` file. This breaks in any team or CI/CD scenario — each machine has its own state, parallel runs can corrupt it, and there is no locking.

The solution is **Remote State**: the state file is stored centrally and protected by a lock so only one execution can run at a time.

### S3 + DynamoDB (AWS standard)

| Resource | Purpose |
|----------|---------|
| **S3 bucket** | Stores the `terraform.tfstate` file centrally |
| **DynamoDB table** | Provides state locking — prevents two executions from running in parallel |

Every time Terraform runs (locally or in GitHub Actions):
1. Downloads state from S3
2. Acquires lock on DynamoDB
3. Executes changes
4. Saves updated state to S3
5. Releases lock

### Bootstrap (one-time setup)

The S3 bucket and DynamoDB table must exist **before** running any Terraform configuration. They are created manually via AWS CLI — they cannot be managed by Terraform itself (chicken-and-egg problem).

Create the S3 bucket:
```cmd
aws s3api create-bucket --bucket cicd-k8s-terraform-state --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1 --profile cicd-k8s
```

Enable versioning (allows rollback to previous state):
```cmd
aws s3api put-bucket-versioning --bucket cicd-k8s-terraform-state --versioning-configuration Status=Enabled --profile cicd-k8s
```

Block public access (state files must never be public):
```cmd
aws s3api put-public-access-block --bucket cicd-k8s-terraform-state --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" --profile cicd-k8s
```

Create the DynamoDB table for locking:
```cmd
aws dynamodb create-table --table-name cicd-k8s-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region eu-west-1 --profile cicd-k8s
```

> `PAY_PER_REQUEST` billing means you only pay when a lock is acquired — effectively free for this project.

---

## How Terraform works

Terraform follows a **plan → apply** cycle:

1. **`terraform init`** — downloads the required providers (AWS) and modules
2. **`terraform plan`** — shows what will be created, modified, or destroyed — no changes made yet
3. **`terraform apply`** — creates the infrastructure on AWS
4. **`terraform destroy`** — destroys all resources managed by this configuration

State is stored in `terraform.tfstate` — Terraform uses this to track what it has created. Do not delete or edit it manually.

---

## Usage

Initialize (run once):
```cmd
terraform init
```

Preview changes:
```cmd
terraform plan -var-file="terraform.tfvars"
```

Apply:
```cmd
terraform apply -var-file="terraform.tfvars"
```

Destroy (always run this when done to avoid costs — see cost warning in [SETUP.md](../SETUP.md)):
```cmd
terraform destroy -var-file="terraform.tfvars"
```

---

## Important: files not committed to git

- `terraform.tfvars` — contains variable values, may include sensitive data
- `terraform.tfstate` — Terraform state file, contains resource IDs and configuration details
- `.terraform/` — downloaded providers and modules cache

These are already listed in `.gitignore`.
