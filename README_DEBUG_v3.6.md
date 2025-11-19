# 🔍 EventHandlers v3.6 DEBUG - Diagnóstico de False Positives

## ⚠️ SITUAÇÃO ATUAL

**PROBLEMA CRÍTICO:**
Emails de domínios **BLACKLIST** continuam entrando na caixa de entrada mesmo após instalação do v3.5.

**Sintomas:**
```
FROM=treinamento@econettreinamento.net.br | DECISION=10 | ALLOW_AUREA: FROM_EMAIL in whitelist
```

**MAS o email NÃO está na whitelist_emails.txt!**

**Domínios afetados:**
- `econettreinamento.net.br` (NA BLACKLIST)
- `promovoo.xyz` (NA BLACKLIST)
- `inovti.com.br` (NA BLACKLIST)
- `*.xyz` (NA BLACKLIST)

---

## 🎯 OBJETIVO DA VERSÃO DEBUG

O **EventHandlers v3.6 DEBUG** vai revelar **EXATAMENTE** qual entrada da whitelist está dando match incorretamente.

### O que mudou na v3.6:

```vbscript
' v3.5 (antiga):
Function IsInList(Byval listCacheName, Byval key)
   ' ... lógica de verificação SEM debug ...
End Function

' v3.6 DEBUG (nova):
Function IsInListDebug(Byval listCacheName, Byval key, Byval debugContext)
   ' NOVO: Log de entrada
   If DEBUG_MODE Then WriteAuditLog "DEBUG [" & debugContext & "]: Checking key='" & key & "' against " & (ub+1) & " entries"

   ' ... lógica de verificação ...

   ' NOVO: Log quando encontrar match
   If regex.Test(key) Then
      If DEBUG_MODE Then WriteAuditLog "DEBUG [" & debugContext & "]: MATCH! Wildcard '" & item & "' matched '" & key & "'"
      IsInListDebug = True
      Exit Function
   End If

   ' NOVO: Log se não encontrar match
   If DEBUG_MODE Then WriteAuditLog "DEBUG [" & debugContext & "]: NO MATCH for '" & key & "'"
End Function
```

### Logs DEBUG que serão gerados:

Para cada email recebido, você verá:

```
DEBUG [WL_EMAIL]: Checking key='treinamento@econettreinamento.net.br' against 127 entries
DEBUG [WL_EMAIL]: MATCH! Wildcard '*econet*' matched 'treinamento@econettreinamento.net.br'
                          ^^^^^^^^^ ESTA É A ENTRADA PROBLEMÁTICA!

DEBUG [WL_DOMAIN]: Checking key='econettreinamento.net.br' against 50 entries
DEBUG [WL_DOMAIN]: NO MATCH for 'econettreinamento.net.br'

DEBUG [WL_IP]: Checking key='178.62.61.52' against 10 entries
DEBUG [WL_IP]: NO MATCH for '178.62.61.52'
```

**RESULTADO:** Saberemos qual linha da `whitelist_emails.txt`, `whitelist_domains.txt` ou `whitelist_ips.txt` está causando o false positive!

---

## 🚀 INSTALAÇÃO

### **Método 1: Script Automatizado (RECOMENDADO)**

```powershell
# Execute como Administrador
pwsh .\APLICAR_DEBUG_v3.6.ps1
```

**O script faz automaticamente:**
1. ✅ Backup do EventHandlers.vbs atual (v3.5)
2. ✅ Para o serviço hMailServer
3. ✅ Instala EventHandlers v3.6 DEBUG
4. ✅ Reinicia o serviço
5. ✅ Oferece opção de limpar o log (recomendado)

---

### **Método 2: Manual**

```powershell
# 1. Backup
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" `
          "C:\hmail-backup\EventHandlers_v3.5_$timestamp.vbs"

# 2. Parar serviço
Stop-Service -Name "hMailServer" -Force

