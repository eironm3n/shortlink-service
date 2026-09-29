<#
.SYNOPSIS
    Baja todo el entorno local en orden inverso: despliegue -> bootstrap -> LocalStack.

.DESCRIPTION
    El orden importa: el estado del despliegue vive dentro de LocalStack, que en el
    plan gratuito no persiste. Si se apagara LocalStack primero, Terraform perderia
    el estado y los contenedores quedarian huerfanos. Si eso ya paso, este script
    los encuentra por etiqueta y los elimina igual.
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"

if (Test-LocalStack) {
    Write-Step '1/3 Despliegue: terraform destroy (el estado esta en LocalStack)'
    Invoke-Native { terraform "-chdir=$LocalDir" init -input=false }
    Invoke-Native { terraform "-chdir=$LocalDir" destroy -auto-approve -input=false }

    Write-Step '2/3 Bootstrap: terraform destroy del bucket del estado'
    Invoke-Native { terraform "-chdir=$BootstrapDir" init -input=false }
    Invoke-Native { terraform "-chdir=$BootstrapDir" destroy -auto-approve -input=false }
} else {
    Write-Step '1/3 LocalStack no esta corriendo: el estado remoto se perdio'
    Write-Host 'Se salta el destroy; los recursos se limpian por etiqueta.' -ForegroundColor Yellow
    Write-Step '2/3 (bootstrap: nada que destruir, el bucket se fue con LocalStack)'
}

# Red de seguridad: tras un destroy correcto no deberia quedar nada.
Remove-Orphans

Write-Step '3/3 LocalStack: docker compose down'
Invoke-Native { docker compose -p $LocalStackProj down }

Write-Step 'Listo: no queda nada corriendo.'
