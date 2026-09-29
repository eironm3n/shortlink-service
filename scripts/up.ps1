<#
.SYNOPSIS
    Levanta todo el entorno local: LocalStack -> bootstrap -> despliegue.

.DESCRIPTION
    1. LocalStack (Docker): emula S3 en localhost:4566.
    2. infra/bootstrap: crea el bucket S3 del estado (su propio estado es local).
    3. infra/local: init contra el backend S3 y limpieza de huerfanos.
    4. infra/local: terraform apply -> red, API, Prometheus y Grafana en Docker.

.PARAMETER BuildLocal
    Construye la imagen de la API desde el Dockerfile en vez de usar la de GHCR.

.EXAMPLE
    .\scripts\up.ps1
    .\scripts\up.ps1 -BuildLocal
#>
[CmdletBinding()]
param([switch]$BuildLocal)

. "$PSScriptRoot\_common.ps1"

Write-Step '1/4 LocalStack: emulador de AWS en localhost:4566'
Assert-AuthToken
$compose = Get-ComposeArgs
Invoke-Native { docker @compose up -d }
Wait-LocalStack

Write-Step '2/4 Bootstrap: bucket S3 para el estado remoto'
Invoke-Native { terraform "-chdir=$BootstrapDir" init -input=false }
Invoke-Native { terraform "-chdir=$BootstrapDir" apply -auto-approve -input=false }

Write-Step '3/4 Despliegue: init contra el backend S3 y limpieza de huerfanos'
Invoke-Native { terraform "-chdir=$LocalDir" init -input=false }
if (Test-LocalStateEmpty) {
    Remove-Orphans
} else {
    Write-Host 'El estado remoto ya tiene recursos: apply los reconcilia.'
}

Write-Step '4/4 Despliegue: terraform apply (Docker)'
$tfVars = @()
if ($BuildLocal) { $tfVars += '-var=build_local=true' }
Invoke-Native { terraform "-chdir=$LocalDir" apply -auto-approve -input=false @tfVars }

Write-Step 'Listo'
Invoke-Native { terraform "-chdir=$LocalDir" output }
Write-Host ''
Write-Host "Estado en el bucket: docker exec shortlink-localstack awslocal s3 ls s3://$StateBucket --recursive"
Write-Host 'Para bajar todo:      .\scripts\down.ps1'
