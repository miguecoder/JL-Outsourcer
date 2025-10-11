# Quick Start Guide

Complete setup in 5 minutes using the Makefile.

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- Node.js >= 16
- Python 3
- Make

## One-Command Setup

```bash
make setup
```

This command will:
1. ✅ Install all dependencies
2. ✅ Initialize Terraform
3. ✅ Deploy infrastructure
4. ✅ Configure frontend with API URL

## Start Frontend

```bash
make frontend-dev
```

Open: **http://localhost:3000**

---

## Common Commands

```bash
# View all available commands
make help

# Check pipeline health
make check

# Test API endpoints
make test-api

# Trigger manual ingestion
make test-ingestion

# View logs
make logs-api
make logs-ingestion
make logs-processing

# Redeploy Lambdas
make deploy-lambdas

# Clean temporary files
make clean
```

---

## Manual Setup (Step-by-Step)

If you prefer manual control:

### 1. Install Dependencies
```bash
make install
```

### 2. Deploy Infrastructure
```bash
make infra-init
make infra-apply
```

### 3. Package & Deploy Lambdas
```bash
make package
make deploy-lambdas
```

### 4. Configure & Run Frontend
```bash
make frontend-setup
make frontend-dev
```

---

## Troubleshooting

### Pipeline not working?
```bash
make check
```

### Lambdas need update?
```bash
make deploy-lambdas
```

### View errors in logs?
```bash
make logs-api
```

---

For detailed documentation, see:
- [README.md](README.md) - Complete overview
- [docs/architecture.md](docs/architecture.md) - Architecture details
- [docs/demo-notes.md](docs/demo-notes.md) - Testing guide

