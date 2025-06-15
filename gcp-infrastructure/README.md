# GCP Keycloak インフラ構成ガイド

このディレクトリには、GCPでKeycloakをデプロイするための設定ファイルとスクリプトが含まれています。

## インフラ構成

```
┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────────┐
│ Cloud Load Balancer │────│     Cloud Run        │────│    Cloud SQL        │
│   (HTTPS証明書)      │    │   (Keycloak)         │    │   (PostgreSQL)      │
└─────────────────────┘    └──────────────────────┘    └─────────────────────┘
                                      │
                            ┌──────────────────────┐
                            │   Secret Manager     │
                            │ (DB認証情報/秘密鍵)   │
                            └──────────────────────┘
```

## 必要なGCPサービス

- **Cloud Run**: Keycloakアプリケーションのホスティング
- **Cloud SQL**: PostgreSQLデータベース
- **Cloud Load Balancing**: HTTPS終端とロードバランシング
- **Secret Manager**: 秘密情報の安全な管理
- **Container Registry**: Dockerイメージの保存
- **VPC**: ネットワークセキュリティ

## デプロイ手順

1. Cloud SQLデータベースの作成
2. Keycloak Dockerイメージのビルドとプッシュ
3. Secret Managerでの秘密情報設定
4. Cloud Runへのデプロイ
5. ロードバランサーの設定
6. DNS設定とSSL証明書の設定

## 前提条件

- Google Cloud CLIがインストール済み
- Dockerがインストール済み  
- 適切なIAM権限を持つGCPプロジェクト

詳細な手順は各設定ファイルを参照してください。