# ======================================================================
# SCRIPT DE ATUALIZAÇÃO AUTOMATIZADA - EventHandlers v3.5
# Aplica a correção com segurança e validações
# ======================================================================

param(
    [switch]$SkipTests = $false,
    [switch]$AutoConfirm = $false
)

$ErrorActionPreference = "Stop"

# ==================== CONFIGURAÇÕES ====================
$scriptPath = $PSScriptRoot
$hmailEventsPath = "C:\Program Files (x86)\hMailServer\Events"
$backupPath = "C:\hmail-backup"
$logPath = "C:\hmail-lists\logs\AureaBlack_Lists.log"

$sourceFile = Join-Path $scriptPath "EventHandlers_v3.5_CORRIGIDO.vbs"
$targetFile = Join-Path $hmailEventsPath "EventHandlers.vbs"
$testScript = Join-Path $scriptPath "TESTE_EventHandlers_v3.5.ps1"

# ==================== BANNER ====================
Write-Host "`n" -NoNewline
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                        ║" -ForegroundColor Cyan
Write-Host "║      ATUALIZAÇÃO EventHandlers v3.4 → v3.5            ║" -ForegroundColor Cyan
Write-Host "║      Correção de Bugs Críticos                        ║" -ForegroundColor Cyan
Write-Host "║                                                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ==================== VALIDAÇÕES PRÉ-INSTALAÇÃO ====================
Write-Host "🔍 VALIDAÇÕES PRÉ-INSTALAÇÃO`n" -ForegroundColor Yellow

# Verificar se está rodando como Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERRO: Este script precisa ser executado como Administrador!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Executando como Administrador" -ForegroundColor Green

# Verificar se arquivo corrigido existe
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERRO: Arquivo $sourceFile não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Arquivo corrigido encontrado" -ForegroundColor Green

# Verificar se serviço existe
$service = Get-Service -Name "hMailServer" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "❌ ERRO: Serviço hMailServer não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Serviço hMailServer encontrado (Status: $($service.Status))" -ForegroundColor Green

# Verificar se arquivo alvo existe
if (-not (Test-Path $targetFile)) {
    Write-Host "⚠️ AVISO: Arquivo alvo $targetFile não existe!" -ForegroundColor Yellow
    Write-Host "  Será criado um novo arquivo." -ForegroundColor Yellow
} else {
    Write-Host "  ✅ Arquivo alvo existe (será feito backup)" -ForegroundColor Green
}

Write-Host ""

