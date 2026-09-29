# Bootstrap del backend remoto: crea el bucket S3 donde infra/local guarda su
# estado. Es el problema del huevo y la gallina: este módulo no puede guardar su
# propio estado en un bucket que todavía no existe, así que su estado es LOCAL
# (terraform.tfstate en esta carpeta, fuera de git).
#
# Apunta a LocalStack (http://localhost:4566), no a AWS: las credenciales son
# falsas y se saltean las validaciones que sólo tienen sentido contra AWS real.

terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = "test"
  secret_key = "test"

  # No hay IAM/STS ni metadata de EC2 reales que consultar.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # localhost:4566/<bucket> en vez de <bucket>.s3.amazonaws.com
  s3_use_path_style = true

  endpoints {
    s3 = var.localstack_endpoint
  }
}

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket

  # El bucket guarda todas las versiones del estado; sin esto `destroy` falla
  # porque el bucket no está vacío. En AWS real se dejaría en false.
  force_destroy = true

  tags = {
    Project   = "shortlink-service"
    ManagedBy = "terraform"
    Purpose   = "terraform-state"
  }
}

# Versionado: cada `apply` deja una versión nueva del estado, así que un estado
# corrupto o borrado por error se puede recuperar.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# El estado puede contener secretos (contraseñas, IPs, ARNs): cifrado en reposo.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Y nunca público.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
