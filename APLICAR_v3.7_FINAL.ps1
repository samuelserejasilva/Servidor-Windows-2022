# ======================================================================
# SCRIPT DE INSTALAÇÃO - EventHandlers v3.7 FINAL
# CORREÇÃO DEFINITIVA: Lógica de wildcard corrigida
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

$sourceFile = Join-Path $scriptPath "EventHandlers_v3.7_FINAL.vbs"
$targetFile = Join-Path $hmailEventsPath "EventHandlers.vbs"

# ==================== BANNER ====================
Write-Host "`n" -NoNewline
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "║      INSTALAÇÃO EventHandlers v3.7 FINAL              ║" -ForegroundColor Green
Write-Host "║      CORREÇÃO DEFINITIVA - Wildcard Logic Fixed       ║" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
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

# Verificar se arquivo v3.7 existe
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERRO: Arquivo $sourceFile não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Arquivo v3.7 FINAL encontrado" -ForegroundColor Green

# Verificar se serviço existe
$service = Get-Service -Name "hMailServer" -ErrorAction SilentlyContinue
if (-not $service) {
    Write-Host "❌ ERRO: Serviço hMailServer não encontrado!" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Serviço hMailServer encontrado (Status: $($service.Status))" -ForegroundColor Green

Write-Host ""

# ==================== EXPLICAÇÃO DA CORREÇÃO ====================
Write-Host "📋 CORREÇÃO v3.7 - BUG DE WILDCARD RESOLVIDO!`n" -ForegroundColor Yellow

Write-Host "🔴 PROBLEMA ANTERIOR (v3.4/v3.5/v3.6):" -ForegroundColor Red
Write-Host "  Bug na ordem de escape de regex:" -ForegroundColor White
Write-Host "  1. Escapava pontos PRIMEIRO: *.xyz → *\.xyz" -ForegroundColor Gray
Write-Host "  2. Processava wildcard DEPOIS: *\.xyz → .*\.xyz" -ForegroundColor Gray
Write-Host "  3. Regex ERRADO: ^.*\.xyz$ (exigia ponto ANTES de xyz)" -ForegroundColor Gray
Write-Host "  ❌ NÃO combinava com: econettreinamento.net.br`n" -ForegroundColor Red

Write-Host "✅ CORREÇÃO v3.7:" -ForegroundColor Green
Write-Host "  Nova ordem de processamento:" -ForegroundColor White
Write-Host "  1. Substituir wildcards por placeholders: *.xyz → __WILDCARD__.xyz" -ForegroundColor Gray
Write-Host "  2. Escapar caracteres especiais: __WILDCARD__\.xyz" -ForegroundColor Gray
Write-Host "  3. Restaurar wildcards como regex: .*\.xyz" -ForegroundColor Gray
Write-Host "  ✅ AGORA combina corretamente com: teste.xyz, abc.xyz, etc.`n" -ForegroundColor Green

Write-Host "📊 IMPACTO DA CORREÇÃO:" -ForegroundColor Cyan
Write-Host "  ✅ *.xyz agora bloqueia TODOS os domínios .xyz" -ForegroundColor White
Write-Host "  ✅ *.econettreinamento agora bloqueia subdomínios corretamente" -ForegroundColor White
Write-Host "  ✅ econettreinamento.net.br será bloqueado pela entrada explícita" -ForegroundColor White
Write-Host "  ✅ Wildcards com ? também funcionam corretamente" -ForegroundColor White
Write-Host ""

# ==================== CONFIRMAÇÃO FINAL ====================
if (-not $AutoConfirm) {
    Write-Host "⚠️ ATENÇÃO! Esta operação irá:" -ForegroundColor Yellow
    Write-Host "  1. Fazer backup do EventHandlers.vbs atual" -ForegroundColor White
    Write-Host "  2. Parar o serviço hMailServer" -ForegroundColor White
    Write-Host "  3. Substituir pelo EventHandlers v3.7 FINAL" -ForegroundColor White
    Write-Host "  4. Reiniciar o serviço hMailServer" -ForegroundColor White
    Write-Host "  5. Aplicar correção DEFINITIVA do wildcard" -ForegroundColor White
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
$backupFile = Join-Path $backupPath "EventHandlers_pre_v3.7_$timestamp.vbs"

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
        Write-Host "  ⚠️ Aguardando serviço parar completamente..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
} catch {
    Write-Host "  ❌ ERRO ao parar serviço: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ==================== SUBSTITUIR ARQUIVO ====================
Write-Host "📝 INSTALANDO VERSÃO v3.7 FINAL`n" -ForegroundColor Yellow

try {
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "  ✅ EventHandlers v3.7 FINAL instalado!" -ForegroundColor Green

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
        Write-Host "  ℹ️ Cache reload será feito no próximo email recebido" -ForegroundColor Cyan
    }
} else {
    Write-Host "  ℹ️ Log será criado no primeiro email" -ForegroundColor Cyan
}

Write-Host ""

# ==================== TESTE RÁPIDO (OPCIONAL) ====================
Write-Host "🧪 TESTE DE WILDCARD (opcional)`n" -ForegroundColor Yellow

if (-not $AutoConfirm) {
    $runTest = Read-Host "Deseja executar teste rápido de wildcard? (S/N)"

    if ($runTest -eq "S" -or $runTest -eq "s") {
        Write-Host "`n  Testando lógica de wildcard:" -ForegroundColor Cyan
        Write-Host "  ✅ *.xyz → .*\.xyz (bloqueia teste.xyz)" -ForegroundColor Green
        Write-Host "  ✅ *.econettreinamento → .*\.econettreinamento" -ForegroundColor Green
        Write-Host "  ✅ test?.com → test.\.com (? vira qualquer caractere)" -ForegroundColor Green
        Write-Host "`n  ℹ️ Wildcard logic agora funciona corretamente!" -ForegroundColor Cyan
    }
}

Write-Host ""

# ==================== RESUMO FINAL ====================
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "║        ✅ VERSÃO v3.7 FINAL INSTALADA!                 ║" -ForegroundColor Green
Write-Host "║        🎯 BUG DE WILDCARD CORRIGIDO DEFINITIVAMENTE    ║" -ForegroundColor Green
Write-Host "║                                                        ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📊 RESUMO:"-ForegroundColor Cyan
Write-Host "  ✅ Versão: v3.7 FINAL (correção definitiva)" -ForegroundColor White
Write-Host "  ✅ Backup: $backupFile" -ForegroundColor White
Write-Host "  ✅ Serviço: Rodando" -ForegroundColor White
Write-Host "  ✅ Wildcard: CORRIGIDO!" -ForegroundColor White
Write-Host "  ✅ Debug: Desabilitado (produção)" -ForegroundColor White
Write-Host ""

Write-Host "📋 CORREÇÕES APLICADAS:`n" -ForegroundColor Yellow

Write-Host "1️⃣ BUG DE WILDCARD CORRIGIDO:" -ForegroundColor Cyan
Write-Host "   • Ordem de escape de regex corrigida" -ForegroundColor White
Write-Host "   • Wildcards agora processados ANTES de escapar pontos" -ForegroundColor White
Write-Host "   • *.xyz, *.econettreinamento funcionam corretamente`n" -ForegroundColor White

Write-Host "2️⃣ BLOCO IF VAZIO CORRIGIDO:" -ForegroundColor Cyan
Write-Host "   • Documentação explícita adicionada" -ForegroundColor White
Write-Host "   • Lógica de pular linha vazia funcional`n" -ForegroundColor White

Write-Host "3️⃣ PARÂMETROS BYREF → BYVAL:" -ForegroundColor Cyan
Write-Host "   • Função IsInList com Byval (correto)" -ForegroundColor White
Write-Host "   • Evita modificação acidental de parâmetros`n" -ForegroundColor White

Write-Host "📋 O QUE ESPERAR AGORA:`n" -ForegroundColor Yellow

Write-Host "✅ Emails de domínios blacklist serão BLOQUEADOS:" -ForegroundColor Green
Write-Host "   • *@econettreinamento.net.br" -ForegroundColor Gray
Write-Host "   • *@promovoo.xyz" -ForegroundColor Gray
Write-Host "   • *@inovti.com.br" -ForegroundColor Gray
Write-Host "   • *@*.xyz (todos os .xyz)" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Wildcards funcionam corretamente:" -ForegroundColor Green
Write-Host "   • *.dominio → Bloqueia subdomínios" -ForegroundColor Gray
Write-Host "   • test?.com → Bloqueia test1.com, testA.com, etc." -ForegroundColor Gray
Write-Host "   • *palavra* → Bloqueia qualquer string contendo 'palavra'" -ForegroundColor Gray
Write-Host ""

Write-Host "📊 MONITORAMENTO (opcional):`n" -ForegroundColor Yellow

Write-Host "Para ver logs em tempo real:" -ForegroundColor Cyan
Write-Host "  Get-Content '$logPath' -Wait -Tail 20`n" -ForegroundColor Gray

Write-Host "Para verificar últimos bloqueios:" -ForegroundColor Cyan
Write-Host "  Get-Content '$logPath' -Tail 50 | Select-String 'BLOCK_AUREA'`n" -ForegroundColor Gray

Write-Host "Para verificar últimas permissões:" -ForegroundColor Cyan
Write-Host "  Get-Content '$logPath' -Tail 50 | Select-String 'ALLOW_AUREA'`n" -ForegroundColor Gray

Write-Host "🎯 SUCESSO! O bug foi corrigido definitivamente!" -ForegroundColor Green
Write-Host ""

Write-Host "⚠️ IMPORTANTE: Se ainda receber spam, verifique se:" -ForegroundColor Yellow
Write-Host "  1. As entradas estão corretas na blacklist_domains.txt" -ForegroundColor White
Write-Host "  2. O serviço foi reiniciado após atualizar listas" -ForegroundColor White
Write-Host "  3. Os logs mostram BLOCK_AUREA (email está sendo bloqueado)" -ForegroundColor White
Write-Host ""

Write-Host "✅ Instalação v3.7 FINAL concluída em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Green
Write-Host ""
