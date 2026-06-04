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

### Old approach: S3 + DynamoDB

The original AWS standard for Terraform remote state used two resources:

| Resource | Purpose |
|----------|---------|
| **S3 bucket** | Stores the `terraform.tfstate` file centrally |
| **DynamoDB table** | Provides state locking — prevents two executions from running in parallel |

Every time Terraform ran:
1. Downloaded state from S3
2. Acquired lock on DynamoDB
3. Executed changes
4. Saved updated state to S3
5. Released lock on DynamoDB

The DynamoDB table was configured in `main.tf` as:
```hcl
dynamodb_table = "cicd-k8s-terraform-locks"
```

And created via AWS CLI:
```cmd
aws dynamodb create-table --table-name cicd-k8s-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region eu-west-1 --profile cicd-k8s
```

> `PAY_PER_REQUEST` billing means you only pay when a lock is acquired — effectively free for this project.

### Current approach: S3 + native lock file (Terraform 1.10+)

The `dynamodb_table` parameter is now deprecated. Terraform 1.10+ introduced `use_lockfile = true` which stores the lock directly in S3 — no DynamoDB table needed.

| Resource | Purpose |
|----------|---------|
| **S3 bucket** | Stores both the `terraform.tfstate` file and the lock file |

The DynamoDB table `cicd-k8s-terraform-locks` was created during initial bootstrap but has since been deleted as it is no longer needed. The `main.tf` backend now uses:
```hcl
use_lockfile = true
```

### Bootstrap (one-time setup)

Only the S3 bucket needs to exist before running any Terraform configuration. It cannot be managed by Terraform itself (chicken-and-egg problem).

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

---

## How Terraform works

Terraform follows a **plan → apply** cycle:

1. **`terraform init`** — downloads the required providers (AWS) and modules
2. **`terraform plan`** — shows what will be created, modified, or destroyed — no changes made yet
3. **`terraform apply`** — creates the infrastructure on AWS
4. **`terraform destroy`** — destroys all resources managed by this configuration

State is stored in `terraform.tfstate` — Terraform uses this to track what it has created. Do not delete or edit it manually.

---

## Credentials

Terraform reads AWS credentials from environment variables. The approach differs between local development and CI/CD.

### Local development

Use the named AWS CLI profile — safer than exposing raw credentials in the terminal.

Or set it manually:
```cmd
set AWS_PROFILE=cicd-k8s
```

Two helper scripts are provided in `cloud/aws/` that do the same and print a reminder:

**CMD** — must be run with `call` so the variable persists in the current session:
```cmd
call cloud\aws\set-profile.bat
```

**PowerShell** — must be dot-sourced with `.` so the variable persists in the current session:
```powershell
. .\cloud\aws\set-profile.ps1
```

Verify the profile is set:
```cmd
echo %AWS_PROFILE%
```
Expected output: `cicd-k8s`. If you see `%AWS_PROFILE%` printed literally, the variable is not set — Terraform will fail with a credentials error.

The AWS provider reads `AWS_PROFILE` automatically and uses the credentials configured for that profile (see [SETUP.md](../SETUP.md)).

### CI/CD (GitHub Actions, Jenkins)

Named profiles don't exist on CI/CD machines. Inject credentials via environment variables:

```cmd
AWS_ACCESS_KEY_ID=your_key_id
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_DEFAULT_REGION=eu-west-1
```

On GitHub Actions these are set via repository secrets and injected into the workflow automatically.

---

## Usage

### Step 1 — Set AWS credentials (every new terminal session)

```powershell
. .\cloud\aws\set-profile.ps1   # PowerShell
```
```cmd
call cloud\aws\set-profile.bat  # CMD
```

### Step 2 — Initialize (run once, or after adding new modules/providers)

```cmd
cd cloud\aws\terraform
terraform init
```

