param(
    [string]$KeyDir,                             # se vier do wrapper, usa
    [string]$CertRootDir = 'C:\Certificados',    # senão, procura key-YYYYMMDD-HHMM aqui
    [string]$HmailAdminUser = 'Administrator',
    [string]$HmailAdminPass = '',                # opcional (evite usar)
    [string]$HmailAdminPassFile = 'C:\Certificados\hmail.pass',  # <-- arquivo DPAPI
    [string]$HmailCertName = 'letsencrypt-2025'
)
function Fail($m) { Write-Error $m; exit 1 }
Add-Type -AssemblyName System.Security
function Read-Dpapi([string]$p) {
    $enc = [IO.File]::ReadAllBytes($p)
    $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $enc, $null, [System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Text.Encoding]::UTF8.GetString($bytes)
}

# Resolve KeyDir
if (-not $KeyDir) {
    Write-Host ">> Procurando diretório de chaves mais recente em $CertRootDir..."
    $KeyDir = Get-ChildItem -Path $CertRootDir -Directory |
    Where-Object { $_.Name -match '^key-\d{8}-\d{4}$' } |
    Sort-Object Name -Descending |
    Select-Object -ExpandProperty FullName -First 1
    if (-not $KeyDir) { Fail "Nenhum diretório 'key-YYYYMMDD-HHMM' encontrado em $CertRootDir" }
}
Write-Host "   Usando diretório: $KeyDir"

$certFile = Join-Path $KeyDir 'fullchain.key'
$keyFile = Join-Path $KeyDir 'privkey.key'
if (!(Test-Path $certFile) -or !(Test-Path $keyFile)) { Fail "Arquivos .key não encontrados em $KeyDir" }

# Senha: prioridade Pass -> PassFile -> erro
if ([string]::IsNullOrWhiteSpace($HmailAdminPass)) {
    if (Test-Path $HmailAdminPassFile) {
        $HmailAdminPass = Read-Dpapi $HmailAdminPassFile
    }
    else { 
        Fail "HmailAdminPass não informado e $HmailAdminPassFile ausente." 
    }
}

try {
    Write-Host ">> Atualizando hMailServer (SSL '$HmailCertName')..."
    
    # Verificar se o hMailServer está rodando
    $service = Get-Service -Name "hMailServer" -ErrorAction SilentlyContinue
    if (-not $service) { throw "Serviço hMailServer não encontrado" }
    if ($service.Status -ne 'Running') { throw "Serviço hMailServer não está rodando (Status: $($service.Status))" }
    
    Write-Host "   Conectando via COM..."
    $hmail = New-Object -ComObject hMailServer.Application -ErrorAction Stop
    
    Write-Host "   Autenticando como '$HmailAdminUser'..."
    $authResult = $hmail.Authenticate($HmailAdminUser, $HmailAdminPass)
    if (-not $authResult) { throw "Falha na autenticação - usuário ou senha inválidos" }
    
    Write-Host "   Acessando configurações SSL..."
    $sslCerts = $hmail.Settings.SSLCertificates
    if (-not $sslCerts) { throw "Não foi possível acessar as configurações SSL do hMailServer" }
    $ssl = $null
    for ($i = 0; $i -lt $sslCerts.Count; $i++) {
        $c = $sslCerts.Item($i)
        if ($c.Name -eq $HmailCertName) { $ssl = $c; break }
    }
    if (-not $ssl) {
        Write-Host "   Criando item SSL '$HmailCertName'..."
        $ssl = $sslCerts.Add()
        $ssl.Name = $HmailCertName
    }
    else {
        Write-Host "   Atualizando item SSL existente '$HmailCertName'..."
    }

    Write-Host "   Certificate: $certFile"
    Write-Host "   PrivateKey : $keyFile"
    $ssl.CertificateFile = $certFile
    $ssl.PrivateKeyFile = $keyFile
    
    Write-Host "   Salvando configuração SSL..."
    $ssl.Save()

    Write-Host "   Reiniciando serviço hMailServer..."
    Restart-Service -Name hMailServer -Force -ErrorAction Stop
    Write-Host "OK: hMail atualizado e reiniciado."
    exit 0
}
catch {
    Fail "Falha ao atualizar hMail: $($_.Exception.Message)"
}
