# GCP Keycloak インフラストラクチャ - Terraform設定

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# 変数定義
variable "project_id" {
  description = "GCP プロジェクト ID"
  type        = string
}

variable "region" {
  description = "GCP リージョン"
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "GCP ゾーン"
  type        = string
  default     = "asia-northeast1-a"
}

variable "domain" {
  description = "Keycloak用ドメイン名"
  type        = string
  default     = ""
}

# プロバイダー設定
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 必要なAPIの有効化
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudsql.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "containerregistry.googleapis.com",
    "sqladmin.googleapis.com",
    "compute.googleapis.com"
  ])

  service = each.key
  disable_on_destroy = false
}

# Cloud SQL インスタンス
resource "google_sql_database_instance" "keycloak_db" {
  name                = "keycloak-db"
  database_version    = "POSTGRES_14"
  region              = var.region
  deletion_protection = false

  settings {
    tier              = "db-f1-micro"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10

    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }
  }

  depends_on = [
    google_project_service.required_apis,
    google_service_networking_connection.private_vpc_connection
  ]
}

# データベース作成
resource "google_sql_database" "keycloak" {
  name     = "keycloak"
  instance = google_sql_database_instance.keycloak_db.name
}

# データベースユーザー作成
resource "google_sql_user" "keycloak" {
  name     = "keycloak"
  instance = google_sql_database_instance.keycloak_db.name
  password = random_password.db_password.result
}

# ランダムパスワード生成
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Secret Manager でパスワード管理
resource "google_secret_manager_secret" "db_password" {
  secret_id = "keycloak-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# VPC ネットワーク
resource "google_compute_network" "vpc" {
  name                    = "keycloak-vpc"
  auto_create_subnetworks = false
}

# サブネット
resource "google_compute_subnetwork" "subnet" {
  name          = "keycloak-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  private_ip_google_access = true
}

# VPC ピアリング用の IP 範囲
resource "google_compute_global_address" "private_ip_range" {
  name          = "keycloak-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

# サービスネットワーキング接続
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Cloud Run サービス
resource "google_cloud_run_service" "keycloak" {
  name     = "keycloak-service"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project_id}/keycloak:latest"
        
        ports {
          container_port = 8080
        }

        resources {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }

        env {
          name  = "KC_DB"
          value = "postgres"
        }

        env {
          name  = "KC_DB_URL"
          value = "jdbc:postgresql:///${google_sql_database.keycloak.name}?host=/cloudsql/${google_sql_database_instance.keycloak_db.connection_name}"
        }

        env {
          name  = "KC_DB_USERNAME"
          value = google_sql_user.keycloak.name
        }

        env {
          name = "KC_DB_PASSWORD"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_password.secret_id
              key  = "latest"
            }
          }
        }

        env {
          name  = "KC_HOSTNAME_STRICT"
          value = "false"
        }

        env {
          name  = "KC_PROXY"
          value = "edge"
        }

        env {
          name  = "KC_HTTP_ENABLED"
          value = "true"
        }
      }

    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "10"
        "autoscaling.knative.dev/minScale" = "1"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.keycloak_db.connection_name
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.required_apis,
    google_sql_database_instance.keycloak_db
  ]
}

# VPC Access Connector
resource "google_vpc_access_connector" "connector" {
  name          = "keycloak-connector"
  ip_cidr_range = "10.1.0.0/28"
  network       = google_compute_network.vpc.name
  region        = var.region

  depends_on = [google_project_service.required_apis]
}

# Cloud Run サービスへのパブリックアクセスを許可
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.keycloak.name
  location = google_cloud_run_service.keycloak.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# 出力値
output "keycloak_url" {
  description = "Keycloak サービス URL"
  value       = google_cloud_run_service.keycloak.status[0].url
}

output "db_connection_name" {
  description = "Cloud SQL 接続名"
  value       = google_sql_database_instance.keycloak_db.connection_name
}

output "admin_console_url" {
  description = "Keycloak 管理コンソール URL"
  value       = "${google_cloud_run_service.keycloak.status[0].url}/admin"
}