# 🔧 GUIA DE ATUALIZAÇÃO - EventHandlers v3.5 CORRIGIDO

## 📋 O QUE FOI CORRIGIDO

### 🐛 **Bug #1: Parâmetro ByRef (CRÍTICO)**
**Linha 207 - Antes:**
```vbscript
Function IsInList(Byref listCacheName, Byval key)
```

**Linha 235 - Depois:**
```vbscript
Function IsInList(Byval listCacheName, Byval key)
```

**Problema:** `ByRef` causava corrupção de dados ao consultar `Global.Value()`, fazendo a função retornar `True` incorretamente.

---

### 🐛 **Bug #2: Escape de Regex Incorreto (CRÍTICO)**
**Linhas 228-237 - Antes:**
```vbscript
If InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then
   pattern = Replace(item, ".", "\.")    ' ❌ Ordem errada!
   pattern = Replace(pattern, "*", ".*")
   pattern = Replace(pattern, "?", ".")
```

**Linhas 253-270 - Depois:**
```vbscript
If InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then
   ' Escapa TODOS os caracteres especiais ANTES
   pattern = item
   pattern = Replace(pattern, "\", "\\")
   pattern = Replace(pattern, ".", "\.")
   pattern = Replace(pattern, "^", "\^")
   ' ... (todos os caracteres especiais)

   ' DEPOIS converte wildcards
   pattern = Replace(pattern, "*", ".*")
   pattern = Replace(pattern, "?", ".")
```

**Problema:** Ordem incorreta criava regex malformado, causando matches incorretos.

---

### ✅ **Melhorias Adicionais**
- ✅ Validação de chaves vazias (linha 241)
- ✅ Validação de entradas vazias no array (linha 254)
- ✅ Comentários explicativos sobre as correções

---

## 🧪 PASSO 1: TESTAR A CORREÇÃO

### Execute o script de teste:
```powershell
pwsh 'C:\Users\Administrator\Desktop\Servidor-Windows-2022\TESTE_EventHandlers_v3.5.ps1'
```

### ✅ Resultado esperado:
```
🎉 TODOS OS TESTES PASSARAM!

✅ O EventHandlers v3.5 está pronto para produção!
```

**Se algum teste falhar, NÃO prossiga! Me avise.**

---

## 💾 PASSO 2: BACKUP DO ARQUIVO ATUAL

### Faça backup do EventHandlers.vbs atual:
```powershell
# Criar pasta de backup
New-Item -ItemType Directory -Path "C:\hmail-backup" -Force

# Fazer backup com timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" `
          "C:\hmail-backup\EventHandlers_$timestamp.vbs"

# Verificar backup
Write-Host "Backup criado:" -ForegroundColor Green
Get-Item "C:\hmail-backup\EventHandlers_$timestamp.vbs" | Select-Object FullName, Length, LastWriteTime
```

---

## 🔄 PASSO 3: SUBSTITUIR O ARQUIVO

### Copiar a versão corrigida:
```powershell
# Parar o serviço hMailServer
Stop-Service -Name "hMailServer" -Force
Write-Host "Serviço hMailServer parado" -ForegroundColor Yellow

# Substituir o arquivo
Copy-Item "C:\Users\Administrator\Desktop\Servidor-Windows-2022\EventHandlers_v3.5_CORRIGIDO.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

Write-Host "Arquivo substituído com sucesso!" -ForegroundColor Green

# Iniciar o serviço
Start-Service -Name "hMailServer"
Write-Host "Serviço hMailServer iniciado" -ForegroundColor Green

# Aguardar 5 segundos
Start-Sleep -Seconds 5

# Verificar status
Get-Service -Name "hMailServer" | Select-Object Name, Status, StartType
```

---

## 🔍 PASSO 4: VALIDAR EM PRODUÇÃO

### 4.1 Monitorar o log:
```powershell
# Limpar o log atual (opcional)
# Clear-Content "C:\hmail-lists\logs\AureaBlack_Lists.log"

# Monitorar em tempo real
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Wait -Tail 20
```

### 4.2 Enviar email de teste:

**Cenário 1: Email BLACKLIST deve ser REJEITADO**
- Envie de: `no-reply@promovoo.xyz`
- Para: `contato@portalauditoria.com.br`
- **Esperado:** `550 BLOCK_BLACK: FROM_DOMAIN in blacklist`

**Cenário 2: Email WHITELIST deve PASSAR**
- Envie de: `samuel.cereja@gmail.com`
- Para: `contato@portalauditoria.com.br`
- **Esperado:** `ALLOW_AUREA: FROM_EMAIL in whitelist`

**Cenário 3: Email NEUTRO deve PASSAR**
- Envie de: `teste@exemplo.com`
- Para: `contato@portalauditoria.com.br`
- **Esperado:** `ALLOW_AUTO: NOT_FOUND`

### 4.3 Verificar headers do email recebido:
```powershell
# No Roundcube ou Outlook, verificar header:
# X-AureaBlack-Decision: ALLOW_AUREA: FROM_EMAIL in whitelist
```

---

## 📊 PASSO 5: VERIFICAR LOGS

### Verificar decisões recentes:
```powershell
$log = Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 50

Write-Host "`n===== DECISÕES RECENTES =====" -ForegroundColor Cyan

# Bloqueios
$blocks = $log | Select-String "BLOCK_BLACK"
Write-Host "`n🔴 BLOQUEIOS: $($blocks.Count)" -ForegroundColor Red
$blocks | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }

# Whitelists
$allows = $log | Select-String "ALLOW_AUREA"
Write-Host "`n✅ WHITELISTS: $($allows.Count)" -ForegroundColor Green
$allows | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }

# Automáticos
$autos = $log | Select-String "ALLOW_AUTO"
Write-Host "`n⚪ AUTOMÁTICOS: $($autos.Count)" -ForegroundColor Yellow
$autos | Select-Object -First 5 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
```

---

## ✅ CHECKLIST DE VALIDAÇÃO

- [ ] Script de teste executado com sucesso
- [ ] Backup do arquivo antigo criado
- [ ] Arquivo substituído
- [ ] Serviço hMailServer reiniciado
- [ ] Log mostra `CACHE_RELOAD: Loading lists...`
- [ ] Email de blacklist foi REJEITADO (550)
- [ ] Email de whitelist foi ACEITO
- [ ] Headers `X-AureaBlack-Decision` corretos

---

## 🆘 ROLLBACK (SE NECESSÁRIO)

Se algo der errado:

```powershell
# Parar o serviço
Stop-Service -Name "hMailServer" -Force

# Restaurar backup (use o timestamp correto)
Copy-Item "C:\hmail-backup\EventHandlers_YYYYMMDD_HHMMSS.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

# Reiniciar serviço
Start-Service -Name "hMailServer"
```

---

## 📝 MUDANÇAS DE VERSÃO

### v3.4 (BUGADO) → v3.5 (CORRIGIDO)
- ✅ Corrigido `ByRef` → `ByVal` (bug crítico)
- ✅ Corrigido escape de regex para wildcards
- ✅ Adicionadas validações de entrada vazia
- ✅ Melhorado tratamento de caracteres especiais

---

## 📞 SUPORTE

Se encontrar problemas:
1. Verifique o log: `C:\hmail-lists\logs\AureaBlack_Lists.log`
2. Procure por `SCRIPT_ERROR`
3. Restaure o backup se necessário
4. Reporte o problema com os logs

---

**Versão do Guia:** 1.0
**Data:** 18/11/2025
**Autor:** Claude Code
