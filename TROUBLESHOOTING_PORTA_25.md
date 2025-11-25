# 🔧 TROUBLESHOOTING: Porta 25 Não Recebe Emails

## 🎯 OBJETIVO

Diagnosticar e corrigir o problema onde **hMailServer não recebe emails externos** porque a porta 25 não está aceitando conexões SMTP de entrada.

---

## 📊 SINTOMAS OBSERVADOS

### ✅ O que FUNCIONA:
- IMAP (porta 993) - ✅ Clientes conseguem acessar caixas
- SMTP autenticado (porta 465) - ✅ Envio de emails OK
- Script EventHandlers executa - ✅ Mas só para emails de SAÍDA

### ❌ O que NÃO funciona:
- Porta 25 não recebe conexões externas
- Zero emails de entrada nos logs
- Script nunca é chamado para emails externos (AUTH=False)

---

## 🔍 DIAGNÓSTICO PASSO A PASSO

### **ETAPA 1: Verificar se Porta 25 Está em LISTEN**

```powershell
# Abra PowerShell como Administrador
netstat -an | findstr ":25"
```

**Resultados Esperados:**

#### ✅ PORTA 25 FUNCIONANDO:
```
TCP    0.0.0.0:25             0.0.0.0:0              LISTENING
TCP    [::]:25                [::]:0                 LISTENING
```
**Interpretação:** Porta 25 está aberta e aguardando conexões IPv4 e IPv6.

#### ❌ PORTA 25 NÃO FUNCIONANDO:
```
(nenhuma saída ou somente outras portas aparecem)
```
**Interpretação:** Serviço SMTP não está em execução ou não iniciou o listener.

#### ⚠️ PORTA 25 SOMENTE IPV6:
```
TCP    [::]:25                [::]:0                 LISTENING
```
**Interpretação:** Porta aberta apenas para IPv6, pode causar problemas com servidores IPv4.

---

### **ETAPA 2: Verificar Status do Serviço hMailServer**

```powershell
Get-Service -Name "hMailServer" | Format-List *
```

**Verificar:**
- `Status` deve ser `Running`
- `StartType` deve ser `Automatic`
- `CanStop` deve ser `True`

**Se serviço não está rodando:**
```powershell
Start-Service -Name "hMailServer"
```

**Se serviço está "travado" (Running mas não responde):**
```powershell
Restart-Service -Name "hMailServer" -Force
Start-Sleep -Seconds 10
Get-Service -Name "hMailServer"
```

---

### **ETAPA 3: Verificar Logs de Erro do hMailServer**

```powershell
# Ver últimas 30 linhas do log de erro
Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_errors.log" -Tail 30
```

**Erros Comuns:**

#### ❌ Erro: "Failed to bind to port 25"
```
ERROR: The SMTP server failed to bind to port 25 (Address already in use)
```
**Causa:** Outro serviço já está usando a porta 25.
**Solução:** Ver ETAPA 6.

#### ❌ Erro: "Access denied"
```
ERROR: Access denied when trying to bind to port 25
```
**Causa:** Permissões insuficientes ou firewall bloqueando.
**Solução:** Executar serviço como administrador ou ajustar permissões.

#### ❌ Erro: "Certificate error"
```
ERROR: Unable to load SSL certificate
```
**Causa:** Problema com certificado SSL/TLS.
**Solução:** Verificar configuração de certificados no hMailServer Administrator.

---

### **ETAPA 4: Testar Conexão Local na Porta 25**

```powershell
Test-NetConnection -ComputerName localhost -Port 25
```

**Resultado Esperado:**
```
ComputerName     : localhost
RemoteAddress    : ::1
RemotePort       : 25
InterfaceAlias   : Loopback Pseudo-Interface 1
SourceAddress    : ::1
TcpTestSucceeded : True  ← ✅ DEVE SER TRUE!
```

**Se TcpTestSucceeded = False:**
- Porta 25 não está aceitando conexões
- Prosseguir para ETAPA 5 (firewall) e ETAPA 6 (conflito de porta)

---

### **ETAPA 5: Verificar Firewall do Windows**

```powershell
# Listar regras de firewall relacionadas à porta 25
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*mail*" -or $_.DisplayName -like "*SMTP*"} | Format-Table DisplayName, Enabled, Direction, Action
```

**Verificar:**
- Deve existir regra permitindo (Action = Allow) tráfego Inbound na porta 25
- Regra deve estar Enabled = True

**Se não existe regra:**
```powershell
# Criar regra de firewall para porta 25
New-NetFirewallRule -DisplayName "hMailServer SMTP Inbound" `
                    -Direction Inbound `
                    -LocalPort 25 `
                    -Protocol TCP `
                    -Action Allow `
                    -Profile Any `
                    -Enabled True
```

**Se regra existe mas está desabilitada:**
```powershell
# Habilitar regra existente (substitua "NOME_DA_REGRA" pelo nome real)
Enable-NetFirewallRule -DisplayName "hMailServer SMTP Inbound"
```