# 3. Instalar v3.6 DEBUG
Copy-Item ".\EventHandlers_v3.6_DEBUG.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

# 4. Iniciar serviço
Start-Service -Name "hMailServer"

# 5. Verificar
Get-Service -Name "hMailServer"
```

---

## 📊 COMO USAR O DEBUG

### **Passo 1: Monitorar o log em tempo real**

Abra um PowerShell e execute:

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Wait -Tail 30
```

Deixe esta janela aberta. Você verá logs em tempo real.

---

### **Passo 2: Aguardar próximo email de SPAM**

Aguarde até que entre um email de:
- `*@econettreinamento.net.br`
- `*@promovoo.xyz`
- `*@inovti.com.br`
- `*@*.xyz`

**Quando entrar**, o log mostrará algo como:

```
11/19/2025 10:30:15 AM | CACHE_RELOAD: Loading lists...
DEBUG [WL_EMAIL]: Checking key='spam@econettreinamento.net.br' against 127 entries
DEBUG [WL_EMAIL]: MATCH! Wildcard '*@econet*' matched 'spam@econettreinamento.net.br'
11/19/2025 10:30:15 AM | FROM=spam@econettreinamento.net.br | To=contato@portalauditoria.com.br | IP=178.62.61.52 | AUTH=False | DECISION=10 | ALLOW_AUREA: FROM_EMAIL in whitelist
```

**PRONTO!** Descobrimos que `*@econet*` está na whitelist_emails.txt causando o problema!

---

### **Passo 3: Capturar e enviar o log DEBUG**

Quando o spam entrar, capture as últimas 100 linhas:

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 100 | Out-File "C:\debug_output.txt"
```

**Envie o arquivo `C:\debug_output.txt` para análise.**

---

## 🔍 O QUE PROCURAR NO LOG

### **Linhas importantes:**

```
DEBUG [WL_EMAIL]: Checking key='...'     ← Verifica whitelist de emails
DEBUG [WL_DOMAIN]: Checking key='...'    ← Verifica whitelist de domínios
DEBUG [WL_IP]: Checking key='...'        ← Verifica whitelist de IPs

DEBUG [BL_EMAIL]: Checking key='...'     ← Verifica blacklist de emails
DEBUG [BL_DOMAIN]: Checking key='...'    ← Verifica blacklist de domínios
DEBUG [BL_IP]: Checking key='...'        ← Verifica blacklist de IPs
```

### **Linhas críticas (revelam o problema):**

```
DEBUG [WL_EMAIL]: MATCH! Wildcard '*econet*' matched 'treinamento@econettreinamento.net.br'
                          ^^^^^^^^^^^ ESTA ENTRADA ESTÁ NA WHITELIST MAS NÃO DEVERIA!

DEBUG [WL_EMAIL]: MATCH! Exact match 'spam@exemplo.com' == 'spam@exemplo.com'
                          ^^^^^^^^^^^^^ ESTA ENTRADA ESTÁ DUPLICADA NA WHITELIST
