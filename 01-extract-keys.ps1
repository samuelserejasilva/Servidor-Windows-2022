param(
    [string]$Base = 'C:\scripts\secrets\',
    [string]$PfxPath,
    [string]$PfxPassword
)
function Fail($m) { Write-Error $m; exit 1 }

# OpenSSL
$OpenSSL = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $OpenSSL) {
    $defaultOpenSsl = 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe'
    if (Test-Path $defaultOpenSsl) { $OpenSSL = $defaultOpenSsl }
}
if (-not $OpenSSL) { Fail "OpenSSL não encontrado (PATH ou 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe')." }

# PFX mais recente se não vier por parâmetro
if (-not $PfxPath) {
    $pfx = Get-ChildItem -Path $Base -Filter '*.pfx' -File |
    Sort-Object LastWriteTime -Desc | Select-Object -First 1
    if (-not $pfx) { Fail "Nenhum .pfx encontrado em $Base" }
    $PfxPath = $pfx.FullName
}
if (!(Test-Path $PfxPath -PathType Leaf)) { Fail "PFX não encontrado: $PfxPath" }
if (-not $PfxPassword) { Fail "Informe -PfxPassword (senha do .pfx)." }

# pasta de saída
$Stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$OutDir = Join-Path $Base "key-$Stamp"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# arquivos temporários
$CertPem = Join-Path $OutDir 'cert.pem'
$ChainPem = Join-Path $OutDir 'chain.pem'
$PrivPem = Join-Path $OutDir 'privkey.pem'

# extração
& $OpenSSL pkcs12 -in $PfxPath -clcerts -nokeys  -passin "pass:$PfxPassword" -out $CertPem   | Out-Null
& $OpenSSL pkcs12 -in $PfxPath -cacerts  -nokeys  -passin "pass:$PfxPassword" -out $ChainPem | Out-Null
& $OpenSSL pkcs12 -in $PfxPath -nocerts -nodes   -passin "pass:$PfxPassword" -out $PrivPem   | Out-Null

# normaliza chave e gera .key
& $OpenSSL pkey -in $PrivPem -out (Join-Path $OutDir 'privkey.key') | Out-Null
Copy-Item $CertPem  (Join-Path $OutDir 'cert.key')  -Force
Copy-Item $ChainPem (Join-Path $OutDir 'chain.key') -Force
# fullchain = cert + chain
Set-Content -Path (Join-Path $OutDir 'fullchain.key') -Value ((Get-Content -Raw $CertPem) + (Get-Content -Raw $ChainPem)) -NoNewline

# devolve o caminho da pasta (para o wrapper)
Write-Output $OutDir
exit 0
