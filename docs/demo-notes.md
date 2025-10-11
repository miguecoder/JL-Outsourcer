# Demo Notes & Troubleshooting Guide

## Table of Contents
- [Quick Demo Steps](#quick-demo-steps)
- [Verification Checklist](#verification-checklist)
- [Testing Scenarios](#testing-scenarios)
- [Common Issues & Solutions](#common-issues--solutions)
- [Useful Commands](#useful-commands)

---

## Quick Demo Steps

### Prerequisites
- AWS credentials configured
- Terraform deployed successfully
- API URL from Terraform outputs

### 1. Deploy Infrastructure (5 minutes)

```bash
cd infra/envs/dev

# Deploy
terraform init
terraform apply -auto-approve

# Save outputs
terraform output > outputs.txt
export API_URL=$(terraform output -raw api_url)
echo "API URL: $API_URL"
```

### 2. Verify Pipeline (10 minutes)

```bash
# Manually trigger ingestion
aws lambda invoke \
  --function-name twl-pipeline-ingestion-dev \
  response.json

# Check response
cat response.json | jq .

# Expected output:
# {
#   "statusCode": 200,
#   "body": "{\"message\":\"Ingestion completed\",\"results\":[...]}"
# }
```

### 3. Check Data Flow (5 minutes)

```bash
# 1. Verify S3 has raw data
aws s3 ls s3://twl-pipeline-raw-data-dev/raw/ --recursive --human-readable

# Expected: Files like raw/source=jsonplaceholder/date=2025-10-11/...

# 2. Verify SQS processed messages
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw queue_url) \
  --attribute-names ApproximateNumberOfMessages

# Expected: 0 (messages processed)

# 3. Verify DynamoDB has curated data
aws dynamodb scan \
  --table-name twl-pipeline-curated-dev \
  --limit 5 | jq '.Items | length'

# Expected: 5 records (or more)
```

### 4. Test API Endpoints (5 minutes)

```bash
# Get analytics
curl "$API_URL/analytics" | jq .

# Expected output:
# {
#   "summary": {
#     "total_records": 100,
#     "total_sources": 2,
#     ...
#   },
#   "by_source": {...},
#   "timeline": [...]
# }

# List records
curl "$API_URL/records?limit=3" | jq .

# Expected: Array of 3 records

# Get specific record (copy an ID from above)
RECORD_ID="jsonplaceholder-1-abc123"
curl "$API_URL/records/$RECORD_ID" | jq .

# Expected: Single record object
```

### 5. Launch Frontend (3 minutes)

```bash
cd frontend

# Install dependencies (first time only)
npm install

# Configure API URL
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.local

# Run dev server
npm run dev
```

Open browser: `http://localhost:3000`

**Expected**:
- Dashboard shows charts with data
- "Records" page shows list
- Click on record → see details

---

## Verification Checklist

### Infrastructure ✅
- [ ] S3 bucket created: `twl-pipeline-raw-data-dev`
- [ ] DynamoDB table created: `twl-pipeline-curated-dev`
- [ ] SQS queue created: `twl-pipeline-ingestion-queue-dev`
- [ ] 3 Lambda functions deployed (ingestion, processing, api)
- [ ] API Gateway created with 3 routes
- [ ] EventBridge rule created (5-minute schedule)

### Data Flow ✅
- [ ] Ingestion Lambda runs successfully
- [ ] Raw data appears in S3
- [ ] SQS messages published
- [ ] Processing Lambda triggered by SQS
- [ ] Curated data in DynamoDB
- [ ] No messages stuck in DLQ

### API ✅
- [ ] `GET /analytics` returns 200
- [ ] `GET /records` returns array
- [ ] `GET /records/{id}` returns single record
- [ ] CORS headers present

### Frontend ✅
- [ ] Dashboard loads without errors
- [ ] Charts display data
- [ ] Records list shows data
- [ ] Detail page works
- [ ] Filters work (source filter)

### Security ✅
- [ ] S3 bucket encrypted
- [ ] DynamoDB table encrypted
- [ ] IAM roles follow least privilege
- [ ] No hardcoded credentials

### Observability ✅
- [ ] CloudWatch Log Groups exist
- [ ] Logs contain structured JSON
- [ ] API Gateway access logs enabled

---

## Testing Scenarios

### Scenario 1: Happy Path (E2E)

**Objective**: Verify complete pipeline from ingestion to UI

**Steps**:
1. Trigger ingestion Lambda
2. Wait 30 seconds
3. Check DynamoDB for new records
4. Open frontend dashboard
5. Verify data displays correctly

**Expected Result**: Data flows through all stages successfully

**Duration**: ~2 minutes

---

### Scenario 2: Idempotency Test

**Objective**: Verify processing is idempotent (no duplicates)

**Steps**:
```bash
# 1. Count records before
BEFORE=$(aws dynamodb scan --table-name twl-pipeline-curated-dev --select COUNT | jq '.Count')
echo "Before: $BEFORE records"

# 2. Trigger ingestion twice
aws lambda invoke --function-name twl-pipeline-ingestion-dev response1.json
aws lambda invoke --function-name twl-pipeline-ingestion-dev response2.json

# 3. Wait for processing (30 seconds)
sleep 30

# 4. Count records after
AFTER=$(aws dynamodb scan --table-name twl-pipeline-curated-dev --select COUNT | jq '.Count')
echo "After: $AFTER records"

# 5. Verify NO duplicates
# Expected: AFTER = BEFORE + ~110 (not BEFORE + 220)
```

**Expected Result**: Records are not duplicated (idempotent upsert works)

---

### Scenario 3: Error Handling

**Objective**: Verify failed messages go to DLQ

**Steps**:
1. Manually send malformed message to SQS:
```bash
aws sqs send-message \
  --queue-url $(terraform output -raw queue_url) \
  --message-body '{"invalid": "message"}'
```

2. Wait for processing (Processing Lambda will fail)

3. Check DLQ:
```bash
# Get DLQ URL (from SQS console or Terraform)
DLQ_URL=$(aws sqs list-queues --queue-name-prefix "twl-pipeline-ingestion-queue-dev-dlq" | jq -r '.QueueUrls[0]')

aws sqs get-queue-attributes \
  --queue-url "$DLQ_URL" \
  --attribute-names ApproximateNumberOfMessages
```

**Expected Result**: Message appears in DLQ after 3 retries

---

### Scenario 4: Scalability Test

**Objective**: Verify system handles burst load

**Steps**:
```bash
# Trigger ingestion 10 times in parallel
for i in {1..10}; do
  aws lambda invoke --function-name twl-pipeline-ingestion-dev response-$i.json &
done
wait

# Wait for processing
sleep 60

# Check for errors in logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/twl-pipeline-processing-dev \
  --filter-pattern "ERROR" \
  --start-time $(date -d '5 minutes ago' +%s)000
```

**Expected Result**: No errors, all records processed

---

## Common Issues & Solutions

### Issue 1: Terraform Apply Fails

**Symptoms**:
```
Error: error creating Lambda Function: InvalidParameterValueException: 
The role defined for the function cannot be assumed by Lambda.
```

**Cause**: IAM role not yet propagated

**Solution**:
```bash
# Wait 10 seconds and retry
sleep 10
terraform apply
```

---

### Issue 2: API Returns 404

**Symptoms**:
```bash
curl $API_URL/records
# Returns: {"message":"Not Found"}
```

**Cause**: API Gateway stage not deployed or Lambda permission missing

**Solution**:
```bash
cd infra/envs/dev
terraform apply -target=module.api
```

---

### Issue 3: Frontend Shows "Failed to fetch"

**Symptoms**: Dashboard shows error: "Failed to fetch analytics"

**Possible Causes**:
1. **Wrong API URL**: Check `.env.local`
2. **CORS issue**: Check API Gateway CORS settings
3. **No data yet**: Ingestion not run

**Solutions**:
```bash
# 1. Verify API URL
cat frontend/.env.local
curl "$API_URL/analytics"

# 2. If API works but frontend fails, check browser console
# Look for CORS errors

# 3. Trigger ingestion if no data
aws lambda invoke --function-name twl-pipeline-ingestion-dev response.json
```

---

### Issue 4: No Data in DynamoDB

**Symptoms**: API returns empty array, frontend shows "No records"

**Possible Causes**:
1. Ingestion Lambda not triggered
2. Processing Lambda failed
3. SQS messages stuck

**Solutions**:
```bash
# 1. Check if ingestion ran
aws logs filter-log-events \
  --log-group-name /aws/lambda/twl-pipeline-ingestion-dev \
  --limit 10

# 2. Check processing Lambda logs for errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/twl-pipeline-processing-dev \
  --filter-pattern "ERROR"

# 3. Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw queue_url) \
  --attribute-names ApproximateNumberOfMessages

# 4. Manually trigger ingestion
aws lambda invoke --function-name twl-pipeline-ingestion-dev response.json
```

---

### Issue 5: Lambda Timeout

**Symptoms**:
```
Task timed out after 60.00 seconds
```

**Cause**: API call taking too long (rare with public APIs)

**Solution**:
```hcl
# In infra/modules/compute/main.tf
resource "aws_lambda_function" "ingestion" {
  timeout = 120  # Increase from 60 to 120
}
```

Then `terraform apply`

---

### Issue 6: S3 Access Denied

**Symptoms**:
```
AccessDenied: User is not authorized to perform: s3:PutObject
```

**Cause**: IAM policy doesn't grant S3 permissions

**Solution**: Check IAM role policy in `infra/modules/compute/main.tf`

```hcl
{
  Effect = "Allow"
  Action = ["s3:PutObject"]
  Resource = "${var.raw_bucket_arn}/*"  # Note the /*
}
```

---

## Useful Commands

### Logs

```bash
# Tail logs (Linux/Mac with AWS CLI v2)
aws logs tail /aws/lambda/twl-pipeline-ingestion-dev --follow

# Filter errors (works on all platforms)
aws logs filter-log-events \
  --log-group-name /aws/lambda/twl-pipeline-processing-dev \
  --filter-pattern "ERROR" \
  --start-time $(date -u -d '10 minutes ago' +%s)000

# Get last 20 log events
aws logs filter-log-events \
  --log-group-name /aws/lambda/twl-pipeline-api-dev \
  --limit 20
```

### DynamoDB

```bash
# Count total records
aws dynamodb scan \
  --table-name twl-pipeline-curated-dev \
  --select COUNT

# Query by source (using GSI)
aws dynamodb query \
  --table-name twl-pipeline-curated-dev \
  --index-name SourceIndex \
  --key-condition-expression "source = :source" \
  --expression-attribute-values '{":source":{"S":"jsonplaceholder"}}' \
  --limit 5

# Get specific record
aws dynamodb get-item \
  --table-name twl-pipeline-curated-dev \
  --key '{"id":{"S":"jsonplaceholder-1-abc123"}}'
```

### S3

```bash
# List all raw files
aws s3 ls s3://twl-pipeline-raw-data-dev/raw/ --recursive

# Count objects
aws s3 ls s3://twl-pipeline-raw-data-dev/raw/ --recursive | wc -l

# Download a raw file
aws s3 cp s3://twl-pipeline-raw-data-dev/raw/source=jsonplaceholder/date=2025-10-11/file.json - | jq .
```

### SQS

```bash
# Get queue URL
QUEUE_URL=$(aws sqs list-queues --queue-name-prefix twl-pipeline-ingestion | jq -r '.QueueUrls[0]')

# Get all queue attributes
aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names All | jq .

# Purge queue (delete all messages)
aws sqs purge-queue --queue-url "$QUEUE_URL"
```

### Lambda

```bash
# List all functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `twl-pipeline`)].FunctionName'

# Get function configuration
aws lambda get-function-configuration \
  --function-name twl-pipeline-ingestion-dev | jq .

# Update function code (after rebuilding zip)
aws lambda update-function-code \
  --function-name twl-pipeline-ingestion-dev \
  --zip-file fileb://lambda-ingestion.zip
```

---

## Performance Benchmarks

### Lambda Execution Times

| Lambda | Avg Duration | Max Memory | Cost per Invocation |
|--------|--------------|------------|---------------------|
| Ingestion | ~5s | ~80 MB | ~$0.000025 |
| Processing | ~10s | ~120 MB | ~$0.000050 |
| API | ~100ms | ~100 MB | ~$0.000002 |

### API Latency

| Endpoint | p50 | p99 | Max |
|----------|-----|-----|-----|
| `/analytics` | 150ms | 300ms | 500ms |
| `/records` | 100ms | 250ms | 400ms |
| `/records/{id}` | 80ms | 200ms | 350ms |

*(Measured with no data, cold start excluded)*

---

## Clean Up

### Remove All Resources

```bash
cd infra/envs/dev

# Destroy infrastructure
terraform destroy -auto-approve

# Verify S3 bucket is empty (Terraform won't delete non-empty buckets)
aws s3 rm s3://twl-pipeline-raw-data-dev --recursive

# Re-run destroy if bucket wasn't empty
terraform destroy -auto-approve
```

**Cost Savings**: Removing resources stops all AWS charges

---

## Demo Script (5 minutes)

**Presenter Script** for live demo:

1. **Show Architecture** (30s)
   - Open `docs/diagrams/architecture.png`
   - Explain: "Data flows from APIs → S3 → SQS → DynamoDB → API → UI"

2. **Trigger Ingestion** (1 min)
   ```bash
   aws lambda invoke --function-name twl-pipeline-ingestion-dev response.json
   cat response.json | jq .
   ```
   - Explain: "This Lambda runs every 5 minutes automatically"

3. **Show Data Flow** (1.5 min)
   ```bash
   # Raw data in S3
   aws s3 ls s3://twl-pipeline-raw-data-dev/raw/ --recursive | tail -5
   
   # Curated data in DynamoDB
   aws dynamodb scan --table-name twl-pipeline-curated-dev --limit 3 | jq .
   ```

4. **Test API** (1 min)
   ```bash
   curl "$API_URL/analytics" | jq '.summary'
   ```

5. **Show Frontend** (1 min)
   - Open `http://localhost:3000`
   - Show dashboard, records list, detail view

**Total**: ~5 minutes

---

## Next Steps

After successful demo:

1. **Add CloudWatch Dashboard** (see `docs/architecture.md`)
2. **Implement Unit Tests** (Jest for Lambdas)
3. **Add CI/CD** (`.github/workflows/deploy.yml`)
4. **Deploy to Production** (create `infra/envs/prod/`)
5. **Add Authentication** (Cognito or API Keys)

---

**Questions?** Check `README.md` or `docs/architecture.md` for more details.

