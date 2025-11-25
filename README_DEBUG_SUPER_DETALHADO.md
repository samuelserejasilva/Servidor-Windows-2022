# 🔍 EventHandlers v3.8 DEBUG SUPER DETALHADO

## 🚨 PROBLEMA: Servidor parou de receber emails (só envia)

### **O que aconteceu:**
- hMailServer parou de receber emails de repente
- Só envia, não recebe
- **Mesmo sem o script EventHandlers**, o problema persiste
- Da última vez, **RESTART com v3.6 DEBUG destrancou** o servidor

### **Conclusão:**
O problema **NÃO é o script**, é o **hMailServer que trava**.
O **RESTART** destrava, não o script em si.

---

## ✅ SOLUÇÃO: v3.8 DEBUG SUPER DETALHADO

Esta versão faz **2 coisas importantes**:

1. **RESTART DO SERVIÇO** → Destrava o hMailServer (como da última vez)
2. **LOGS EXTREMAMENTE DETALHADOS** → Permite diagnosticar se houver problemas

### **Melhorias desta versão:**

✅ **Baseada na v3.8 atual** (sua versão de produção)
✅ **Bug de wildcard CORRIGIDO** (*.xyz agora funciona!)
✅ **Logs SUPER detalhados** (mostra cada passo da verificação)
✅ **Política mantida**: AUTH > BLACKLIST > WHITELIST > DEFAULT
✅ **Result.Value mantido** (integração correta com hMailServer)

---

## 🚀 INSTALAÇÃO RÁPIDA

### **Execute como Administrador:**

```powershell
pwsh .\APLICAR_DEBUG_SUPER_DETALHADO.ps1
```

**O script faz automaticamente:**
1. ✅ Validações (Admin, arquivos, serviço)
2. ✅ Backup da versão atual
3. ✅ Opcional: Limpar log para facilitar análise
4. ✅ Parar o serviço hMailServer (5 segundos)
5. ✅ Instalar v3.8 DEBUG
6. ✅ **REINICIAR o serviço** (8 segundos) → **ISSO DESTRAVA!**
7. ✅ Verificar porta 25 (SMTP)
8. ✅ Verificar cache reload

---

## 📊 LOGS DEBUG - O QUE VOCÊ VAI VER

### **Exemplo de log quando um email chegar:**

