# hMailServer — Checklist de Configuração e Diagnóstico

> Servidor de e-mail em **Windows Server 2022**, com **hMailServer + Roundcube**,
> integrado ao domínio **portalauditoria.com.br** e publicado em  
> `mail.portalauditoria.com.br` atrás do **Mikrotik**.

---

## 1. Visão geral do ambiente

- **Domínio:** `portalauditoria.com.br`
- **Host de e-mail público:** `mail.portalauditoria.com.br`
- **Servidor de e-mail:** hMailServer em Windows Server 2022
- **Webmail:** Roundcube em `https://www.portalauditoria.com.br/webmail/`
- **Firewall/NAT:** Mikrotik (porta 25/587/993 → servidor interno)
- **DNS:** MX, SPF, DKIM, DMARC configurados no Registro.br

---

## 2. Checklist de configuração básica

### 2.1 Domínio e contas

No **hMailServer Administrator**:

1. **Domains**
   - `portalauditoria.com.br` criado.
   - Ativo (checkbox `Enabled` marcado).

2. **Accounts**
   - Criar pelo menos:
     - `teste@portalauditoria.com.br` (para diagnóstico).
     - Contas reais de produção.
   - Verificar:
     - Senha forte.
     - Limite de tamanho de caixa (quota) se aplicável.

3. **Aliases** (opcional):
   - Emails alternativos apontando para contas reais (ex.: `contato@`, `suporte@`).

---

### 2.2 Protocolos e portas (hMailServer)

**Settings → Protocols**

1. **SMTP**
   - `Enabled` ✅
   - Porta padrão: `25`
   - `Delivery of e-mail` configurado para saída (se usar relay, configurar aqui).

2. **IMAP**
   - `Enabled` ✅
   - Porta: `143` (opcional)
   - Porta: `993` (IMAPS) recomendada.

3. **POP3** (se usar)
   - `Enabled` só se houver necessidade.
   - **Recomendação:** priorizar IMAP/IMAPS.

---

### 2.3 TLS / Certificados

**Settings → Advanced → SSL certificates**

- Importar certificado (PFX) emitido via **Let’s Encrypt**:
  - Nome: `mail.portalauditoria.com.br`
  - Caminho PFX e senha configurados.

**Settings → Advanced → TCP/IP ports**

- IMAP (143) — sem SSL (opcional).
- IMAPS (993) — com SSL, usando o certificado `mail.portalauditoria.com.br`.
- SMTP (25) — pode aceitar STARTTLS (opcional, recomendado).
- SMTP (587) — submissão autenticada com STARTTLS obrigatório.

> **Boa prática:**  
> Para clientes (Outlook/Thunderbird), padronizar:
> - IMAP: `993` + SSL/TLS  
> - SMTP: `587` + STARTTLS + autenticação obrigatória

---

## 3. IP Ranges (Anti-relay e permissões)

**Settings → Advanced → IP Ranges**

IP ranges definem **quem pode enviar o quê**. Os principais:

### 3.1 My Computer

- Geralmente `127.0.0.1` (localhost).
- **Permissões típicas:**
  - Allow deliveries from: `Local`, `External`
  - Allow deliveries to: `Local`, `External`
  - Require SMTP authentication: `desmarcado` (para o próprio servidor).

> Usado para: webmail (Roundcube em localhost), scripts internos, etc.

### 3.2 LAN (opcional)

Se quiser permitir envio sem autenticação de impressoras/softwares específicos da rede:

- IP Range: rede interna (ex.: `10.165.0.0-10.165.0.255`)
- Allow deliveries from: `Local`, `External`
- Allow deliveries to: `Local`, `External`
- Require authentication:
  - Pode deixar **desmarcado** apenas para IPs confiáveis.
  - Se possível, limitar a hosts específicos, não à LAN toda.

### 3.3 Internet

- Engloba “o resto do mundo”.
- **MUITO IMPORTANTE**:

  - Allow deliveries from:
    - `[x] External`
    - `[x] Local`
  - Allow deliveries to:
    - `[x] Local`
    - `[ ] External`  (para evitar relay aberto)
  - Require SMTP authentication:
    - `[ ] Local to local`
    - `[x] Local to external`
    - `[x] External to external`
    - `[ ] External to local`  (para permitir receber e-mail da internet sem exigir auth)

> **Resumo:**  
> Para receber e-mail externo → local, **não** pode exigir autenticação em "External to local".  
> Para evitar spam/relay → sempre exigir auth de "Local to external" e "External to external".

---

## 4. Logs — onde ver e o que habilitar

**Settings → Logging**

Ativar pelo menos:

- `[x] Application`
- `[x] SMTP`
- `[x] IMAP`
- `[x] TCP/IP` (útil para debug de conexão)

Caminho típico dos logs:

```text
C:\Program Files (x86)\hMailServer\Logs\
  hmailserver_YYYY-MM-DD.log
  hmailserver_awstats_YYYY-MM-DD.log

```

 ## Firewall Windows + Mikrotik
 > Firewall do Windows Server
    Garantir que o Windows aceite:
> Entrada:
> 25/TCP (SMTP)
> 587/TCP (SMTP submissão)
> 143/TCP (IMAP) se usado
> 993/TCP (IMAPS)

    Saída: normalmente liberada (para que o servidor envie e-mail externo).

```powershell
# 
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*SMTP*" -or $_.DisplayName -like "*IMAP*" } |
  Select DisplayName, Enabled, Direction, Action

```
