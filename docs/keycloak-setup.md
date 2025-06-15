# Keycloak設定ガイド

## 1. 管理者アカウント作成

Keycloakの初回起動時に管理者アカウントを作成：

```bash
# Cloud Runログから初期管理者情報を確認
gcloud run services logs tail keycloak-service --region=asia-northeast1
```

## 2. レルム作成

**レルム名**: `refine-app`

### レルム設定
- **Display name**: Refine SPA Application
- **Enabled**: ✅
- **User registration**: ✅ (必要に応じて)
- **Login with email**: ✅
- **Duplicate emails**: ❌

## 3. クライアント作成

**クライアントID**: `refine-spa-app`

### 基本設定
- **Client type**: `OpenID Connect`
- **Client authentication**: `Off` (Public client)
- **Authorization**: `Off`
- **Standard flow**: ✅
- **Direct access grants**: ✅

### アクセス設定  
- **Valid redirect URIs**:
  - `http://localhost:3000/*` (開発環境)
  - `http://localhost:5173/*` (Vite開発サーバー)
  - `https://your-production-domain.com/*` (本番環境)
- **Valid post logout redirect URIs**: 
  - `http://localhost:3000`
  - `http://localhost:5173`
  - `https://your-production-domain.com`
- **Web origins**: `*` または具体的なドメイン

### 高度な設定
- **Access token lifespan**: `5 minutes`
- **Client session idle**: `30 minutes`
- **Client session max**: `12 hours`

## 4. ユーザー作成（テスト用）

### テストユーザー
- **Username**: `testuser`
- **Email**: `test@example.com`
- **First name**: `Test`
- **Last name**: `User`
- **Password**: `testpassword123`

### 設定
- **Email verified**: ✅
- **Enabled**: ✅

## 5. ロール設定（オプション）

### レルムロール
- `admin` - 管理者ロール
- `user` - 一般ユーザーロール

### クライアントロール（refine-spa-app）
- `viewer` - 読み取り専用
- `editor` - 編集権限
- `admin` - 管理権限

## 6. Keycloak URL確認

デプロイ完了後、以下でKeycloak URLを確認：

```bash
# Terraform出力から確認
make tf-output

# または直接確認
gcloud run services describe keycloak-service --region=asia-northeast1 --format="value(status.url)"
```

## 7. React SPA側設定

`.env.local`を更新：

```env
VITE_KEYCLOAK_URL=https://your-new-keycloak-url.run.app
VITE_KEYCLOAK_REALM=refine-app
VITE_KEYCLOAK_CLIENT_ID=refine-spa-app
```

## 8. 認証フロー確認

1. React SPA起動: `npm run dev`
2. ブラウザで `http://localhost:3000` にアクセス
3. Keycloakログイン画面へリダイレクト確認
4. テストユーザーでログイン
5. "Welcome Aboard!" 画面表示確認

## トラブルシューティング

### よくある問題

1. **Redirect URI mismatch**
   - Keycloakクライアント設定でURLを確認
   - `localhost` vs `127.0.0.1` の違いに注意

2. **CORS エラー**
   - Keycloakの Web origins 設定を確認
   - `*` または具体的なオリジンを設定

3. **Keycloak起動しない**
   - Cloud Runログでデータベース接続を確認
   - Secret Managerの権限を確認

### ログ確認コマンド

```bash
# Cloud Runログ
gcloud run services logs tail keycloak-service --region=asia-northeast1

# Cloud SQLログ
gcloud sql operations list --instance=keycloak-db
```