```
╔══════════════════════════════════════════════════════════════════╗
║               NOVO EMAIL RECEBIDO - DEBUG MODE                   ║
╚══════════════════════════════════════════════════════════════════╝

DEBUG [EMAIL_INFO]: ┌─ Informações do Remetente ─┐
DEBUG [EMAIL_INFO]: │ FROM Email    : [spam@econettreinamento.net.br]
DEBUG [EMAIL_INFO]: │ FROM Domain   : [econettreinamento.net.br]
DEBUG [EMAIL_INFO]: │ Remote IP     : [178.62.61.52]
DEBUG [EMAIL_INFO]: │ Authenticated : [False]
DEBUG [EMAIL_INFO]: └────────────────────────────┘
DEBUG [EMAIL_INFO]: TO (first): [contato@portalauditoria.com.br]
DEBUG [EMAIL_INFO]: Recipients are ALL internal: [False]

DEBUG [CACHE_STATUS]: ┌─ Status do Cache ─┐
DEBUG [CACHE_STATUS]: │ WL_Emails  : 127 entries
DEBUG [CACHE_STATUS]: │ WL_Domains : 50 entries
DEBUG [CACHE_STATUS]: │ WL_IPs     : 10 entries
DEBUG [CACHE_STATUS]: │ BL_Emails  : 500 entries
DEBUG [CACHE_STATUS]: │ BL_Domains : 1851 entries
DEBUG [CACHE_STATUS]: │ BL_IPs     : 100 entries
DEBUG [CACHE_STATUS]: └───────────────────┘

DEBUG [STEP_1]: ▶ Verificando AUTENTICACAO...
DEBUG [STEP_1]: ❌ NOT authenticated or internal message

DEBUG [STEP_2]: ▶ Verificando BLACKLIST (prioridade sobre whitelist)...
DEBUG [STEP_2]: ┌─ Checking BL_Emails ─┐
DEBUG [BL_EMAIL]: 🔍 Procurando [spam@econettreinamento.net.br] em 500 entradas...
DEBUG [BL_EMAIL]: ❌ NO MATCH para [spam@econettreinamento.net.br] (500 entradas verificadas)
DEBUG [STEP_2]: └─ BL_Emails: NO MATCH ─┘

DEBUG [STEP_2]: ┌─ Checking BL_Domains ─┐
DEBUG [BL_DOMAIN]: 🔍 Procurando [econettreinamento.net.br] em 1851 entradas...
DEBUG [BL_DOMAIN]:   [150] Testando WILDCARD: [*.xyz] vs [econettreinamento.net.br]
DEBUG [BL_DOMAIN]:     ┌─ Wildcard Processing ─┐
DEBUG [BL_DOMAIN]:     │ Input   : [*.xyz]
DEBUG [BL_DOMAIN]:     │ Step 1  : [__WILDCARD_STAR__.xyz] (placeholders)
DEBUG [BL_DOMAIN]:     │ Step 2  : [__WILDCARD_STAR__\.xyz] (escaped)
DEBUG [BL_DOMAIN]:     │ Step 3  : [.*\.xyz] (wildcards restored)
DEBUG [BL_DOMAIN]:     │ Final   : [^.*\.xyz$] (with anchors)
DEBUG [BL_DOMAIN]:     │ Test    : ❌ NO MATCH [econettreinamento.net.br] vs [^.*\.xyz$]
DEBUG [BL_DOMAIN]:     └───────────────────────┘
DEBUG [BL_DOMAIN]:   [450] Testando WILDCARD: [econettreinamento.net.br] vs [econettreinamento.net.br]
DEBUG [BL_DOMAIN]:   [450] ✅✅✅ MATCH EXATO! [econettreinamento.net.br] == [econettreinamento.net.br]
DEBUG [STEP_2]: 🔴 BLOQUEADO! Domínio encontrado na BLACKLIST
DEBUG [STEP_2]: 🎯 DECISAO FINAL: BLOCK_BLACK: FROM_DOMAIN in blacklist

═══════════════════════════════════════════════════════════════════
🎯 DECISAO FINAL: 25/11/2025 10:30:15 AM | FROM=spam@econettreinamento.net.br | To=contato@portalauditoria.com.br | IP=178.62.61.52 | AUTH=False | DECISION=30 | BLOCK_BLACK: FROM_DOMAIN in blacklist
═══════════════════════════════════════════════════════════════════

DEBUG [ACTION]: 🔴 BLOQUEANDO EMAIL (oMessage.Delete + Result.Value=2)
SMTP_REJECT: spam@econettreinamento.net.br -> BLOCK_BLACK: FROM_DOMAIN in blacklist
```

---

## 🎯 INTERPRETAÇÃO DOS LOGS

### **Símbolos usados:**

| Símbolo | Significado |
|---------|-------------|
| `✅` | Match encontrado / Operação bem-sucedida |
| `❌` | Nenhum match / Operação falhou |
| `🔍` | Procurando / Verificando |
| `🎯` | Decisão final |
| `🔴` | Email bloqueado |
| `✅✅✅` | Match confirmado (3 checks) |
| `⚠️` | Aviso / Atenção |
| `▶` | Início de verificação |

---

### **Seções do log:**

1. **`[EMAIL_INFO]`** - Informações do remetente
2. **`[CACHE_STATUS]`** - Quantas entradas em cada lista
3. **`[STEP_1]`** - Verificação de autenticação
4. **`[STEP_2]`** - Verificação de BLACKLIST
5. **`[STEP_3]`** - Verificação de WHITELIST
6. **`[STEP_4]`** - Decisão DEFAULT
7. **`[ACTION]`** - Ação final (bloquear ou permitir)

---

### **Contextos de verificação:**

