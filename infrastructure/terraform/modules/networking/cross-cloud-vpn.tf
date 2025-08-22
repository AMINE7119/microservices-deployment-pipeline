# Cross-Cloud VPN Configuration for AWS-GCP connectivity

variable "aws_vpc_id" {
  description = "AWS VPC ID"
  type        = string
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "gcp_network_name" {
  description = "GCP VPC network name"
  type        = string
}

variable "gcp_subnet_cidr" {
  description = "GCP subnet CIDR"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

# AWS Side - Customer Gateway and VPN Connection
resource "aws_customer_gateway" "gcp_gateway" {
  bgp_asn    = 65000
  ip_address = google_compute_address.vpn_gateway_ip.address
  type       = "ipsec.1"

  tags = {
    Name = "gcp-customer-gateway"
  }
}

resource "aws_vpn_gateway" "aws_vpn_gw" {
  vpc_id = var.aws_vpc_id

  tags = {
    Name = "aws-vpn-gateway"
  }
}

resource "aws_vpn_connection" "aws_gcp_vpn" {
  customer_gateway_id = aws_customer_gateway.gcp_gateway.id
  vpn_gateway_id      = aws_vpn_gateway.aws_vpn_gw.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "aws-gcp-vpn-connection"
  }
}

resource "aws_vpn_connection_route" "gcp_route" {
  vpn_connection_id      = aws_vpn_connection.aws_gcp_vpn.id
  destination_cidr_block = var.gcp_subnet_cidr
}

# AWS Route Propagation
resource "aws_vpn_gateway_route_propagation" "main" {
  vpn_gateway_id = aws_vpn_gateway.aws_vpn_gw.id
  route_table_id = data.aws_route_table.main.id
}

data "aws_route_table" "main" {
  vpc_id = var.aws_vpc_id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# GCP Side - Cloud VPN
resource "google_compute_address" "vpn_gateway_ip" {
  name    = "vpn-gateway-ip"
  region  = var.gcp_region
  project = var.gcp_project_id
}

resource "google_compute_vpn_gateway" "gcp_vpn_gw" {
  name    = "gcp-vpn-gateway"
  network = var.gcp_network_name
  region  = var.gcp_region
  project = var.gcp_project_id
}

resource "google_compute_forwarding_rule" "esp" {
  name        = "vpn-esp-rule"
  ip_protocol = "ESP"
  ip_address  = google_compute_address.vpn_gateway_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.id
  project     = var.gcp_project_id
  region      = var.gcp_region
}

resource "google_compute_forwarding_rule" "udp500" {
  name        = "vpn-udp500-rule"
  ip_protocol = "UDP"
  port_range  = "500"
  ip_address  = google_compute_address.vpn_gateway_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.id
  project     = var.gcp_project_id
  region      = var.gcp_region
}

resource "google_compute_forwarding_rule" "udp4500" {
  name        = "vpn-udp4500-rule"
  ip_protocol = "UDP"
  port_range  = "4500"
  ip_address  = google_compute_address.vpn_gateway_ip.address
  target      = google_compute_vpn_gateway.gcp_vpn_gw.id
  project     = var.gcp_project_id
  region      = var.gcp_region
}

# VPN Tunnels (you would need to create one for each AWS VPN connection tunnel)
resource "google_compute_vpn_tunnel" "tunnel1" {
  name          = "aws-gcp-tunnel1"
  peer_ip       = aws_vpn_connection.aws_gcp_vpn.tunnel1_address
  shared_secret = aws_vpn_connection.aws_gcp_vpn.tunnel1_preshared_key
  vpn_gateway   = google_compute_vpn_gateway.gcp_vpn_gw.id
  ike_version   = 2
  project       = var.gcp_project_id
  region        = var.gcp_region

  depends_on = [
    google_compute_forwarding_rule.esp,
    google_compute_forwarding_rule.udp500,
    google_compute_forwarding_rule.udp4500,
  ]
}

resource "google_compute_vpn_tunnel" "tunnel2" {
  name          = "aws-gcp-tunnel2"
  peer_ip       = aws_vpn_connection.aws_gcp_vpn.tunnel2_address
  shared_secret = aws_vpn_connection.aws_gcp_vpn.tunnel2_preshared_key
  vpn_gateway   = google_compute_vpn_gateway.gcp_vpn_gw.id
  ike_version   = 2
  project       = var.gcp_project_id
  region        = var.gcp_region

  depends_on = [
    google_compute_forwarding_rule.esp,
    google_compute_forwarding_rule.udp500,
    google_compute_forwarding_rule.udp4500,
  ]
}

# Routes for GCP to AWS
resource "google_compute_route" "to_aws" {
  name                = "route-to-aws"
  dest_range          = var.aws_vpc_cidr
  network             = var.gcp_network_name
  next_hop_vpn_tunnel = google_compute_vpn_tunnel.tunnel1.id
  priority            = 1000
  project             = var.gcp_project_id
}

# Outputs
output "aws_vpn_connection_id" {
  value = aws_vpn_connection.aws_gcp_vpn.id
}

output "gcp_vpn_gateway_ip" {
  value = google_compute_address.vpn_gateway_ip.address
}

output "tunnel1_address" {
  value = aws_vpn_connection.aws_gcp_vpn.tunnel1_address
}

output "tunnel2_address" {
  value = aws_vpn_connection.aws_gcp_vpn.tunnel2_address
}