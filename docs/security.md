# セキュリティガイドライン

## 🔒 機密情報の管理

### 絶対にコミットしてはいけないファイル

- `terraform-key.json` - Terraformサービスアカウントキー
- `.env.local` - 環境変数（Keycloak URLなど）
- `terraform.tfvars` - Terraformの変数値
- `*.tfstate` - Terraformの状態ファイル
- GCPサービスアカウントキー全般

### 安全な管理方法

1. **環境変数**
   ```bash
   # サービスアカウントキーは環境変数で管理
   export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-key.json
   
   # または安全な場所に保存
   mkdir -p ~/.config/gcloud/keys/
   mv terraform-key.json ~/.config/gcloud/keys/
   ```

2. **Secret Manager使用**
   ```bash
   # 機密データはSecret Managerに保存
   gcloud secrets create app-secret --data-file=secret.txt
   ```

## 🛡️ GCPセキュリティベストプラクティス

### IAM権限の最小化

```bash
# 必要最小限の権限のみ付与
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

### サービスアカウント管理

```bash
# 専用サービスアカウントを作成
gcloud iam service-accounts create keycloak-sa \
  --display-name="Keycloak Service Account"

# 必要最小限の権限のみ付与
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:keycloak-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

## 🔐 Keycloakセキュリティ設定

### 必須設定

1. **HTTPS強制**
   ```
   KC_HOSTNAME_STRICT=true (本番環境)
   KC_PROXY=edge
   ```

2. **強力な管理者パスワード**
   ```bash
   # 32文字のランダムパスワード生成
   openssl rand -base64 32
   ```

3. **セッション設定**
   - Access Token: 5分
   - Refresh Token: 30分
   - Session Timeout: 12時間

### クライアント設定

```json
{
  "clientId": "refine-spa-app",
  "publicClient": true,
  "redirectUris": [
    "https://your-domain.com/*"
  ],
  "webOrigins": [
    "https://your-domain.com"
  ]
}
```

## 🌐 ネットワークセキュリティ

### Cloud SQL

- **プライベートIP**: VPCネットワーク内のみアクセス
- **認証ネットワーク**: 特定IPからのみアクセス許可
- **SSL接続**: 必須

### Cloud Run

- **VPC Connector**: プライベートネットワーク経由でDB接続
- **IAM認証**: 認証されたユーザーのみアクセス
- **HTTPS**: 全通信の暗号化

## 📋 セキュリティチェックリスト

### デプロイ前

- [ ] `.gitignore`で機密ファイルを除外
- [ ] 環境変数に本番URLを設定
- [ ] サービスアカウント権限を最小化
- [ ] Terraformステートファイルを除外

### デプロイ後

- [ ] Keycloak管理者パスワードを変更
- [ ] Cloud SQLのパブリックIPを無効化
- [ ] Cloud Runのアクセス制御を確認
- [ ] ログ監視を有効化

### 定期メンテナンス

- [ ] サービスアカウントキーのローテーション（90日毎）
- [ ] Keycloakのアップデート
- [ ] セキュリティログの確認
- [ ] アクセス権限の棚卸し

## 🚨 インシデント対応

### 機密情報漏洩時

1. **即座に無効化**
   ```bash
   # サービスアカウントキーを無効化
   gcloud iam service-accounts keys delete KEY_ID \
     --iam-account=SERVICE_ACCOUNT_EMAIL
   ```

2. **新しいキーを生成**
   ```bash
   gcloud iam service-accounts keys create new-key.json \
     --iam-account=SERVICE_ACCOUNT_EMAIL
   ```

3. **影響範囲の調査**
   - Cloud Auditログの確認
   - 不正アクセスの有無
   - 影響を受けるリソースの特定

### 不正アクセス検知時

1. **アクセスを遮断**
2. **ログの保全**
3. **影響範囲の調査**
4. **セキュリティ強化**

## 📚 参考資料

- [GCP セキュリティベストプラクティス](https://cloud.google.com/security/best-practices)
- [Keycloak セキュリティガイド](https://www.keycloak.org/docs/latest/server_admin/#_security)
- [Cloud Run セキュリティ](https://cloud.google.com/run/docs/securing)
- [Cloud SQL セキュリティ](https://cloud.google.com/sql/docs/security)