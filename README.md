# aws-terraform-cicd

Multi-tier AWS infrastructure provisioned with Terraform and automated via GitHub Actions CI/CD pipeline.

## What this provisions

- VPC with public and private subnets across two AZs
- EC2 t2.micro running a Dockerized Flask app
- Security groups with HTTP/HTTPS/SSH rules
- IAM role with least-privilege S3 read access
- S3 bucket with versioning and public access blocked
- DynamoDB table for Terraform state locking
- S3 remote backend for Terraform state

## CI/CD Flow

```
Pull Request → terraform plan (preview only, no changes)
Merge to main → terraform apply (requires manual approval)
```

## Project Structure

```
aws-terraform-cicd/
├── .github/
│   └── workflows/
│       └── terraform.yml
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
└── README.md
```

## Setup

1. Create S3 bucket for remote state
2. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to GitHub Secrets
3. Create `production` environment in GitHub with required reviewers
4. Push to a branch → raise PR → review plan → merge to deploy
