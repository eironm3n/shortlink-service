variable "region" {
  description = "Región (LocalStack la acepta pero no la usa para nada real)."
  type        = string
  default     = "us-east-1"
}

variable "localstack_endpoint" {
  description = "URL de LocalStack."
  type        = string
  default     = "http://localhost:4566"
}

variable "state_bucket" {
  description = "Nombre del bucket del estado. Tiene que coincidir con infra/local/backend.tf."
  type        = string
  default     = "shortlink-tfstate"
}
