output "api_url" {
  description = "API del acortador (docs en /docs)."
  value       = "http://localhost:${var.api_port}"
}

output "prometheus_url" {
  description = "Prometheus."
  value       = "http://localhost:${var.prometheus_port}"
}

output "grafana_url" {
  description = "Dashboard de Grafana (login anónimo como Viewer)."
  value       = "http://localhost:${var.grafana_port}/d/shortlink-service"
}

output "api_image" {
  description = "Imagen que corre la API."
  value       = docker_image.api.name
}
