# Funciones y rutas compartidas por up.ps1, down.ps1 y demo-lock.ps1.
# Se carga con: . "$PSScriptRoot\_common.ps1"

$ErrorActionPreference = 'Stop'

$RepoRoot         = Split-Path -Parent $PSScriptRoot
$EnvFile          = Join-Path $RepoRoot '.env'
$LocalStackFile   = Join-Path $RepoRoot 'infra\localstack\docker-compose.yml'
$LocalStackProj   = 'shortlink-localstack'
$LocalStackUrl    = 'http://localhost:4566'
$BootstrapDir     = Join-Path $RepoRoot 'infra\bootstrap'
$LocalDir         = Join-Path $RepoRoot 'infra\local'
$StateBucket      = 'shortlink-tfstate'
$ManagedLabel     = 'managed-by=terraform-shortlink-local'

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

# Ejecuta un comando externo (terraform, docker) y corta el script si falla.
# $ErrorActionPreference se relaja durante la llamada porque docker y terraform
# escriben progreso en stderr, y PowerShell 5.1 lo trataria como error.
function Invoke-Native([scriptblock]$Command) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) { throw "Fallo (exit $code): $Command" }
}

# El token puede venir del .env (recomendado) o de una variable de entorno.
function Assert-AuthToken {
    if ($env:LOCALSTACK_AUTH_TOKEN) { return }
    if (Test-Path $EnvFile) {
        $line = Get-Content $EnvFile | Where-Object { $_ -match '^\s*LOCALSTACK_AUTH_TOKEN\s*=\s*\S+' }
        if ($line) { return }
    }
    throw "Falta LOCALSTACK_AUTH_TOKEN. Copia .env.example a .env y pega tu token (app.localstack.cloud -> Settings -> Auth Tokens)."
}

function Get-ComposeArgs {
    $composeArgs = @('compose')
    if (Test-Path $EnvFile) { $composeArgs += @('--env-file', $EnvFile) }
    $composeArgs += @('-f', $LocalStackFile)
    return $composeArgs
}

# LocalStack esta listo cuando su endpoint de salud reporta S3 disponible.
function Test-LocalStack {
    try {
        $health = Invoke-RestMethod "$LocalStackUrl/_localstack/health" -TimeoutSec 3
        return $health.services.s3 -in @('available', 'running')
    } catch {
        return $false
    }
}

function Wait-LocalStack([int]$TimeoutSec = 120) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-LocalStack) { Write-Host 'LocalStack listo (S3 disponible).'; return }
        $status = docker inspect -f '{{.State.Status}}' shortlink-localstack 2>$null
        if ($status -eq 'exited') {
            docker logs --tail 15 shortlink-localstack
            throw 'LocalStack se detuvo al arrancar (revisa el token en .env).'
        }
        Start-Sleep -Seconds 2
    }
    throw "LocalStack no respondio en $TimeoutSec s."
}

# Recursos con la etiqueta del modulo infra/local que existen en Docker.
function Get-Orphans {
    [pscustomobject]@{
        Containers = @(docker ps -aq --filter "label=$ManagedLabel")
        Networks   = @(docker network ls -q --filter "label=$ManagedLabel")
        Volumes    = @(docker volume ls -q --filter "label=$ManagedLabel")
    }
}

# Si el estado se perdio (p. ej. se apago LocalStack antes del destroy), los
# contenedores siguen vivos pero Terraform ya no sabe que existen. Se buscan por
# etiqueta, asi nunca se toca nada que no haya creado este modulo.
function Remove-Orphans {
    $o = Get-Orphans
    $total = $o.Containers.Count + $o.Networks.Count + $o.Volumes.Count
    if ($total -eq 0) { Write-Host 'Sin recursos huerfanos.'; return }

    Write-Host "Eliminando $total recurso(s) huerfano(s) con la etiqueta $ManagedLabel" -ForegroundColor Yellow
    if ($o.Containers.Count) { Invoke-Native { docker rm -f @($o.Containers) } }
    if ($o.Networks.Count)   { Invoke-Native { docker network rm @($o.Networks) } }
    if ($o.Volumes.Count)    { Invoke-Native { docker volume rm @($o.Volumes) } }
}

# true si el estado remoto de infra/local no tiene recursos (o no existe).
function Test-LocalStateEmpty {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $resources = & terraform "-chdir=$LocalDir" state list 2>$null
        if ($LASTEXITCODE -ne 0) { throw 'No se pudo leer el estado remoto.' }
    } finally {
        $ErrorActionPreference = $previous
    }
    return -not $resources
}
