# ======================================================================
# INSTALAÇÃO - EventHandlers v3.8 DEBUG SUPER DETALHADO
# RESTART DO SERVIÇO + Logs extremamente detalhados
# ======================================================================

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║   EventHandlers v3.8 DEBUG SUPER DETALHADO                 ║" -ForegroundColor Cyan
Write-Host "║   RESTART + Logs completos para diagnóstico                ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Verificar Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ ERRO: Execute como Administrador!`n" -ForegroundColor Red
    exit 1
}

$scriptPath = $PSScriptRoot
$sourceFile = Join-Path $scriptPath "EventHandlers_v3.8_DEBUG_SUPER_DETALHADO.vbs"
$targetFile = "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs"
$backupPath = "C:\hmail-backup"
$logPath = "C:\hmail-lists\logs\AureaBlack_Lists.log"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  ATENÇÃO: Esta versão gera LOGS EXTREMAMENTE DETALHADOS!" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "📋 O QUE ESTA VERSÃO DEBUG FAZ:`n" -ForegroundColor Cyan
Write-Host "  ✅ Mostra TODAS as informações do email recebido" -ForegroundColor White
Write-Host "  ✅ Mostra quantas entradas tem em cada lista" -ForegroundColor White
Write-Host "  ✅ Mostra CADA comparação de whitelist/blacklist" -ForegroundColor White
Write-Host "  ✅ Mostra transformação completa de regex wildcard" -ForegroundColor White
Write-Host "  ✅ Mostra decisão final detalhada" -ForegroundColor White
Write-Host "  ✅ BUG DE WILDCARD CORRIGIDO (*.xyz funciona!)" -ForegroundColor Green
Write-Host ""

Write-Host "⚠️ IMPORTANTE:`n" -ForegroundColor Yellow
Write-Host "  • Log vai ficar MUITO GRANDE (normal e esperado)" -ForegroundColor White
Write-Host "  • Use apenas para diagnosticar (1-2 dias)" -ForegroundColor White
Write-Host "  • Depois volte para v3.8 CORRIGIDO (sem debug)`n" -ForegroundColor White

# Validações
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ ERRO: Arquivo DEBUG não encontrado!`n" -ForegroundColor Red
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

# Backup da versão atual
if (Test-Path $targetFile) {
    $backupFile = Join-Path $backupPath "EventHandlers_pre_DEBUG_$timestamp.vbs"
    Copy-Item $targetFile $backupFile -Force
    Write-Host "💾 Backup criado: $backupFile" -ForegroundColor Cyan

    $backupInfo = Get-Item $backupFile
    Write-Host "   Tamanho: $($backupInfo.Length) bytes" -ForegroundColor Gray
    Write-Host "   Data: $($backupInfo.LastWriteTime)`n" -ForegroundColor Gray
} else {
    Write-Host "⚠️ EventHandlers.vbs não existe, será criado`n" -ForegroundColor Yellow
}

# Limpar log antigo (opcional mas recomendado)
Write-Host "🧹 PREPARAÇÃO DO LOG`n" -ForegroundColor Yellow

