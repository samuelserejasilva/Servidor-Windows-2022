#Requires -RunAsAdministrator
param(
    [string]$Base = 'C:\Certificados',
    [string]$PfxPath,                          # WACS preenche com {CacheFile}
    [string]$PfxPassword,                      # WACS preenche com {CachePassword}
    [switch]$UpdateHmail = $false,
    [string]$HmailAdminUser = 'Administrator',
    [string]$HmailAdminPass = '',
    [string]$HmailCertName = 'letsencrypt-2025'
)

function Fail($m) { Write-Error $m; exit 1 }

# caminhos dos scripts de lógica (podem ser alterados à vontade, sem tocar no WACS)
$s1 = Join-Path $Base '01-extract-keys.ps1'
$s2 = Join-Path $Base '02-update-hmail.ps1'

if (!(Test-Path $s1)) { Fail "Script não encontrado: $s1" }

# 1) extrai chaves/PEM a partir do PFX -> devolve a pasta key-AAAAmmdd-HHmm
$keyDir = & powershell -NoProfile -ExecutionPolicy Bypass -File $s1 `
    -Base $Base -PfxPath $PfxPath -PfxPassword $PfxPassword
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($keyDir)) {
    Fail "Falha na extração de chaves (01-extract-keys.ps1)."
}
Write-Host ">> Pasta gerada: $keyDir"

# 2) opcional: atualiza hMail usando a pasta gerada
if ($UpdateHmail) {
    if (!(Test-Path $s2)) {
        Write-Warning "02-update-hmail.ps1 não encontrado; pulando atualização do hMail."
    }
    else {
        # Nova versão: usa arquivo DPAPI por padrão, sem passar senha na linha de comando
        & powershell -NoProfile -ExecutionPolicy Bypass -File $s2 `
            -KeyDir $keyDir `
            -HmailAdminUser $HmailAdminUser `
            -HmailAdminPassFile "C:\Certificados\hmail.pass" `
            -HmailCertName $HmailCertName
        if ($LASTEXITCODE -ne 0) { Fail "Falha ao atualizar hMail (02-update-hmail.ps1)." }
    }
}

exit