# ==================== EXECUTAR TESTES ====================
if (-not $SkipTests) {
    Write-Host "🧪 EXECUTANDO TESTES`n" -ForegroundColor Yellow

    if (Test-Path $testScript) {
        try {
            & pwsh $testScript
            Write-Host ""

            if (-not $AutoConfirm) {
                $continue = Read-Host "Os testes passaram? Digite 'SIM' para continuar"
                if ($continue -ne "SIM") {
                    Write-Host "❌ Atualização cancelada pelo usuário." -ForegroundColor Red
                    exit 0
                }
            }
        } catch {
            Write-Host "❌ ERRO ao executar testes: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "⚠️ AVISO: Script de teste não encontrado. Pulando testes." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Testes pulados (--SkipTests)" -ForegroundColor Yellow
}

Write-Host ""

# ==================== CONFIRMAÇÃO FINAL ====================
if (-not $AutoConfirm) {
    Write-Host "⚠️ ATENÇÃO! Esta operação irá:" -ForegroundColor Yellow
    Write-Host "  1. Parar o serviço hMailServer" -ForegroundColor White
    Write-Host "  2. Fazer backup do EventHandlers.vbs atual" -ForegroundColor White
    Write-Host "  3. Substituir pelo EventHandlers v3.5" -ForegroundColor White
    Write-Host "  4. Reiniciar o serviço hMailServer" -ForegroundColor White
    Write-Host ""
    $confirm = Read-Host "Digite 'CONFIRMO' para prosseguir"

    if ($confirm -ne "CONFIRMO") {
        Write-Host "❌ Atualização cancelada pelo usuário." -ForegroundColor Red
        exit 0
    }
}

Write-Host ""

# ==================== CRIAR PASTA DE BACKUP ====================
Write-Host "💾 CRIANDO BACKUP`n" -ForegroundColor Yellow

if (-not (Test-Path $backupPath)) {
    New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    Write-Host "  ✅ Pasta de backup criada: $backupPath" -ForegroundColor Green
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = Join-Path $backupPath "EventHandlers_v3.4_$timestamp.vbs"

if (Test-Path $targetFile) {
    Copy-Item $targetFile $backupFile -Force
    Write-Host "  ✅ Backup criado: $backupFile" -ForegroundColor Green

    $backupInfo = Get-Item $backupFile
    Write-Host "     Tamanho: $($backupInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "     Data: $($backupInfo.LastWriteTime)" -ForegroundColor Gray
} else {
    Write-Host "  ⚠️ Arquivo original não existe, backup não criado" -ForegroundColor Yellow
}

Write-Host ""

# ==================== PARAR SERVIÇO ====================
Write-Host "🛑 PARANDO SERVIÇO hMailServer`n" -ForegroundColor Yellow

try {
    Stop-Service -Name "hMailServer" -Force
    Start-Sleep -Seconds 2

    $service = Get-Service -Name "hMailServer"
    if ($service.Status -eq "Stopped") {
        Write-Host "  ✅ Serviço parado com sucesso" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Serviço não está totalmente parado (Status: $($service.Status))" -ForegroundColor Yellow
        Write-Host "  Aguardando mais 5 segundos..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Host "  ❌ ERRO ao parar serviço: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ==================== SUBSTITUIR ARQUIVO ====================
Write-Host "📝 SUBSTITUINDO ARQUIVO`n" -ForegroundColor Yellow

try {
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "  ✅ Arquivo substituído com sucesso" -ForegroundColor Green

    $newFile = Get-Item $targetFile
    Write-Host "     Arquivo: $targetFile" -ForegroundColor Gray
    Write-Host "     Tamanho: $($newFile.Length) bytes" -ForegroundColor Gray
    Write-Host "     Modificado: $($newFile.LastWriteTime)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ ERRO ao substituir arquivo: $_" -ForegroundColor Red
    Write-Host "`n🔄 RESTAURANDO BACKUP..." -ForegroundColor Yellow

    if (Test-Path $backupFile) {
        Copy-Item $backupFile $targetFile -Force
        Write-Host "  ✅ Backup restaurado" -ForegroundColor Green
    }

    exit 1
}

Write-Host ""

# ==================== INICIAR SERVIÇO ====================
Write-Host "▶️ INICIANDO SERVIÇO hMailServer`n" -ForegroundColor Yellow

try {
    Start-Service -Name "hMailServer"
    Start-Sleep -Seconds 5

    $service = Get-Service -Name "hMailServer"
    if ($service.Status -eq "Running") {
        Write-Host "  ✅ Serviço iniciado com sucesso (Status: $($service.Status))" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Serviço não está rodando! (Status: $($service.Status))" -ForegroundColor Red
        throw "Serviço não iniciou corretamente"
    }
} catch {
    Write-Host "  ❌ ERRO ao iniciar serviço: $_" -ForegroundColor Red
    Write-Host "`n🔄 RESTAURANDO BACKUP..." -ForegroundColor Yellow

    if (Test-Path $backupFile) {
        Stop-Service -Name "hMailServer" -Force -ErrorAction SilentlyContinue
        Copy-Item $backupFile $targetFile -Force
        Start-Service -Name "hMailServer"
        Write-Host "  ✅ Backup restaurado e serviço reiniciado" -ForegroundColor Green
    }

    exit 1
}

Write-Host ""

# ==================== VALIDAÇÃO PÓS-INSTALAÇÃO ====================
Write-Host "✅ VALIDAÇÃO PÓS-INSTALAÇÃO`n" -ForegroundColor Yellow

Start-Sleep -Seconds 3

# Verificar se o log foi atualizado
if (Test-Path $logPath) {
    $logContent = Get-Content $logPath -Tail 10 -ErrorAction SilentlyContinue
    $cacheReload = $logContent | Where-Object { $_ -match "CACHE_RELOAD" }

    if ($cacheReload) {
        Write-Host "  ✅ Cache recarregado detectado no log:" -ForegroundColor Green
        $cacheReload | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ⚠️ Cache reload não detectado ainda (pode levar alguns segundos)" -ForegroundColor Yellow
        Write-Host "     Envie um email de teste para forçar o reload" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️ Log não encontrado em $logPath" -ForegroundColor Yellow
}

Write-Host ""

# ==================== RESUMO FINAL ====================
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "║           ✅ ATUALIZAÇÃO CONCLUÍDA COM SUCESSO         ║" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📊 RESUMO:" -ForegroundColor Cyan
Write-Host "  ✅ Versão: v3.4 → v3.5" -ForegroundColor White
Write-Host "  ✅ Backup: $backupFile" -ForegroundColor White
Write-Host "  ✅ Serviço: Rodando" -ForegroundColor White
Write-Host ""

Write-Host "📋 PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "  1. Monitorar o log:" -ForegroundColor White
Write-Host "     Get-Content '$logPath' -Wait -Tail 20" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Enviar email de teste de domínio blacklist:" -ForegroundColor White
Write-Host "     De: no-reply@promovoo.xyz" -ForegroundColor Gray
Write-Host "     Para: contato@portalauditoria.com.br" -ForegroundColor Gray
Write-Host "     Esperado: 550 BLOCK_BLACK" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Verificar headers dos emails recebidos:" -ForegroundColor White
Write-Host "     Procurar por: X-AureaBlack-Decision" -ForegroundColor Gray
Write-Host ""

Write-Host "🆘 ROLLBACK (se necessário):" -ForegroundColor Red
Write-Host "  Stop-Service -Name 'hMailServer' -Force" -ForegroundColor Gray
Write-Host "  Copy-Item '$backupFile' '$targetFile' -Force" -ForegroundColor Gray
Write-Host "  Start-Service -Name 'hMailServer'" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Atualização finalizada em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Green
Write-Host ""
