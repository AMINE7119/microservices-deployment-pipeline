output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke_cluster.name
}

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.gke_cluster.id
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.gke_cluster.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64 encoded)"
  value       = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.gke_cluster.location
}

output "cluster_version" {
  description = "GKE cluster version"
  value       = google_container_cluster.gke_cluster.master_version
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc_network.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_cidr" {
  description = "Subnet CIDR block"
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}

output "pods_cidr" {
  description = "Pods CIDR block"
  value       = var.pods_ipv4_cidr_block
}

output "services_cidr" {
  description = "Services CIDR block"
  value       = var.services_ipv4_cidr_block
}

output "service_account_email" {
  description = "Service account email for GKE nodes"
  value       = google_service_account.gke_node_sa.email
}

output "workload_identity_pool" {
  description = "Workload Identity Pool"
  value       = "${var.project_id}.svc.id.goog"
}

output "kubeconfig_command" {
  description = "gcloud command to update kubeconfig"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.gke_cluster.name} --region ${var.region} --project ${var.project_id}"
}

output "node_pools" {
  description = "Information about the node pools"
  value = {
    for pool in google_container_node_pool.node_pools : pool.name => {
      name               = pool.name
      initial_node_count = pool.initial_node_count
      min_node_count     = pool.autoscaling[0].min_node_count
      max_node_count     = pool.autoscaling[0].max_node_count
      machine_type       = pool.node_config[0].machine_type
      preemptible        = pool.node_config[0].preemptible
    }
  }
}