.PHONY: help install deploy test clean package frontend infra check logs
.DEFAULT_GOAL := help

# Variables
PROJECT_NAME = twl-pipeline

# Leer ENV desde .env.secrets si existe, sino usar dev por defecto
# Prioridad: ENV desde línea de comandos > PIPELINE_ENV desde .env.secrets > dev por defecto
ifneq ($(ENV),)
  # ENV ya está definido desde línea de comandos (ENV=prod make ...)
else
  # Intentar leer PIPELINE_ENV desde .env.secrets
  ifneq ($(wildcard .env.secrets),)
    PIPELINE_ENV := $(shell grep -E '^PIPELINE_ENV=' .env.secrets 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d ' ')
    ifneq ($(PIPELINE_ENV),)
      ENV := $(PIPELINE_ENV)
    else
      ENV := dev
    endif
  else
    ENV := dev
  endif
endif

INFRA_DIR = infra/envs/$(ENV)
FRONTEND_DIR = frontend

# Colors for output
BLUE = \033[0;34m
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)Usage:$(NC)\n  make $(GREEN)<target>$(NC) [ENV=dev|prod]\n\n$(YELLOW)Current Environment: $(ENV)$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Installation & Setup

install: install-services install-frontend ## Install all dependencies
	@echo "$(GREEN)✅ All dependencies installed$(NC)"

install-services: ## Install Lambda services dependencies
	@echo "$(BLUE)📦 Installing service dependencies...$(NC)"
	@cd services/ingestion && npm install --production
	@cd services/processing && npm install --production
	@cd services/api && npm install --production
	@echo "$(GREEN)✅ Services dependencies installed$(NC)"

install-frontend: ## Install frontend dependencies
	@echo "$(BLUE)📦 Installing frontend dependencies...$(NC)"
	@cd $(FRONTEND_DIR) && npm install
	@echo "$(GREEN)✅ Frontend dependencies installed$(NC)"

##@ Infrastructure (Terraform)

infra-init: ## Initialize Terraform
	@echo "$(BLUE)🔧 Initializing Terraform...$(NC)"
	@cd $(INFRA_DIR) && terraform init -upgrade
	@echo "$(GREEN)✅ Terraform initialized$(NC)"

infra-plan: ## Run Terraform plan (usa variables PIPELINE_* desde .env.secrets)
	@echo "$(BLUE)📋 Running Terraform plan...$(NC)"
	@echo "$(YELLOW)Environment: $(ENV)$(NC)"
	@ENV=$(ENV) ./terraform.sh plan

infra-apply: ## Apply Terraform changes (usa variables PIPELINE_* desde .env.secrets)
	@echo "$(BLUE)🚀 Applying Terraform changes...$(NC)"
	@echo "$(YELLOW)Environment: $(ENV)$(NC)"
	@ENV=$(ENV) ./terraform.sh apply
	@echo "$(GREEN)✅ Infrastructure deployed$(NC)"

infra-destroy: ## Destroy all infrastructure (use with caution!)
	@echo "$(RED)⚠️  Destroying infrastructure...$(NC)"
	@echo "$(YELLOW)Environment: $(ENV)$(NC)"
	@ENV=$(ENV) ./terraform.sh destroy

infra-output: ## Show Terraform outputs
	@cd $(INFRA_DIR) && terraform output

##@ Lambda Packaging & Deployment

package: package-ingestion package-processing package-api ## Package all Lambda functions
	@echo "$(GREEN)✅ All Lambdas packaged$(NC)"

package-ingestion: ## Package ingestion Lambda
	@echo "$(BLUE)📦 Packaging ingestion Lambda...$(NC)"
	@cd services/ingestion && \
		python3 -c "import zipfile, os; \
		z = zipfile.ZipFile('../../lambda-ingestion.zip', 'w', zipfile.ZIP_DEFLATED); \
		z.write('index.js'); \
		[z.write(os.path.join(r, f), os.path.join('node_modules', os.path.relpath(os.path.join(r, f), 'node_modules'))) \
		for r, _, files in os.walk('node_modules') for f in files]; \
		z.close()"
	@echo "$(GREEN)✅ lambda-ingestion.zip created$(NC)"

package-processing: ## Package processing Lambda
	@echo "$(BLUE)📦 Packaging processing Lambda...$(NC)"
	@cd services/processing && \
		python3 -c "import zipfile, os; \
		z = zipfile.ZipFile('../../lambda-processing.zip', 'w', zipfile.ZIP_DEFLATED); \
		z.write('index.js'); \
		[z.write(os.path.join(r, f), os.path.join('node_modules', os.path.relpath(os.path.join(r, f), 'node_modules'))) \
		for r, _, files in os.walk('node_modules') for f in files]; \
		z.close()"
	@echo "$(GREEN)✅ lambda-processing.zip created$(NC)"

package-api: ## Package API Lambda
	@echo "$(BLUE)📦 Packaging API Lambda...$(NC)"
	@cd services/api && \
		python3 -c "import zipfile, os; \
		z = zipfile.ZipFile('../../lambda-api.zip', 'w', zipfile.ZIP_DEFLATED); \
		z.write('index.js'); \
		[z.write(os.path.join(r, f), os.path.join('node_modules', os.path.relpath(os.path.join(r, f), 'node_modules'))) \
		for r, _, files in os.walk('node_modules') for f in files]; \
		z.close()"
	@echo "$(GREEN)✅ lambda-api.zip created$(NC)"

