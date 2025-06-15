import Keycloak from "keycloak-js";

// Vite環境変数からKeycloak設定を取得
const keycloakConfig = {
  // GCP Cloud Runにデプロイされたkeycloakのurl
  url: import.meta.env.VITE_KEYCLOAK_URL || "https://keycloak-service-9026893589.asia-northeast1.run.app",
  realm: import.meta.env.VITE_KEYCLOAK_REALM || "refine-app",
  clientId: import.meta.env.VITE_KEYCLOAK_CLIENT_ID || "refine-spa-app",
};

// Keycloakインスタンスの作成
const keycloak = new Keycloak(keycloakConfig);

// 開発/本番環境の設定は環境変数で制御
// 必要に応じて keycloak.init() オプションを設定

export default keycloak;