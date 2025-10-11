# TWL Pipeline - Architecture Diagram

## System Overview Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              DATA SOURCES (External)                             │
│  ┌──────────────────────┐            ┌──────────────────────────────────────┐  │
│  │  JSONPlaceholder API │            │       RandomUser API                 │  │
│  │  (Posts Data)        │            │       (User Profiles)                │  │
│  └──────────────────────┘            └──────────────────────────────────────┘  │
└──────────────────────────────┬─────────────────────────┬───────────────────────┘
                               │                         │
                               └─────────────────────────┘
                                         │
                    ┌────────────────────▼────────────────────┐
                    │   EventBridge Scheduled Rule            │
                    │   (cron: rate(5 minutes))               │
                    │   Triggers: Lambda Ingestion            │
                    └────────────────────┬────────────────────┘
                                         │
┌────────────────────────────────────────▼─────────────────────────────────────────┐
│                           INGESTION LAYER (Lambda)                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐    │
│  │  Lambda: twl-pipeline-ingestion-dev                                     │    │
│  │  • Runtime: Node.js 16                                                  │    │
│  │  • Timeout: 60s                                                         │    │
│  │  • Memory: 256 MB                                                       │    │
│  │  • Actions:                                                             │    │
│  │    1. Fetch data from APIs                                              │    │
│  │    2. Generate MD5 hash for fingerprinting                              │    │
│  │    3. Store raw JSON in S3 (partitioned by source/date)                │    │
│  │    4. Publish message to SQS with metadata                              │    │
│  │  • IAM: s3:PutObject, sqs:SendMessage, logs:*                           │    │
│  └─────────────────────────────────────────────────────────────────────────┘    │
└────────────────────────────────┬─────────────────────┬──────────────────────────┘
                                 │                     │
                    ┌────────────▼────────┐   ┌────────▼──────────┐
                    │                     │   │                   │
┌───────────────────▼──────────────┐      │   │  ┌────────────────▼───────────────┐
│   RAW DATA LAKE (S3)             │      │   │  │   MESSAGE QUEUE (SQS)          │
│  ┌───────────────────────────┐  │      │   │  │  ┌──────────────────────────┐  │
│  │  Bucket:                  │  │      │   │  │  │ Queue:                   │  │
│  │  twl-pipeline-raw-data    │  │      │   │  │  │ twl-pipeline-ingestion   │  │
│  │                           │  │      │   │  │  │                          │  │
│  │  Structure:               │  │      │   │  │  │ Message Format:          │  │
│  │  raw/                     │  │      │   │  │  │ {                        │  │
│  │    source=jsonplaceholder/│  │      │   │  │  │   source: "...",         │  │
│  │      date=2025-10-11/     │  │      │   │  │  │   s3Key: "...",          │  │
│  │        timestamp.json     │  │      │   │  │  │   hash: "...",           │  │
│  │    source=randomuser/     │  │      │   │  │  │   capturedAt: "..."      │  │
│  │      date=2025-10-11/     │  │      │   │  │  │ }                        │  │
│  │        timestamp.json     │  │      │   │  │  │                          │  │
│  │                           │  │      │   │  │  │ Config:                  │  │
│  │  Features:                │  │      │   │  │  │ • Batch Size: 10         │  │
│  │  • Encryption: AES-256    │  │      │   │  │  │ • Visibility: 60s        │  │
│  │  • Versioning: Enabled    │  │      │   │  │  │ • DLQ: Enabled (3 tries) │  │
│  │  • Immutable              │  │      │   │  │  └──────────────────────────┘  │
│  └───────────────────────────┘  │      │   │  └────────────────┬──────────────┘
└──────────────────────────────────┘      │   │                  │
                                          │   │                  │
                                          │   │  ┌───────────────▼────────────────┐
                                          │   │  │  DLQ (Dead Letter Queue)       │
                                          │   │  │  Failed messages after 3 tries │
                                          │   │  └────────────────────────────────┘
                                          │   │
                                          │   └─────────────────┐
                                          │                     │