**Testar novamente:**
```powershell
Test-NetConnection -ComputerName localhost -Port 25
```

---

### **ETAPA 6: Verificar Conflito de Porta 25**

```powershell
# Ver qual processo está usando a porta 25
netstat -ano | findstr ":25"
```

**Exemplo de saída:**
```
TCP    0.0.0.0:25       0.0.0.0:0     LISTENING       1234
```

O número final (1234) é o PID (Process ID). Descobrir qual processo:

```powershell
Get-Process -Id 1234
```

**Processos Comuns que Conflitam:**

| Processo | Descrição | Solução |
|----------|-----------|---------|
| `inetinfo.exe` | IIS SMTP Service | Desabilitar IIS SMTP |
| `Microsoft.Exchange.*` | Exchange Server | Reconfigurar Exchange |
| `hmailserver.exe` | hMailServer (esperado) | ✅ Correto! |
| Outro desconhecido | Malware ou serviço inesperado | Investigar e remover |

**Para desabilitar IIS SMTP:**
```powershell
Stop-Service -Name "SMTPSVC" -Force
Set-Service -Name "SMTPSVC" -StartupType Disabled
```

---

### **ETAPA 7: Verificar IP Ranges do hMailServer**

**Procedimento Manual:**

1. Abrir **hMailServer Administrator**
2. Conectar ao servidor
3. Navegar: **Settings → Advanced → IP Ranges**
4. Verificar configuração

**Configuração Esperada:**

Deve existir pelo menos um IP Range que permite conexões externas:

| Nome | Prioridade | Lower IP | Upper IP | Allow connections | Allow deliveries |
|------|-----------|----------|----------|-------------------|------------------|
| Internet | 10 ou 15 | 0.0.0.0 | 255.255.255.255 | ✅ Sim | ✅ Sim |

**Se NÃO existe:**

1. Clicar em **Add**
2. Configurar:
   - Name: `Internet`
   - Priority: `15`
   - Lower IP: `0.0.0.0`
   - Upper IP: `255.255.255.255`
3. Na aba **Incoming connections**:
   - ✅ Marcar: "Allow connections from this range"
4. Na aba **Deliveries**:
   - ✅ Marcar: "Allow deliveries from IP range to these email addresses"
   - Selecionar: "All addresses"
5. Clicar **Save**
6. Reiniciar serviço hMailServer

**Se existe mas está desabilitado:**
- Editar o IP Range
- Marcar as opções corretas
- Salvar e reiniciar serviço

---

### **ETAPA 8: Testar Conexão SMTP Manual**

```powershell
# Abrir Telnet (se não instalado, instalar primeiro)
# Instalar Telnet:
# dism /online /Enable-Feature /FeatureName:TelnetClient

# Conectar à porta 25:
telnet localhost 25
```

**Resposta Esperada:**
```
220 mail.portalauditoria.com.br ESMTP
```

**Testar comandos SMTP:**
```
EHLO teste.com
MAIL FROM:<teste@teste.com>
RCPT TO:<usuario@portalauditoria.com.br>
QUIT
```

**Se receber "250 OK" para RCPT TO:** ✅ Porta 25 funcionando!

**Se receber "550 Relay not allowed" ou similar:** ⚠️ IP Range ou política anti-relay bloqueando.

**Se não conectar:** ❌ Porta 25 não está funcionando - revisar ETAPAs anteriores.

---

### **ETAPA 9: Verificar Logs SMTP em Tempo Real**

```powershell
# Monitorar log do hMailServer em tempo real
Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_*.log" -Wait -Tail 20
```

**Enviar email de teste externo** (Gmail, Outlook, etc.) para `usuario@portalauditoria.com.br`

**Deve aparecer no log:**
```
"SMTPD" <PID> <Thread> "<data>" "<IP_EXTERNO>" "RECEIVED: MAIL FROM:<remetente@gmail.com>"
"SMTPD" <PID> <Thread> "<data>" "<IP_EXTERNO>" "RECEIVED: RCPT TO:<usuario@portalauditoria.com.br>"
```

**Se NÃO aparece:** Email não está chegando ao servidor (problema de rede/DNS/firewall externo).

---

## 🛠️ SOLUÇÕES RÁPIDAS

### **Solução 1: Restart Completo do hMailServer**

```powershell
# Parar serviço
Stop-Service -Name "hMailServer" -Force

# Aguardar 10 segundos
Start-Sleep -Seconds 10

# Iniciar serviço
Start-Service -Name "hMailServer"

# Aguardar 10 segundos para inicialização completa
Start-Sleep -Seconds 10

# Verificar se porta 25 está em LISTEN
netstat -an | findstr ":25"

# Verificar logs
Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_errors.log" -Tail 5
```

### **Solução 2: Desabilitar IPv6 (se causando problemas)**

