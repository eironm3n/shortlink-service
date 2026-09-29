variable "docker_host" {
  description = "Daemon de Docker. En Windows con Docker Desktop: npipe:////./pipe/docker_engine; en Linux/macOS: unix:///var/run/docker.sock."
  type        = string
  default     = "npipe:////./pipe/docker_engine"
}

variable "build_local" {
  description = "true = construir la imagen desde el Dockerfile del repo; false = usar var.api_image (GHCR)."
  type        = bool
  default     = false
}

variable "api_image" {
  description = "Imagen publicada por el CI."
  type        = string
  default     = "ghcr.io/eironm3n/shortlink-service:latest"
}

variable "prometheus_image" {
  description = "Imagen de Prometheus (misma versión que docker-compose.yml)."
  type        = string
  default     = "prom/prometheus:v2.53.2"
}

variable "grafana_image" {
  description = "Imagen de Grafana (misma versión que docker-compose.yml)."
  type        = string
  default     = "grafana/grafana:11.2.0"
}

variable "api_port" {
  description = "Puerto del host para la API."
  type        = number
  default     = 8000
}

variable "prometheus_port" {
  description = "Puerto del host para Prometheus."
  type        = number
  default     = 9090
}

variable "grafana_port" {
  description = "Puerto del host para Grafana."
  type        = number
  default     = 3000
}
