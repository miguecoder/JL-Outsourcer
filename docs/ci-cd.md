# CI/CD Pipeline Documentation

## Overview

GitHub Actions workflow implementing automated deployment with manual approval gates.

## Workflow Structure

### Pipeline Stages

```
┌─────────────┐
│  Validate   │  ← Lint & Format checks
└──────┬──────┘
       │
┌──────▼──────┐
│    Test     │  ← Unit tests
└──────┬──────┘
       │
┌──────▼──────┐
│    Plan     │  ← Terraform plan (PRs only)
└──────┬──────┘
       │
┌──────▼──────┐
│   Deploy    │  ← Infrastructure (manual approval)
│    Infra    │
└──────┬──────┘
       │
┌──────▼──────┐
│   Deploy    │  ← Lambda functions
│   Lambdas   │
└──────┬──────┘
       │
┌──────▼──────┐
│ Integration │  ← E2E tests
│    Test     │
└─────────────┘
```

## Jobs

### 1. **Validate** (Always runs)
- Terraform format check
- Terraform validate
- Service linting

**Duration**: ~2 minutes

### 2. **Test** (Always runs)
- Unit tests for Lambda functions
- Currently: placeholder tests
- Future: Jest + mocks

**Duration**: ~1 minute

### 3. **Plan** (Pull Requests only)
- Terraform plan
- Comments plan output in PR
- Helps reviewers understand infrastructure changes

**Duration**: ~3 minutes

### 4. **Deploy Infrastructure** (Main branch only, Manual approval)
- Requires manual approval via GitHub environment
- Terraform apply
- Creates/updates AWS resources

**Duration**: ~5 minutes

### 5. **Deploy Lambdas** (Main branch only)
- Package Lambda functions
- Upload to AWS Lambda
- Updates function code

**Duration**: ~2 minutes

### 6. **Integration Test** (Main branch only)
- Tests ingestion Lambda
- Tests API endpoints
- Health check

**Duration**: ~1 minute

---

## Setup

### 1. GitHub Secrets

Configure these secrets in GitHub repo settings:

```
AWS_ACCESS_KEY_ID       → AWS access key
AWS_SECRET_ACCESS_KEY   → AWS secret key
```

Go to: **Settings → Secrets and variables → Actions → New repository secret**

### 2. GitHub Environment (Manual Approval)

Create a `production` environment with protection rules:

1. Go to: **Settings → Environments → New environment**
2. Name: `production`
3. Enable: **Required reviewers**
4. Add yourself as reviewer

This adds a **manual approval gate** before infrastructure deployment.

---

## Triggers

### On Pull Request
```yaml
- Validate
- Test
- Plan (with PR comment)
```

### On Push to Main
```yaml
- Validate
- Test
- Deploy Infrastructure (with manual approval)
- Deploy Lambdas
- Integration Test
```

### Manual Trigger
```yaml
workflow_dispatch
```

Can be triggered manually from GitHub Actions tab.

---

## Usage

### For Development (Feature Branch)

```bash
git checkout -b feature/my-feature
# Make changes
git commit -m "feat: add new feature"
git push origin feature/my-feature
```

Create PR → GitHub Actions runs **validate**, **test**, and **plan**

### For Deployment (Main Branch)

```bash
git checkout main
git merge feature/my-feature
git push origin main
```

GitHub Actions runs full pipeline:
1. ✅ Validate & Test (automatic)
2. ⏸️ **Manual approval required**
3. ✅ Deploy infrastructure (after approval)
4. ✅ Deploy Lambdas
5. ✅ Integration tests

---

## Manual Approval

When deploying to main, you'll see:

```
⏸️ Waiting for approval from required reviewers
   Review pending deployment to production
```

Click **"Review deployments"** → Select environment → **Approve**

---

## Monitoring

### View Workflow Runs
GitHub repo → **Actions** tab

### Check Logs
Click on any workflow run → Click on job name → View logs

### Artifacts
None currently, but can be added for:
- Terraform plans
- Test reports
- Lambda packages

---

## Local Testing

Test workflow components locally:

### Validate
```bash
cd infra/envs/dev
terraform fmt -check -recursive
terraform validate
```

### Lint
```bash
cd services/ingestion
npm run lint
```

### Package
```bash
make package
```

---

## Troubleshooting

### ❌ Terraform Init Fails

**Cause**: Backend credentials or state lock

**Solution**: Check AWS credentials, ensure state file is accessible

### ❌ Terraform Apply Fails

**Cause**: Resource conflicts, quota limits

**Solution**: Check terraform logs, resolve conflicts manually

### ❌ Lambda Deploy Fails

**Cause**: Package too large, permissions issue

**Solution**: 
- Check lambda-*.zip sizes (must be < 50MB)
- Verify IAM permissions for Lambda update

### ⏸️ Workflow Stuck on Approval

**Cause**: No reviewers configured

**Solution**: Add reviewers in Environment settings

---

## Future Enhancements

- [ ] Real unit tests with Jest
- [ ] E2E tests with real data validation
- [ ] Terraform plan as PR comment
- [ ] Slack/email notifications
- [ ] Blue-green deployment
- [ ] Automated rollback on failure
- [ ] Performance testing
- [ ] Security scanning (Snyk, Trivy)

---

## Costs

GitHub Actions is **free** for public repos and includes:
- 2,000 minutes/month for private repos
- Unlimited for public repos

This workflow uses ~15 minutes per full deployment.

---

## Best Practices

✅ **Always create PRs** for code review
✅ **Never push directly to main** without PR
✅ **Review Terraform plans** before approving
✅ **Test locally** before pushing
✅ **Use descriptive commit messages**

❌ Don't skip manual approval for production
❌ Don't commit AWS credentials
❌ Don't deploy without testing

---

For more information, see:
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)

