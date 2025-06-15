# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際のClaude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

これはTypeScriptとViteで構築されたRefineベースのReactアプリケーションです。Refineは、認証、データ管理、ルーティングが組み込まれた管理パネル、ダッシュボード、内部ツールを構築するためのReactフレームワークです。

## 主要技術

- **フロントエンドフレームワーク**: React 18 with TypeScript
- **ビルドツール**: Vite
- **UIフレームワーク**: Ant Design (antd) via @refinedev/antd
- **認証**: Keycloak via @react-keycloak/web
- **データプロバイダ**: @refinedev/simple-rest（現在は偽のAPIを使用）
- **ルーティング**: React Router v7 via @refinedev/react-router
- **開発ツール**: Refine DevTools and Kbar

## アーキテクチャ

アプリケーションはRefineのアーキテクチャパターンに従っています：

- **認証**: `src/index.tsx`でのKeycloak統合と`src/App.tsx`での認証プロバイダ
- **データレイヤー**: RefineのデータプロバイダパターンによるREST API統合
- **UIコンポーネント**: Refineの拡張機能でラップされたAnt Designコンポーネント
- **状態管理**: Refineが内部的にほとんどの状態管理を処理
- **ルーティング**: RefineのルーターバインディングによるReact Router

## 開発コマンド

```bash
# 開発サーバーの起動
npm run dev

# 本番用ビルド（TypeScriptコンパイルを含む）
npm run build

# 本番サーバーの起動
npm run start

# Refine CLIへのアクセス
npm run refine
```

## プロジェクト構造

- `src/App.tsx`: Refineの設定とKeycloak認証プロバイダを含むメインアプリケーションコンポーネント
- `src/index.tsx`: Keycloakプロバイダの設定を含むアプリケーションエントリーポイント
- `src/contexts/`: Reactコンテキスト（カラーモード）
- `src/components/`: 再利用可能なUIコンポーネント
- `src/pages/`: アプリケーションページ/ルート

## 認証設定

アプリは以下の設定でKeycloakを認証に使用しています：
- **クライアントID**: refine-demo
- **Keycloak URL**: https://lemur-0.cloud-iam.com/auth
- **レルム**: refine

認証プロバイダはログイン、ログアウト、トークン検証、ユーザーアイデンティティ管理を処理します。

## データプロバイダ

現在は`https://api.fake-rest.refine.dev`の偽のREST APIを使用するよう設定されています。本番環境にデプロイする際は、実際のAPIエンドポイントに置き換える必要があります。