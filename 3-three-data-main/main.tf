
provider "google" {
  project = var.project_id
  region  = var.region
}

# VPC networks

resource "google_compute_network" "vpc-frontend" {
  name                      = "vpc-frontend"
  auto_create_subnetworks   = false
}

resource "google_compute_network" "vpc-backend" {
  name                      = "vpc-backend"
  auto_create_subnetworks   = false
}

# Subnets

resource "google_compute_subnetwork" "frontend-subnet" {
  name          = "frontend-subnet"
  ip_cidr_range = var.frontend_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc-frontend.id
}

resource "google_compute_subnetwork" "backend-subnet" {
  name          = "backend-subnet"
  ip_cidr_range = var.backend_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc-backend.id
}

# For Cloud SQL private ip
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection

# # Create an IP address
resource "google_compute_global_address" "private-ip-range" {
  name          = "google-vpc-backend"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc-backend.id
}

# # Create a private connection
resource "google_service_networking_connection" "private-vpc-connection" {
  network                 = google_compute_network.vpc-backend.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private-ip-range.name]
}

# for serverless VPC access (allow Cloud Run services to access VPC resources)
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector

resource "google_vpc_access_connector" "connector-frontend" {
  name                    = "connector-frontend"
  region                  = var.region
  network                 = google_compute_network.vpc-frontend.name
  ip_cidr_range           = var.frontend_connector_cidr
  min_instances           = 2
  max_instances           = 3
}

resource "google_vpc_access_connector" "connector-backend" {
  name                    = "connector-backend"
  region                  = var.region
  network                 = google_compute_network.vpc-backend.name
  ip_cidr_range           = var.backend_connector_cidr
  min_instances           = 2
  max_instances           = 3
}

# VPC peering
# THIS SHOULD GO BOTH WAYS
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering

resource "google_compute_network_peering" "frontend-to-backend" {
    name          = "frontend-to-backend-peering"
    network       = google_compute_network.vpc-frontend.self_link
    peer_network  = google_compute_network.vpc-backend.self_link         
}

resource "google_compute_network_peering" "backend-to-frontend" {
    name          = "backend-to-frontend-peering"
    network       = google_compute_network.vpc-backend.self_link
    peer_network  = google_compute_network.vpc-frontend.self_link   

    depends_on = [google_compute_network_peering.frontend-to-backend]      
}

# Firewall rules
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall

resource "google_compute_firewall" "allow-frontend-to-backend" {
  name    = "allow-frontend-to-backend"
  network = google_compute_network.vpc-backend.name

  allow {
    protocol  = "tcp"
    ports     = ["8080"]
  }

  source_ranges = [var.frontend_subnet_cidr, var.frontend_connector_cidr]
  direction     = "INGRESS"
}

# MySQL DB

resource "google_sql_database_instance" "marius-db" {
    name                = var.db_instance_name
    database_version    = var.db_version
    region              = var.region
    settings {
        tier = var.db_tier

        ip_configuration { 
            ipv4_enabled    = false
            private_network = google_compute_network.vpc-backend.id
        }
    }

    depends_on = [google_service_networking_connection.private-vpc-connection]
}

resource "google_sql_database" "app_database" {
    name        = var.db_name
    instance    = google_sql_database_instance.marius-db.name
}

resource "google_sql_user" "app_user"{
    name        = var.db_user
    instance    = google_sql_database_instance.marius-db.name
    password    = var.db_password
}

# Cloud runs

resource "google_cloud_run_v2_service" "backend-service" {
  name      = "backend"
  location  = var.region // europe-west4 right? yes
  ingress   = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {

    vpc_access {
      connector = google_vpc_access_connector.connector-backend.id
      egress    = "ALL_TRAFFIC"
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.marius-db.connection_name]
      }
    }

    containers {
      image = var.backend_image
      
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu     = var.backend_cpu
          memory  = var.backend_memory
        }
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "DB_PASS"
        value = var.db_password
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.marius-db.connection_name
      }
    }
  }
  depends_on = [
    google_vpc_access_connector.connector-backend,
    google_sql_database_instance.marius-db
  ]
}

resource "google_cloud_run_v2_service" "frontend-service" {
  name = "frontend"
  location = var.region // europe-west4 right? yes
  ingress = "INGRESS_TRAFFIC_ALL"
  
  template {

    vpc_access {
      connector = google_vpc_access_connector.connector-frontend.id
      egress    = "ALL_TRAFFIC"
    }

    containers {
      image = var.frontend_image

      ports {
        container_port = 3000
      }

      resources {
        limits = {
          cpu     = var.frontend_cpu
          memory  = var.frontend_memory
        }
      }

      env {
        name      = "API_ADDRESS"
        value     = google_cloud_run_v2_service.backend-service.uri
      }
    }
  }

  depends_on = [
    google_vpc_access_connector.connector-frontend,
    google_cloud_run_v2_service.backend-service,
    google_compute_network_peering.frontend-to-backend,
    google_compute_network_peering.backend-to-frontend,
    google_compute_firewall.allow-frontend-to-backend
  ]
}

# IAM to allow public access to frontend
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service_iam
resource "google_cloud_run_v2_service_iam_member" "frontend-public" {
  project   = var.project_id
  location  = var.region
  name      = google_cloud_run_v2_service.frontend-service.name
  role      = "roles/run.invoker"
  member    = "allUsers"
}