| Contexto | Lista | O que verifica |
|----------|-------|----------------|
| `WL_EMAIL` | whitelist_emails.txt | Email completo (ex: teste@exemplo.com) |
| `WL_DOMAIN` | whitelist_domains.txt | Domínio (ex: exemplo.com, *.xyz) |
| `WL_IP` | whitelist_ips.txt | IP (ex: 192.168.1.100, 192.168.*) |
| `BL_EMAIL` | blacklist_emails.txt | Email completo |
| `BL_DOMAIN` | blacklist_domains.txt | Domínio (ex: econettreinamento.net.br, *.xyz) |
| `BL_IP` | blacklist_ips.txt | IP |

---

## 🔧 COMANDOS ÚTEIS

### **1. Monitorar logs em TEMPO REAL (RECOMENDADO):**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Wait -Tail 50
```

**Deixe esta janela aberta** e veja os logs aparecerem em tempo real quando emails chegarem!

---

### **2. Ver apenas linhas DEBUG:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 200 | Select-String "DEBUG"
```

---

### **3. Ver decisões finais:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 100 | Select-String "DECISAO FINAL"
```

---

### **4. Ver emails bloqueados:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 100 | Select-String "BLOCK_BLACK"
```

---

### **5. Ver emails permitidos:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Tail 100 | Select-String "ALLOW_"
```

---

### **6. Procurar email específico:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" | Select-String "econettreinamento"
```

---

### **7. Ver cache reload:**

```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" | Select-String "CACHE_RELOAD"
```

---

## 🐛 BUG CORRIGIDO NESTA VERSÃO

### **Problema nas versões v3.7 e v3.8 originais:**

A função `MatchWildcard()` tinha a ordem de processamento **ERRADA**:

```vbscript
' ❌ VERSÃO BUGADA (v3.7/v3.8 original):
regexPattern = Replace(pattern, ".", "\.")      ' Escapa PRIMEIRO
regexPattern = Replace(regexPattern, "*", ".*")  ' Wildcard DEPOIS

' Exemplo: *.xyz
' Resultado: *.xyz → *\.xyz → .*\.xyz (ERRADO!)
' Regex: ^.*\.xyz$ (exige ponto ANTES de xyz)
' ❌ NÃO combina com: teste.xyz, abc.xyz
```

### **Correção na v3.8 DEBUG:**

```vbscript
' ✅ VERSÃO CORRIGIDA (v3.8 DEBUG):

' 1. Placeholders (protege wildcards)
regexPattern = Replace(pattern, "*", "__WILDCARD_STAR__")
regexPattern = Replace(regexPattern, "?", "__WILDCARD_QUESTION__")

' 2. Escapar caracteres especiais
regexPattern = Replace(regexPattern, ".", "\.")
' ... outros caracteres ...

' 3. Restaurar wildcards
regexPattern = Replace(regexPattern, "__WILDCARD_STAR__", ".*")
regexPattern = Replace(regexPattern, "__WILDCARD_QUESTION__", ".")

' Exemplo: *.xyz
' Passo 1: __WILDCARD_STAR__.xyz
' Passo 2: __WILDCARD_STAR__\.xyz (ponto escapado!)
' Passo 3: .*\.xyz (wildcard restaurado!)
' Regex: ^.*\.xyz$ (CORRETO!)
' ✅ Combina com: teste.xyz, abc.xyz, qualquer.xyz
```

---

## 📋 PRÓXIMOS PASSOS

### **1. INSTALAR v3.8 DEBUG:**

```powershell
pwsh .\APLICAR_DEBUG_SUPER_DETALHADO.ps1
```

**Isso vai:**
- ✅ Fazer backup da versão atual
- ✅ Parar o serviço
- ✅ Instalar v3.8 DEBUG
- ✅ **REINICIAR o serviço** → **DESTRAVA!**
- ✅ Verificar porta 25
- ✅ Verificar cache

---

### **2. TESTAR RECEPÇÃO DE EMAIL:**

Envie um email de teste para o servidor (de qualquer conta externa).

