# AWS Setup

This folder contains all AWS-related configuration and documentation for the `cicd-k8s` project.

---

## ⚠️ Cost Warning — Read Before Starting

### EKS pricing
- **Control plane: $0.10/hour (~$72/month)** — charged regardless of whether pods are running or not
- **Fargate nodes: ~$0.01-0.02/hour** per pod — charged only while pods are running
- **There is no "pause" for EKS** — the cluster is either running (and billing) or deleted

### For this project
Turn the cluster on to run experiments, then **delete it immediately when done**.

A typical session (2-3 hours) costs roughly **$0.30-0.50**. Leaving it on overnight costs **~$1**. Forgetting it for a month costs **~$72**.

### Delete the cluster when done
```cmd
eksctl delete cluster --name cicd-k8s-cluster --region eu-west-1 --profile cicd-k8s
```

This deletes the cluster, all nodes, the VPC, and all associated resources. Double-check in the AWS Console (**EKS** and **CloudFormation**) that no stacks are left behind.

---

## IAM User

Create a dedicated IAM user for CLI access — never use root credentials for day-to-day operations.

**AWS Console → IAM → Users → Create user**

- Name: `cicd-k8s-admin`
- Do NOT enable console access (CLI only)
- **Permissions → Attach policies directly** — add the following managed policies:

| Policy | Purpose |
|--------|---------|
| `AmazonEKSClusterPolicy` | Create, modify and delete EKS clusters. Required for `eksctl create cluster` and control plane configuration. |
| `AmazonEKSWorkerNodePolicy` | Manage EKS worker nodes (the EC2 instances that run pods). Required for nodes to register themselves in the cluster. |
| `AmazonEC2ContainerRegistryFullAccess` | Push and pull images to/from ECR (AWS's private Docker registry). Even though we currently use Docker Hub, ECR will be used in production to keep images private and close to the cluster. |
| `AmazonVPCFullAccess` | Create the VPC, subnets, security groups, and load balancers that EKS needs. Without this, cluster creation fails because the network infrastructure cannot be provisioned. |
| `IAMFullAccess` | EKS automatically creates IAM roles during setup (one for the cluster, one for the nodes). Without this it cannot create those roles and the cluster won't start. |
| `AmazonS3FullAccess` | Create and manage the S3 bucket used for Terraform remote state storage. |
| `AmazonDynamoDBFullAccess` | Create and manage the DynamoDB table used for Terraform state locking. |
| `AmazonEC2FullAccess` | Create and manage EC2 resources required by the VPC module (Elastic IP, subnets, NAT Gateway, route tables, internet gateway). |
| `AmazonEKSServicePolicy` | AWS managed policy for the EKS service role. |
| `cicd-k8s-EKSFullAccess` *(inline policy)* | Custom inline policy granting full EKS administration (`eks:*`). No AWS managed policy exists for this — must be created manually. JSON: `{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":"eks:*","Resource":"*"}]}` |

> **Tech debt — Least Privilege:** The `*FullAccess` managed policies above are overly permissive and would never pass a security review in a real environment. The correct approach is to create **custom IAM policies** with only the specific actions needed. For example, S3 only needs `s3:CreateBucket`, `s3:PutBucketVersioning`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket`. Similarly for DynamoDB, EKS, and the others. For this personal learning project `FullAccess` policies are acceptable as a shortcut, but should be replaced with granular custom policies before using this setup in any shared or production environment.

---

## Access Keys

Generate CLI access keys for the IAM user:

**IAM → Users → cicd-k8s-admin → Security credentials → Create access key** → select **CLI**

Save the `Access Key ID` and `Secret Access Key` — they are shown only once.

---

## AWS CLI Profile

Configure a named profile so credentials are isolated from other AWS accounts:

```cmd
aws configure --profile cicd-k8s
```

Enter when prompted:
- **AWS Access Key ID** — the key ID generated in the previous step
- **AWS Secret Access Key** — the secret key generated in the previous step
- **Default region** — `eu-west-1` (Ireland): the closest European region to Italy with full service availability. Alternative: `eu-south-1` (Milan) but has fewer available services.
- **Default output format** — `json`: machine-readable format compatible with all CLI tools and scripts

Credentials are stored in `~/.aws/credentials` under the `[cicd-k8s]` profile. Use `--profile cicd-k8s` with every AWS CLI command, or set the environment variable:

```cmd
set AWS_PROFILE=cicd-k8s
```

Verify the profile works:
```cmd
aws sts get-caller-identity --profile cicd-k8s
```

You should see the `cicd-k8s-admin` user ARN in the response.

---

## Architecture Plan

### Multi-account strategy

| Environment | AWS Account | Cluster | Namespaces |
|-------------|-------------|---------|------------|
| dev | `cicd-k8s-admin` (current) | `cicd-k8s-cluster` | `dev` |
| staging | `cicd-k8s-admin` (current) | `cicd-k8s-cluster` | `staging` |
| prod | separate AWS account (future) | `cicd-k8s-prod-cluster` | `prod` |

Dev and staging share a single EKS cluster (cost efficient, isolated via namespaces). Prod lives in a completely separate AWS account for full isolation of costs, IAM permissions, and network — the industry standard for production workloads.

**Current focus:** dev + staging on a single cluster. Prod on a separate account will be tackled later.

### Infrastructure as Code

All AWS infrastructure is managed with **Terraform** — the industry standard IaC tool. It works across AWS, Azure, and GCP, making it reusable when other cloud providers are added.

Terraform configuration will live in `cloud/aws/terraform/`.

---

## Required tools

### Terraform

Infrastructure as Code tool used to provision the EKS cluster and all related AWS resources (VPC, subnets, IAM roles, node groups).

Install on Windows (choose one):
```cmd
winget install HashiCorp.Terraform
```
```cmd
choco install terraform
```

Verify:
```cmd
terraform version
```

### eksctl

The official CLI for creating and managing EKS clusters. Useful for quick operations and debugging outside of Terraform.

Install on Windows:
```cmd
winget install eksctl
```

Verify:
```cmd
eksctl version
```
