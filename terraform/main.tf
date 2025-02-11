variable "project_id" {
  description = "GCP project id"
}

variable "region" {
  description = "Region to deploy"
  default = "us-central1"
}

variable "image_url" {
  description = "url of the image including the part @sha256..."
}

variable "datadog_api_key" {
  description = "The Datadog API Key"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_cloud_run_service" "terraform_with_sidecar" {
  name     = "dd-nodejs"
  location = var.region

  template {
    metadata {
      annotations = {
        "run.googleapis.com/container-dependencies" = jsonencode({main-app = ["sidecar-container"]})
      }
    }
    spec {
      volumes {
        name = "shared-volume"
        empty_dir {
          medium = "Memory"
        }
      }

      containers {
        name  = "main-app"
        image = var.image_url

        ports {
          container_port = 8080
        }
        volume_mounts {
          name      = "shared-volume"
          mount_path = "/shared-volume"
        }
        startup_probe {
          tcp_socket {
            port = 8080
          }
          initial_delay_seconds = 0  # Delay before the probe starts
          period_seconds        = 10   # Time between probes
          failure_threshold     = 3   # Number of failures before marking as unhealthy
          timeout_seconds       = 1  # Number of failures before marking as unhealthy
        }

        # Environment variables for the main container
        env {
          name  = "DD_SERVICE"
          value = "dd-nodejs"
        }

        # Resource limits for the main container
        resources {
          limits = {
            memory = "512Mi"
            cpu    = "1"
          }
        }
      }

      # Sidecar container
      containers {
        name  = "sidecar-container"
        image = "gcr.io/datadoghq/serverless-init:latest"

        # Mount the shared volume
        volume_mounts {
          name      = "shared-volume"
          mount_path = "/shared-volume"
        }

        # Startup Probe for TCP Health Check
        startup_probe {
          tcp_socket {
            port = 12345
          }
          initial_delay_seconds = 0  # Delay before the probe starts
          period_seconds        = 10   # Time between probes
          failure_threshold     = 3   # Number of failures before marking as unhealthy
          timeout_seconds       = 1
        }

        # Environment variables for the sidecar container
        env {
          name  = "DD_SITE"
          value = "us5.datadoghq.com"
        }
        env {
          name  = "DD_SERVERLESS_LOG_PATH"
          value = "shared-volume/logs/*.log"
        }
        env {
          name  = "DD_ENV"
          value = "Serverless"
        }
        env {
          name  = "DD_API_KEY"
          value = var.datadog_api_key
        }
        env {
          name  = "DD_SERVICE"
          value = "dd-nodejs"
        }
        env {
          name  = "DD_VERSION"
          value = "1"
        }
        env {
          name  = "DD_LOG_LEVEL"
          value = "debug"
        }
        env {
          name  = "DD_LOGS_INJECTION"
          value = "true"
        }
        env {
          name  = "DD_HEALTH_PORT"
          value = "12345"
        }

        # Resource limits for the sidecar
        resources {
          limits = {
            memory = "512Mi"
            cpu    = "1"
          }
        }
      }
    }
  }

  # Define traffic splitting
  traffic {
    percent         = 100
    latest_revision = true
  }
}