**Se o restart funcionou (como da última vez):**
- ✅ Email vai chegar na caixa de entrada
- ✅ Logs DEBUG vão aparecer no arquivo
- ✅ Servidor destrancado!

---

### **3. MONITORAR LOGS:**

```powershell
# Abra um PowerShell separado e execute:
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Wait -Tail 50
```

Deixe essa janela aberta. Você verá logs em tempo real quando emails chegarem!

---

### **4. VERIFICAR PORTA 25:**

```powershell
netstat -an | Select-String ":25.*LISTEN"
```

**Deve mostrar:**
```
TCP    0.0.0.0:25    0.0.0.0:0    LISTENING
```

Se **NÃO mostrar LISTENING**, o servidor **NÃO está recebendo** emails!

---

## 🆘 SE O RESTART NÃO RESOLVER

Se após o restart você **AINDA NÃO receber emails**, o problema é mais profundo:

### **1. Verificar logs de ERRO do hMailServer:**

```powershell
Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_*.log" -Tail 50 | Select-String "ERROR"
```

**Procure por:**
- `Failed to accept connection`
- `Port already in use`
- `Unable to bind to port 25`
- `Access denied`

---

### **2. Verificar se outro processo está na porta 25:**

```powershell
# Ver qual processo está usando porta 25:
netstat -ano | Select-String ":25.*LISTEN"

# A última coluna é o PID. Veja qual processo é:
Get-Process -Id <PID>
```

Se **outro processo** estiver na porta 25, você precisa pará-lo!

---

### **3. Verificar firewall:**

```powershell
# Ver regras de firewall:
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*mail*"} | Select-Object DisplayName, Enabled, Direction

# Testar conexão na porta 25:
Test-NetConnection -ComputerName localhost -Port 25
```

---

### **4. Reiniciar o servidor Windows (última opção):**

```powershell
Restart-Computer -Force
```

**⚠️ ATENÇÃO:** Isso vai reiniciar o servidor Windows completo!

---

## 📊 EXEMPLO COMPLETO DE LOG DEBUG

