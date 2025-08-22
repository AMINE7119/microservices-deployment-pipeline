terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for state management
  backend "gcs" {
    bucket = "microservices-terraform-state"
    prefix = "gcp/gke"
  }
}

provider "google" {
  project = var.project_id
  region  = var.gcp_region
}

# Variables
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "microservices-gke"
}

# Deploy GKE cluster
module "gke_cluster" {
  source = "../../modules/gcp-gke"
  
  project_id         = var.project_id
  cluster_name       = var.cluster_name
  region            = var.gcp_region
  kubernetes_version = "1.29"
  
  zones = [
    "${var.gcp_region}-a",
    "${var.gcp_region}-b",
    "${var.gcp_region}-c"
  ]
  
  network_name             = "microservices-network"
  subnet_cidr             = "10.1.0.0/20"
  pods_ipv4_cidr_block    = "10.2.0.0/16"
  services_ipv4_cidr_block = "10.3.0.0/16"
  
  node_pools = [
    {
      name               = "default-pool"
      machine_type       = "e2-standard-4"
      min_count          = 2
      max_count          = 10
      initial_node_count = 3
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      preemptible        = false
      auto_repair        = true
      auto_upgrade       = true
    },
    {
      name               = "spot-pool"
      machine_type       = "e2-standard-4"
      min_count          = 0
      max_count          = 20
      initial_node_count = 2
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      preemptible        = true
      auto_repair        = true
      auto_upgrade       = true
    }
  ]
  
  enable_private_cluster = false
  enable_autopilot      = false
  
  labels = {
    environment = var.environment
    terraform   = "true"
  }
}

# Google Container Registry
resource "google_container_registry" "registry" {
  project  = var.project_id
  location = "US"
}

# IAM binding for GCR
resource "google_storage_bucket_iam_member" "registry_public" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Global Load Balancer
resource "google_compute_global_address" "default" {
  name = "${var.cluster_name}-global-ip"
}

resource "google_compute_health_check" "default" {
  name               = "${var.cluster_name}-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  
  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "${var.cluster_name}-backend"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.default.id]
  load_balancing_scheme = "EXTERNAL"
  
  backend {
    group = google_compute_instance_group.gke_nodes.id
  }
  
  cdn_policy {
    cache_mode                   = "CACHE_ALL_STATIC"
    default_ttl                  = 3600
    max_ttl                      = 86400
    client_ttl                   = 3600
    negative_caching             = true
    serve_while_stale            = 86400
    signed_url_cache_max_age_sec = 7200
  }
}

resource "google_compute_url_map" "default" {
  name            = "${var.cluster_name}-url-map"
  default_service = google_compute_backend_service.default.id
  
  host_rule {
    hosts        = ["*"]
    path_matcher = "allpaths"
  }
  
  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.default.id
    
    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.default.id
    }
  }
}

resource "google_compute_target_http_proxy" "default" {
  name    = "${var.cluster_name}-http-proxy"
  url_map = google_compute_url_map.default.id
}

resource "google_compute_target_https_proxy" "default" {
  name             = "${var.cluster_name}-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "${var.cluster_name}-ssl-cert"
  
  managed {
    domains = ["gcp.microservices.example.com"]
  }
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.cluster_name}-http-forwarding-rule"
  target     = google_compute_target_http_proxy.default.id
  port_range = "80"
  ip_address = google_compute_global_address.default.address
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.cluster_name}-https-forwarding-rule"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
  ip_address = google_compute_global_address.default.address
}

# Get the instance group created by GKE
data "google_compute_instance_group" "gke_nodes" {
  name = "${var.cluster_name}-default-pool-instance-group"
  zone = "${var.gcp_region}-a"
  
  depends_on = [module.gke_cluster]
}

resource "google_compute_instance_group" "gke_nodes" {
  name        = "${var.cluster_name}-instance-group"
  description = "Instance group for GKE nodes"
  zone        = "${var.gcp_region}-a"
  network     = module.gke_cluster.network_name
}

# Cloud Armor Security Policy
resource "google_compute_security_policy" "default" {
  name = "${var.cluster_name}-security-policy"
  
  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
  
  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      
      ban_duration_sec = 600
    }
  }
  
  # Block suspicious requests
  rule {
    action   = "deny(403)"
    priority = "2000"
    match {
      expr {
        expression = "origin.region_code == 'CN' || origin.region_code == 'RU'"
      }
    }
  }
}

# Artifact Registry for container images
resource "google_artifact_registry_repository" "microservices" {
  location      = var.gcp_region
  repository_id = "microservices"
  description   = "Microservices container registry"
  format        = "DOCKER"
  
  docker_config {
    immutable_tags = false
  }
}

# IAM for Artifact Registry
resource "google_artifact_registry_repository_iam_member" "public" {
  project    = var.project_id
  location   = google_artifact_registry_repository.microservices.location
  repository = google_artifact_registry_repository.microservices.name
  role       = "roles/artifactregistry.reader"
  member     = "allUsers"
}

# Outputs
output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke_cluster.cluster_endpoint
  sensitive   = true
}

output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke_cluster.cluster_name
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.gke_cluster.kubeconfig_command
}

output "load_balancer_ip" {
  description = "Global load balancer IP"
  value       = google_compute_global_address.default.address
}

output "artifact_registry_url" {
  description = "Artifact Registry URL"
  value       = "${var.gcp_region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.microservices.repository_id}"
}