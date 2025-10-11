# Architecture & Design Decisions

## Table of Contents
- [System Overview](#system-overview)
- [Architecture Diagram](#architecture-diagram)
- [Component Details](#component-details)
- [Data Flow](#data-flow)
- [Security Model](#security-model)
- [Design Decisions & Trade-offs](#design-decisions--trade-offs)
- [Scalability & Performance](#scalability--performance)
- [Observability Strategy](#observability-strategy)

---

## System Overview

TWL Data Pipeline is a serverless, event-driven data ingestion and processing system built on AWS. It follows a **tiered data lake architecture**:

```
RAW LAYER (S3)  →  PROCESSING (Lambda + SQS)  →  CURATED LAYER (DynamoDB)  →  API/UI
```

### Key Characteristics
- **Serverless**: Zero server management, auto-scaling
- **Event-driven**: EventBridge + SQS for decoupled components
- **Idempotent**: Safe to retry operations without side effects
- **Scalable**: Handles variable load automatically
- **Cost-efficient**: Pay-per-use model

---

## Architecture Diagram

```
┌────────────────────┐
│   Data Sources     │
│  - JSONPlaceholder │
│  - RandomUser API  │
└─────────┬──────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│  EventBridge Rule (cron: every 5 minutes)                │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │   INGESTION LAMBDA            │
         │  - Fetch from APIs            │
         │  - Store raw in S3            │
         │  - Publish to SQS             │
         └───────┬──────────────┬────────┘
                 │              │
       ┌─────────▼────┐    ┌────▼────────┐
       │   S3 Bucket  │    │  SQS Queue  │
       │   (Raw Data) │    │             │
       │  Encrypted   │    │  + DLQ      │
       └──────────────┘    └────┬────────┘
                                │
                                ▼
                   ┌────────────────────────────┐
                   │   PROCESSING LAMBDA        │
                   │  - Transform data          │
                   │  - Deduplicate (MD5)       │
                   │  - Idempotent upsert       │
                   └────────────┬───────────────┘
                                │
                                ▼
                     ┌──────────────────────┐
                     │  DynamoDB Table      │
                     │  (Curated Data)      │
                     │  - GSI: SourceIndex  │
                     │  - Encrypted         │
                     └──────────┬───────────┘
                                │
                                ▼
                  ┌─────────────────────────────┐
                  │  API LAMBDA + API GATEWAY   │
                  │  - GET /records             │
                  │  - GET /records/{id}        │
                  │  - GET /analytics           │
                  └────────────┬────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   Next.js Frontend   │
                    │  - Dashboard         │
                    │  - Records Browser   │
                    │  - Analytics Charts  │
                    └──────────────────────┘

         Observability: CloudWatch Logs + Metrics
```

---

## Component Details

### 1. Ingestion Service (Lambda)

**Purpose**: Fetch data from external sources and persist raw data.

**Triggers**: EventBridge Rule (every 5 minutes)

**Responsibilities**:
- Fetch data from 2 public APIs (JSONPlaceholder, RandomUser)
- Generate MD5 hash for fingerprinting
- Store raw JSON in S3 with partitioned keys: `raw/source={name}/date={YYYY-MM-DD}/{timestamp}.json`
- Publish SQS message with metadata (S3 key, hash, source)
- Structured logging (JSON format)

**IAM Permissions**:
- `s3:PutObject` on raw bucket
- `sqs:SendMessage` on ingestion queue
- `logs:CreateLogGroup`, `logs:PutLogEvents`

**Key Code**:
```javascript
// Idempotent key generation
const hash = crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');
const s3Key = `raw/source=${source.name}/date=${date}/${timestamp}-${hash}.json`;
```

---

### 2. Processing Service (Lambda)

**Purpose**: Transform raw data into curated, normalized records.

**Triggers**: SQS messages from ingestion queue

**Responsibilities**:
- Read raw data from S3 (using S3 key from SQS message)
- Transform/normalize data (source-specific logic)
- Generate fingerprint (MD5 of individual records)
- **Idempotent upsert** to DynamoDB (using `ConditionExpression`)
- Deduplication (prevent duplicate inserts)

**IAM Permissions**:
- `s3:GetObject` on raw bucket
- `dynamodb:PutItem`, `dynamodb:GetItem` on curated table
- `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`
- `logs:CreateLogGroup`, `logs:PutLogEvents`

**Key Code**:
```javascript
// Idempotent upsert - will fail silently if record already exists
await dynamodb.put({
  TableName: TABLE_NAME,
  Item: item,
  ConditionExpression: 'attribute_not_exists(id)'  // Only insert if new
}).promise();
```

**Error Handling**:
- Failed messages go to **Dead Letter Queue (DLQ)** after 3 retries
- Logs all errors with structured context

---

### 3. Storage Layer

#### S3 (Raw Data Lake)
- **Bucket**: `twl-pipeline-raw-data-{env}`
- **Encryption**: AES-256 (server-side)
- **Versioning**: Enabled
- **Partitioning**: `raw/source={name}/date={YYYY-MM-DD}/`
- **Lifecycle**: Immutable (no deletes)

#### DynamoDB (Curated Data)
- **Table**: `twl-pipeline-curated-{env}`
- **Billing**: Pay-per-request (auto-scaling)
- **Key Schema**: 
  - **Partition Key**: `id` (String) - unique record identifier
  - **GSI**: `SourceIndex` - Query by `source` + `captured_at`
- **Attributes**:
  ```json
  {
    "id": "jsonplaceholder-1-abc123",
    "source": "jsonplaceholder",
    "captured_at": "2025-10-11T10:30:00Z",
    "fingerprint": "md5-hash",
    "raw_s3_key": "raw/source=jsonplaceholder/...",
    "title": "Post title",
    "body": "Post content",
    "processed_at": "2025-10-11T10:31:00Z"
  }
  ```
- **Encryption**: AWS-managed keys

---

### 4. Messaging (SQS)

**Queue**: `twl-pipeline-ingestion-queue-{env}`

**Configuration**:
- **Visibility Timeout**: 60 seconds (matches Lambda timeout)
- **Batch Size**: 10 messages per Lambda invocation
- **DLQ**: Enabled after 3 retries
- **Encryption**: AWS-managed

**Message Format**:
```json
{
  "source": "jsonplaceholder",
  "type": "posts",
  "s3Bucket": "twl-pipeline-raw-data-dev",
  "s3Key": "raw/source=jsonplaceholder/date=2025-10-11/timestamp.json",
  "capturedAt": "2025-10-11T10:30:00Z",
  "hash": "abc123",
  "recordCount": 100
}
```

---

### 5. API Service (Lambda + API Gateway)

**API Gateway**: HTTP API (not REST API for simplicity)

**Endpoints**:
1. **GET /records**
   - Query params: `?limit=20&source=jsonplaceholder&lastKey=base64`
   - Pagination via `LastEvaluatedKey` (base64 encoded)
   - Filtering by source using GSI

2. **GET /records/{id}**
   - Get single record by ID
   - Returns 404 if not found

3. **GET /analytics**
   - Aggregated metrics: total records, by source, by date
   - Timeline for last 7 days

**CORS**: Enabled for all origins (frontend)

**Logging**: CloudWatch access logs (JSON format)

**IAM Permissions**:
- `dynamodb:GetItem`, `dynamodb:Query`, `dynamodb:Scan`

---

### 6. Frontend (Next.js 14)

**Tech Stack**:
- Next.js 14 (App Router)
- TypeScript
- Tailwind CSS
- Recharts (data visualization)

**Pages**:
1. **Dashboard** (`/`)
   - Summary cards (total records, sources, date range)
   - Bar chart: Records by source
   - Line chart: Ingestion timeline

2. **Records List** (`/records`)
   - Table view with pagination
   - Filter by source
   - Click to view details

3. **Record Detail** (`/records/[id]`)
   - Complete record information
   - Raw JSON viewer

**API Integration**:
- Environment variable: `NEXT_PUBLIC_API_URL`
- Client-side fetching (using `fetch` API)
- Error handling with user-friendly messages

---

## Data Flow

### End-to-End Flow (Happy Path)

1. **T=0:00**: EventBridge triggers Ingestion Lambda
2. **T=0:05**: Lambda fetches data from 2 APIs (parallel)
3. **T=0:10**: Raw data saved to S3 (2 files)
4. **T=0:11**: 2 SQS messages published
5. **T=0:12**: Processing Lambda triggered (by SQS)
6. **T=0:15**: Data transformed and saved to DynamoDB (100 records)
7. **T=0:20**: User opens frontend
8. **T=0:21**: Frontend calls `/analytics` API
9. **T=0:22**: API Lambda queries DynamoDB
10. **T=0:23**: Dashboard displays charts with fresh data

**Total Latency**: ~23 seconds from ingestion to visualization

---

## Security Model

### IAM Least-Privilege

Each Lambda has a dedicated IAM role with **minimum required permissions**:

```hcl
# Example: Processing Lambda
{
  "Effect": "Allow",
  "Action": ["dynamodb:PutItem", "dynamodb:GetItem"],
  "Resource": "arn:aws:dynamodb:*:*:table/twl-pipeline-curated-dev"
}
```

No wildcards (`*`) in resource ARNs.

### Encryption

| Component | Encryption at Rest | Encryption in Transit |
|-----------|--------------------|-----------------------|
| S3 | AES-256 | TLS 1.2 |
| DynamoDB | AWS-managed | TLS 1.2 |
| SQS | AWS-managed | TLS 1.2 |
| API Gateway | N/A | TLS 1.2 |

### Secrets Management

**Current**: No secrets (public APIs)  
**Future**: Use AWS Secrets Manager for API keys

### Network Security

**No VPC** (intentional simplification):
- All services use managed AWS endpoints
- TLS encryption in transit
- Trade-off: Faster setup, no NAT Gateway costs

---

## Design Decisions & Trade-offs

### 1. Serverless (Lambda) vs Containers (ECS/Fargate)

| Decision | Serverless (Lambda) |
|----------|---------------------|
| **Pros** | No server management, auto-scaling, pay-per-use, faster deployment |
| **Cons** | Cold starts (~1s), 15-min execution limit, vendor lock-in |
| **Why** | Perfect for event-driven, short-lived tasks. No need for long-running processes |

### 2. DynamoDB vs RDS (PostgreSQL)

| Decision | DynamoDB |
|----------|----------|
| **Pros** | Serverless, auto-scaling, fast key-value access, no schema migrations, better for Terraform |
| **Cons** | Limited query flexibility, more expensive for full table scans |
| **Why** | Curated data has simple access patterns (get by ID, query by source). No complex JOINs needed |

### 3. SQS vs Kafka/MSK

| Decision | SQS |
|----------|-----|
| **Pros** | Fully managed, simple setup, DLQ built-in, cheap for low volume |
| **Cons** | Less throughput, no replay from offset, eventual consistency |
| **Why** | 2-3 sources with low volume. Kafka would be overkill and expensive |

### 4. HTTP API vs REST API (API Gateway)

| Decision | HTTP API |
|----------|----------|
| **Pros** | Simpler, faster, cheaper, better for Lambda proxy integration |
| **Cons** | Less features (no request validation, no API keys) |
| **Why** | We don't need advanced features. Focus on simplicity |

### 5. Single Environment (dev only)

| Decision | Single Environment |
|----------|---------------------|
| **Pros** | Faster development, lower cost, simpler to demo |
| **Cons** | Not production-ready multi-env setup |
| **Why** | Modules are parameterized. Adding `prod` is just duplicating `envs/prod/` |

### 6. No VPC

| Decision | No VPC |
|----------|--------|
| **Pros** | Simpler setup, no NAT Gateway costs ($45/month), faster Lambda cold starts |
| **Cons** | Less network isolation |
| **Why** | All AWS services use managed endpoints with TLS. No sensitive data |

---

## Scalability & Performance

### Auto-Scaling

| Component | Scaling Mechanism | Limit |
|-----------|-------------------|-------|
| Ingestion Lambda | Concurrent executions | 1000 (default account limit) |
| Processing Lambda | SQS batch size (10) | 1000 concurrent |
| DynamoDB | On-demand | Unlimited |
| API Lambda | Concurrent executions | 1000 |
| API Gateway | Managed | 10,000 RPS (default) |

### Performance Optimizations

1. **S3 Partitioning**: Date-based partitions for faster queries
2. **DynamoDB GSI**: Query by source without scanning entire table
3. **SQS Batching**: Process 10 messages per Lambda invocation
4. **Lambda Memory**: 256 MB (ingestion/processing), 512 MB (API) - balanced cost/performance

### Idempotency

**Processing Lambda** uses conditional writes:
```javascript
ConditionExpression: 'attribute_not_exists(id)'
```

- If record exists, operation fails silently (no error thrown)
- Safe to replay messages from DLQ

### Fault Tolerance

1. **Retry Logic**: SQS retries failed messages up to 3 times
2. **DLQ**: Failed messages go to Dead Letter Queue for manual inspection
3. **Lambda Timeouts**: Set to 60 seconds (sufficient for API calls)
4. **S3 Versioning**: Protects against accidental deletes

---

## Observability Strategy

### Logging

**Structured Logging** (JSON format):
```json
{
  "message": "Processing record",
  "source": "jsonplaceholder",
  "recordId": "abc123",
  "timestamp": "2025-10-11T10:30:00Z"
}
```

**Log Groups**:
- `/aws/lambda/twl-pipeline-ingestion-dev`
- `/aws/lambda/twl-pipeline-processing-dev`
- `/aws/lambda/twl-pipeline-api-dev`
- `/aws/apigateway/twl-pipeline-dev`

**Retention**: 7 days (configurable)

### Metrics (Future)

**Custom CloudWatch Metrics**:
- `RecordsIngested` (count, by source)
- `RecordsProcessed` (count, by source)
- `ProcessingErrors` (count)
- `APILatency` (milliseconds, p50/p99)

### Alarms (Future)

- **Error Rate** > 5% (1 minute)
- **Queue Depth** > 1000 messages
- **Lambda Throttles** > 10 (1 minute)

### Tracing (Future)

**AWS X-Ray** for distributed tracing:
- Track request through Ingestion → SQS → Processing → DynamoDB
- Identify bottlenecks

---

## Cost Estimation (Monthly)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda (Ingestion) | 8,640 invocations/month @ 5s each | ~$0.20 |
| Lambda (Processing) | 8,640 invocations/month @ 10s each | ~$0.40 |
| Lambda (API) | 10,000 requests/month @ 100ms | ~$0.02 |
| S3 | 1 GB storage + 10K PUT | ~$0.05 |
| DynamoDB | 1M reads + 100K writes | ~$0.50 |
| SQS | 10K messages | ~$0.01 |
| API Gateway | 10K requests | ~$0.01 |
| **Total** | | **~$1.19/month** |

*(Assumes low volume for demo purposes)*

---

## Future Improvements

1. **CloudWatch Dashboard**: Unified view of all metrics
2. **CloudWatch Alarms**: Proactive monitoring
3. **Unit Tests**: Jest for Lambdas
4. **Integration Tests**: E2E happy path
5. **Multi-environment**: dev, staging, prod
6. **Authentication**: Cognito for API
7. **Data Retention**: S3 Lifecycle policies (archive after 90 days)
8. **Cost Optimization**: Reserved capacity for DynamoDB
9. **Real Scraping**: Puppeteer/Playwright for dynamic websites
10. **AI/ML**: Data enrichment, anomaly detection

---

## Conclusion

This architecture prioritizes **simplicity**, **scalability**, and **cost-efficiency** while demonstrating production-ready practices:

- ✅ Serverless (zero server management)
- ✅ Event-driven (decoupled components)
- ✅ Idempotent (safe retries)
- ✅ Encrypted (at rest and in transit)
- ✅ Observable (structured logs)
- ✅ Infrastructure as Code (Terraform)

The design is **pragmatic** - avoiding over-engineering while keeping the door open for future enhancements.