if (Test-Path $logPath) {
    $currentLogSize = (Get-Item $logPath).Length
    $logLineCount = (Get-Content $logPath).Count

    Write-Host "  Log atual:" -ForegroundColor Cyan
    Write-Host "    Tamanho: $([math]::Round($currentLogSize/1KB, 2)) KB" -ForegroundColor Gray
    Write-Host "    Linhas: $logLineCount`n" -ForegroundColor Gray

    $clearLog = Read-Host "  Deseja LIMPAR o log para facilitar análise? (S/N)"

    if ($clearLog -eq "S" -or $clearLog -eq "s") {
        # Backup do log
        $logBackupFile = "C:\hmail-lists\logs\AureaBlack_Lists_backup_$timestamp.log"
        Copy-Item $logPath $logBackupFile -Force
        Write-Host "  ✅ Backup do log: $logBackupFile" -ForegroundColor Green

        # Limpar log
        Clear-Content $logPath
        Write-Host "  ✅ Log limpo!`n" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️ Log mantido (não limpo)`n" -ForegroundColor Cyan
    }
} else {
    Write-Host "  ℹ️ Log será criado automaticamente`n" -ForegroundColor Cyan
}

# Parar serviço
Write-Host "🛑 PARANDO hMailServer..." -ForegroundColor Yellow
try {
    Stop-Service -Name "hMailServer" -Force
    Write-Host "   ⏳ Aguardando serviço parar completamente..." -ForegroundColor Gray
    Start-Sleep -Seconds 5

    $service = Get-Service -Name "hMailServer"
    if ($service.Status -eq "Stopped") {
        Write-Host "   ✅ Serviço PARADO com sucesso`n" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️ Aguardando mais tempo..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Write-Host "   ✅ Serviço parado (Status: $($service.Status))`n" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ ERRO ao parar serviço: $_`n" -ForegroundColor Red
    exit 1
}

# Instalar versão DEBUG
Write-Host "📝 INSTALANDO v3.8 DEBUG SUPER DETALHADO..." -ForegroundColor Yellow
try {
    Copy-Item $sourceFile $targetFile -Force

    $newFile = Get-Item $targetFile
    Write-Host "   ✅ Arquivo DEBUG instalado!" -ForegroundColor Green
    Write-Host "   Caminho: $targetFile" -ForegroundColor Gray
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

# RESTART DO SERVIÇO (isso que provavelmente destrava!)
Write-Host "▶️ REINICIANDO hMailServer (ISSO DESTRAVA O SERVIDOR!)..." -ForegroundColor Yellow
try {
    Start-Service -Name "hMailServer"
    Write-Host "   ⏳ Aguardando serviço iniciar completamente..." -ForegroundColor Gray
    Start-Sleep -Seconds 8

    $service = Get-Service -Name "hMailServer"
    if ($service.Status -eq "Running") {
        Write-Host "   ✅ Serviço INICIADO com sucesso!" -ForegroundColor Green
        Write-Host "   Status: $($service.Status)`n" -ForegroundColor Gray
    } else {
        throw "Serviço não iniciou corretamente (Status: $($service.Status))"
    }
} catch {
    Write-Host "   ❌ ERRO ao iniciar serviço: $_`n" -ForegroundColor Red

    # Restaurar backup
    if (Test-Path $backupFile) {
        Write-Host "🔄 Restaurando backup..." -ForegroundColor Yellow
        Stop-Service -Name "hMailServer" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Copy-Item $backupFile $targetFile -Force
        Start-Service -Name "hMailServer"
        Start-Sleep -Seconds 5
        Write-Host "   ✅ Backup restaurado e serviço reiniciado`n" -ForegroundColor Green
    }
    exit 1
}

# Verificar porta SMTP 25
Write-Host "🔍 VERIFICANDO PORTA 25 (SMTP)..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

$port25 = netstat -an | Select-String ":25.*LISTEN"
if ($port25) {
    Write-Host "   ✅ Porta 25 está LISTENING (servidor recebendo emails!)" -ForegroundColor Green
    $port25 | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    Write-Host ""
} else {
    Write-Host "   ⚠️ Porta 25 NÃO está LISTENING!" -ForegroundColor Red
    Write-Host "   Isso pode significar que o servidor NÃO vai receber emails!`n" -ForegroundColor Red
}

# Verificar cache reload no log
Write-Host "📊 VERIFICANDO CACHE RELOAD..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

if (Test-Path $logPath) {
    $recentLogs = Get-Content $logPath -Tail 20 -ErrorAction SilentlyContinue
    $cacheReload = $recentLogs | Where-Object { $_ -match "CACHE_RELOAD" }

    if ($cacheReload) {
        Write-Host "   ✅ Cache recarregado com sucesso:" -ForegroundColor Green
        $cacheReload | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
        Write-Host ""
    } else {
        Write-Host "   ℹ️ Cache será carregado no próximo email recebido`n" -ForegroundColor Cyan
    }
} else {
    Write-Host "   ℹ️ Log será criado no primeiro email`n" -ForegroundColor Cyan
}

# Resumo final
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║        ✅ INSTALAÇÃO DEBUG CONCLUÍDA COM SUCESSO!          ║" -ForegroundColor Green
Write-Host "║        🔄 SERVIÇO REINICIADO (deve destravar!)             ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 RESUMO:" -ForegroundColor Cyan
Write-Host "   ✅ Versão: v3.8 DEBUG SUPER DETALHADO" -ForegroundColor White
Write-Host "   ✅ DEBUG_MODE: ATIVADO" -ForegroundColor White
Write-Host "   ✅ Wildcard: CORRIGIDO (*.xyz funciona!)" -ForegroundColor White
Write-Host "   ✅ Política: AUTH > BLACKLIST > WHITELIST > DEFAULT" -ForegroundColor White
Write-Host "   ✅ Serviço: Rodando" -ForegroundColor White
Write-Host "   ✅ Backup: $backupFile`n" -ForegroundColor White

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  📨 TESTE DE RECEPÇÃO DE EMAIL" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "Envie um email de TESTE para seu servidor agora!`n" -ForegroundColor White

Write-Host "Se o servidor DESTRAVAR (como da última vez), você verá:" -ForegroundColor Cyan
Write-Host "  ✅ Email chegando na caixa de entrada" -ForegroundColor Green
Write-Host "  ✅ Logs DEBUG aparecendo no arquivo de log`n" -ForegroundColor Green

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  📋 MONITORAMENTO DE LOGS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "🔍 COMANDO 1: Monitorar logs em TEMPO REAL (RECOMENDADO):" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Wait -Tail 50`n" -ForegroundColor Gray

Write-Host "🔍 COMANDO 2: Ver últimas 100 linhas do log:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Tail 100`n" -ForegroundColor Gray

Write-Host "🔍 COMANDO 3: Ver apenas linhas DEBUG:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Tail 200 | Select-String 'DEBUG'`n" -ForegroundColor Gray

Write-Host "🔍 COMANDO 4: Ver decisões finais:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Tail 100 | Select-String 'DECISAO FINAL'`n" -ForegroundColor Gray

Write-Host "🔍 COMANDO 5: Ver cache reload:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' | Select-String 'CACHE_RELOAD'`n" -ForegroundColor Gray

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  📊 EXEMPLO DE LOG DEBUG QUE VOCÊ VAI VER" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "Quando um email chegar, você verá logs assim:`n" -ForegroundColor White

Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Gray
Write-Host "║         NOVO EMAIL RECEBIDO - DEBUG MODE             ║" -ForegroundColor Gray
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: ┌─ Informações do Remetente ─┐" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: │ FROM Email    : [teste@exemplo.com]" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: │ FROM Domain   : [exemplo.com]" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: │ Remote IP     : [1.2.3.4]" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: │ Authenticated : [False]" -ForegroundColor Gray
Write-Host "DEBUG [EMAIL_INFO]: └────────────────────────────┘" -ForegroundColor Gray
Write-Host "..." -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]: 🔍 Procurando [exemplo.com] em 1851 entradas..." -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]:   [150] Testando WILDCARD: [*.xyz] vs [exemplo.com]" -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]:     │ Step 1  : [__WILDCARD_STAR__.xyz] (placeholders)" -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]:     │ Step 2  : [__WILDCARD_STAR__\.xyz] (escaped)" -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]:     │ Step 3  : [.*\.xyz] (wildcards restored)" -ForegroundColor Gray
Write-Host "DEBUG [BL_DOMAIN]:     │ Test    : ❌ NO MATCH" -ForegroundColor Gray
Write-Host "..." -ForegroundColor Gray
Write-Host "🎯 DECISAO FINAL: 25/11/2025 10:30 AM | FROM=teste@exemplo.com | ..." -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  🎯 PRÓXIMOS PASSOS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "1️⃣ ENVIAR EMAIL DE TESTE:" -ForegroundColor Cyan
Write-Host "   Envie um email para o servidor (de qualquer conta externa)`n" -ForegroundColor White

Write-Host "2️⃣ MONITORAR LOGS:" -ForegroundColor Cyan
Write-Host "   Get-Content '$logPath' -Wait -Tail 50`n" -ForegroundColor Gray

Write-Host "3️⃣ VERIFICAR SE EMAIL CHEGOU:" -ForegroundColor Cyan
Write-Host "   • Se chegou: ✅ Servidor destrancou! (restart funcionou!)" -ForegroundColor Green
Write-Host "   • Se NÃO chegou: ❌ Problema persiste (veja troubleshooting abaixo)`n" -ForegroundColor Red

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "  🆘 TROUBLESHOOTING (se ainda NÃO receber emails)" -ForegroundColor Red
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Red

Write-Host "Se após o restart você AINDA NÃO receber emails:`n" -ForegroundColor Yellow

Write-Host "🔍 1. Verificar porta 25:" -ForegroundColor Cyan
Write-Host "   netstat -an | Select-String ':25.*LISTEN'" -ForegroundColor Gray
Write-Host "   (deve mostrar TCP 0.0.0.0:25 LISTENING)`n" -ForegroundColor Gray

Write-Host "🔍 2. Ver logs de ERRO do hMailServer:" -ForegroundColor Cyan
Write-Host "   Get-Content 'C:\Program Files (x86)\hMailServer\Logs\hmailserver_*.log' -Tail 50`n" -ForegroundColor Gray

Write-Host "🔍 3. Verificar se outro processo está na porta 25:" -ForegroundColor Cyan
Write-Host "   netstat -ano | Select-String ':25.*LISTEN'" -ForegroundColor Gray
Write-Host "   (anote o PID e veja qual processo: Get-Process -Id <PID>)`n" -ForegroundColor Gray

Write-Host "🔍 4. Testar conexão SMTP:" -ForegroundColor Cyan
Write-Host "   Test-NetConnection -ComputerName localhost -Port 25`n" -ForegroundColor Gray

Write-Host "🔍 5. Verificar firewall:" -ForegroundColor Cyan
Write-Host "   Get-NetFirewallRule | Where-Object {`$_.DisplayName -like '*mail*'}`n" -ForegroundColor Gray

Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Yellow

Write-Host "✅ Instalação v3.8 DEBUG concluída em: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 O RESTART FOI FEITO! Se funcionou como da última vez, o servidor deve estar recebendo emails agora!" -ForegroundColor Green
Write-Host ""
