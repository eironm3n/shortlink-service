# El estado de este despliegue vive en el bucket S3 que crea infra/bootstrap,
# dentro de LocalStack. Un bloque backend no admite variables: los valores van
# fijos y el bucket tiene que coincidir con var.state_bucket del bootstrap.

terraform {
  backend "s3" {
    bucket = "shortlink-tfstate"
    key    = "local/terraform.tfstate"
    region = "us-east-1"

    # Lock nativo de S3 (Terraform >= 1.11): mientras dura una operación existe
    # local/terraform.tfstate.tflock en el bucket, creado con una escritura
    # condicional (If-None-Match). Reemplaza a la tabla DynamoDB (deprecada).
    use_lockfile = true
    encrypt      = true

    # LocalStack en vez de AWS.
    endpoints = {
      s3 = "http://localhost:4566"
    }
    use_path_style              = true
    access_key                  = "test"
    secret_key                  = "test"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
  }
}