deploy-lambdas: package ## Deploy all Lambda functions to AWS (usa variables PIPELINE_* desde .env.secrets)
	@echo "$(BLUE)🚀 Deploying Lambda functions...$(NC)"
	@./aws-cli.sh lambda update-function-code --function-name $(PROJECT_NAME)-ingestion-$(ENV) --zip-file fileb://lambda-ingestion.zip
	@./aws-cli.sh lambda update-function-code --function-name $(PROJECT_NAME)-processing-$(ENV) --zip-file fileb://lambda-processing.zip
	@./aws-cli.sh lambda update-function-code --function-name $(PROJECT_NAME)-api-$(ENV) --zip-file fileb://lambda-api.zip
	@echo "$(GREEN)✅ All Lambdas deployed$(NC)"

##@ Frontend

frontend-dev: ## Run frontend in development mode
	@echo "$(BLUE)🌐 Starting frontend dev server...$(NC)"
	@cd $(FRONTEND_DIR) && npm run dev

frontend-build: ## Build frontend for production
	@echo "$(BLUE)🔨 Building frontend...$(NC)"
	@cd $(FRONTEND_DIR) && npm run build

frontend-setup: ## Configure frontend with API URL
	@echo "$(BLUE)⚙️  Configuring frontend...$(NC)"
	@cd $(INFRA_DIR) && terraform output -raw api_url > ../../../.api_url_temp
	@echo "NEXT_PUBLIC_API_URL=$$(cat .api_url_temp)" > $(FRONTEND_DIR)/.env.local
	@rm .api_url_temp
	@echo "$(GREEN)✅ Frontend configured with API URL$(NC)"

##@ Testing & Monitoring

test: ## Run unit tests for all services
	@echo "$(BLUE)🧪 Running unit tests...$(NC)"
	@cd services/ingestion && npm test
	@cd services/processing && npm test
	@cd services/api && npm test
	@echo "$(GREEN)✅ All tests passed$(NC)"

test-api: ## Test API endpoints
	@echo "$(BLUE)🧪 Testing API endpoints...$(NC)"
	@API_URL=$$(cd $(INFRA_DIR) && terraform output -raw api_url); \
	echo "Testing /analytics..."; \
	curl -s "$$API_URL/analytics" | python3 -m json.tool || echo "Failed"; \
	echo "\nTesting /records..."; \
	curl -s "$$API_URL/records?limit=3" | python3 -m json.tool || echo "Failed"

test-ingestion: ## Manually trigger ingestion Lambda (usa variables PIPELINE_* desde .env.secrets)
	@echo "$(BLUE)🔄 Triggering ingestion Lambda...$(NC)"
	@./aws-cli.sh lambda invoke --function-name $(PROJECT_NAME)-ingestion-$(ENV) response.json
	@cat response.json | python3 -m json.tool
	@rm response.json

check: ## Health check of the entire pipeline
	@echo "$(BLUE)🔍 Running pipeline health check...$(NC)"
	@bash scripts/check-pipeline-impl.sh

logs-ingestion: ## View ingestion Lambda logs (usa variables PIPELINE_* desde .env.secrets)
	@./aws-cli.sh logs filter-log-events \
		--log-group-name /aws/lambda/$(PROJECT_NAME)-ingestion-$(ENV) \
		--limit 20 \
		--query 'events[*].message' \
		--output text

logs-processing: ## View processing Lambda logs (usa variables PIPELINE_* desde .env.secrets)
	@./aws-cli.sh logs filter-log-events \
		--log-group-name /aws/lambda/$(PROJECT_NAME)-processing-$(ENV) \
		--limit 20 \
		--query 'events[*].message' \
		--output text

logs-api: ## View API Lambda logs (usa variables PIPELINE_* desde .env.secrets)
	@./aws-cli.sh logs filter-log-events \
		--log-group-name /aws/lambda/$(PROJECT_NAME)-api-$(ENV) \
		--limit 20 \
		--query 'events[*].message' \
		--output text

##@ Complete Workflows

deploy: install-services package infra-apply deploy-lambdas ## Full deployment (infra + lambdas)
	@echo "$(GREEN)✅ Complete deployment finished$(NC)"

setup: install infra-init infra-apply frontend-setup ## Initial project setup
	@echo "$(GREEN)✅ Project setup complete$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Run: make frontend-dev"
	@echo "  2. Open: http://localhost:3000"

clean: ## Clean temporary files and build artifacts
	@echo "$(BLUE)🧹 Cleaning temporary files...$(NC)"
	@rm -f lambda-*.zip
	@rm -f response.json
	@rm -f .api_url_temp
	@rm -rf $(FRONTEND_DIR)/.next
	@echo "$(GREEN)✅ Cleaned$(NC)"

clean-frontend: ## Clean and rebuild frontend
	@echo "$(BLUE)🧹 Cleaning frontend...$(NC)"
	@cd $(FRONTEND_DIR) && rm -rf .next node_modules
	@echo "$(BLUE)📦 Reinstalling dependencies...$(NC)"
	@cd $(FRONTEND_DIR) && npm install
	@echo "$(GREEN)✅ Frontend cleaned and ready$(NC)"

##@ Documentation

docs: ## Open documentation
	@echo "$(BLUE)📖 Documentation files:$(NC)"
	@echo "  README.md - Project overview"
	@echo "  docs/architecture.md - Architecture decisions"
	@echo "  docs/demo-notes.md - Testing & troubleshooting"
	@echo "  docs/diagrams/architecture-diagram.md - Visual diagram"