```

---

## 🎯 CENÁRIOS ESPERADOS

### **Cenário 1: Match incorreto em whitelist_emails.txt**

```
DEBUG [WL_EMAIL]: MATCH! Wildcard '*@econ*' matched 'treinamento@econettreinamento.net.br'
```

**Problema:** Entrada `*@econ*` na whitelist está pegando econettreinamento.net.br
**Solução:** Remover ou corrigir esta entrada

---

### **Cenário 2: Match incorreto em whitelist_domains.txt**

```
DEBUG [WL_DOMAIN]: MATCH! Wildcard '*.net.br' matched 'econettreinamento.net.br'
```

**Problema:** Entrada `*.net.br` na whitelist está pegando TODOS os .net.br
**Solução:** Remover ou especificar melhor esta entrada

---

### **Cenário 3: Bug no código de regex**

```
DEBUG [WL_EMAIL]: MATCH! Wildcard 'exemplo.*' matched 'totalmente_diferente@teste.com'
```

**Problema:** Regex ainda está com bug (improvável mas possível)
**Solução:** Corrigir lógica de regex no código

---

## ⚠️ NOTAS IMPORTANTES

### **Sobre o tamanho do log:**

⚠️ **O log vai crescer MUITO com o debug ativado!**

**Normal:** ~100 linhas por hora
**Com DEBUG:** ~500-1000 linhas por hora

**Recomendações:**
1. Use esta versão apenas para diagnosticar
2. Depois de encontrar o problema, instalaremos v3.7 FINAL (sem debug)
3. Limpe o log periodicamente se necessário:
   ```powershell
   # Backup do log antes de limpar
   Copy-Item "C:\hmail-lists\logs\AureaBlack_Lists.log" `
             "C:\hmail-lists\logs\AureaBlack_Lists_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

   # Limpar log
   Clear-Content "C:\hmail-lists\logs\AureaBlack_Lists.log"
   ```

---

### **Sobre o desempenho:**

⚠️ **O debug logging adiciona overhead mínimo:**
- Cada email: +5-10ms de processamento
- Impacto: Praticamente zero para servidores de baixo/médio tráfego

✅ **Seguro usar em produção para diagnóstico curto (1-2 dias)**

---

## 🔧 DIFERENÇAS v3.5 vs v3.6

| Aspecto | v3.5 | v3.6 DEBUG |
|---------|------|------------|
| ByRef → ByVal | ✅ Corrigido | ✅ Mantido |
| Regex escape | ✅ Corrigido | ✅ Mantido |
| Bloco If vazio | ❌ Presente | ✅ Corrigido |
| Debug logging | ❌ Ausente | ✅ Adicionado |
| Mostra qual entry matched | ❌ Não | ✅ SIM! |
| Tamanho do log | Normal | Grande |
| Uso em produção | ✅ Permanente | ⚠️ Temporário |

---

## 📋 CHECKLIST DE DIAGNÓSTICO

- [ ] v3.6 DEBUG instalado
- [ ] Serviço hMailServer reiniciado
- [ ] Log sendo monitorado em tempo real
- [ ] Aguardando próximo spam entrar
- [ ] Spam entrou → Log DEBUG capturado
- [ ] Identificada entrada problemática na whitelist
- [ ] Enviado log DEBUG para análise

---

## 🎯 PRÓXIMOS PASSOS

### **Após capturar o log DEBUG:**

1. **Identificar a entrada problemática**
   - Qual linha da whitelist está causando match?
   - É um wildcard muito amplo?
   - É uma entrada duplicada?

2. **Criar EventHandlers v3.7 FINAL**
   - Remover debug logging
   - Aplicar correção específica baseada no diagnóstico
   - Testar extensivamente
   - Deploy permanente

3. **Atualizar documentação**
   - Adicionar caso ao portfólio
   - Documentar solução final

---

## 🆘 ROLLBACK

Se precisar reverter para v3.5:

```powershell
# Parar serviço
Stop-Service -Name "hMailServer" -Force

# Restaurar backup (ajuste o timestamp)
Copy-Item "C:\hmail-backup\EventHandlers_v3.5_YYYYMMDD_HHMMSS.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

# Iniciar serviço
Start-Service -Name "hMailServer"
```

---

## 📞 SUPORTE

**Se encontrar problemas:**
1. Verifique se DEBUG_MODE = True (linha 16 do EventHandlers_v3.6_DEBUG.vbs)
2. Verifique se o log está sendo gerado
3. Procure por `SCRIPT_ERROR` no log
4. Envie as últimas 100 linhas do log para análise

---

**Versão:** 3.6 DEBUG
**Data:** 19/11/2025
**Status:** ⚠️ DIAGNÓSTICO - USO TEMPORÁRIO
**Objetivo:** Identificar causa dos false positives na whitelist
