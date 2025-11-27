variable "project_id" {
  description = "cloud-computing-e25"
  type        = string
  default     = "cloud-computing-e25-terraform"
}

variable "region" {
  description = "europe-west4"
  type        = string
  default     = "europe-west4"
}

# Network config

variable "frontend_subnet_cidr" {
    description = "CIDR for frontend subnet"
    type        = string
    default     = "10.10.1.0/24"
}

variable "backend_subnet_cidr" {
    description = "CIDR for backend subnet"
    type        = string
    default     = "10.20.1.0/24"
}

variable "frontend_connector_cidr" {
    description = "CIDR for frontend VPC connector"
    type        = string
    default     = "10.30.1.0/28"
}

variable "backend_connector_cidr" {
    description = "CIDR for backend VPC connector"
    type        = string
    default     = "10.40.1.0/28"
}

# Cloud SQL config

variable db_instance_name {
  description = ""
  type        = string
  default     = "marius-db-db"
}

variable "db_name" {
    description = ""
    type        = string
    default     = "marius-db"
}

variable "db_user" {
    description = ""
    type        = string
    default     = "marius-user"
}

variable db_password {
  description = "description"
  type        = string
  default     = "Password1!"
}


variable "db_tier" {
    description = ""
    type        = string
    default     = "db-f1-micro" # I think this is the smallest one?
}

variable "db_version" {
    description = ""
    type        = string
    default     = "MYSQL_8_0"
}

# Cloud Run config

variable "backend_image" {
    description = "gcr.io/cloud-computing-e25-terraform/{image-name}" # ToDo
    type        = string
    default     = "gcr.io/cloud-computing-e25-terraform/marius-sql"
}

variable "frontend_image" {
    description = "gcr.io/cloud-computing-e25-terraform/{image-name}" # ToDo
    type        = string
    default     = "gcr.io/cloud-computing-e25-terraform/marius-frontend"
}

variable "backend_cpu" {
  description = ""
  type        = string
  default     = "1"
}

variable "backend_memory" {
  description = ""
  type        = string
  default     = "512Mi"
}

variable "frontend_cpu" {
  description = ""
  type        = string
  default     = "1"
}

variable "frontend_memory" {
  description = ""
  type        = string
  default     = "512Mi"
}

variable "min_instances" {
  description = ""
  type        = number
  default     = 0
}

variable "max_instances" {
  description = ""
  type        = number
  default     = 10
}
