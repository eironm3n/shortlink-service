terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Managed container runtime on AWS Lightsail: the cheapest way to run a single
# always-on container with a public HTTPS endpoint and health checks.
resource "aws_lightsail_container_service" "this" {
  name        = var.service_name
  power       = "nano"
  scale       = 1
  is_disabled = false

  tags = {
    Project   = "shortlink-service"
    ManagedBy = "terraform"
  }
}

resource "aws_lightsail_container_service_deployment_version" "this" {
  service_name = aws_lightsail_container_service.this.name

  container {
    container_name = "api"
    image          = var.image

    ports = {
      "8000" = "HTTP"
    }

    environment = {
      SHORTLINK_BASE_URL = "https://${var.service_name}.local"
      SHORTLINK_VERSION  = var.image_tag
    }
  }

  public_endpoint {
    container_name = "api"
    container_port = 8000

    health_check {
      path                = "/healthz"
      success_codes       = "200"
      interval_seconds    = 30
      timeout_seconds     = 5
      healthy_threshold   = 2
      unhealthy_threshold = 3
    }
  }
}
