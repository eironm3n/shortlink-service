output "url" {
  description = "Public HTTPS URL of the container service."
  value       = aws_lightsail_container_service.this.url
}

output "state" {
  description = "Current state of the container service."
  value       = aws_lightsail_container_service.this.state
}
