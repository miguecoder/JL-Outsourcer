# TWL Data Pipeline - Technical Challenge

Production-ready proof of concept demonstrating an automated data pipeline: **ingest → process → store → expose**.

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)
[![Next.js](https://img.shields.io/badge/Frontend-Next.js-black)](https://nextjs.org/)

## 🎯 Overview

This project simulates a multi-source data ingestion pipeline with automated processing, storage in a tiered data lake architecture (raw → curated), and real-time visualization through a web interface.

### Architecture

```
Data Sources → Ingestion (Lambda) → S3 (Raw) → SQS → Processing (Lambda) → DynamoDB (Curated) → API (Lambda + API Gateway) → Web UI (Next.js)
```

See [docs/architecture.md](docs/architecture.md) for detailed architecture and design decisions.

## 🚀 Quick Start

### Prerequisites

- AWS Account with credentials configured
- Terraform >= 1.0
- Node.js >= 16
- Python 3
- AWS CLI v2
- Make

### **Fastest Way** (Using Makefile)

```bash
make setup          # Complete setup (infra + dependencies)
make frontend-dev   # Run frontend
```

Open: **http://localhost:3000**

**For detailed commands**, see [QUICK_START.md](QUICK_START.md) or run `make help`.

---

### Alternative: Manual Setup

<details>
<summary>Click to expand manual setup steps</summary>

#### 1. Deploy Infrastructure

```bash
# Navigate to infra directory
cd infra/envs/dev

# Initialize Terraform
terraform init

# Deploy (review plan first)
terraform plan
terraform apply

# Save API URL for frontend
export API_URL=$(terraform output -raw api_url)
echo $API_URL
```

#### 2. Run Frontend

```bash
cd frontend

# Install dependencies
npm install

# Configure API URL
echo "NEXT_PUBLIC_API_URL=$API_URL" > .env.local

# Run development server
npm run dev
```

Visit `http://localhost:3000` to see the dashboard.

</details>

---

### Verify Pipeline

The ingestion Lambda runs **automatically every 5 minutes**. 

To verify or test manually:
```bash
make check           # Health check of entire pipeline
make test-ingestion  # Manually trigger ingestion
make test-api        # Test API endpoints
make logs-api        # View logs
```

See [QUICK_START.md](QUICK_START.md) for more commands.

## 📁 Project Structure

```
├── services/              # Lambda functions (Node.js)
│   ├── ingestion/        # Fetches data from APIs → S3 + SQS
│   ├── processing/       # Processes SQS messages → DynamoDB
│   └── api/              # REST API for frontend
├── infra/                # Terraform Infrastructure as Code
│   ├── modules/          # Reusable Terraform modules
│   │   ├── storage/      # S3 + DynamoDB
│   │   ├── messaging/    # SQS queues
│   │   ├── compute/      # Ingestion & Processing Lambdas
│   │   └── api/          # API Gateway + API Lambda
│   └── envs/dev/         # Development environment
├── frontend/             # Next.js web application
├── docs/                 # Documentation & diagrams
└── .github/workflows/    # CI/CD pipelines
```

## 🏗️ Infrastructure Components

### Data Sources (Simulated)
- **JSONPlaceholder API**: Posts data (https://jsonplaceholder.typicode.com)
- **RandomUser API**: User profiles (https://randomuser.me)

### AWS Services

| Service | Purpose | Security |
|---------|---------|----------|
| **Lambda** | Serverless compute (3 functions) | IAM roles with least privilege |
| **S3** | Raw data storage (partitioned by source/date) | Encryption at rest (AES-256), versioning enabled |
| **DynamoDB** | Curated data storage | Encryption at rest, GSI for queries |
| **SQS** | Message queue for async processing | DLQ for failed messages |
| **API Gateway** | HTTP API for frontend | CORS enabled, CloudWatch logging |
| **CloudWatch** | Logs, metrics, alarms | Structured JSON logs |
| **EventBridge** | Scheduled ingestion (every 5 min) | Automated triggers |

### Infrastructure as Code (Terraform)

- **Modular design**: Reusable modules for different components
- **Remote state**: S3 backend with DynamoDB locking
- **Environment separation**: `dev` environment (extendable to `prod`)
- **Security baseline**: 
  - Least-privilege IAM policies per Lambda
  - Secrets Manager for API keys (future)
  - Encryption at rest and in transit

## 🔄 Data Flow

1. **Ingestion** (Every 30 minutes via EventBridge)
   - Lambda fetches data from 2 public APIs
   - Saves raw JSON to S3: `raw/source={name}/date={YYYY-MM-DD}/{timestamp}.json`
   - Publishes message to SQS with metadata

2. **Processing** (Triggered by SQS)
   - Lambda consumes messages from queue
   - Fetches raw data from S3
   - Transforms and normalizes data
   - **Idempotent upsert** to DynamoDB (using `ConditionExpression`)
   - Deduplication via MD5 fingerprint

3. **API** (HTTP REST via API Gateway)
   - `GET /records` - List records (with pagination & filtering)
   - `GET /records/{id}` - Get single record
   - `GET /analytics` - Aggregated metrics

4. **Frontend** (Next.js)
   - Dashboard with charts (Bar chart by source, Line chart timeline)
   - Records browser with filters
   - Detail view for individual records

## 📊 Key Features

### ✅ Functional
- [x] Multi-source data ingestion
- [x] Raw data persistence (S3, partitioned)
- [x] Asynchronous processing pipeline (SQS)
- [x] Idempotent processing (no duplicates)
- [x] Curated data storage (DynamoDB with GSI)
- [x] REST API with 3 endpoints
- [x] Web UI with dashboard & analytics

### 🔒 Security
- [x] IAM least-privilege policies per Lambda
- [x] S3 bucket encryption at rest (AES-256)
- [x] DynamoDB encryption at rest
- [x] API Gateway with CORS
- [x] Structured logging (JSON format)

### 📈 Scalability & Resilience
- [x] Serverless auto-scaling (Lambda)
- [x] DynamoDB on-demand billing (auto-scaling)
- [x] SQS with Dead Letter Queue (DLQ)
- [x] Idempotency for safe retries
- [x] S3 versioning enabled

### 👀 Observability
- [x] CloudWatch Logs (all Lambdas + API Gateway)
- [x] Structured logging (JSON with context)
- [x] API Gateway access logs
- [ ] CloudWatch Dashboard (TODO)
- [ ] Custom metrics (TODO)
- [ ] Alarms (TODO)

## 🧪 Testing

### Manual Testing

```bash
# Test ingestion Lambda
aws lambda invoke --function-name twl-pipeline-ingestion-dev response.json

# Check S3 for raw data
aws s3 ls s3://twl-pipeline-raw-data-dev/raw/ --recursive

# Check DynamoDB for processed data
aws dynamodb scan --table-name twl-pipeline-curated-dev --limit 5

# Test API endpoints
curl $API_URL/analytics | jq .
curl $API_URL/records | jq .
```

### Unit Tests
```bash
cd services/ingestion
npm test  # TODO: Implement tests
```

## 🚧 CI/CD Pipeline

### GitHub Actions Workflow

Located in `.github/workflows/deploy.yml`:

- **On Pull Request**: Lint, validate Terraform, run tests
- **On Push to Main**: Deploy to dev environment
- **Manual Approval**: Required for production deploys

```bash
# Workflow steps:
1. Checkout code
2. Configure AWS credentials
3. Terraform fmt & validate
4. Run unit tests
5. Terraform plan (with approval)
6. Deploy Lambdas (zip + upload)
7. Terraform apply
8. Deploy frontend (Vercel/Amplify)
```

## 📖 Documentation

- [Architecture & Design Decisions](docs/architecture.md)
- [Demo & Testing Notes](docs/demo-notes.md)
- [Architecture Diagram](docs/diagrams/architecture.png)

## 🎯 Trade-offs & Decisions

### Why Serverless (Lambda)?
- **Pro**: Zero infrastructure management, auto-scaling, pay-per-use
- **Con**: Cold starts, 15-min execution limit
- **Decision**: Perfect for this pipeline (short-lived, event-driven)

### Why DynamoDB over RDS?
- **Pro**: Serverless, auto-scaling, fast key-value access, no schema migrations
- **Con**: Limited query flexibility, more expensive for scans
- **Decision**: Curated data has simple access patterns (get by ID, query by source)

### Why SQS over Kafka?
- **Pro**: Fully managed, simple setup, DLQ built-in
- **Con**: Less throughput than Kafka, no replay from offset
- **Decision**: SQS is sufficient for 2-3 sources; Kafka would be overkill

### Single Environment (dev only)
- **Trade-off**: Saved time by not implementing `prod` environment
- **Production-ready**: Modules are parameterized and ready to scale

## 🛠️ Maintenance & Operations

### View Logs
```bash
# Ingestion Lambda
aws logs filter-log-events --log-group-name /aws/lambda/twl-pipeline-ingestion-dev

# Processing Lambda
aws logs filter-log-events --log-group-name /aws/lambda/twl-pipeline-processing-dev

# API Lambda
aws logs filter-log-events --log-group-name /aws/lambda/twl-pipeline-api-dev
```

### Monitor Queue
```bash
aws sqs get-queue-attributes \
  --queue-url $(terraform output -raw queue_url) \
  --attribute-names All
```

### Troubleshooting

See [docs/demo-notes.md](docs/demo-notes.md) for common issues and solutions.

## 🌟 Future Enhancements

- [ ] CloudWatch Dashboard with custom metrics
- [ ] CloudWatch Alarms (error rate, queue depth)
- [ ] Unit & integration tests (Jest)
- [ ] Multi-environment (dev, staging, prod)
- [ ] Authentication (Cognito or API Key)
- [ ] Data retention policies (S3 lifecycle, DynamoDB TTL)
- [ ] Cost optimization (reserved capacity, S3 Intelligent-Tiering)
- [ ] Real scraping with Puppeteer/Playwright
- [ ] AI/ML integration (data enrichment)

## 📝 License

MIT License - See LICENSE file

## 👤 Author

Miguel - Technical Challenge for JL Outsourcer

---

**Total Development Time**: ~20 hours  
**Lines of Code**: ~1,500  
**AWS Services**: 7  
**Terraform Modules**: 4
