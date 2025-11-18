# =========================================================================
# SCRIPT DE AUTO-BLOQUEIO (Fail2Ban)
# Lê o log nativo do hMailServer procurando por falhas de login (530/535)
# Aqui está a lógica exata no script que faz essa verificação:
# Carregar Blacklist: Primeiro, o script lê todos os IPs que já estão no seu blacklist_ips.txt 
# e guarda na memória (na variável $blacklist_ips).
# Filtrar Atacantes: Quando ele analisa os logs, ele só seleciona um IP para bloquear se ele atender a três condições:
# Tiver 5 ou mais falhas (ex: Count -ge 5). > NÃO estar já na blacklist_ips.txt (ex: $blacklist_ips -notcontains $_.Name).
# e adiciona os IPs maliciosos ao blacklist_ips.txt
# pwsh 'C:\hmail-lists\app-ant-spam\filtos\bloqueio\AUTO-BLOQUEIO-Fail2Ban.ps1'
# =========================================================================

# --- Configuração ---
$log = "C:\Program Files (x86)\hMailServer\Logs\hmailserver_$(Get-Date -f yyyy-MM-dd).log"
$blacklist_file = "C:\hmail-lists\lists\blacklist_ips.txt"
$whitelist_file = "C:\hmail-lists\lists\whitelist_ips.txt" # Importante para não se bloquear
$min_falhas = 5 # Bloquear IPs com 5 ou mais falhas

# --- Execução ---
Write-Host "Iniciando verificação de força bruta (530/535) em $log" -ForegroundColor Cyan

$regex = '"(\d{1,3}(?:\.\d{1,3}){3})"\s*"SENT:\s+(?:530|535)\b'

# Carregar listas para evitar duplicados e falsos-positivos
try {
    $blacklist_ips = Get-Content $blacklist_file -ErrorAction SilentlyContinue
    $whitelist_ips = Get-Content $whitelist_file -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Erro ao ler arquivos de lista. Verifique os caminhos."
    $blacklist_ips = @()
    $whitelist_ips = @()
}

# Encontrar IPs
Write-Host "Analisando IPs..."
$top = Select-String -Path $log -Pattern 'SENT:\s+530|SENT:\s+535' -ErrorAction SilentlyContinue |
ForEach-Object {
  if ($_ -match $regex) { $matches[1] }
} | Group-Object | Sort-Object Count -Desc

# Mostra ranking
Write-Host "Ranking de falhas de login (530/535) de hoje:"
$top | Format-Table Count, Name -Auto -HideTableHeaders

# Filtrar IPs para bloquear
# 1. Tem que ter $min_falhas ou mais
# 2. NÃO PODE estar na sua whitelist
# 3. NÃO PODE já estar na sua blacklist
$IPsParaBloquear = $top | Where-Object { 
    ($_.Count -ge $min_falhas) -and 
    ($whitelist_ips -notcontains $_.Name) -and 
    ($blacklist_ips -notcontains $_.Name) 
}

if ($IPsParaBloquear) {
    Write-Host "ADICIONANDO OS SEGUINTES IPs À BLACKLIST:" -ForegroundColor Red
    
    foreach ($ip_info in $IPsParaBloquear) {
        $ip = $ip_info.Name
        Write-Host "ADICIONANDO $ip à blacklist_ips.txt ($($ip_info.Count) falhas)" -ForegroundColor Yellow
        
        # Adiciona o IP ao arquivo de blacklist
        Add-Content -Path $blacklist_file -Value $ip
    }
} else {
    Write-Host "Nenhum IP novo atingiu o limite para bloqueio." -ForegroundColor Green
}

Write-Host "Verificação concluída."