┌─────────────────────────────────────────▼─────────────────────▼───────────────────┐
│                         PROCESSING LAYER (Lambda)                                 │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │  Lambda: twl-pipeline-processing-dev                                     │    │
│  │  • Runtime: Node.js 16                                                   │    │
│  │  • Timeout: 60s                                                          │    │
│  │  • Memory: 256 MB                                                        │    │
│  │  • Trigger: SQS messages (batch of 10)                                   │    │
│  │  • Actions:                                                              │    │
│  │    1. Read SQS message (get S3 key)                                      │    │
│  │    2. Fetch raw JSON from S3                                             │    │
│  │    3. Transform/normalize data (source-specific logic)                   │    │
│  │    4. Generate fingerprint (MD5 of individual records)                   │    │
│  │    5. Idempotent upsert to DynamoDB                                      │    │
│  │       • Uses ConditionExpression: attribute_not_exists(id)               │    │
│  │       • Prevents duplicates                                              │    │
│  │  • IAM: s3:GetObject, dynamodb:PutItem, sqs:*, logs:*                    │    │
│  └──────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          │
┌─────────────────────────────────────────▼────────────────────────────────────────┐
│                      CURATED DATA STORE (DynamoDB)                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  Table: twl-pipeline-curated-dev                                         │   │
│  │                                                                           │   │
│  │  Key Schema:                                                             │   │
│  │  • Partition Key: id (String) - "source-originalId-hash"                 │   │
│  │                                                                           │   │
│  │  Global Secondary Index (GSI):                                           │   │
│  │  • Name: SourceIndex                                                     │   │
│  │  • Keys: source (PK), captured_at (SK)                                   │   │
│  │  • Use: Query all records from a specific source                         │   │
│  │                                                                           │   │
│  │  Attributes (example):                                                   │   │
│  │  {                                                                       │   │
│  │    id: "jsonplaceholder-1-abc123",                                       │   │
│  │    source: "jsonplaceholder",                                            │   │
│  │    captured_at: "2025-10-11T10:30:00Z",                                  │   │
│  │    fingerprint: "md5-hash",                                              │   │
│  │    raw_s3_key: "raw/source=jsonplaceholder/...",                         │   │
│  │    title: "Post title",                                                  │   │
│  │    body: "Post content",                                                 │   │
│  │    processed_at: "2025-10-11T10:31:00Z"                                  │   │
│  │  }                                                                       │   │
│  │                                                                           │   │
│  │  Features:                                                               │   │
│  │  • Billing: On-demand (auto-scaling)                                     │   │
│  │  • Encryption: AWS-managed keys                                          │   │
│  │  • Backup: Point-in-time recovery (optional)                             │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          │
┌─────────────────────────────────────────▼────────────────────────────────────────┐
│                              API LAYER                                            │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  API Gateway (HTTP API)                                                  │   │
│  │  • Type: HTTP API (simpler, cheaper than REST API)                       │   │
│  │  • Stage: dev (auto-deploy enabled)                                      │   │
│  │  • CORS: Enabled for all origins                                         │   │
│  │  • Logging: CloudWatch access logs (JSON format)                         │   │
│  │                                                                           │   │
│  │  Routes:                                                                 │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │   │
│  │  │  GET /records                                                   │    │   │
│  │  │  • Query params: ?limit=20&source=jsonplaceholder&lastKey=...   │    │   │
│  │  │  • Returns: { records: [...], count: N, lastKey: "..." }        │    │   │
│  │  └─────────────────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │   │
│  │  │  GET /records/{id}                                              │    │   │
│  │  │  • Returns: Single record object or 404                         │    │   │
│  │  └─────────────────────────────────────────────────────────────────┘    │   │
│  │  ┌─────────────────────────────────────────────────────────────────┐    │   │
│  │  │  GET /analytics                                                 │    │   │
│  │  │  • Returns: { summary: {...}, by_source: {...}, timeline: [...] }│   │   │
│  │  └─────────────────────────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────┬───────────────────────────────────┘   │
│                                         │                                        │
│  ┌──────────────────────────────────────▼───────────────────────────────────┐   │
│  │  Lambda: twl-pipeline-api-dev                                           │   │
│  │  • Runtime: Node.js 16                                                  │   │
│  │  • Timeout: 30s                                                         │   │
│  │  • Memory: 512 MB                                                       │   │
│  │  • Integration: Lambda Proxy (API Gateway → Lambda)                     │   │
│  │  • Actions:                                                             │   │
│  │    - Route requests to appropriate handler                              │   │
│  │    - Query DynamoDB (Scan, Query, GetItem)                              │   │
│  │    - Return JSON response with CORS headers                             │   │
│  │  • IAM: dynamodb:GetItem, dynamodb:Query, dynamodb:Scan, logs:*         │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────┬────────────────────────────────────────┘
                                          │
                                          │ HTTPS/TLS
                                          │
