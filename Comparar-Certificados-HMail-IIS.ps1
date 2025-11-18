# ============================================================================
# COMPARAR-CERTIFICADOS-HMAIL-IIS.PS1
# Comparação entre Certificados do hMailServer e IIS
# ============================================================================

Write-Host "`n🔍 COMPARAÇÃO DE CERTIFICADOS: hMailServer vs IIS" -ForegroundColor Green
Write-Host "=" * 55

# Verificar se é administrador
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n❌ ERRO: Execute como Administrador!" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎯 OBJETIVO: Verificar se ambos os serviços usam o mesmo certificado" -ForegroundColor Yellow

# Função para obter informações do certificado
function Get-CertificateInfo {
    param([string]$Subject, [string]$Source)
    
    try {
        # Buscar certificado por subject
        $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { 
            $_.Subject -like "*$Subject*" -or 
            $_.DnsNameList -contains $Subject -or
            $_.Subject -like "*portalauditoria*"
        } | Sort-Object NotAfter -Descending | Select-Object -First 1
        
        if ($cert) {
            return @{
                Source             = $Source
                Subject            = $cert.Subject
                Issuer             = $cert.Issuer
                Thumbprint         = $cert.Thumbprint
                NotBefore          = $cert.NotBefore
                NotAfter           = $cert.NotAfter
                SerialNumber       = $cert.SerialNumber
                FriendlyName       = $cert.FriendlyName
                DnsNames           = $cert.DnsNameList.Unicode -join ", "
                KeyLength          = $cert.PublicKey.Key.KeySize
                SignatureAlgorithm = $cert.SignatureAlgorithm.FriendlyName
                Status             = "✅ Encontrado"
            }
        }
        else {
            return @{
                Source = $Source
                Status = "❌ Não encontrado"
            }
        }
    }
    catch {
        return @{
            Source = $Source
            Status = "❌ Erro: $($_.Exception.Message)"
        }
    }
}

