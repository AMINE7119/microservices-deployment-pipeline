variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "microservices-gke"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "GCP zones for the cluster"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "kubernetes_version" {
  description = "Kubernetes version for GKE cluster"
  type        = string
  default     = "1.29"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "microservices-network"
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.1.0.0/20"
}

variable "pods_ipv4_cidr_block" {
  description = "CIDR block for pods"
  type        = string
  default     = "10.2.0.0/16"
}

variable "services_ipv4_cidr_block" {
  description = "CIDR block for services"
  type        = string
  default     = "10.3.0.0/16"
}

variable "node_pools" {
  description = "Configuration for node pools"
  type = list(object({
    name               = string
    machine_type       = string
    min_count          = number
    max_count          = number
    initial_node_count = number
    disk_size_gb       = number
    disk_type          = string
    preemptible        = bool
    auto_repair        = bool
    auto_upgrade       = bool
  }))
  default = [
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
}

variable "enable_private_cluster" {
  description = "Enable private GKE cluster"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

variable "enable_autopilot" {
  description = "Enable GKE Autopilot mode"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    environment = "production"
    project     = "microservices-platform"
    managed_by  = "terraform"
  }
}