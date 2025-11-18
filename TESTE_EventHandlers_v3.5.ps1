# ======================================================================
# SCRIPT DE TESTE - EventHandlers v3.5 CORRIGIDO
# Valida as correções antes de aplicar em produção
# ======================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "TESTE EventHandlers v3.5 - CORREÇÕES" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ==================== CONFIGURAÇÃO ====================
$basePath = "C:\hmail-lists\lists"
$blDomains = Get-Content "$basePath\blacklist_domains.txt" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^;" -and $_.Trim() -ne "" }
$blEmails = Get-Content "$basePath\blacklist_emails.txt" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^;" -and $_.Trim() -ne "" }
$wlDomains = Get-Content "$basePath\whitelist_domains.txt" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^;" -and $_.Trim() -ne "" }
$wlEmails = Get-Content "$basePath\whitelist_emails.txt" | Where-Object { $_ -notmatch "^#" -and $_ -notmatch "^;" -and $_.Trim() -ne "" }

Write-Host "LISTAS CARREGADAS:" -ForegroundColor Yellow
Write-Host "  Blacklist Domains: $($blDomains.Count)" -ForegroundColor Gray
Write-Host "  Blacklist Emails: $($blEmails.Count)" -ForegroundColor Gray
Write-Host "  Whitelist Domains: $($wlDomains.Count)" -ForegroundColor Gray
Write-Host "  Whitelist Emails: $($wlEmails.Count)`n" -ForegroundColor Gray

# ==================== FUNÇÃO DE TESTE ====================
function Test-EmailMatch {
    param(
        [string]$email,
        [string]$domain,
        [array]$domainList,
        [array]$emailList
    )

    $emailLower = $email.ToLower()
    $domainLower = $domain.ToLower()

    # Verifica email exato
    foreach($item in $emailList) {
        if($item.ToLower() -eq $emailLower) {
            return @{Match=$true; Type="EMAIL"; Pattern=$item}
        }
    }

    # Verifica domínio (exato ou wildcard)
    foreach($item in $domainList) {
        $itemLower = $item.ToLower()

        # Wildcard
        if($itemLower -match '\*' -or $itemLower -match '\?') {
            # Converte wildcard para regex
            $pattern = $itemLower
            $pattern = $pattern -replace '\\', '\\'
            $pattern = $pattern -replace '\.', '\.'
            $pattern = $pattern -replace '\^', '\^'
            $pattern = $pattern -replace '\$', '\$'
            $pattern = $pattern -replace '\+', '\+'
            $pattern = $pattern -replace '\(', '\('
            $pattern = $pattern -replace '\)', '\)'
            $pattern = $pattern -replace '\[', '\['
            $pattern = $pattern -replace '\]', '\]'
            $pattern = $pattern -replace '\{', '\{'
            $pattern = $pattern -replace '\}', '\}'
            $pattern = $pattern -replace '\|', '\|'
            $pattern = $pattern -replace '\*', '.*'
            $pattern = $pattern -replace '\?', '.'
            $pattern = "^$pattern$"

            if($domainLower -match $pattern) {
                return @{Match=$true; Type="DOMAIN_WILDCARD"; Pattern=$item}
            }
        }
        # Match exato
        elseif($itemLower -eq $domainLower) {
            return @{Match=$true; Type="DOMAIN_EXACT"; Pattern=$item}
        }
    }

    return @{Match=$false; Type="NONE"; Pattern=""}
}

# ==================== CASOS DE TESTE ====================
$testCases = @(
    @{Email="no-reply652@aspi.promovoo.xyz"; ExpectedBL=$true; ExpectedWL=$false}
    @{Email="treinamento@econettreinamento.net.br"; ExpectedBL=$true; ExpectedWL=$false}
    @{Email="eduardo.pladar@inovti.com.br"; ExpectedBL=$true; ExpectedWL=$false}
    @{Email="no-reply389@infrastructure.promovoo.xyz"; ExpectedBL=$true; ExpectedWL=$false}
    @{Email="samuel.cereja@gmail.com"; ExpectedBL=$false; ExpectedWL=$true}
    @{Email="contabil@portalauditoria.com.br"; ExpectedBL=$false; ExpectedWL=$true}
    @{Email="teste@exemplo.com"; ExpectedBL=$false; ExpectedWL=$false}
)

# ==================== EXECUTAR TESTES ====================
$passed = 0
$failed = 0

foreach($test in $testCases) {
    $email = $test.Email
    $domain = $email.Split("@")[1]

    Write-Host "───────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "TESTANDO: $email" -ForegroundColor White

    # Verifica Blacklist
    $blResult = Test-EmailMatch -email $email -domain $domain -domainList $blDomains -emailList $blEmails

    # Verifica Whitelist
    $wlResult = Test-EmailMatch -email $email -domain $domain -domainList $wlDomains -emailList $wlEmails

    # Resultados
    Write-Host "  Blacklist: " -NoNewline -ForegroundColor Gray
    if($blResult.Match) {
        Write-Host "MATCH ($($blResult.Type): $($blResult.Pattern))" -ForegroundColor Red
    } else {
        Write-Host "NO MATCH" -ForegroundColor Green
    }

    Write-Host "  Whitelist: " -NoNewline -ForegroundColor Gray
    if($wlResult.Match) {
        Write-Host "MATCH ($($wlResult.Type): $($wlResult.Pattern))" -ForegroundColor Green
    } else {
        Write-Host "NO MATCH" -ForegroundColor Yellow
    }

    # Verificar expectativa
    $blOK = ($blResult.Match -eq $test.ExpectedBL)
    $wlOK = ($wlResult.Match -eq $test.ExpectedWL)

    if($blOK -and $wlOK) {
        Write-Host "  ✅ TESTE PASSOU" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  ❌ TESTE FALHOU" -ForegroundColor Red
        if(-not $blOK) { Write-Host "     Blacklist esperado: $($test.ExpectedBL), obtido: $($blResult.Match)" -ForegroundColor Red }
        if(-not $wlOK) { Write-Host "     Whitelist esperado: $($test.ExpectedWL), obtido: $($wlResult.Match)" -ForegroundColor Red }
        $failed++
    }
}

# ==================== RESUMO ====================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RESUMO DOS TESTES" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ✅ Passaram: $passed" -ForegroundColor Green
Write-Host "  ❌ Falharam: $failed" -ForegroundColor Red
Write-Host "  📊 Total: $($testCases.Count)`n" -ForegroundColor White

if($failed -eq 0) {
    Write-Host "🎉 TODOS OS TESTES PASSARAM!" -ForegroundColor Green
    Write-Host "`n✅ O EventHandlers v3.5 está pronto para produção!" -ForegroundColor Green
    Write-Host "`nPróximos passos:" -ForegroundColor Yellow
    Write-Host "  1. Fazer backup do EventHandlers.vbs atual" -ForegroundColor White
    Write-Host "  2. Substituir pelo EventHandlers_v3.5_CORRIGIDO.vbs" -ForegroundColor White
    Write-Host "  3. Reiniciar o serviço hMailServer" -ForegroundColor White
    Write-Host "  4. Monitorar os logs C:\hmail-lists\logs\AureaBlack_Lists.log" -ForegroundColor White
} else {
    Write-Host "⚠️ ALGUNS TESTES FALHARAM!" -ForegroundColor Yellow
    Write-Host "Revise as configurações antes de aplicar em produção." -ForegroundColor Yellow
}

Write-Host ""
