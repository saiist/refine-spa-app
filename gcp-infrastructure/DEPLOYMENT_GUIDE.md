# GCP Keycloak デプロイメントガイド

## 🚀 デプロイ手順

### 1. 前提条件の確認

```bash
# Google Cloud CLI のインストール確認
gcloud version

# Dockerのインストール確認  
docker version

# Terraformのインストール確認（オプション）
terraform version

# GCPプロジェクトの設定
gcloud config set project YOUR_PROJECT_ID
gcloud auth login
gcloud auth configure-docker
```

### 2. 簡単デプロイ（推奨）

```bash
# デプロイスクリプトの実行
chmod +x deploy.sh
./deploy.sh YOUR_PROJECT_ID asia-northeast1
```

### 3. Terraformを使用したデプロイ（上級者向け）

```bash
cd terraform

# Terraform初期化
terraform init

# 変数ファイルの作成
cat > terraform.tfvars << EOF
project_id = "your-project-id"
region     = "asia-northeast1"
domain     = "your-domain.com"  # オプション
EOF

# デプロイ計画の確認
terraform plan

# デプロイ実行
terraform apply
```

## 🔧 デプロイ後の設定

### 1. Keycloak管理者設定

1. デプロイ完了後に表示されるURLにアクセス
2. `/admin`パスで管理コンソールにアクセス
3. 初回アクセス時に管理者アカウントを作成

### 2. レルムとクライアントの設定

```bash
# レルム設定のインポート（オプション）
# 管理コンソールで realm-config.json をインポート
```

または手動で以下を設定：

- **レルム名**: `refine-app`
- **クライアントID**: `refine-spa-app`
- **クライアントタイプ**: Public（SPAアプリケーション）
- **リダイレクトURI**: 
  - `http://localhost:3000/*` (開発用)
  - `https://your-domain.com/*` (本番用)

### 3. React アプリケーションの設定

```bash
# 環境変数ファイルの作成
cp .env.example .env.local

# .env.local を編集して実際のKeycloak URLを設定
REACT_APP_KEYCLOAK_URL=https://keycloak-service-xxx-an.a.run.app
REACT_APP_KEYCLOAK_REALM=refine-app
REACT_APP_KEYCLOAK_CLIENT_ID=refine-spa-app
```

## 🔐 セキュリティ設定

### SSL証明書の設定

```bash
# カスタムドメインの場合
gcloud run domain-mappings create \
  --service keycloak-service \
  --domain your-domain.com \
  --region asia-northeast1
```

### ファイアウォール設定

```bash
# 必要に応じてファイアウォールルールを設定
gcloud compute firewall-rules create allow-keycloak \
  --allow tcp:8080 \
  --source-ranges 0.0.0.0/0 \
  --description "Allow Keycloak access"
```

## 📊 監視とメンテナンス

### ログの確認

```bash
# Cloud Runのログ確認
gcloud logs tail --follow \
  --filter="resource.type=cloud_run_revision AND resource.labels.service_name=keycloak-service"

# Cloud SQLのログ確認
gcloud logs tail --follow \
  --filter="resource.type=gce_instance AND logName=projects/YOUR_PROJECT_ID/logs/cloudsql.googleapis.com%2Fpostgres.log"
```

### バックアップ

```bash
# Cloud SQLの自動バックアップを確認
gcloud sql instances describe keycloak-db --format="value(settings.backupConfiguration)"
```

## 🔄 アップデート手順

### Keycloakのバージョンアップ

```bash
# 新しいイメージをビルド
docker build -t gcr.io/YOUR_PROJECT_ID/keycloak:new-version ./keycloak
docker push gcr.io/YOUR_PROJECT_ID/keycloak:new-version

# Cloud Runサービスの更新
gcloud run deploy keycloak-service \
  --image gcr.io/YOUR_PROJECT_ID/keycloak:new-version \
  --region asia-northeast1
```

## 🆘 トラブルシューティング

### よくある問題

1. **接続エラー**: Cloud SQLの接続設定を確認
2. **メモリ不足**: Cloud Runのメモリ制限を増加
3. **起動失敗**: 環境変数とSecret Managerの設定を確認

### デバッグコマンド

```bash
# サービスの詳細確認
gcloud run services describe keycloak-service --region asia-northeast1

# データベース接続確認
gcloud sql connect keycloak-db --user=keycloak

# シークレットの確認
gcloud secrets versions access latest --secret="keycloak-db-password"
```

## 💰 コスト最適化

- Cloud Runの最小インスタンス数を0に設定（開発環境）
- Cloud SQLを適切なマシンタイプに調整
- 不要な時間帯はCloud SQLを停止（開発環境）

## 🗑️ リソースの削除

```bash
# Terraformを使用した場合
terraform destroy

# 手動削除の場合
gcloud run services delete keycloak-service --region asia-northeast1
gcloud sql instances delete keycloak-db
gcloud secrets delete keycloak-db-password
```