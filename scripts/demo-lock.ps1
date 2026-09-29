<#
.SYNOPSIS
    Demuestra el lock del estado con dos `terraform apply` simultaneos.

.DESCRIPTION
    A: un apply que reemplaza el contenedor de la API (tarda unos segundos y
       mantiene el lock mientras tanto), en segundo plano.
    B: un segundo apply lanzado mientras A corre. Tiene que fallar con
       "Error acquiring the state lock".
    Entre medio se lista el bucket para ver el archivo .tflock.

    Requiere el entorno levantado con .\scripts\up.ps1. Reinicia la API.
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"

if (-not (Test-LocalStack)) { throw 'LocalStack no esta corriendo: primero .\scripts\up.ps1' }

function Show-Bucket {
    docker exec shortlink-localstack awslocal s3 ls "s3://$StateBucket/local/"
}

Write-Step 'Bucket antes: solo el estado'
Show-Bucket

Write-Step 'A: terraform apply -replace=docker_container.api (en segundo plano)'
$jobA = Start-Job -ArgumentList $LocalDir -ScriptBlock {
    param($dir)
    terraform "-chdir=$dir" apply -auto-approve -input=false -no-color -replace=docker_container.api 2>&1
}

# Esperar a que A tome el lock (aparece el .tflock en el bucket).
$deadline = (Get-Date).AddSeconds(60)
do {
    Start-Sleep -Milliseconds 500
    $listing = Show-Bucket
} until (($listing -match '\.tflock') -or (Get-Date) -gt $deadline)

Write-Step 'Bucket mientras A corre: aparece el lock'
$listing

Write-Step 'B: segundo terraform apply, al mismo tiempo'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& terraform "-chdir=$LocalDir" apply -auto-approve -input=false -no-color -lock-timeout=0s 2>&1 | Out-Host
$codeB = $LASTEXITCODE
$ErrorActionPreference = $previous
Write-Host "B termino con exit code $codeB (esperado: 1, lock ocupado)" -ForegroundColor Yellow

Write-Step 'Resultado de A'
Receive-Job -Job $jobA -Wait | Select-Object -Last 3
Remove-Job -Job $jobA

Write-Step 'Bucket despues: A libero el lock'
Show-Bucket
