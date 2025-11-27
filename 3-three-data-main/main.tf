
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
  network       = google_compute_network.vpc-frontend.name
}

resource "google_compute_subnetwork" "backend-subnet" {
  name          = "backend-subnet"
  ip_cidr_range = var.backend_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc-backend.name
}

# For Cloud SQL private ip
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection

# # Create an IP address
# resource "google_compute_global_address" "private-ip-range" {
#   name          = "google-vpc-backend"
#   purpose       = "VPC_PEERING"
#   address_type  = "INTERNAL"
#   prefix_length = 16
#   network       = google_compute_network.vpc-backend.name
# }

# # Create a private connection
# resource "google_service_networking_connection" "private-vpc-connection" {
#   network                 = google_compute_network.vpc-backend.name
#   service                 = "servicenetworking.googleapis.com"
#   reserved_peering_ranges = [google_compute_global_address.private-ip-range.name]
# }

# for serverless VPC access (allow Cloud Run services to access VPC resources)
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vpc_access_connector

# resource "google_vpc_access_connector" "connector-frontend" {
#   name                    = "connector-frontend"
#   region                  = var.region
#   network                 = google_compute_network.vpc-frontend.name
#   ip_cidr_range           = var.frontend_connector_cidr
#   min_instances           = 1
#   max_instances           = 2
# }

# resource "google_vpc_access_connector" "connector-backend" {
#   name                    = "connector-backend"
#   region                  = var.region
#   network                 = google_compute_network.vpc-backend.name
#   ip_cidr_range           = var.backend_connector_cidr
#   min_instances           = 1
#   max_instances           = 2
# }

# VPC peering
# THIS SHOULD GO BOTH WAYS
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering

# resource "google_compute_network_peering" "frontend-to-backend" {
#     name          = "frontend-to-backend-peering"
#     network       = google_compute_network.vpc-frontend.self_link
#     peer_network  = google_compute_network.vpc-backend.self_link
#          
# }

# resource "google_compute_network_peering" "backend-to-frontend" {
#     name          = "backend-to-frontend-peering"
#     network       = google_compute_network.vpc-backend.self_link
#     peer_network  = google_compute_network.vpc-frontend.self_link
#          
# }

# MySQL DB

resource "google_sql_database_instance" "marius-db" {
    name                = var.db_instance_name
    database_version    = var.db_version
    region              = var.region
    settings {
        tier = var.db_tier

        # ip_configuration { 
        #     ipv4_enabled    = false
        #     private_network = google_compute_network.vpc-backend.name
        # }
    }

    #depeends_on = [google_service_networking_connection.private-vpc-connection]
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

# Cloud runs?

resource "google_cloud_run_service" "frontend-service" {
  name = "frontend"
  location = var.region // europe-west4 right?
  template {
    spec {
      containers {
        image = var.frontend_image
      }
    }
  }
}

resource "google_cloud_run_service" "backend-service" {
  name = "backend"
  location = var.region // europe-west4 right?
  template {
    spec {
      containers {
        image = var.backend_image
      }
    }
  }
}