# ======================================================================
# SCRIPT DE INSTALAÇÃO - EventHandlers v3.6 DEBUG
# Instala versão com logging detalhado para diagnosticar o bug
# ======================================================================

param(
    [switch]$AutoConfirm = $false
)

$ErrorActionPreference = "Stop"

# ==================== CONFIGURAÇÕES ====================
$scriptPath = $PSScriptRoot
$hmailEventsPath = "C:\Program Files (x86)\hMailServer\Events"
$backupPath = "C:\hmail-backup"
$logPath = "C:\hmail-lists\logs\AureaBlack_Lists.log"

$sourceFile = Join-Path $scriptPath "EventHandlers_v3.6_DEBUG.vbs"
$targetFile = Join-Path $hmailEventsPath "EventHandlers.vbs"

# ==================== BANNER ====================
Write-Host "`n" -NoNewline
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                        ║" -ForegroundColor Cyan
Write-Host "║      INSTALAÇÃO EventHandlers v3.6 DEBUG              ║" -ForegroundColor Cyan
Write-Host "║      Diagnóstico de False Positives                   ║" -ForegroundColor Cyan
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

# Verificar se arquivo debug existe
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERRO: Arquivo $sourceFile não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Arquivo DEBUG encontrado" -ForegroundColor Green

# Verificar se serviço existe
$service = Get-Service -Name "hMailServer" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "❌ ERRO: Serviço hMailServer não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Serviço hMailServer encontrado (Status: $($service.Status))" -ForegroundColor Green

Write-Host ""

# ==================== INFORMAÇÕES IMPORTANTES ====================
Write-Host "📋 SOBRE ESTA VERSÃO DEBUG`n" -ForegroundColor Yellow
Write-Host "  Esta versão v3.6 DEBUG irá:" -ForegroundColor White
Write-Host "  ✅ Logar CADA verificação de lista (whitelist/blacklist)" -ForegroundColor White
Write-Host "  ✅ Mostrar QUAL entrada deu match" -ForegroundColor White
Write-Host "  ✅ Identificar se foi match exato ou wildcard" -ForegroundColor White
Write-Host "  ✅ Revelar a causa dos false positives" -ForegroundColor White
Write-Host ""
Write-Host "  ⚠️ O log ficará GRANDE devido ao debug detalhado!" -ForegroundColor Yellow
Write-Host "  💡 Use esta versão apenas para diagnosticar o problema" -ForegroundColor Cyan
Write-Host ""

