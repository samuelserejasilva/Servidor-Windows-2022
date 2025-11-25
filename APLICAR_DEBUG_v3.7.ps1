# ======================================================================
# INSTALAÇÃO RÁPIDA - EventHandlers v3.7 DEBUG
# Para diagnosticar problemas de whitelist/blacklist
# ======================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  EventHandlers v3.7 DEBUG - INSTALAÇÃO    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Verificar Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERRO: Execute como Administrador!`n" -ForegroundColor Red
    exit 1
}

$scriptPath = $PSScriptRoot
$sourceFile = Join-Path $scriptPath "EventHandlers_v3.7_DEBUG.vbs"
$targetFile = "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs"
$backupPath = "C:\hmail-backup"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Criar pasta de backup
if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
}

# Backup
if (Test-Path $targetFile) {
    $backupFile = Join-Path $backupPath "EventHandlers_pre_DEBUG_$timestamp.vbs"
    Copy-Item $targetFile $backupFile -Force
    Write-Host "✅ Backup criado: $backupFile" -ForegroundColor Green
}

# Parar serviço
Write-Host "🛑 Parando hMailServer..." -ForegroundColor Yellow
Stop-Service -Name "hMailServer" -Force
Start-Sleep -Seconds 3

# Instalar
Write-Host "📝 Instalando v3.7 DEBUG..." -ForegroundColor Yellow
Copy-Item $sourceFile $targetFile -Force

# Iniciar
Write-Host "▶️ Iniciando hMailServer..." -ForegroundColor Yellow
Start-Service -Name "hMailServer"
Start-Sleep -Seconds 5

# Verificar
$service = Get-Service -Name "hMailServer"
if ($service.Status -eq "Running") {
    Write-Host "`n✅ INSTALAÇÃO CONCLUÍDA!" -ForegroundColor Green
    Write-Host "   Versão: v3.7 DEBUG" -ForegroundColor White
    Write-Host "   DEBUG_MODE: ATIVADO" -ForegroundColor White
    Write-Host "   Serviço: Rodando`n" -ForegroundColor White

    Write-Host "📊 MONITORAR LOGS EM TEMPO REAL:" -ForegroundColor Cyan
    Write-Host "   Get-Content 'C:\hmail-lists\logs\AureaBlack_Lists.log' -Wait -Tail 30`n" -ForegroundColor Gray

    Write-Host "🔍 VER LINHAS DEBUG:" -ForegroundColor Cyan
    Write-Host "   Get-Content 'C:\hmail-lists\logs\AureaBlack_Lists.log' -Tail 100 | Select-String 'DEBUG'`n" -ForegroundColor Gray

    Write-Host "⚠️ IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "   • Esta versão DEBUG gera MUITOS logs" -ForegroundColor White
    Write-Host "   • Use apenas para diagnóstico (1-2 dias)" -ForegroundColor White
    Write-Host "   • Depois volte para v3.7 FINAL (sem debug)`n" -ForegroundColor White
} else {
    Write-Host "`n❌ ERRO: Serviço não iniciou!" -ForegroundColor Red
    Write-Host "   Status: $($service.Status)`n" -ForegroundColor Red
}
