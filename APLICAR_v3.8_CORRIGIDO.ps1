# ======================================================================
# INSTALAÇÃO - EventHandlers v3.8 CORRIGIDO
# Versão de PRODUÇÃO com wildcard corrigido
# ======================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  EventHandlers v3.8 CORRIGIDO - INSTALAÇÃO        ║" -ForegroundColor Green
Write-Host "║  Versão de PRODUÇÃO com wildcard CORRIGIDO         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Green

# Verificar Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERRO: Execute como Administrador!`n" -ForegroundColor Red
    exit 1
}

$scriptPath = $PSScriptRoot
$sourceFile = Join-Path $scriptPath "EventHandlers_v3.8_CORRIGIDO.vbs"
$targetFile = "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs"
$backupPath = "C:\hmail-backup"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Validações
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERRO: Arquivo v3.8 CORRIGIDO não encontrado!`n" -ForegroundColor Red
    exit 1
}

$service = Get-Service -Name "hMailServer" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "❌ ERRO: Serviço hMailServer não encontrado!`n" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Validações OK`n" -ForegroundColor Green

# Criar pasta de backup
if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Write-Host "✅ Pasta de backup criada: $backupPath`n" -ForegroundColor Green
}

# Backup
if (Test-Path $targetFile) {
    $backupFile = Join-Path $backupPath "EventHandlers_pre_v3.8_$timestamp.vbs"
    Copy-Item $targetFile $backupFile -Force
    Write-Host "💾 Backup criado: $backupFile" -ForegroundColor Cyan

    $backupInfo = Get-Item $backupFile
    Write-Host "   Tamanho: $($backupInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "   Data: $($backupInfo.LastWriteTime)`n" -ForegroundColor Gray
}

# Parar serviço
Write-Host "🛑 Parando hMailServer..." -ForegroundColor Yellow
try {
    Stop-Service -Name "hMailServer" -Force
    Start-Sleep -Seconds 3
    Write-Host "   ✅ Serviço parado`n" -ForegroundColor Green
} catch {
    Write-Host "   ❌ ERRO ao parar serviço: $_`n" -ForegroundColor Red
    exit 1
}

# Instalar
Write-Host "📝 Instalando EventHandlers v3.8 CORRIGIDO..." -ForegroundColor Yellow
try {
    Copy-Item $sourceFile $targetFile -Force

    $newFile = Get-Item $targetFile
    Write-Host "   ✅ Arquivo instalado" -ForegroundColor Green
    Write-Host "   Tamanho: $($newFile.Length) bytes" -ForegroundColor Gray
    Write-Host "   Modificado: $($newFile.LastWriteTime)`n" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ ERRO ao instalar: $_`n" -ForegroundColor Red

    # Restaurar backup
    if (Test-Path $backupFile) {
        Write-Host "🔄 Restaurando backup..." -ForegroundColor Yellow
        Copy-Item $backupFile $targetFile -Force
        Write-Host "   ✅ Backup restaurado`n" -ForegroundColor Green
    }
    exit 1
}

# Iniciar serviço
Write-Host "▶️ Iniciando hMailServer..." -ForegroundColor Yellow
try {
    Start-Service -Name "hMailServer"
    Start-Sleep -Seconds 5

    $service = Get-Service -Name "hMailServer"
    if ($service.Status -eq "Running") {
        Write-Host "   ✅ Serviço iniciado com sucesso!`n" -ForegroundColor Green
    } else {
        throw "Serviço não iniciou (Status: $($service.Status))"
    }
} catch {
    Write-Host "   ❌ ERRO ao iniciar serviço: $_`n" -ForegroundColor Red

    # Restaurar backup
    if (Test-Path $backupFile) {
        Write-Host "🔄 Restaurando backup..." -ForegroundColor Yellow
        Stop-Service -Name "hMailServer" -Force -ErrorAction SilentlyContinue
        Copy-Item $backupFile $targetFile -Force
        Start-Service -Name "hMailServer"
        Write-Host "   ✅ Backup restaurado e serviço reiniciado`n" -ForegroundColor Green
    }
    exit 1
}

# Verificar cache reload
Start-Sleep -Seconds 3
$logPath = "C:\hmail-lists\logs\AureaBlack_Lists.log"

if (Test-Path $logPath) {
    $recentLogs = Get-Content $logPath -Tail 10 -ErrorAction SilentlyContinue
    $cacheReload = $recentLogs | Where-Object { $_ -match "CACHE_RELOAD" }

    if ($cacheReload) {
        Write-Host "✅ Cache de listas carregado:" -ForegroundColor Green
        $cacheReload | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        Write-Host ""
    }
}

# Resumo final
Write-Host "╔════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                    ║" -ForegroundColor Green
Write-Host "║        ✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!        ║" -ForegroundColor Green
Write-Host "║                                                    ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 RESUMO:" -ForegroundColor Cyan
Write-Host "   ✅ Versão: v3.8 CORRIGIDO (produção)" -ForegroundColor White
Write-Host "   ✅ Wildcard: CORRIGIDO (*.xyz funciona!)" -ForegroundColor White
Write-Host "   ✅ Política: AUTH > BLACKLIST > WHITELIST > DEFAULT" -ForegroundColor White
Write-Host "   ✅ Cache: Reload automático (5 minutos)" -ForegroundColor White
Write-Host "   ✅ Serviço: Rodando" -ForegroundColor White
Write-Host "   ✅ Backup: $backupFile`n" -ForegroundColor White

Write-Host "📋 CORREÇÕES APLICADAS:" -ForegroundColor Yellow
Write-Host "   ✅ BUG DE WILDCARD CORRIGIDO!" -ForegroundColor Green
Write-Host "      • Ordem de escape de regex corrigida" -ForegroundColor White
Write-Host "      • *.xyz, *.econettreinamento funcionam corretamente" -ForegroundColor White
Write-Host "      • Wildcards processados ANTES de escapar pontos`n" -ForegroundColor White

Write-Host "🎯 O QUE ESPERAR:" -ForegroundColor Yellow
Write-Host "   ✅ Emails de blacklist_domains.txt serão BLOQUEADOS" -ForegroundColor White
Write-Host "   ✅ Wildcards *.xyz, *.econettreinamento funcionam" -ForegroundColor White
Write-Host "   ✅ Whitelist tem prioridade (emails legítimos passam)" -ForegroundColor White
Write-Host "   ✅ Autenticados sempre passam`n" -ForegroundColor White

Write-Host "📊 MONITORAMENTO (opcional):" -ForegroundColor Cyan
Write-Host "   # Ver logs em tempo real:" -ForegroundColor Gray
Write-Host "   Get-Content '$logPath' -Wait -Tail 20`n" -ForegroundColor Gray
Write-Host "   # Ver últimos bloqueios:" -ForegroundColor Gray
Write-Host "   Get-Content '$logPath' -Tail 50 | Select-String 'BLOCK_BLACK'`n" -ForegroundColor Gray
Write-Host "   # Ver últimas permissões:" -ForegroundColor Gray
Write-Host "   Get-Content '$logPath' -Tail 50 | Select-String 'ALLOW_AUREA'`n" -ForegroundColor Gray

Write-Host "✅ Instalação v3.8 CORRIGIDO concluída em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Green
Write-Host ""