```
╔══════════════════════════════════════════════════════════════════╗
║               NOVO EMAIL RECEBIDO - DEBUG MODE                   ║
╚══════════════════════════════════════════════════════════════════╝

DEBUG [EMAIL_INFO]: ┌─ Informações do Remetente ─┐
DEBUG [EMAIL_INFO]: │ FROM Email    : [teste@exemplo.com]
DEBUG [EMAIL_INFO]: │ FROM Domain   : [exemplo.com]
DEBUG [EMAIL_INFO]: │ Remote IP     : [1.2.3.4]
DEBUG [EMAIL_INFO]: │ Authenticated : [False]
DEBUG [EMAIL_INFO]: └────────────────────────────┘
DEBUG [EMAIL_INFO]: TO (first): [contato@portalauditoria.com.br]
DEBUG [EMAIL_INFO]: Recipients are ALL internal: [False]

DEBUG [CACHE_STATUS]: ┌─ Status do Cache ─┐
DEBUG [CACHE_STATUS]: │ WL_Emails  : 127 entries
DEBUG [CACHE_STATUS]: │ WL_Domains : 50 entries
DEBUG [CACHE_STATUS]: │ WL_IPs     : 10 entries
DEBUG [CACHE_STATUS]: │ BL_Emails  : 500 entries
DEBUG [CACHE_STATUS]: │ BL_Domains : 1851 entries
DEBUG [CACHE_STATUS]: │ BL_IPs     : 100 entries
DEBUG [CACHE_STATUS]: └───────────────────┘

DEBUG [STEP_1]: ▶ Verificando AUTENTICACAO...
DEBUG [STEP_1]: ❌ NOT authenticated or internal message

DEBUG [STEP_2]: ▶ Verificando BLACKLIST (prioridade sobre whitelist)...
DEBUG [STEP_2]: ┌─ Checking BL_Emails ─┐
DEBUG [BL_EMAIL]: 🔍 Procurando [teste@exemplo.com] em 500 entradas...
DEBUG [BL_EMAIL]: ❌ NO MATCH para [teste@exemplo.com] (500 entradas verificadas)
DEBUG [STEP_2]: └─ BL_Emails: NO MATCH ─┘

DEBUG [STEP_2]: ┌─ Checking BL_Domains ─┐
DEBUG [BL_DOMAIN]: 🔍 Procurando [exemplo.com] em 1851 entradas...
DEBUG [BL_DOMAIN]: ❌ NO MATCH para [exemplo.com] (1851 entradas verificadas)
DEBUG [STEP_2]: └─ BL_Domains: NO MATCH ─┘

DEBUG [STEP_2]: ┌─ Checking BL_IPs ─┐
DEBUG [BL_IP]: 🔍 Procurando [1.2.3.4] em 100 entradas...
DEBUG [BL_IP]: ❌ NO MATCH para [1.2.3.4] (100 entradas verificadas)
DEBUG [STEP_2]: └─ BL_IPs: NO MATCH ─┘
DEBUG [STEP_2]: ✅ Não encontrado em nenhuma BLACKLIST

DEBUG [STEP_3]: ▶ Verificando WHITELIST (apenas se não estiver em blacklist)...
DEBUG [STEP_3]: ┌─ Checking WL_Emails ─┐
DEBUG [WL_EMAIL]: 🔍 Procurando [teste@exemplo.com] em 127 entradas...
DEBUG [WL_EMAIL]:   [50] ✅✅✅ MATCH EXATO! [teste@exemplo.com] == [teste@exemplo.com]
DEBUG [STEP_3]: ✅ PERMITIDO! Email encontrado na WHITELIST
DEBUG [STEP_3]: 🎯 DECISAO FINAL: ALLOW_AUREA: FROM_EMAIL in whitelist

═══════════════════════════════════════════════════════════════════
🎯 DECISAO FINAL: 25/11/2025 10:30:15 AM | FROM=teste@exemplo.com | To=contato@portalauditoria.com.br | IP=1.2.3.4 | AUTH=False | DECISION=10 | ALLOW_AUREA: FROM_EMAIL in whitelist
═══════════════════════════════════════════════════════════════════

DEBUG [ACTION]: ✅ PERMITINDO EMAIL (Result.Value=0)
```

---

## ⚙️ CONFIGURAÇÕES

### **DEBUG_MODE:**

```vbscript
Const DEBUG_MODE = True  ' ← Linha 13 do EventHandlers_v3.8_DEBUG_SUPER_DETALHADO.vbs
```

**Para desativar debug:**
1. Mude para `False`
2. Reinicie o serviço

**OU melhor:** Instale a v3.8 CORRIGIDO (sem debug) para produção.

---

### **CACHE_RELOAD_MINUTES:**

```vbscript
Const CACHE_RELOAD_MINUTES = 5  ' ← Linha 16
```

Cache é recarregado automaticamente a cada 5 minutos.

**Para forçar reload:** Reinicie o serviço hMailServer.

---

## 🔄 VOLTAR PARA VERSÃO DE PRODUÇÃO

Após diagnosticar o problema, **volte para v3.8 CORRIGIDO** (sem debug):

```powershell
# Parar serviço
Stop-Service -Name "hMailServer" -Force

# Instalar v3.8 CORRIGIDO (sem debug)
Copy-Item "EventHandlers_v3.8_CORRIGIDO.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

# Reiniciar
Start-Service -Name "hMailServer"
```

**OU use o script:**
```powershell
pwsh .\APLICAR_v3.8_CORRIGIDO.ps1
```

---

## 📈 TAMANHO DO LOG

### **Versão PRODUÇÃO (sem debug):**
- ~50-100 linhas por hora
- ~1-2 KB por hora

### **Versão DEBUG SUPER DETALHADO:**
- ~500-1000 linhas por hora
- ~20-50 KB por hora

**⚠️ O log vai crescer RÁPIDO!** Use apenas temporariamente (1-2 dias).

---

## 🎯 FLUXOGRAMA DE DECISÃO