┌─────────────────────────────────────────▼────────────────────────────────────────┐
│                        PRESENTATION LAYER (Frontend)                              │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  Next.js 14 Web Application                                              │   │
│  │  • Framework: Next.js (App Router)                                       │   │
│  │  • Language: TypeScript                                                  │   │
│  │  • Styling: Tailwind CSS                                                 │   │
│  │  • Charts: Recharts                                                      │   │
│  │                                                                           │   │
│  │  Pages:                                                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Dashboard (/)                                                 │     │   │
│  │  │  • Summary cards (total records, sources, date range)          │     │   │
│  │  │  • Bar chart: Records by source                                │     │   │
│  │  │  • Line chart: Ingestion timeline                              │     │   │
│  │  │  • Data: Fetched from GET /analytics                           │     │   │
│  │  └────────────────────────────────────────────────────────────────┘     │   │
│  │  ┌────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Records List (/records)                                       │     │   │
│  │  │  • Table view with columns: ID, Source, Data, Date             │     │   │
│  │  │  • Filter by source (dropdown)                                 │     │   │
│  │  │  • Pagination (via lastKey)                                    │     │   │
│  │  │  • Click row → navigate to detail                              │     │   │
│  │  │  • Data: Fetched from GET /records?source=...                  │     │   │
│  │  └────────────────────────────────────────────────────────────────┘     │   │
│  │  ┌────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Record Detail (/records/[id])                                 │     │   │
│  │  │  • Core information (ID, source, dates, fingerprint)           │     │   │
│  │  │  • Data fields (title, name, email, etc.)                      │     │   │
│  │  │  • Raw JSON viewer                                             │     │   │
│  │  │  • Data: Fetched from GET /records/{id}                        │     │   │
│  │  └────────────────────────────────────────────────────────────────┘     │   │
│  │                                                                           │   │
│  │  Environment:                                                            │   │
│  │  • NEXT_PUBLIC_API_URL: API Gateway endpoint                             │   │
│  │  • Deployment: Local dev (npm run dev) or Vercel                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────┐
│                            OBSERVABILITY LAYER                                   │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  CloudWatch Logs                                                         │   │
│  │  • /aws/lambda/twl-pipeline-ingestion-dev                                │   │
│  │  • /aws/lambda/twl-pipeline-processing-dev                               │   │
│  │  • /aws/lambda/twl-pipeline-api-dev                                      │   │
│  │  • /aws/apigateway/twl-pipeline-dev                                      │   │
│  │  • Format: Structured JSON logs                                          │   │
│  │  • Retention: 7 days                                                     │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  CloudWatch Metrics (Future)                                             │   │
│  │  • RecordsIngested, RecordsProcessed, APILatency                         │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  CloudWatch Alarms (Future)                                              │   │
│  │  • Error Rate, Queue Depth, Lambda Throttles                             │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────────────────────┐
│                          INFRASTRUCTURE AS CODE                                  │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │  Terraform                                                               │   │
│  │                                                                           │   │
│  │  Modules:                                                                │   │
│  │  • storage:   S3 bucket + DynamoDB table                                 │   │
│  │  • messaging: SQS queue + DLQ                                            │   │
│  │  • compute:   Ingestion & Processing Lambdas + EventBridge               │   │
│  │  • api:       API Gateway + API Lambda                                   │   │
│  │                                                                           │   │
│  │  Environment: dev (extendable to prod)                                   │   │
│  │  State: S3 backend with DynamoDB locking                                 │   │
│  │  Security: IAM roles, encryption, least privilege                        │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

