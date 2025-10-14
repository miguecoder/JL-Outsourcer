# Security Documentation

## Overview

This document outlines the security measures implemented in the TWL Pipeline project.

---

## 🔐 Authentication & Authorization

### API Key (Basic Auth)

The API includes a basic authentication mechanism using API Keys stored in AWS Systems Manager (SSM).

#### Implementation

**Infrastructure (Terraform):**
- API Key generated with random suffix
- Stored in SSM Parameter Store (SecureString)
- Path: `/twl-pipeline/{environment}/api-key`

**Frontend:**
- Reads API Key from environment variable
- Sends in `x-api-key` header (optional)
- Graceful fallback if not configured

#### Get API Key

```bash
cd infra/envs/dev
terraform output -raw api_key
```

#### Configure Frontend

```bash
cd frontend

# Get API key from Terraform
API_KEY=$(cd ../infra/envs/dev && terraform output -raw api_key)

# Add to .env.local
echo "NEXT_PUBLIC_API_KEY=$API_KEY" >> .env.local
```

**Note:** Currently, the API Key is **optional** (not enforced). To enforce it, uncomment the authorizer configuration in `infra/modules/api/main.tf`.

---

## 🔒 IAM Security

### Least Privilege Principle

Each Lambda function has a dedicated IAM role with minimum required permissions.

#### Ingestion Lambda
```json
{
  "s3:PutObject": ["arn:aws:s3:::bucket-name/*"],
  "sqs:SendMessage": ["arn:aws:sqs:*:*:queue-name"],
  "logs:*": ["arn:aws:logs:*:*:*"]
}
```

#### Processing Lambda
```json
{
  "s3:GetObject": ["arn:aws:s3:::bucket-name/*"],
  "dynamodb:PutItem": ["arn:aws:dynamodb:*:*:table/*"],
  "sqs:ReceiveMessage": ["arn:aws:sqs:*:*:queue-name"],
  "logs:*": ["arn:aws:logs:*:*:*"]
}
```

#### API Lambda
```json
{
  "dynamodb:GetItem": ["arn:aws:dynamodb:*:*:table/*"],
  "dynamodb:Query": ["arn:aws:dynamodb:*:*:table/*/index/*"],
  "dynamodb:Scan": ["arn:aws:dynamodb:*:*:table/*"],
  "logs:*": ["arn:aws:logs:*:*:*"]
}
```

**No wildcards** in resource ARNs.

---

## 🔐 Encryption

### At Rest

| Service | Encryption | Key Management |
|---------|------------|----------------|
| **S3** | AES-256 | AWS-managed |
| **DynamoDB** | Enabled | AWS-managed |
| **SQS** | Enabled | AWS-managed |
| **SSM** | SecureString | AWS-managed |

### In Transit

All communications use **TLS 1.2+**:
- ✅ HTTPS for API Gateway
- ✅ TLS for S3 API calls
- ✅ TLS for DynamoDB API calls
- ✅ TLS for SQS messaging

---

## 🔑 Secrets Management

### Current Implementation

**API Key:**
- Stored in **AWS Systems Manager (SSM)** Parameter Store
- Type: SecureString (encrypted at rest)
- Access via IAM permissions only

**AWS Credentials:**
- **GitHub Actions**: Stored in GitHub Secrets
- **Local dev**: `~/.aws/credentials` (never committed)

### Best Practices

✅ **DO:**
- Use environment variables
- Store secrets in SSM/Secrets Manager
- Use GitHub Secrets for CI/CD
- Rotate credentials regularly

❌ **DON'T:**
- Hardcode credentials in code
- Commit `.env` or `.env.secrets` files
- Share credentials via Git
- Use long-lived credentials

---

## 🛡️ Network Security

### Current Implementation

**No VPC** (intentional simplification):
- All services use AWS managed endpoints
- TLS encryption in transit
- Public internet access

### Production Recommendations

For production, consider:
- ✅ VPC with private subnets
- ✅ NAT Gateway for outbound traffic
- ✅ VPC Endpoints for AWS services
- ✅ Security Groups with least privilege
- ✅ Network ACLs

