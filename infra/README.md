# Infra — Terraform (AWS Lightsail Containers)

Infraestructura como código para desplegar la imagen del servicio en un
**AWS Lightsail Container Service** (`nano`, 1 réplica): la forma más barata de
tener un contenedor siempre encendido con endpoint HTTPS público y health check.

## Qué crea

| Recurso | Para qué |
|---|---|
| `aws_lightsail_container_service` | El runtime administrado del contenedor |
| `aws_lightsail_container_service_deployment_version` | La versión de despliegue: imagen, puerto, variables de entorno y health check sobre `/healthz` |

## Uso

```bash
cd infra
terraform init
terraform plan  -var="image=ghcr.io/eironm3n/shortlink-service:latest"
terraform apply -var="image=ghcr.io/eironm3n/shortlink-service:latest"
terraform output url
```

Para destruir todo: `terraform destroy`.

## Costo

El plan `nano` cuesta ~**USD 7/mes** mientras el servicio esté activo. Por eso
**no se aplica automáticamente**: el pipeline de CI sólo corre
`terraform fmt -check`, `init -backend=false` y `validate` — no necesita
credenciales de AWS ni genera gasto.

## Notas

- La imagen tiene que ser **públicamente descargable** (el paquete de GHCR de
  este repo es público).
- El estado (`terraform.tfstate`) queda local y está en `.gitignore`. Para uso
  real, configurar un backend remoto (S3 + DynamoDB lock).
