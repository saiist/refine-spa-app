# Refine SPA + Keycloak 統合開発・デプロイメント用 Makefile

# 設定変数
PROJECT_ID ?= my-project-1227-413021
REGION ?= asia-northeast1
SERVICE_NAME = keycloak-service
IMAGE_NAME = gcr.io/$(PROJECT_ID)/keycloak
DB_INSTANCE_NAME = keycloak-db

# 出力用カラーコード
GREEN = \033[0;32m
YELLOW = \033[0;33m
RED = \033[0;31m
NC = \033[0m # カラーリセット

.PHONY: help install dev build deploy-keycloak setup-gcp clean lint test security-check clean-secrets rotate-keys hybrid-deploy enable-apis start deploy check info quick-setup urls debug health fix-common-issues update-env show-env

help: ## ヘルプメッセージを表示
	@echo "$(GREEN)利用可能なコマンド:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

install: ## 依存関係をインストール
	@echo "$(GREEN)依存関係をインストール中...$(NC)"
	npm install

dev: ## 開発サーバーを起動
	@echo "$(GREEN)開発サーバーを起動中...$(NC)"
	npm run dev

build: ## アプリケーションをビルド
	@echo "$(GREEN)アプリケーションをビルド中...$(NC)"
	npm run build

lint: ## リンターを実行
	@echo "$(GREEN)リンターを実行中...$(NC)"
	npm run lint || echo "$(YELLOW)リンターが設定されていません$(NC)"

test: ## テストを実行
	@echo "$(GREEN)テストを実行中...$(NC)"
	npm test || echo "$(YELLOW)テストが設定されていません$(NC)"

# よく使用するコマンドのエイリアス
start: dev ## 開発サーバー起動のエイリアス

deploy: hybrid-deploy ## ハイブリッドデプロイのエイリアス

check: security-check ## セキュリティチェックのエイリアス

info: ## プロジェクト情報を表示
	@echo "$(GREEN)=== プロジェクト情報 ===$(NC)"
	@echo "$(YELLOW)プロジェクトID:$(NC) $(PROJECT_ID)"
	@echo "$(YELLOW)リージョン:$(NC) $(REGION)"
	@echo "$(YELLOW)サービス名:$(NC) $(SERVICE_NAME)"
	@echo "$(YELLOW)イメージ名:$(NC) $(IMAGE_NAME)"
	@echo ""
	@echo "$(GREEN)=== 現在のGCPコンテキスト ===$(NC)"
	@gcloud config get-value project 2>/dev/null || echo "$(RED)プロジェクトが設定されていません$(NC)"
	@gcloud config get-value compute/region 2>/dev/null || echo "$(YELLOW)デフォルトリージョンが設定されていません$(NC)"
	@echo ""
	@echo "$(GREEN)=== クイックコマンド ===$(NC)"
	@echo "  $(YELLOW)make start$(NC)    - 開発サーバー起動"
	@echo "  $(YELLOW)make deploy$(NC)   - GCPにデプロイ"
	@echo "  $(YELLOW)make status$(NC)   - サービス状況確認"
	@echo "  $(YELLOW)make logs$(NC)     - サービスログ表示"

quick-setup: ## クイックプロジェクトセットアップ（依存関係＋環境設定）
	@echo "$(GREEN)=== クイックプロジェクトセットアップ ===$(NC)"
	make install
	make setup-env
	@echo "$(GREEN)✓ セットアップ完了！'make start'で開発を開始してください$(NC)"

urls: ## 全サービスURLを表示
	@echo "$(GREEN)=== サービスURL ===$(NC)"
	@echo "$(YELLOW)Keycloakサービスを確認中...$(NC)"
	@KEYCLOAK_URL=$$(gcloud run services describe $(SERVICE_NAME) --region=$(REGION) --format="value(status.url)" 2>/dev/null); \
	if [ -n "$$KEYCLOAK_URL" ]; then \
		echo "  Keycloakサービス: $$KEYCLOAK_URL"; \
		echo "  管理コンソール:   $$KEYCLOAK_URL/admin"; \
		echo "  レルムURL:       $$KEYCLOAK_URL/realms/refine-app"; \
	else \
		echo "  $(RED)Keycloakサービスが見つかりません$(NC)"; \
	fi
	@echo "$(YELLOW)ローカル開発環境:$(NC)"
	@echo "  React App:        http://localhost:3000"
	@echo "  Vite Dev Server:  http://localhost:5173"

# GCPインフラストラクチャコマンド

setup-gcp: ## GCPプロジェクトの設定とAPI有効化
	@echo "$(GREEN)Setting up GCP project...$(NC)"
	gcloud config set project $(PROJECT_ID)
	gcloud services enable \
		cloudsql.googleapis.com \
		run.googleapis.com \
		secretmanager.googleapis.com \
		containerregistry.googleapis.com \
		sqladmin.googleapis.com

setup-env: ## サンプルから.env.localを作成
	@echo "$(GREEN)環境設定ファイルをセットアップ中...$(NC)"
	@if [ ! -f .env.local ]; then \
		cp .env.example .env.local; \
		echo "$(YELLOW).env.localを実際の値で編集してください$(NC)"; \
	else \
		echo "$(YELLOW).env.localは既に存在します$(NC)"; \
	fi

update-env: ## .env.localを現在のKeycloak URLで更新
	@echo "$(GREEN)Updating environment variables...$(NC)"
	@KEYCLOAK_URL=$$(gcloud run services describe $(SERVICE_NAME) --region=$(REGION) --format="value(status.url)" 2>/dev/null); \
	if [ -n "$$KEYCLOAK_URL" ]; then \
		echo "$(YELLOW)Found Keycloak URL: $$KEYCLOAK_URL$(NC)"; \
		if [ -f .env.local ]; then \
			sed -i.bak "s|VITE_KEYCLOAK_URL=.*|VITE_KEYCLOAK_URL=$$KEYCLOAK_URL|" .env.local; \
			echo "$(GREEN)✓ Updated VITE_KEYCLOAK_URL in .env.local$(NC)"; \
		else \
			echo "VITE_KEYCLOAK_URL=$$KEYCLOAK_URL" > .env.local; \
			echo "VITE_KEYCLOAK_REALM=refine-app" >> .env.local; \
			echo "VITE_KEYCLOAK_CLIENT_ID=refine-spa-app" >> .env.local; \
			echo "$(GREEN)✓ Created .env.local with Keycloak URL$(NC)"; \
		fi; \
	else \
		echo "$(RED)Keycloak service not found. Deploy first with 'make deploy'$(NC)"; \
	fi

show-env: ## 現在の環境変数を表示
	@echo "$(GREEN)=== Environment Variables ===$(NC)"
	@if [ -f .env.local ]; then \
		echo "$(YELLOW)From .env.local:$(NC)"; \
		cat .env.local | grep -v "^#" | grep -v "^$$"; \
	else \
		echo "$(RED).env.local not found$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Runtime environment:$(NC)"
	@echo "NODE_ENV: $${NODE_ENV:-development}"
	@echo "Project ID: $(PROJECT_ID)"
	@echo "Region: $(REGION)"

build-keycloak: ## AMD64用Keycloak Dockerイメージをビルド
	@echo "$(GREEN)Building Keycloak Docker image...$(NC)"
	cd gcp-infrastructure/keycloak && \
	docker buildx build --platform linux/amd64 -t $(IMAGE_NAME):latest . --load

push-keycloak: build-keycloak ## KeycloakイメージをContainer Registryにプッシュ
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

# 開発支援コマンド

logs: ## Cloud Runログを表示
	@echo "$(GREEN)Viewing Cloud Run logs...$(NC)"
	gcloud logs tail --follow \
		--filter="resource.type=cloud_run_revision AND resource.labels.service_name=$(SERVICE_NAME)"

status: ## サービス状況を確認
	@echo "$(GREEN)Checking service status...$(NC)"
	@echo "$(YELLOW)Cloud Run Services:$(NC)"
	@gcloud run services list --region=$(REGION) 2>/dev/null || echo "$(RED)No Cloud Run services found$(NC)"
	@echo ""
	@echo "$(YELLOW)Cloud SQL Instances:$(NC)"
	@gcloud sql instances list 2>/dev/null || echo "$(RED)No Cloud SQL instances found$(NC)"
	@echo ""
	@echo "$(YELLOW)Secret Manager:$(NC)"
	@gcloud secrets list --filter="name:keycloak" 2>/dev/null || echo "$(RED)No secrets found$(NC)"

debug: ## デプロイメント問題をデバッグ
	@echo "$(GREEN)=== Deployment Debug Information ===$(NC)"
	@echo "$(YELLOW)1. Checking GCP authentication...$(NC)"
	@gcloud auth list --filter="status:ACTIVE" --format="table(account)" 2>/dev/null || echo "$(RED)Not authenticated$(NC)"
	@echo ""
	@echo "$(YELLOW)2. Checking project configuration...$(NC)"
	@echo "Current project: $$(gcloud config get-value project 2>/dev/null || echo 'Not set')"
	@echo "Expected project: $(PROJECT_ID)"
	@echo ""
	@echo "$(YELLOW)3. Checking enabled APIs...$(NC)"
	@gcloud services list --enabled --filter="name:(run.googleapis.com OR sqladmin.googleapis.com OR secretmanager.googleapis.com)" --format="table(name)" 2>/dev/null
	@echo ""
	@echo "$(YELLOW)4. Checking Docker images...$(NC)"
	@gcloud container images list --repository=gcr.io/$(PROJECT_ID) 2>/dev/null || echo "$(RED)No images found$(NC)"
	@echo ""
	@echo "$(YELLOW)5. Checking service account...$(NC)"
	@gcloud iam service-accounts list --filter="email:terraform-sa@$(PROJECT_ID).iam.gserviceaccount.com" 2>/dev/null || echo "$(RED)Terraform service account not found$(NC)"

health: ## 全サービスのヘルスチェック
	@echo "$(GREEN)=== Health Check ===$(NC)"
	@echo "$(YELLOW)Checking Keycloak service...$(NC)"
	@KEYCLOAK_URL=$$(gcloud run services describe $(SERVICE_NAME) --region=$(REGION) --format="value(status.url)" 2>/dev/null); \
	if [ -n "$$KEYCLOAK_URL" ]; then \
		echo "Service URL: $$KEYCLOAK_URL"; \
		echo "Testing health endpoint..."; \
		curl -s -o /dev/null -w "Status: %{http_code}\n" "$$KEYCLOAK_URL/health" || echo "$(RED)Health check failed$(NC)"; \
	else \
		echo "$(RED)Service not found$(NC)"; \
	fi
	@echo ""
	@echo "$(YELLOW)Checking database connection...$(NC)"
	@gcloud sql instances describe $(DB_INSTANCE_NAME) --format="value(state)" 2>/dev/null || echo "$(RED)Database not found$(NC)"

fix-common-issues: ## Fix common deployment issues
	@echo "$(GREEN)=== Fixing Common Issues ===$(NC)"
	@echo "$(YELLOW)1. Setting correct project...$(NC)"
	@gcloud config set project $(PROJECT_ID)
	@echo "$(YELLOW)2. Enabling required APIs...$(NC)"
	@make enable-apis
	@echo "$(YELLOW)3. Checking Docker configuration...$(NC)"
	@gcloud auth configure-docker --quiet
	@echo "$(GREEN)✓ Common issues fixed$(NC)"

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

# Terraformコマンド

tf-init: ## Terraformを初期化
	@echo "$(GREEN)Terraformを初期化中...$(NC)"
	cd gcp-infrastructure/terraform && terraform init

tf-plan: ## Terraformデプロイメントを計画
	@echo "$(GREEN)Terraformデプロイメントを計画中...$(NC)"
	cd gcp-infrastructure/terraform && GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json terraform plan

tf-apply: ## Terraformデプロイメントを適用
	@echo "$(GREEN)Terraformデプロイメントを適用中...$(NC)"
	cd gcp-infrastructure/terraform && GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json terraform apply -auto-approve

tf-destroy: ## Terraformリソースを削除
	@echo "$(RED)Terraformリソースを削除中...$(NC)"
	cd gcp-infrastructure/terraform && GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json terraform destroy -auto-approve

enable-apis: ## 必要なGCP APIを手動で有効化
	@echo "$(GREEN)Enabling required GCP APIs...$(NC)"
	gcloud services enable run.googleapis.com sqladmin.googleapis.com secretmanager.googleapis.com containerregistry.googleapis.com compute.googleapis.com servicenetworking.googleapis.com vpcaccess.googleapis.com --project=$(PROJECT_ID)

hybrid-deploy: enable-apis build-keycloak push-keycloak ## ハイブリッドデプロイメント（API + Terraform）
	@echo "$(GREEN)Starting hybrid deployment...$(NC)"
	@echo "$(YELLOW)1. APIs enabled manually$(NC)"
	@echo "$(YELLOW)2. Keycloak image built and pushed$(NC)"
	@echo "$(GREEN)3. Running Terraform for infrastructure...$(NC)"
	make tf-apply

security-check: ## セキュリティ問題をチェック
	@echo "$(GREEN)Running security checks...$(NC)"
	@echo "$(YELLOW)Checking for exposed secrets...$(NC)"
	@if [ -f terraform-key.json ]; then echo "$(RED)WARNING: terraform-key.json found in project root!$(NC)"; fi
	@if [ -f .env.local ]; then echo "$(YELLOW)INFO: .env.local found (should not be committed)$(NC)"; fi
	@if [ -d gcp-infrastructure/terraform/.terraform ]; then echo "$(YELLOW)INFO: Terraform state directory found$(NC)"; fi
	@echo "$(GREEN)Checking .gitignore coverage...$(NC)"
	@git check-ignore terraform-key.json 2>/dev/null && echo "$(GREEN)✓ terraform-key.json is ignored$(NC)" || echo "$(RED)✗ terraform-key.json not ignored$(NC)"
	@git check-ignore .env.local 2>/dev/null && echo "$(GREEN)✓ .env.local is ignored$(NC)" || echo "$(RED)✗ .env.local not ignored$(NC)"

clean-secrets: ## プロジェクトから機密ファイルを削除
	@echo "$(RED)Removing sensitive files...$(NC)"
	@rm -f terraform-key.json gcp-key*.json service-account-*.json
	@rm -rf gcp-infrastructure/terraform/.terraform/
	@rm -f gcp-infrastructure/terraform/terraform.tfstate*
	@echo "$(GREEN)Sensitive files removed$(NC)"

rotate-keys: ## GCPサービスアカウントキーをローテーション
	@echo "$(GREEN)Rotating service account keys...$(NC)"
	@echo "$(YELLOW)Current keys:$(NC)"
	@gcloud iam service-accounts keys list --iam-account=terraform-sa@$(PROJECT_ID).iam.gserviceaccount.com
	@echo "$(YELLOW)Creating new key...$(NC)"
	@gcloud iam service-accounts keys create terraform-key-new.json --iam-account=terraform-sa@$(PROJECT_ID).iam.gserviceaccount.com
	@echo "$(GREEN)New key created: terraform-key-new.json$(NC)"
	@echo "$(RED)Please update your GOOGLE_APPLICATION_CREDENTIALS and delete old key$(NC)"