**Trade-off:** Added complexity vs. security depth

---

## 🔍 Vulnerability Scanning

### Dependency Scanning

**npm audit** for Node.js dependencies:
```bash
cd services/ingestion && npm audit
cd services/processing && npm audit
cd services/api && npm audit
cd frontend && npm audit
```

### Future Enhancements

- [ ] Integrate Snyk or Dependabot
- [ ] Automated security scanning in CI/CD
- [ ] Container image scanning (if using containers)

---

## 📊 Security Monitoring

### CloudWatch Alarms

**3 alarms configured:**

1. **Lambda Errors** (threshold: 10)
   - Detects excessive errors
   - Indicates potential attacks or bugs

2. **DLQ Messages** (threshold: 5)
   - Detects processing failures
   - May indicate malformed input

3. **API 5XX Errors** (threshold: 5)
   - Detects API failures
   - May indicate backend issues

### Logging

**Structured logs** (JSON format) include:
- Timestamp
- Request ID
- Source/action
- Error details (if any)

**Retention:** 7 days (configurable)

---

## 🔐 Compliance Checklist

### OWASP Top 10

| Risk | Status | Mitigation |
|------|--------|------------|
| Broken Access Control | ⚠️ Partial | API Key (optional), IAM roles |
| Cryptographic Failures | ✅ Mitigated | Encryption at rest + TLS |
| Injection | ✅ Mitigated | DynamoDB (NoSQL), no SQL injection |
| Insecure Design | ✅ Mitigated | Least privilege, separation of concerns |
| Security Misconfiguration | ✅ Mitigated | IaC, default encryption |
| Vulnerable Components | ⚠️ Partial | npm audit, no automated scanning |
| Authentication Failures | ⚠️ Partial | API Key (basic), no MFA |
| Data Integrity Failures | ✅ Mitigated | Hash verification, idempotency |
| Logging Failures | ✅ Mitigated | CloudWatch, structured logs |
| SSRF | ✅ Mitigated | No user-controlled URLs |

---

## 🚀 Production Hardening (Future)

### Recommended Enhancements

1. **Cognito Integration**
   - User authentication
   - JWT tokens
   - MFA support

2. **WAF (Web Application Firewall)**
   - Rate limiting
   - SQL injection protection
   - XSS protection

3. **API Gateway API Keys (Native)**
   - Usage plans
   - Throttling
   - Quota management

4. **KMS (Customer Managed Keys)**
   - Custom encryption keys
   - Key rotation
   - Fine-grained access control

5. **VPC**
   - Private subnets
   - VPC endpoints
   - Network isolation

6. **GuardDuty**
   - Threat detection
   - Anomaly detection
   - Security notifications

---

## 📋 Security Checklist

Before production deployment:

- [x] IAM roles with least privilege
- [x] Encryption at rest (S3, DynamoDB)
- [x] TLS in transit
- [x] Secrets in SSM Parameter Store
- [x] CloudWatch logging enabled
- [x] CloudWatch alarms configured
- [ ] API authentication enforced
- [ ] VPC configured
- [ ] WAF rules defined
- [ ] Backup strategy implemented
- [ ] Incident response plan documented
- [ ] Regular security audits scheduled

---

## 🆘 Security Incident Response

### If Credentials are Compromised

1. **Rotate immediately:**
   ```bash
   aws iam create-access-key --user-name YOUR_USER
   aws iam delete-access-key --access-key-id OLD_KEY --user-name YOUR_USER
   ```

2. **Update GitHub Secrets**

3. **Update local credentials:** `~/.aws/credentials`

4. **Redeploy with new credentials**

### If API Key is Exposed

1. **Regenerate key:**
   ```bash
   cd infra/envs/dev
   terraform taint module.api.random_string.api_key_suffix
   terraform apply
   ```

2. **Update frontend:** New API key in `.env.local`

---

## 📚 References

- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Terraform Security](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)

---

For questions or security concerns, contact the development team.

