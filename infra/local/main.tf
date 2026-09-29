# Despliegue local con el provider de Docker: Terraform crea en esta PC la red,
# la API, Prometheus y Grafana (lo mismo que docker-compose.yml, pero como IaC y
# con el estado guardado en el backend remoto; ver backend.tf).

terraform {
  required_version = ">= 1.11"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
  }
}

provider "docker" {
  host = var.docker_host
}

locals {
  repo_root  = abspath("${path.module}/../..")
  monitoring = "${local.repo_root}/monitoring"

  # Todo lo que crea este módulo lleva esta etiqueta: scripts/up.ps1 y
  # down.ps1 la usan para encontrar recursos huérfanos si el estado se perdió.
  labels = {
    "managed-by" = "terraform-shortlink-local"
  }

  # Si cambia el código, el Dockerfile o las dependencias, se reconstruye.
  build_hash = sha1(join("", [
    for f in concat(["Dockerfile", "requirements.txt"], sort(fileset(local.repo_root, "app/**/*.py"))) :
    filesha1("${local.repo_root}/${f}")
  ]))
}

# --- Red ----------------------------------------------------------------------

resource "docker_network" "this" {
  name = "shortlink-local"

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# --- API ----------------------------------------------------------------------

# Por defecto, la misma imagen que el CI escaneó con Trivy y publicó en GHCR.
# Con build_local = true se construye desde el Dockerfile del repo.
resource "docker_image" "api" {
  name         = var.build_local ? "shortlink-service:terraform-local" : var.api_image
  keep_locally = true

  dynamic "build" {
    for_each = var.build_local ? [1] : []
    content {
      context = local.repo_root
    }
  }

  triggers = var.build_local ? { build_hash = local.build_hash } : {}
}

resource "docker_volume" "api_data" {
  name = "shortlink-local-data"

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

resource "docker_container" "api" {
  name    = "shortlink-api"
  image   = docker_image.api.image_id
  restart = "unless-stopped"

  env = [
    "SHORTLINK_BASE_URL=http://localhost:${var.api_port}",
    "SHORTLINK_VERSION=terraform-local",
  ]

  ports {
    internal = 8000
    external = var.api_port
    ip       = "127.0.0.1"
  }

  # Alias "api": es el nombre que usa monitoring/prometheus.yml como target.
  networks_advanced {
    name    = docker_network.this.id
    aliases = ["api"]
  }

  volumes {
    volume_name    = docker_volume.api_data.name
    container_path = "/data"
  }

  # La imagen trae HEALTHCHECK sobre /healthz: `apply` no termina hasta que la
  # API responde de verdad.
  wait         = true
  wait_timeout = 90

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}

# --- Prometheus ---------------------------------------------------------------

resource "docker_image" "prometheus" {
  name         = var.prometheus_image
  keep_locally = true
}

resource "docker_container" "prometheus" {
  name    = "shortlink-prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"
  command = ["--config.file=/etc/prometheus/prometheus.yml"]

  # Misma configuración que usa docker compose: una sola fuente de verdad.
  upload {
    file    = "/etc/prometheus/prometheus.yml"
    content = file("${local.monitoring}/prometheus.yml")
  }

  ports {
    internal = 9090
    external = var.prometheus_port
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name    = docker_network.this.id
    aliases = ["prometheus"]
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_container.api]
}

# --- Grafana ------------------------------------------------------------------

resource "docker_image" "grafana" {
  name         = var.grafana_image
  keep_locally = true
}

resource "docker_container" "grafana" {
  name    = "shortlink-grafana"
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin",
    "GF_AUTH_ANONYMOUS_ENABLED=true",
    "GF_AUTH_ANONYMOUS_ORG_ROLE=Viewer",
    "GF_USERS_DEFAULT_THEME=light",
  ]

  # Datasource y dashboard aprovisionados desde monitoring/ (los mismos
  # archivos que monta docker compose).
  upload {
    file    = "/etc/grafana/provisioning/datasources/datasource.yml"
    content = file("${local.monitoring}/grafana/provisioning/datasources/datasource.yml")
  }

  upload {
    file    = "/etc/grafana/provisioning/dashboards/dashboards.yml"
    content = file("${local.monitoring}/grafana/provisioning/dashboards/dashboards.yml")
  }

  upload {
    file    = "/var/lib/grafana/dashboards/shortlink.json"
    content = file("${local.monitoring}/grafana/dashboards/shortlink.json")
  }

  ports {
    internal = 3000
    external = var.grafana_port
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = docker_network.this.id
  }

  dynamic "labels" {
    for_each = local.labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  depends_on = [docker_container.prometheus]
}
