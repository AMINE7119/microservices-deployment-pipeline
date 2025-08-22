# AWS CloudFront Edge Deployment Configuration

variable "aws_alb_domain" {
  description = "AWS ALB domain name"
  type        = string
}

variable "gcp_lb_domain" {
  description = "GCP Load Balancer domain"
  type        = string
}

variable "domain_name" {
  description = "Main domain name"
  type        = string
  default     = "microservices.example.com"
}

variable "s3_bucket_name" {
  description = "S3 bucket for static assets"
  type        = string
  default     = "microservices-static-assets"
}

variable "enable_waf" {
  description = "Enable AWS WAF for CloudFront"
  type        = bool
  default     = true
}

# S3 Bucket for Static Assets
resource "aws_s3_bucket" "static_assets" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for microservices static assets"
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_assets.arn}/*"
      }
    ]
  })
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "edge_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Microservices Edge CDN Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_All"  # Use all edge locations
  http_version        = "http2and3"       # Enable HTTP/3 QUIC

  aliases = [var.domain_name, "cdn.${var.domain_name}"]

  # Origin for S3 Static Assets
  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "S3-${var.s3_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # Origin for AWS ALB (Dynamic Content)
  origin {
    domain_name = var.aws_alb_domain
    origin_id   = "ALB-AWS"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-Edge-Location"
      value = "aws"
    }
  }

  # Origin for GCP Load Balancer (Fallback)
  origin {
    domain_name = var.gcp_lb_domain
    origin_id   = "LB-GCP"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 60
      origin_keepalive_timeout = 60
    }

    custom_header {
      name  = "X-Edge-Location"
      value = "gcp"
    }
  }

  # Origin Group for Failover
  origin_group {
    origin_id = "microservices-origin-group"

    failover_criteria {
      status_codes = [500, 502, 503, 504, 403, 404]
    }

    member {
      origin_id = "ALB-AWS"
    }

    member {
      origin_id = "LB-GCP"
    }
  }

  # Default Cache Behavior (Dynamic Content)
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "microservices-origin-group"
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Accept", "Accept-Language", "Accept-Encoding", "Authorization"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 31536000

    # Lambda@Edge functions
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.edge_auth.qualified_arn
      include_body = false
    }

    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = aws_lambda_function.edge_headers.qualified_arn
      include_body = false
    }
  }

  # Cache Behavior for Static Assets
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${var.s3_bucket_name}"
    compress         = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  # Cache Behavior for API
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "microservices-origin-group"
    compress         = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "https-only"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.edge_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.edge_waf[0].arn : null

  tags = {
    Name        = "microservices-edge-cdn"
    Environment = "production"
  }
}

# ACM Certificate for CloudFront
resource "aws_acm_certificate" "edge_cert" {
  provider          = aws.us_east_1  # CloudFront requires certificates in us-east-1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${var.domain_name}",
    "cdn.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda@Edge for Authentication
resource "aws_lambda_function" "edge_auth" {
  provider         = aws.us_east_1
  filename         = "edge-functions/auth.zip"
  function_name    = "edge-auth-function"
  role            = aws_iam_role.lambda_edge.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("edge-functions/auth.zip")
  runtime         = "nodejs18.x"
  publish         = true
}

# Lambda@Edge for Security Headers
resource "aws_lambda_function" "edge_headers" {
  provider         = aws.us_east_1
  filename         = "edge-functions/headers.zip"
  function_name    = "edge-headers-function"
  role            = aws_iam_role.lambda_edge.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("edge-functions/headers.zip")
  runtime         = "nodejs18.x"
  publish         = true
}

# IAM Role for Lambda@Edge
resource "aws_iam_role" "lambda_edge" {
  name = "lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "lambda.amazonaws.com",
            "edgelambda.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_edge_basic" {
  role       = aws_iam_role.lambda_edge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# WAF Web ACL for CloudFront
resource "aws_wafv2_web_acl" "edge_waf" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1
  name     = "edge-protection"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "edge-waf"
    sampled_requests_enabled   = true
  }
}

# Outputs
output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.edge_cdn.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.edge_cdn.domain_name
}

output "cloudfront_distribution_arn" {
  value = aws_cloudfront_distribution.edge_cdn.arn
}