# ==================== CONFIRMAÇÃO FINAL ====================
if (-not $AutoConfirm) {
    Write-Host "⚠️ ATENÇÃO! Esta operação irá:" -ForegroundColor Yellow
    Write-Host "  1. Fazer backup do EventHandlers.vbs atual (v3.5)" -ForegroundColor White
    Write-Host "  2. Parar o serviço hMailServer" -ForegroundColor White
    Write-Host "  3. Substituir pelo EventHandlers v3.6 DEBUG" -ForegroundColor White
    Write-Host "  4. Reiniciar o serviço hMailServer" -ForegroundColor White
    Write-Host "  5. Ativar logging DEBUG detalhado" -ForegroundColor White
    Write-Host ""
    $confirm = Read-Host "Digite 'CONFIRMO' para prosseguir"

    if ($confirm -ne "CONFIRMO") {
        Write-Host "❌ Instalação cancelada pelo usuário." -ForegroundColor Red
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
$backupFile = Join-Path $backupPath "EventHandlers_v3.5_$timestamp.vbs"

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

# ==================== LIMPAR LOG ANTERIOR (OPCIONAL) ====================
Write-Host "🧹 PREPARAR LOG`n" -ForegroundColor Yellow

if (Test-Path $logPath) {
    Write-Host "  ℹ️ Log atual tem $((Get-Content $logPath).Count) linhas" -ForegroundColor Cyan

    if (-not $AutoConfirm) {
        $clearLog = Read-Host "  Deseja LIMPAR o log para facilitar análise? (S/N)"
        if ($clearLog -eq "S" -or $clearLog -eq "s") {
            # Fazer backup do log antes de limpar
            $logBackup = "C:\hmail-lists\logs\AureaBlack_Lists_backup_$timestamp.log"
            Copy-Item $logPath $logBackup -Force
            Write-Host "  ✅ Backup do log: $logBackup" -ForegroundColor Green

            Clear-Content $logPath
            Write-Host "  ✅ Log limpo!" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️ Log mantido (não limpo)" -ForegroundColor Cyan
        }
    }
} else {
    Write-Host "  ℹ️ Log será criado automaticamente" -ForegroundColor Cyan
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
        Write-Host "  ⚠️ Aguardando serviço parar completamente..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Host "  ❌ ERRO ao parar serviço: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ==================== SUBSTITUIR ARQUIVO ====================
Write-Host "📝 INSTALANDO VERSÃO DEBUG`n" -ForegroundColor Yellow

try {
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "  ✅ EventHandlers v3.6 DEBUG instalado!" -ForegroundColor Green

    $newFile = Get-Item $targetFile
    Write-Host "     Arquivo: $targetFile" -ForegroundColor Gray
    Write-Host "     Tamanho: $($newFile.Length) bytes" -ForegroundColor Gray
    Write-Host "     Modificado: $($newFile.LastWriteTime)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ ERRO ao instalar: $_" -ForegroundColor Red
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
        Write-Host "  ✅ Serviço iniciado com sucesso!" -ForegroundColor Green
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
        Write-Host "  ✅ Cache recarregado detectado no log!" -ForegroundColor Green
        $cacheReload | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ⚠️ Cache reload não detectado ainda (normal, aguarde primeiro email)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️ Log não encontrado (será criado no primeiro email)" -ForegroundColor Yellow
}

Write-Host ""

# ==================== RESUMO FINAL ====================
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "║        ✅ VERSÃO DEBUG INSTALADA COM SUCESSO           ║" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📊 RESUMO:"-ForegroundColor Cyan
Write-Host "  ✅ Versão: v3.5 → v3.6 DEBUG" -ForegroundColor White
Write-Host "  ✅ Backup: $backupFile" -ForegroundColor White
Write-Host "  ✅ Serviço: Rodando" -ForegroundColor White
Write-Host "  ✅ Debug: ATIVADO" -ForegroundColor White
Write-Host ""

Write-Host "📋 PRÓXIMOS PASSOS IMPORTANTES:`n" -ForegroundColor Yellow

Write-Host "1️⃣ MONITORAR O LOG EM TEMPO REAL:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Wait -Tail 50`n" -ForegroundColor Gray

Write-Host "2️⃣ AGUARDAR PRÓXIMO EMAIL DE SPAM:" -ForegroundColor Cyan
Write-Host "   O próximo email de econettreinamento.net.br, promovoo.xyz ou inovti.com.br" -ForegroundColor White
Write-Host "   que entrar na caixa vai gerar logs DEBUG mostrando:" -ForegroundColor White
Write-Host "   • Qual lista foi consultada (WL_EMAIL, WL_DOMAIN, BL_EMAIL, etc.)" -ForegroundColor Gray
Write-Host "   • Quantas entradas foram verificadas" -ForegroundColor Gray
Write-Host "   • QUAL ENTRADA DEU MATCH (se houver)" -ForegroundColor Gray
Write-Host "   • Se foi match exato ou wildcard`n" -ForegroundColor Gray

Write-Host "3️⃣ PROCURAR LINHAS COM 'DEBUG' NO LOG:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' | Select-String 'DEBUG'`n" -ForegroundColor Gray

Write-Host "4️⃣ QUANDO O SPAM ENTRAR, ENVIE O LOG COMPLETO:" -ForegroundColor Cyan
Write-Host "   Pegue as últimas 100 linhas do log e me envie:" -ForegroundColor White
Write-Host "   Get-Content '$logPath' -Tail 100 | Out-File 'C:\debug_output.txt'`n" -ForegroundColor Gray

Write-Host "5️⃣ EXEMPLO DO QUE VOCÊ VERÁ:" -ForegroundColor Cyan
Write-Host "   DEBUG [WL_EMAIL]: Checking key='treinamento@econettreinamento.net.br' against 127 entries" -ForegroundColor Gray
Write-Host "   DEBUG [WL_EMAIL]: MATCH! Wildcard '*@econet*' matched 'treinamento@econettreinamento.net.br'" -ForegroundColor Gray
Write-Host "   ^--- Isso revelará qual entrada da whitelist está causando o problema!`n" -ForegroundColor Yellow

Write-Host "⚠️ IMPORTANTE:" -ForegroundColor Red
Write-Host "  • Esta versão DEBUG gera MUITOS logs (normal e esperado)" -ForegroundColor White
Write-Host "  • Deixe rodando até capturar o próximo spam" -ForegroundColor White
Write-Host "  • Depois de diagnosticar, vamos criar v3.7 FINAL com correção definitiva`n" -ForegroundColor White

Write-Host "🆘 ROLLBACK (se necessário):" -ForegroundColor Yellow
Write-Host "  Stop-Service -Name 'hMailServer' -Force" -ForegroundColor Gray
Write-Host "  Copy-Item '$backupFile' '$targetFile' -Force" -ForegroundColor Gray
Write-Host "  Start-Service -Name 'hMailServer'`n" -ForegroundColor Gray

Write-Host "✅ Instalação DEBUG finalizada em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Green
Write-Host ""
Write-Host "💡 DICA: Abra outro PowerShell e execute:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Wait -Tail 30" -ForegroundColor White
Write-Host "   para ver os logs em tempo real enquanto aguarda o spam.`n" -ForegroundColor White
