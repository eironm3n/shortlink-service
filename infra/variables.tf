variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "service_name" {
  description = "Name of the Lightsail container service."
  type        = string
  default     = "shortlink-service"
}

variable "image" {
  description = "Container image to deploy (must be publicly pullable)."
  type        = string
  default     = "ghcr.io/eironm3n/shortlink-service:latest"
}

variable "image_tag" {
  description = "Human-readable tag reported by the app on /version."
  type        = string
  default     = "lightsail"
}
