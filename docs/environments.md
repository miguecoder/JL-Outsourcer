# Multi-Environment Configuration

## Overview

The project supports multiple environments:
- **dev** - Development environment (default)
- **prod** - Production environment

Each environment has:
- Separate AWS resources
- Isolated Terraform state
- Independent configuration

---

## Environment Structure

```
infra/envs/
├── dev/
│   ├── backend.tf      # State: dev/terraform.tfstate
│   ├── main.tf         # Modules with environment="dev"
│   ├── variables.tf    # Default: environment="dev"
│   └── outputs.tf
└── prod/
    ├── backend.tf      # State: prod/terraform.tfstate
    ├── main.tf         # Modules with environment="prod"
    ├── variables.tf    # Default: environment="prod"
    └── outputs.tf
```

---

## Switching Between Environments

### Using Makefile (Recommended)

```bash
# Deploy to dev (default)
make infra-apply

# Deploy to prod
make infra-apply ENV=prod

# Check prod status
make check ENV=prod

# View prod logs
make logs-api ENV=prod
```

### Manual Method

```bash
# For dev
cd infra/envs/dev
terraform init
terraform apply

# For prod
cd infra/envs/prod
terraform init
terraform apply
```

---

## Resource Naming Convention

Resources are named with environment suffix:

**Dev Environment:**
- S3: `twl-pipeline-raw-data-dev`
- DynamoDB: `twl-pipeline-curated-dev`
- Lambda: `twl-pipeline-ingestion-dev`
- SQS: `twl-pipeline-processing-dev`

**Prod Environment:**
- S3: `twl-pipeline-raw-data-prod`
- DynamoDB: `twl-pipeline-curated-prod`
- Lambda: `twl-pipeline-ingestion-prod`
- SQS: `twl-pipeline-processing-prod`

---

## Differences Between Environments

### Dev Environment

**Purpose:** Testing and development

**Characteristics:**
- Smaller resource sizes
- Shorter retention periods
- More verbose logging
- Manual triggers allowed

**Ingestion Schedule:**
```hcl
schedule_expression = "rate(5 minutes)"
```

**Lambda Memory:**
- Ingestion: 256 MB
- Processing: 256 MB
- API: 512 MB

---

### Prod Environment

**Purpose:** Production workload (if deployed)

**Recommended Characteristics:**
- Larger resource sizes
- Longer retention periods
- Optimized logging
- Automated only

**Suggested Adjustments for Prod:**

#### 1. Less Frequent Ingestion (Cost Optimization)
```hcl
# infra/modules/compute/main.tf (make configurable)
schedule_expression = var.environment == "prod" ? "rate(1 hour)" : "rate(5 minutes)"
```

#### 2. Higher Lambda Memory (Performance)
```hcl
memory_size = var.environment == "prod" ? 512 : 256
```

#### 3. Longer Log Retention
```hcl
retention_in_days = var.environment == "prod" ? 30 : 7
```

#### 4. DynamoDB Reserved Capacity (Cost Optimization)
```hcl
billing_mode = var.environment == "prod" ? "PROVISIONED" : "PAY_PER_REQUEST"
```

---

## Deployment Guide

### First-Time Deployment

#### Dev Environment
```bash
cd infra/envs/dev
terraform init
terraform plan
terraform apply

# Get outputs
terraform output
```

#### Prod Environment
```bash
cd infra/envs/prod
terraform init
terraform plan

# Review plan carefully!
# Prod should have different resource names

terraform apply

# Get outputs
terraform output
```

---

## Environment Variables

### Frontend Configuration

**Dev:**
```bash
cd frontend
echo "NEXT_PUBLIC_API_URL=$(cd ../infra/envs/dev && terraform output -raw api_url)" > .env.local
```

**Prod:**
```bash
cd frontend
echo "NEXT_PUBLIC_API_URL=$(cd ../infra/envs/prod && terraform output -raw api_url)" > .env.production
```

---

## Cost Comparison

### Dev Environment (Current Configuration)
- **Lambda:** ~$0.60/month (frequent executions)
- **S3:** ~$0.05/month (1 GB)
- **DynamoDB:** ~$0.50/month (on-demand)
- **SQS:** ~$0.01/month
- **API Gateway:** ~$0.01/month
- **Total:** ~$1.17/month

### Prod Environment (Recommended)
- **Lambda:** ~$2.00/month (less frequent, more memory)
- **S3:** ~$0.20/month (more data, lifecycle policies)
- **DynamoDB:** ~$5.00/month (reserved capacity)
- **SQS:** ~$0.05/month
- **API Gateway:** ~$1.00/month (more traffic)
- **Total:** ~$8.25/month

---

## State Management

### Backend Configuration

Both environments use the **same S3 bucket** but **different keys**:

```hcl
# Dev
key = "dev/terraform.tfstate"

# Prod
key = "prod/terraform.tfstate"
```

This allows:
- ✅ Centralized state storage
- ✅ Independent state files
- ✅ Concurrent operations
- ✅ DynamoDB locking prevents conflicts

---

## CI/CD Integration

### GitHub Actions Workflow

**Current:** Only deploys to `dev` on push to `main`

**To Enable Prod Deployments:**

1. Create a `release` branch
2. Update workflow:
```yaml
deploy-prod:
  if: github.ref == 'refs/heads/release'
  environment: production-release
  # ... same steps but with ENV=prod
```

3. Merge to `release` → Deploys to prod

---

## Switching Environments (Quick Reference)

```bash
# All commands support ENV parameter

# Deploy
make infra-apply ENV=dev      # Deploy to dev
make infra-apply ENV=prod     # Deploy to prod

# Check health
make check ENV=dev
make check ENV=prod

# View logs
make logs-api ENV=dev
make logs-api ENV=prod

# Destroy (use with caution!)
make infra-destroy ENV=dev
make infra-destroy ENV=prod
```

---

## Best Practices

### Development (dev)
✅ Test new features here first  
✅ Frequent deployments OK  
✅ Can destroy/recreate anytime  
✅ Lower cost configuration  

### Production (prod)
✅ Only deploy tested features  
✅ Require manual approval  
✅ Enable backups and retention  
✅ Optimize for performance and cost  
✅ Monitor closely  

---

## Migration Path

To promote changes from dev → prod:

```bash
# 1. Test in dev
cd infra/envs/dev
terraform apply

# 2. Verify it works
make check ENV=dev

# 3. Apply to prod (after approval)
cd ../prod
terraform plan  # Review carefully!
terraform apply
```

---

## Rollback Strategy

If something breaks in prod:

### Option 1: Rollback Terraform State
```bash
cd infra/envs/prod
terraform state list
terraform state pull > backup.tfstate
# Apply previous working state
```

### Option 2: Redeploy Previous Lambda Code
```bash
# Checkout previous commit
git checkout <previous-commit-hash>

# Rebuild and deploy Lambdas
make deploy-lambdas ENV=prod

# Return to current
git checkout main
```

---

## Monitoring Both Environments

```bash
# Compare resource counts
echo "=== DEV ===" && make check ENV=dev
echo "=== PROD ===" && make check ENV=prod

# View dashboards
terraform output -state=infra/envs/dev/.terraform/terraform.tfstate dashboard_url
terraform output -state=infra/envs/prod/.terraform/terraform.tfstate dashboard_url
```

---

## Summary

- ✅ Two independent environments (dev, prod)
- ✅ Same codebase, different configurations
- ✅ Isolated state files
- ✅ Easy switching via ENV parameter
- ✅ Production-ready for real workloads

For questions, see [README.md](../README.md) or [docs/architecture.md](architecture.md).

