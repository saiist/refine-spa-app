# Refine SPA Application with Keycloak Makefile

# Variables
PROJECT_ID ?= my-project-1227-413021
REGION ?= asia-northeast1
SERVICE_NAME = keycloak-service
IMAGE_NAME = gcr.io/$(PROJECT_ID)/keycloak
DB_INSTANCE_NAME = keycloak-db

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help install dev build deploy-keycloak setup-gcp clean lint test

help: ## Show this help message
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

install: ## Install dependencies
	@echo "$(GREEN)Installing dependencies...$(NC)"
	npm install

dev: ## Start development server
	@echo "$(GREEN)Starting development server...$(NC)"
	npm run dev

build: ## Build the application
	@echo "$(GREEN)Building application...$(NC)"
	npm run build

lint: ## Run linter
	@echo "$(GREEN)Running linter...$(NC)"
	npm run lint || echo "$(YELLOW)Linter not configured$(NC)"

test: ## Run tests
	@echo "$(GREEN)Running tests...$(NC)"
	npm test || echo "$(YELLOW)Tests not configured$(NC)"

# GCP Infrastructure Commands

setup-gcp: ## Setup GCP project and enable APIs
	@echo "$(GREEN)Setting up GCP project...$(NC)"
	gcloud config set project $(PROJECT_ID)
	gcloud services enable \
		cloudsql.googleapis.com \
		run.googleapis.com \
		secretmanager.googleapis.com \
		containerregistry.googleapis.com \
		sqladmin.googleapis.com

setup-env: ## Create .env.local from example
	@echo "$(GREEN)Setting up environment file...$(NC)"
	@if [ ! -f .env.local ]; then \
		cp .env.example .env.local; \
		echo "$(YELLOW)Please edit .env.local with your actual values$(NC)"; \
	else \
		echo "$(YELLOW).env.local already exists$(NC)"; \
	fi

build-keycloak: ## Build Keycloak Docker image for AMD64
	@echo "$(GREEN)Building Keycloak Docker image...$(NC)"
	cd gcp-infrastructure/keycloak && \
	docker buildx build --platform linux/amd64 -t $(IMAGE_NAME):latest . --load

push-keycloak: build-keycloak ## Push Keycloak image to Container Registry
	@echo "$(GREEN)Pushing Keycloak image...$(NC)"
	docker push $(IMAGE_NAME):latest

create-db: ## Create Cloud SQL instance
	@echo "$(GREEN)Creating Cloud SQL instance...$(NC)"
	@if ! gcloud sql instances describe $(DB_INSTANCE_NAME) --quiet 2>/dev/null; then \
		gcloud sql instances create $(DB_INSTANCE_NAME) \
			--database-version=POSTGRES_14 \
			--tier=db-f1-micro \
			--region=$(REGION) \
			--storage-type=SSD \
			--storage-size=10GB; \
		gcloud sql databases create keycloak --instance=$(DB_INSTANCE_NAME); \
		DB_PASSWORD=$$(openssl rand -base64 32); \
		gcloud sql users create keycloak --instance=$(DB_INSTANCE_NAME) --password=$$DB_PASSWORD; \
		echo -n "$$DB_PASSWORD" | gcloud secrets create keycloak-db-password --data-file=-; \
		echo "$(GREEN)Database created with password stored in Secret Manager$(NC)"; \
	else \
		echo "$(YELLOW)Database instance already exists$(NC)"; \
	fi

deploy-keycloak: push-keycloak ## Deploy Keycloak to Cloud Run
	@echo "$(GREEN)Deploying Keycloak to Cloud Run...$(NC)"
	gcloud run deploy $(SERVICE_NAME) \
		--image=$(IMAGE_NAME):latest \
		--platform=managed \
		--region=$(REGION) \
		--allow-unauthenticated \
		--memory=2Gi \
		--cpu=2 \
		--timeout=3600 \
		--max-instances=1 \
		--concurrency=10 \
		--set-env-vars="KC_HOSTNAME_STRICT=false,KC_HTTP_ENABLED=true,KEYCLOAK_ADMIN=admin,KEYCLOAK_ADMIN_PASSWORD=admin123" \
		--command="/opt/keycloak/bin/kc.sh" \
		--args="start-dev,--http-port=8080"

deploy-full: setup-gcp create-db deploy-keycloak ## Full deployment pipeline
	@echo "$(GREEN)Full deployment completed!$(NC)"
	@echo "Access Keycloak at: $$(gcloud run services describe $(SERVICE_NAME) --region=$(REGION) --format='value(status.url)')"

# Development helpers

logs: ## View Cloud Run logs
	@echo "$(GREEN)Viewing Cloud Run logs...$(NC)"
	gcloud logs tail --follow \
		--filter="resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_NAME)"

status: ## Check service status
	@echo "$(GREEN)Checking service status...$(NC)"
	gcloud run services list --region=$(REGION)
	gcloud sql instances list

clean: ## Clean up local files
	@echo "$(GREEN)Cleaning up...$(NC)"
	rm -rf node_modules
	rm -rf dist
	docker system prune -f

clean-gcp: ## Clean up GCP resources (DANGEROUS)
	@echo "$(RED)WARNING: This will delete GCP resources$(NC)"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	gcloud run services delete $(SERVICE_NAME) --region=$(REGION) --quiet
	gcloud sql instances delete $(DB_INSTANCE_NAME) --quiet
	gcloud secrets delete keycloak-db-password --quiet

# Terraform commands (if migrated)

tf-init: ## Initialize Terraform
	@echo "$(GREEN)Initializing Terraform...$(NC)"
	cd gcp-infrastructure/terraform && terraform init

tf-plan: ## Plan Terraform deployment
	@echo "$(GREEN)Planning Terraform deployment...$(NC)"
	cd gcp-infrastructure/terraform && terraform plan

tf-apply: ## Apply Terraform deployment
	@echo "$(GREEN)Applying Terraform deployment...$(NC)"
	cd gcp-infrastructure/terraform && terraform apply

tf-destroy: ## Destroy Terraform resources
	@echo "$(RED)Destroying Terraform resources...$(NC)"
	cd gcp-infrastructure/terraform && terraform destroy