# Função para obter configuração do hMailServer
function Get-hMailCertificateConfig {
    Write-Host "`n🔍 Verificando configuração do hMailServer..." -ForegroundColor Cyan
    
    $hmailConfigPath = "C:\Program Files (x86)\hMailServer\Bin\hMailServer.ini"
    
    if (Test-Path $hmailConfigPath) {
        try {
            $config = Get-Content $hmailConfigPath
            $sslConfig = $config | Where-Object { $_ -like "*SSL*" -or $_ -like "*Certificate*" -or $_ -like "*TLS*" }
            
            Write-Host "   📄 Configurações SSL encontradas:" -ForegroundColor Yellow
            foreach ($line in $sslConfig) {
                Write-Host "      $line" -ForegroundColor Gray
            }
            
            # Procurar por thumbprint específico
            $thumbprintLine = $config | Where-Object { $_ -like "*Thumbprint*" -or $_ -like "*Certificate*" }
            if ($thumbprintLine) {
                Write-Host "`n   🔑 Configuração de certificado:" -ForegroundColor Yellow
                foreach ($line in $thumbprintLine) {
                    Write-Host "      $line" -ForegroundColor Gray
                }
            }
            
        }
        catch {
            Write-Host "   ❌ Erro ao ler configuração: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "   ❌ Arquivo de configuração não encontrado: $hmailConfigPath" -ForegroundColor Red
    }
}

# Função para obter configuração do IIS
function Get-IISCertificateConfig {
    Write-Host "`n🔍 Verificando configuração do IIS..." -ForegroundColor Cyan
    
    try {
        # Verificar se o módulo WebAdministration está disponível
        Import-Module WebAdministration -ErrorAction Stop
        
        # Obter bindings HTTPS
        $sslBindings = Get-WebBinding | Where-Object { $_.protocol -eq "https" }
        
        if ($sslBindings) {
            Write-Host "   📄 Bindings HTTPS encontrados:" -ForegroundColor Yellow
            
            foreach ($binding in $sslBindings) {
                Write-Host "`n      🌐 Site: $($binding.ItemXPath -replace '.*name=.([^.]+).*', '$1')" -ForegroundColor Green
                Write-Host "         📍 Endereço: $($binding.bindingInformation)" -ForegroundColor Gray
                Write-Host "         🔗 Protocolo: $($binding.protocol)" -ForegroundColor Gray
                
                # Tentar obter o certificado do binding
                $certHash = $binding.certificateHash
                if ($certHash) {
                    Write-Host "         🔑 Hash do Certificado: $certHash" -ForegroundColor Gray
                    
                    # Buscar certificado pelo hash
                    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $certHash }
                    if ($cert) {
                        Write-Host "         📋 Subject: $($cert.Subject)" -ForegroundColor Gray
                        Write-Host "         📅 Válido até: $($cert.NotAfter.ToString('dd/MM/yyyy HH:mm'))" -ForegroundColor Gray
                    }
                }
                else {
                    Write-Host "         ⚠️  Nenhum certificado associado" -ForegroundColor Yellow
                }
            }
            
            return $sslBindings
        }
        else {
            Write-Host "   ⚠️  Nenhum binding HTTPS encontrado" -ForegroundColor Yellow
            return $null
        }
        
    }
    catch {
        Write-Host "   ❌ Erro ao verificar IIS: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "   💡 Tentando método alternativo..." -ForegroundColor Yellow
        
        # Método alternativo usando netsh
        try {
            $netshOutput = netsh http show sslcert
            Write-Host "   📄 Configurações SSL (netsh):" -ForegroundColor Yellow
            
            $relevantLines = $netshOutput | Where-Object { $_ -like "*443*" -or $_ -like "*Certificate Hash*" -or $_ -like "*portalauditoria*" }
            foreach ($line in $relevantLines) {
                Write-Host "      $line" -ForegroundColor Gray
            }
        }
        catch {
            Write-Host "   ❌ Erro no método alternativo: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return $null
    }
}

# Função para comparar certificados
function Compare-Certificates {
    param($HmailCert, $IISCert)
    
    Write-Host "`n📊 COMPARAÇÃO DOS CERTIFICADOS:" -ForegroundColor Yellow
    
    if ($HmailCert.Status -like "*Encontrado*" -and $IISCert.Status -like "*Encontrado*") {
        
        Write-Host "`n   🔍 Comparando thumbprints..." -ForegroundColor Cyan
        
        if ($HmailCert.Thumbprint -eq $IISCert.Thumbprint) {
            Write-Host "   ✅ MESMO CERTIFICADO! Thumbprints idênticos" -ForegroundColor Green
            Write-Host "      🔑 Thumbprint: $($HmailCert.Thumbprint)" -ForegroundColor Gray
        }
        else {
            Write-Host "   ❌ CERTIFICADOS DIFERENTES!" -ForegroundColor Red
            Write-Host "      🔑 hMailServer: $($HmailCert.Thumbprint)" -ForegroundColor Red
            Write-Host "      🔑 IIS: $($IISCert.Thumbprint)" -ForegroundColor Red
        }
        
        Write-Host "`n   📋 Detalhes dos certificados:" -ForegroundColor Cyan
        
        $properties = @('Subject', 'Issuer', 'NotAfter', 'SerialNumber', 'KeyLength', 'SignatureAlgorithm')
        
        foreach ($prop in $properties) {
            $hmailValue = $HmailCert.$prop
            $iisValue = $IISCert.$prop
            
            if ($hmailValue -eq $iisValue) {
                Write-Host "      ✅ $prop`: $hmailValue" -ForegroundColor Green
            }
            else {
                Write-Host "      ❌ $prop`:" -ForegroundColor Red
                Write-Host "         hMail: $hmailValue" -ForegroundColor Red
                Write-Host "         IIS: $iisValue" -ForegroundColor Red
            }
        }
        
    }
    else {
        Write-Host "   ⚠️  Não é possível comparar - um ou ambos certificados não foram encontrados" -ForegroundColor Yellow
        
        if ($HmailCert.Status -notlike "*Encontrado*") {
            Write-Host "      ❌ hMailServer: $($HmailCert.Status)" -ForegroundColor Red
        }
        
        if ($IISCert.Status -notlike "*Encontrado*") {
            Write-Host "      ❌ IIS: $($IISCert.Status)" -ForegroundColor Red
        }
    }
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

Write-Host "`n🚀 INICIANDO VERIFICAÇÃO..." -ForegroundColor Green

# 1. Listar todos os certificados disponíveis
Write-Host "`n📋 CERTIFICADOS INSTALADOS:" -ForegroundColor Yellow
$allCerts = Get-ChildItem Cert:\LocalMachine\My | Where-Object { 
    $_.Subject -like "*portalauditoria*" -or 
    $_.DnsNameList.Unicode -contains "portalauditoria.com.br" -or
    $_.DnsNameList.Unicode -contains "mail.portalauditoria.com.br"
} | Sort-Object NotAfter -Descending

if ($allCerts) {
    foreach ($cert in $allCerts) {
        $status = if ($cert.NotAfter -gt (Get-Date)) { "✅ Válido" } else { "❌ Expirado" }
        Write-Host "`n   📄 Subject: $($cert.Subject)" -ForegroundColor Cyan
        Write-Host "      🔑 Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "      📅 Válido: $($cert.NotBefore.ToString('dd/MM/yyyy')) até $($cert.NotAfter.ToString('dd/MM/yyyy'))" -ForegroundColor Gray
        Write-Host "      📝 DNS Names: $($cert.DnsNameList.Unicode -join ', ')" -ForegroundColor Gray
        Write-Host "      🏷️  Status: $status" -ForegroundColor $(if ($status -like "*Válido*") { "Green" } else { "Red" })
    }
}
else {
    Write-Host "   ❌ Nenhum certificado para portalauditoria.com.br encontrado!" -ForegroundColor Red
}

# 2. Verificar configuração do hMailServer
Get-hMailCertificateConfig

# 3. Verificar configuração do IIS
$iisBindings = Get-IISCertificateConfig

# 4. Obter informações específicas dos certificados
Write-Host "`n🔍 OBTENDO INFORMAÇÕES ESPECÍFICAS..." -ForegroundColor Cyan

$hmailCert = Get-CertificateInfo "portalauditoria.com.br" "hMailServer"
$iisCert = Get-CertificateInfo "portalauditoria.com.br" "IIS"

# 5. Comparar certificados
Compare-Certificates $hmailCert $iisCert

# 6. Verificar conectividade externa
Write-Host "`n🌐 TESTE DE CONECTIVIDADE EXTERNA:" -ForegroundColor Yellow

Write-Host "`n   📧 SMTP (porta 25):" -ForegroundColor Cyan
try {
    $smtpTest = Test-NetConnection -ComputerName "mail.portalauditoria.com.br" -Port 25 -InformationLevel Quiet
    if ($smtpTest) {
        Write-Host "      ✅ Porta 25 acessível" -ForegroundColor Green
    }
    else {
        Write-Host "      ❌ Porta 25 não acessível" -ForegroundColor Red
    }
}
catch {
    Write-Host "      ❌ Erro no teste: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n   🌐 HTTPS (porta 443):" -ForegroundColor Cyan
try {
    $httpsTest = Test-NetConnection -ComputerName "portalauditoria.com.br" -Port 443 -InformationLevel Quiet
    if ($httpsTest) {
        Write-Host "      ✅ Porta 443 acessível" -ForegroundColor Green
    }
    else {
        Write-Host "      ❌ Porta 443 não acessível" -ForegroundColor Red
    }
}
catch {
    Write-Host "      ❌ Erro no teste: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n" + "=" * 55
Write-Host "🎯 RESUMO DA VERIFICAÇÃO" -ForegroundColor Green

Write-Host "`n📊 RESULTADO:" -ForegroundColor Yellow
if ($hmailCert.Thumbprint -and $iisCert.Thumbprint) {
    if ($hmailCert.Thumbprint -eq $iisCert.Thumbprint) {
        Write-Host "   ✅ Certificados IDÊNTICOS - Configuração correta!" -ForegroundColor Green
    }
    else {
        Write-Host "   ⚠️  Certificados DIFERENTES - Pode precisar sincronizar" -ForegroundColor Yellow
    }
}
else {
    Write-Host "   ❌ Não foi possível determinar - Verifique configurações" -ForegroundColor Red
}

Write-Host "`n💡 RECOMENDAÇÕES:" -ForegroundColor Cyan
Write-Host "   • Ambos os serviços devem usar o mesmo certificado" -ForegroundColor White
Write-Host "   • Verifique se as configurações estão apontando para o certificado correto" -ForegroundColor White
Write-Host "   • Reinicie os serviços após alterações de certificado" -ForegroundColor White

Write-Host "`n✨ VERIFICAÇÃO CONCLUÍDA!" -ForegroundColor Green