**Se porta 25 só está em LISTEN para IPv6 mas você precisa IPv4:**

1. Abrir hMailServer Administrator
2. Settings → Advanced → TCP/IP ports
3. Verificar configuração SMTP:
   - Port: 25
   - Address: 0.0.0.0 (para IPv4) OU :: (para IPv6) OU VAZIO (ambos)
4. Alterar para `0.0.0.0` se estava `::`
5. Salvar e reiniciar serviço

### **Solução 3: Verificar DNS e MX Record**

```powershell
# Verificar registro MX do domínio
nslookup -type=MX portalauditoria.com.br
```

**Resultado Esperado:**
```
portalauditoria.com.br  MX preference = 10, mail exchanger = mail.portalauditoria.com.br
```

**Verificar IP do servidor:**
```powershell
nslookup mail.portalauditoria.com.br
```

**Deve retornar o IP correto do servidor.**

Se DNS/MX não está configurado corretamente, emails externos não saberão para onde enviar!

---

## 📋 CHECKLIST DE VERIFICAÇÃO

Execute este checklist na ordem:

- [ ] **ETAPA 1:** Porta 25 está em LISTEN? (`netstat -an | findstr ":25"`)
- [ ] **ETAPA 2:** Serviço hMailServer está rodando? (`Get-Service -Name "hMailServer"`)
- [ ] **ETAPA 3:** Logs não mostram erros críticos?
- [ ] **ETAPA 4:** Teste local na porta 25 bem-sucedido? (`Test-NetConnection`)
- [ ] **ETAPA 5:** Firewall permite tráfego na porta 25?
- [ ] **ETAPA 6:** Nenhum conflito de porta? (outro serviço usando porta 25)
- [ ] **ETAPA 7:** IP Ranges permite conexões externas?
- [ ] **ETAPA 8:** Teste SMTP manual funciona? (`telnet localhost 25`)
- [ ] **ETAPA 9:** Logs mostram conexões SMTP de entrada?
- [ ] **DNS/MX:** Registro MX aponta para servidor correto?

---

## 🎯 DIAGNÓSTICO RÁPIDO (1 MINUTO)

```powershell
# Execute este bloco completo no PowerShell como Administrador:

Write-Host "`n=== DIAGNÓSTICO PORTA 25 ===" -ForegroundColor Cyan

Write-Host "`n1. Status do Serviço:" -ForegroundColor Yellow
Get-Service -Name "hMailServer" | Select-Object Status, StartType

Write-Host "`n2. Porta 25 em LISTEN:" -ForegroundColor Yellow
netstat -an | findstr ":25"

Write-Host "`n3. Teste de Conexão Local:" -ForegroundColor Yellow
Test-NetConnection -ComputerName localhost -Port 25 | Select-Object TcpTestSucceeded

Write-Host "`n4. Processo na Porta 25:" -ForegroundColor Yellow
$port25 = netstat -ano | findstr ":25.*LISTENING"
if ($port25) {
    $pid = ($port25 -split '\s+')[-1]
    Get-Process -Id $pid | Select-Object ProcessName, Id
}

Write-Host "`n5. Últimos Erros:" -ForegroundColor Yellow
Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_errors.log" -Tail 3

Write-Host "`n=== FIM DO DIAGNÓSTICO ===`n" -ForegroundColor Cyan
```

**Copie e cole este bloco no PowerShell para diagnóstico instantâneo!**

---

## 🚀 APÓS CORRIGIR PORTA 25

Quando a porta 25 estiver funcionando corretamente:

1. ✅ Confirmar que `netstat -an | findstr ":25"` mostra `LISTENING`
2. ✅ Enviar email de teste de Gmail/Outlook para seu domínio
3. ✅ Verificar que email aparece nos logs: `Get-Content "C:\Program Files (x86)\hMailServer\Logs\hmailserver_*.log" -Tail 50`
4. ✅ **ENTÃO** instalar v3.8.1 DEBUG: `.\APLICAR_v3.8.1_DEBUG.ps1`
5. ✅ Monitorar `C:\hmail-lists\logs\AureaBlack_Lists.log` para logs detalhados

---

## 📞 SUPORTE ADICIONAL

Se após todas as etapas a porta 25 ainda não funciona:

1. **Verificar com provedor de internet:**
   - Alguns ISPs bloqueiam porta 25 em IPs residenciais
   - Pode ser necessário IP comercial ou usar porta alternativa (587)

2. **Verificar firewall de rede/roteador:**
   - Port forwarding configurado corretamente?
   - Porta 25 bloqueada no roteador?

3. **Logs detalhados do Windows:**
   ```powershell
   Get-EventLog -LogName System -Source "Service Control Manager" -Newest 20 | Where-Object {$_.Message -like "*hMail*"}
   ```

---

**Data:** 25/11/2025
**Versão:** 1.0
**Status:** Aguardando execução pelo usuário
