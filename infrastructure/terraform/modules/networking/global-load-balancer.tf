# Global Load Balancer Configuration using Cloudflare

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
  default     = "microservices.example.com"
}

variable "aws_alb_dns" {
  description = "AWS ALB DNS name"
  type        = string
}

variable "gcp_lb_ip" {
  description = "GCP Load Balancer IP"
  type        = string
}

variable "azure_lb_ip" {
  description = "Azure Load Balancer IP (optional)"
  type        = string
  default     = ""
}

# Health Check Origins
locals {
  origins = {
    aws = {
      address = var.aws_alb_dns
      enabled = true
      weight  = 100
      region  = "us-east-1"
    }
    gcp = {
      address = var.gcp_lb_ip
      enabled = true
      weight  = 100
      region  = "us-central1"
    }
  }
}

# Cloudflare Load Balancer Pool for AWS
resource "cloudflare_load_balancer_pool" "aws_pool" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  account_id         = var.cloudflare_account_id
  name               = "aws-eks-pool"
  minimum_origins    = 1
  notification_email = "ops@example.com"

  origins {
    name    = "aws-eks-origin"
    address = var.aws_alb_dns
    enabled = true
    weight  = 100
    header {
      header = "Host"
      values = [var.domain_name]
    }
  }

  monitor = cloudflare_load_balancer_monitor.health_check[0].id

  description = "AWS EKS cluster pool"
}

# Cloudflare Load Balancer Pool for GCP
resource "cloudflare_load_balancer_pool" "gcp_pool" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  account_id         = var.cloudflare_account_id
  name               = "gcp-gke-pool"
  minimum_origins    = 1
  notification_email = "ops@example.com"

  origins {
    name    = "gcp-gke-origin"
    address = var.gcp_lb_ip
    enabled = true
    weight  = 100
    header {
      header = "Host"
      values = [var.domain_name]
    }
  }

  monitor = cloudflare_load_balancer_monitor.health_check[0].id

  description = "GCP GKE cluster pool"
}

# Add required variables
variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  default     = ""
}

# Health Check Monitor
resource "cloudflare_load_balancer_monitor" "health_check" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  account_id           = var.cloudflare_account_id
  type                = "http"
  expected_codes      = "200"
  method              = "GET"
  timeout             = 5
  path                = "/health"
  interval            = 60
  retries             = 2
  description         = "Health check for microservices"

  header {
    header = "Host"
    values = [var.domain_name]
  }
}

# Global Load Balancer
resource "cloudflare_load_balancer" "global_lb" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  zone_id          = var.cloudflare_zone_id
  name             = var.domain_name
  default_pool_ids = [cloudflare_load_balancer_pool.aws_pool[0].id]
  fallback_pool_id = cloudflare_load_balancer_pool.gcp_pool[0].id
  description      = "Global load balancer for microservices"
  proxied          = true
  steering_policy  = "geo"

  # Region-specific routing
  region_pools {
    region   = "ENAM"  # Eastern North America
    pool_ids = [cloudflare_load_balancer_pool.aws_pool[0].id]
  }

  region_pools {
    region   = "WNAM"  # Western North America
    pool_ids = [cloudflare_load_balancer_pool.gcp_pool[0].id]
  }

  # Pop pools for specific Cloudflare PoPs
  pop_pools {
    pop      = "LAX"
    pool_ids = [cloudflare_load_balancer_pool.gcp_pool[0].id]
  }

  pop_pools {
    pop      = "ORD"
    pool_ids = [cloudflare_load_balancer_pool.aws_pool[0].id]
  }

  # Session affinity
  session_affinity     = "cookie"
  session_affinity_ttl = 1800

  # Adaptive routing
  adaptive_routing {
    failover_across_pools = true
  }

  # Random steering for canary deployments
  random_steering {
    default_weight = 1
    pool_weights = {
      (cloudflare_load_balancer_pool.aws_pool[0].id) = 0.7
      (cloudflare_load_balancer_pool.gcp_pool[0].id) = 0.3
    }
  }
}

# DNS Records
resource "cloudflare_record" "cname_aws" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "aws"
  value   = var.aws_alb_dns
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "a_gcp" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = "gcp"
  value   = var.gcp_lb_ip
  type    = "A"
  ttl     = 1
  proxied = false
}

# Page Rules for caching and performance
resource "cloudflare_page_rule" "cache_static" {
  count = var.cloudflare_zone_id != "" ? 1 : 0

  zone_id  = var.cloudflare_zone_id
  target   = "${var.domain_name}/static/*"
  priority = 1

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 7200
    browser_cache_ttl = 3600
  }
}

# Alternative: AWS Route53 Configuration (if not using Cloudflare)
resource "aws_route53_zone" "main" {
  count = var.cloudflare_zone_id == "" ? 1 : 0
  name  = var.domain_name
}

resource "aws_route53_health_check" "aws_health" {
  count             = var.cloudflare_zone_id == "" ? 1 : 0
  fqdn              = var.aws_alb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "gcp_health" {
  count             = var.cloudflare_zone_id == "" ? 1 : 0
  ip_address        = var.gcp_lb_ip
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "www" {
  count   = var.cloudflare_zone_id == "" ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.aws_alb_dns
    zone_id                = data.aws_lb.alb.zone_id
    evaluate_target_health = true
  }

  set_identifier = "aws-primary"

  geolocation_routing_policy {
    continent = "NA"
  }

  health_check_id = aws_route53_health_check.aws_health[0].id
}

data "aws_lb" "alb" {
  name = var.aws_alb_dns
}

# Outputs
output "global_lb_hostname" {
  value       = var.domain_name
  description = "Global load balancer hostname"
}

output "aws_endpoint" {
  value       = "aws.${var.domain_name}"
  description = "AWS-specific endpoint"
}

output "gcp_endpoint" {
  value       = "gcp.${var.domain_name}"
  description = "GCP-specific endpoint"
}