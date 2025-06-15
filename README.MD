# Refine SPA App with Keycloak Authentication

<div align="center" style="margin: 30px;">
    <a href="https://refine.dev">
    <img alt="refine logo" src="https://refine.ams3.cdn.digitaloceanspaces.com/readme/refine-readme-banner.png">
    </a>
</div>
<br/>

Keycloak認証が統合されたRefine SPAアプリケーション。GCP Cloud Runでの本格的な認証システムを実装。

## 🌟 特徴

- ⚛️ **React 18** + **TypeScript** + **Vite**
- 🎨 **Ant Design** UIコンポーネント
- 🔐 **Keycloak** 認証統合
- ☁️ **GCP Cloud Run** デプロイ対応
- 🐳 **Docker** マルチアーキテクチャ対応（ARM/AMD64）
- 🛠️ **Makefile** による自動化

## 🚀 クイックスタート

### 1. リポジトリのクローン

```bash
git clone [repository-url]
cd refine-spa-app
```

### 2. 依存関係のインストール

```bash
make install
# または
npm install
```

### 3. 環境設定

```bash
make setup-env
# .env.local を編集してKeycloak URLを設定
```

### 4. 開発サーバーの起動

```bash
make dev
# または
npm run dev
```

## 🔧 利用可能なコマンド

### 開発用コマンド

```bash
make install      # 依存関係のインストール
make dev          # 開発サーバーの起動
make build        # 本番用ビルド
make lint         # リンターの実行
make test         # テストの実行
```

### GCPデプロイ用コマンド

```bash
make setup-gcp            # GCPプロジェクトの設定
make deploy-full          # 完全デプロイメント
make deploy-keycloak      # Keycloakのみデプロイ
make build-keycloak       # Keycloakイメージビルド
make create-db            # Cloud SQLデータベース作成
```

### 運用・監視コマンド

```bash
make logs         # Cloud Runログの表示
make status       # サービス状況の確認
make clean        # ローカルファイルのクリーンアップ
```

## 🏗️ アーキテクチャ

### フロントエンド
- **Framework**: Refine (React)
- **UI Library**: Ant Design
- **Build Tool**: Vite
- **Authentication**: Keycloak JS

### バックエンド（認証）
- **Authentication Server**: Keycloak
- **Platform**: GCP Cloud Run
- **Database**: Cloud SQL (PostgreSQL)
- **Secrets**: Secret Manager

### インフラ
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React SPA     │────│   Cloud Run     │────│   Cloud SQL     │
│   (Frontend)    │    │   (Keycloak)    │    │ (PostgreSQL)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                       ┌─────────────────┐
                       │ Secret Manager  │
                       │ (DB Credentials)│
                       └─────────────────┘
```

## 🔐 認証設定

### Keycloak設定

1. **レルム**: `refine-app`
2. **クライアント**: `refine-spa-app`
3. **Client Type**: Public (SPA)
4. **Redirect URIs**: 
   - `http://localhost:5173/*`
   - `https://your-domain.com/*`

### 環境変数

```env
VITE_KEYCLOAK_URL=https://your-keycloak-instance.run.app
VITE_KEYCLOAK_REALM=refine-app
VITE_KEYCLOAK_CLIENT_ID=refine-spa-app
```

## 🐳 Docker & マルチアーキテクチャ

このプロジェクトは**ARM64 (Apple Silicon/Windows ARM)** 環境から**AMD64 (Cloud Run)** 用のイメージをビルド可能：

```bash
# ARM環境からAMD64イメージをビルド
docker buildx build --platform linux/amd64 -t gcr.io/PROJECT/keycloak .
```

## 🌍 デプロイメント

### ハイブリッドデプロイ（推奨）

Terraform + Shell補完アプローチで安定したデプロイメントを実行：

```bash
# プロジェクトIDを設定
export PROJECT_ID=your-gcp-project-id

# ハイブリッドデプロイメント（API有効化 + Terraform）
make hybrid-deploy PROJECT_ID=$PROJECT_ID
```

**ハイブリッドデプロイの流れ：**
1. 🔧 GCP API自動有効化（Shell）
2. 🐳 Keycloakイメージビルド・プッシュ（Shell）
3. 🏗️ インフラストラクチャ作成（Terraform）

### 従来の自動デプロイ

```bash
# 完全シェルベースデプロイメント
make deploy-full PROJECT_ID=$PROJECT_ID
```

### Terraformのみ使用

```bash
# 事前にAPIを有効化済みの場合
make tf-init
make tf-plan
make tf-apply
```

### 手動デプロイ

1. **GCPプロジェクト設定**
   ```bash
   make setup-gcp PROJECT_ID=your-project-id
   ```

2. **データベース作成**
   ```bash
   make create-db
   ```

3. **Keycloakデプロイ**
   ```bash
   make deploy-keycloak
   ```

## 📊 監視とログ

```bash
# リアルタイムログ監視
make logs

# サービス状況確認
make status
```

## 🛠️ 開発環境

### 必要なツール
- Node.js 18+
- Docker
- Google Cloud CLI
- Make

### 対応環境
- ✅ macOS (Intel/Apple Silicon)
- ✅ Windows (x64/ARM64) + WSL2
- ✅ Linux (x64/ARM64)

## 📚 詳細ドキュメント

- [Keycloak設定ガイド](./gcp-infrastructure/README.md)
- [デプロイメントガイド](./gcp-infrastructure/DEPLOYMENT_GUIDE.md)
- [Claude開発ガイド](./CLAUDE.md)

## 🔗 関連リンク

- **Refine**: [ドキュメント](https://refine.dev/docs)
- **Keycloak**: [ドキュメント](https://www.keycloak.org/documentation)
- **GCP Cloud Run**: [ドキュメント](https://cloud.google.com/run/docs)

## 📄 ライセンス

MIT

## 🙋‍♂️ サポート

問題が発生した場合：

1. [Issues](https://github.com/your-repo/issues) でバグ報告
2. [Discussions](https://github.com/your-repo/discussions) で質問
3. `make logs` でログを確認
4. [トラブルシューティングガイド](./gcp-infrastructure/DEPLOYMENT_GUIDE.md#トラブルシューティング) を参照