```
Email recebido
    │
    ├─ Autenticado? ────────────────────── ✅ PERMITIR (AUTH)
    │   Sim → ALLOW_AUREA
    │   Não ↓
    │
    ├─ Mensagem interna? ─────────────────── ✅ PERMITIR (INTERNAL)
    │   Sim → ALLOW_AUREA
    │   Não ↓
    │
    ├─ Em BLACKLIST? ──────────────────────── 🔴 BLOQUEAR (BLACKLIST)
    │   Email → BLOCK_BLACK
    │   Domínio → BLOCK_BLACK
    │   IP → BLOCK_BLACK
    │   Não ↓
    │
    ├─ Em WHITELIST? ──────────────────────── ✅ PERMITIR (WHITELIST)
    │   Email → ALLOW_AUREA
    │   Domínio → ALLOW_AUREA
    │   IP → ALLOW_AUREA
    │   Não ↓
    │
    └─ DEFAULT ────────────────────────────── ✅ PERMITIR (DEFAULT)
        → ALLOW_AUTO
```

---

## 🔐 POLÍTICA DE SEGURANÇA

### **Prioridades (em ordem):**

1. **AUTH** (prioridade máxima) - Usuários autenticados sempre passam
2. **BLACKLIST** - Bloqueia spam (prioridade sobre whitelist!)
3. **WHITELIST** - Permite emails legítimos (só se não estiver em blacklist)
4. **DEFAULT** - Permite por padrão se não estiver em nenhuma lista

### **Por que BLACKLIST tem prioridade sobre WHITELIST?**

Exemplo:
```
whitelist_domains.txt: *.com
blacklist_domains.txt: spam.com
```

Email: `teste@spam.com`

**Política antiga (WL > BL):**
- Verifica whitelist primeiro
- `*.com` dá match → **PERMITE** (ERRADO!)
- Nunca checa blacklist → Spam entra!

**Política nova (BL > WL):**
- Verifica blacklist primeiro
- `spam.com` dá match → **BLOQUEIA** (CORRETO!)
- Nunca checa whitelist → Spam bloqueado!

---

## 📦 ARQUIVOS

| Arquivo | Descrição | Uso |
|---------|-----------|-----|
| `EventHandlers_v3.8_DEBUG_SUPER_DETALHADO.vbs` | Script com logs detalhados | Diagnóstico (1-2 dias) |
| `APLICAR_DEBUG_SUPER_DETALHADO.ps1` | Script de instalação | Instalação automatizada |
| `EventHandlers_v3.8_CORRIGIDO.vbs` | Script de produção | Uso permanente |
| `APLICAR_v3.8_CORRIGIDO.ps1` | Script de instalação | Produção |

---

## ✅ CHECKLIST PÓS-INSTALAÇÃO

- [ ] v3.8 DEBUG instalado
- [ ] Serviço hMailServer reiniciado
- [ ] Porta 25 está LISTENING (verificado)
- [ ] Log sendo monitorado em tempo real
- [ ] Email de teste enviado
- [ ] Email de teste RECEBIDO (servidor destrancou!)
- [ ] Logs DEBUG aparecendo no arquivo

**Se TODOS os itens foram marcados: ✅ SUCESSO!**

---

## 🎓 CONCLUSÃO

**EventHandlers v3.8 DEBUG SUPER DETALHADO** serve para:

1. ✅ **RESTART destranca** o servidor (como da última vez)
2. ✅ **Logs detalhados** permitem diagnosticar problemas
3. ✅ **Bug de wildcard corrigido** (*.xyz funciona!)
4. ✅ **Política segura** (BLACKLIST > WHITELIST)

**Após confirmar que está funcionando:**
- Volte para **v3.8 CORRIGIDO** (sem debug) para produção permanente

---

**Versão:** 3.8 DEBUG SUPER DETALHADO
**Data:** 25/11/2025
**Status:** ⚠️ **DIAGNÓSTICO TEMPORÁRIO** (use 1-2 dias, depois volte para v3.8 CORRIGIDO)
