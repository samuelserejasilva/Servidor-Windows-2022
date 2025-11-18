# Autoconfiguração de E-mail — Autodiscover (Outlook) e Autoconfig (Thunderbird)

> Este documento descreve como está estruturada a **autoconfiguração de clientes de e-mail**
> para o domínio **portalauditoria.com.br**, usando:
>
> - **hMailServer** como servidor de e-mail;
> - **IIS** para servir os arquivos XML de autodiscover/autoconfig;
> - Integração com **DNS** (MX, SPF, DKIM, DMARC).

---

## 1. Visão geral

Objetivo:

- Permitir que clientes de e-mail (Outlook, Thunderbird, etc.) se configurem quase sozinhos,
  preenchendo automaticamente:
  - Servidor de entrada (**IMAP**)
  - Servidor de saída (**SMTP**)
  - Portas
  - Tipo de criptografia (SSL/TLS ou STARTTLS)
  - Formato de usuário (e-mail completo)

Cenário:

- **Servidor de e-mail:** hMailServer
- **Host de e-mail público:** `mail.portalauditoria.com.br`
- **Web server:** IIS no mesmo Windows Server 2022
- **Webmail:** Roundcube em `https://www.portalauditoria.com.br/webmail/`
- **Clientes alvo:**
  - Outlook (via `autodiscover.xml`)
  - Thunderbird / Mozilla (via `config-v1.1.xml`)

---

## 2. DNS para e-mail

### 2.1 Registros básicos (A e MX)

Exemplo de configuração atual no Registro.br:

- `A`  
  - `portalauditoria.com.br` → `167.250.65.254`
  - `mail.portalauditoria.com.br` → `167.250.65.254`

- `MX`  
  - `@` → prioridade `10` → `mail.portalauditoria.com.br.`

Isso garante que:

- Navegação em `www.portalauditoria.com.br` / `portalauditoria.com.br` vá para o IIS.
- E-mails para `@portalauditoria.com.br` sejam entregues ao hMailServer atrás do Mikrotik.

### 2.2 SPF

Registro **TXT** sugerido (já utilizado):

```txt
v=spf1 mx ip4:167.250.65.254 -all
_dmarc.portalauditoria.com.br. IN TXT "v=DMARC1; p=quarantine; sp=quarantine; adkim=s; aspf=s; rua=mailto:dmarc@portalauditoria.com.br; ruf=mailto:dmarc@portalauditoria.com.br"