```
[1] EventBridge (every 5 min)
      │
      ▼
[2] Ingestion Lambda (fetch APIs)
      │
      ├─────► [3] S3 (store raw JSON)
      │
      └─────► [4] SQS (publish message)
              │
              ▼
          [5] Processing Lambda (SQS trigger)
              │
              ├─────► [6] S3 (read raw JSON)
              │
              └─────► [7] DynamoDB (upsert curated)
                      │
                      ▼
                  [8] API Lambda (query)
                      │
                      ▼
                  [9] API Gateway (HTTP)
                      │
                      ▼
                 [10] Next.js Frontend (display)
```

## Security Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  IAM Roles & Policies (Least Privilege)                      │
│                                                               │
│  Ingestion Lambda:                                           │
│  • s3:PutObject (raw bucket only)                            │
│  • sqs:SendMessage (ingestion queue only)                    │
│                                                               │
│  Processing Lambda:                                          │
│  • s3:GetObject (raw bucket only)                            │
│  • dynamodb:PutItem (curated table only)                     │
│  • sqs:ReceiveMessage, DeleteMessage (ingestion queue)       │
│                                                               │
│  API Lambda:                                                 │
│  • dynamodb:GetItem, Query, Scan (curated table + GSI)       │
│                                                               │
│  All Lambdas:                                                │
│  • logs:CreateLogGroup, PutLogEvents (own log group)         │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│  Encryption                                                   │
│                                                               │
│  At Rest:                                                    │
│  • S3: AES-256 (AWS-managed)                                 │
│  • DynamoDB: AWS-managed keys                                │
│  • SQS: AWS-managed                                          │
│                                                               │
│  In Transit:                                                 │
│  • All services: TLS 1.2+                                    │
│  • API Gateway: HTTPS only                                   │
└──────────────────────────────────────────────────────────────┘
```

## Scalability Model

```
Load: 1 request/sec
  ├─► Ingestion Lambda: 1 concurrent execution
  ├─► SQS: 1-10 messages/sec
  ├─► Processing Lambda: 1-2 concurrent executions
  └─► DynamoDB: 1-5 WCU, 1-5 RCU (on-demand scales automatically)

Load: 100 requests/sec
  ├─► Ingestion Lambda: 100 concurrent executions
  ├─► SQS: 100-1000 messages/sec
  ├─► Processing Lambda: 10-20 concurrent executions
  └─► DynamoDB: Auto-scales to handle load

Limits:
  • Lambda: 1000 concurrent executions (account limit)
  • SQS: Unlimited throughput
  • DynamoDB: On-demand scales to 40K RCU / 40K WCU
  • API Gateway: 10,000 RPS (default account limit)
```

---

## Key Design Principles

1. **Serverless**: Zero infrastructure management
2. **Event-Driven**: Decoupled components via SQS
3. **Idempotent**: Safe to retry operations
4. **Immutable**: Raw data never modified
5. **Observable**: Structured logs throughout
6. **Secure**: Encryption + least-privilege IAM
7. **Cost-Efficient**: Pay-per-use, no idle resources
8. **Scalable**: Auto-scaling at every layer

---

**For interactive diagram**: Use tools like Draw.io, Lucidchart, or Excalidraw to create a visual version based on this layout.