What `terraform init` does — **no AWS resources are created, no costs:**
- Downloads the AWS provider plugin
- Connects to the S3 bucket and verifies read/write access
- Connects to the DynamoDB table and verifies lock access
- The `terraform.tfstate` file in S3 is created only after the first `terraform apply`

### Step 3 — Preview changes (free, read-only)

```cmd
terraform plan
```

Shows exactly what will be created, modified, or destroyed — nothing is changed in AWS. Always run this before `apply` to verify the changes.

### Step 4 — Apply (creates real AWS resources — costs money)

```cmd
terraform apply
```

After apply completes, verify the resources in the AWS Console (region: **eu-west-1**):

| AWS Service | Console path | What to verify |
|-------------|-------------|----------------|
| **EKS** | EKS → Clusters | `cicd-k8s-cluster` exists, status Active |
| **EKS** | EKS → Clusters → cicd-k8s-cluster → Compute tab | Fargate profiles: `kube-system`, `dev`, `staging` — each with status Active |
| **VPC** | VPC → Your VPCs | `cicd-k8s-cluster-vpc` exists |
| **VPC** | VPC → Subnets | 4 subnets: 2 public (`10.0.0.0/24`, `10.0.1.0/24`), 2 private (`10.0.10.0/24`, `10.0.11.0/24`) |
| **VPC** | VPC → Internet Gateways | `cicd-k8s-cluster-igw` attached to the VPC |
| **VPC** | VPC → NAT Gateways | `cicd-k8s-cluster-nat` in state Available |
| **VPC** | VPC → Route Tables | 2 route tables: public and private |
| **EC2** | EC2 → Elastic IPs | 1 EIP allocated for the NAT Gateway |
| **IAM** | IAM → Roles | `cicd-k8s-cluster-cluster-role` and `cicd-k8s-cluster-fargate-role` |
| **S3** | S3 → cicd-k8s-terraform-state | `eks/terraform.tfstate` file exists |

### Step 5 — Connect kubectl to the cluster

After apply, configure kubectl to talk to EKS instead of Minikube:

```cmd
aws eks update-kubeconfig --name cicd-k8s-cluster --region eu-west-1 --profile cicd-k8s
```

Verify the connection:
```cmd
kubectl get pods -A
```

#### Grant AWS Console access to Kubernetes resources

By default the AWS Console shows: *"Your current IAM principal doesn't have access to Kubernetes objects on this cluster."* This is because the console needs an explicit EKS access entry.

Run these two commands once after `terraform apply`:

```cmd
aws eks create-access-entry --cluster-name cicd-k8s-cluster --principal-arn arn:aws:iam::664003006512:user/cicd-k8s-admin --region eu-west-1 --profile cicd-k8s
```

```cmd
aws eks associate-access-policy --cluster-name cicd-k8s-cluster --principal-arn arn:aws:iam::664003006512:user/cicd-k8s-admin --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope type=cluster --region eu-west-1 --profile cicd-k8s
```

After this, the AWS Console EKS → Resources tab will show pods, deployments, and namespaces.

You should see system pods running in the `kube-system` namespace on Fargate.

Then deploy the app to the dev namespace:
```cmd
kubectl apply -k k8s/overlays/dev
kubectl get all -n dev
```

The app is now running on AWS EKS. To access it externally, the LoadBalancer Service will be assigned a DNS hostname by AWS (not an IP like on Minikube).

### Step 6 — Destroy (always run this when done to avoid costs)

```cmd
terraform destroy
```

After destroy, verify in the AWS Console that all resources listed above are gone. Also check **CloudFormation → Stacks** to ensure no stacks were left behind.

Destroys all resources managed by this configuration. Double-check in the AWS Console (**EKS** and **CloudFormation**) that no stacks are left behind.

---

## Important: files not committed to git

- `terraform.tfvars` — contains variable values, may include sensitive data
- `terraform.tfstate` — Terraform state file, contains resource IDs and configuration details
- `.terraform/` — downloaded providers and modules cache

These are already listed in `.gitignore`.
