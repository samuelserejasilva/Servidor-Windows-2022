# Servidor Windows Server 2022 — Ambiente de Produção

Servidor Windows Server 2022 para hospedagem de apps Java (Spring Boot/Tomcat), sites PHP em IIS e serviço de e-mail corporativo com hMailServer/Roundcube, integrado a Mikrotik e SSL Let's Encrypt.

---

## 🎯 Objetivo

Este repositório documenta a infraestrutura que eu utilizo em produção para o domínio **servindores**, servindo como:

- Portfólio técnico (infraestrutura Windows + rede + e-mail).
- Base de referência para montar ambientes semelhantes em laboratório.
- Histórico versionado de scripts, ajustes e documentação.

---

## 🧱 Arquitetura Geral

- **Sistema operacional:** Windows Server 2022
- **Web server / Proxy:**
  - IIS + ARR (Application Request Routing)
  - URL Rewrite enviando tráfego HTTP/HTTPS para Tomcat (reverse proxy)
- **Aplicações Java:**
  - Tomcat 11
  - Aplicações Java / Spring Boot publicadas atrás do IIS (X-Forwarded-*)
- **PHP:**
  - PHP 8.x via CGI / FastCGI no IIS
  - Configuração dedicada para webmail (Roundcube) e outros apps PHP
- **E-mail corporativo:**
  - hMailServer (SMTP, IMAP, POP3)
  - Roundcube como webmail em `/webmail`
  - Autodiscover/Autoconfig para configuração automática de clientes
- **Rede e borda:**
  - Mikrotik (NAT, firewall, port forwarding)
  - Integração com DNS público (Registro.br)
- **Certificados:**
  - Let’s Encrypt (Win-ACME)
  - SSL para `mail.`, `www.` e outros subdomínios

---

## 🌐 Serviços publicados (endpoints principais)

Principais serviços expostos pelo ambiente:

### 🌍 Aplicação Web Principal (Java / Tomcat)

- Servida via **IIS + ARR** como reverse proxy.
- Tráfego:
  - HTTP → redirecionado para HTTPS (com exceção de `/.well-known/acme-challenge/` para o Let’s Encrypt).
  - HTTPS → encaminhado para o Tomcat em `http://127.0.0.1:8080/...`
- Cabeçalhos de proxy:
  - `X-Forwarded-Proto: https`
  - `X-Forwarded-Host: {HTTP_HOST}`
  - `X-Forwarded-Port: 443`

### 📧 Webmail (Roundcube)

- URL: `https://www.portalauditoria.com.br/webmail/`
- Stack:
  - IIS + PHP FastCGI (`C:\php\php-cgi.exe`)
  - `AppPool_Webmail` dedicado (No Managed Code, 64-bit)
  - `webmail.ini` próprio para o PHP (extensões e performance)
- Segurança:
  - `installer` bloqueado em produção via `web.config`
  - Permissões NTFS restritas (`Modify` apenas em `logs/` e `temp/`)
  - Cabeçalhos de segurança (`X-Frame-Options`, `X-Content-Type-Options`, etc.)

### 🧩 Autodiscover (Outlook)

- Endpoint:  
  `https://portalauditoria.com.br/autodiscover/autodiscover.xml`
- Função:
  - Permitir que o Outlook descubra automaticamente:
    - IMAP: `mail.portalauditoria.com.br:993` (SSL/TLS)
    - SMTP: `mail.portalauditoria.com.br:587` (STARTTLS)
    - Login usando o próprio e-mail do usuário.

### 🐦 Autoconfig (Thunderbird / Mozilla)

- Endpoint:  
  `https://portalauditoria.com.br/mail/config-v1.1.xml`
- Função:
  - Auto-configuração de contas em clientes Mozilla (Thunderbird, etc.) usando:
    - IMAP 993 (SSL)
    - SMTP 587 (STARTTLS)
    - Usuário = e-mail completo.

> Esses endpoints são tratados via **exceções** nas regras de URL Rewrite do `web.config` raiz, para não serem enviados ao Tomcat:
> - `/webmail/`
> - `/php/`
> - `/autodiscover/`
> - `/mail/`
> - `/.well-known/` (ACME, etc.)

---

## 📂 O que há neste repositório

- `docs/` — Documentação técnica:
  - Visão geral do ambiente.
  - Configurações principais de Windows, IIS, Tomcat, PHP, hMailServer, Mikrotik.
  - Guias específicos:
    - IIS + PHP FastCGI + Roundcube (`/webmail`)
    - IIS + ARR + Tomcat + Autodiscover/Autoconfig
- `scripts/` — Scripts de automação e apoio:
  - PowerShell para instalação/configuração no Windows.
  - Scripts Mikrotik (`.rsc`) para NAT e firewall.
- `config/` — Exemplos de arquivos de configuração anonimizados.
- `infra/` (opcional) — Diagramas e documentação de rede futuramente.

> **Atenção:** informações sensíveis (senhas, chaves privadas, IPs internos reais) não são versionadas aqui.


## 👤 Autor

Samuel S. — Administração de sistemas Windows, redes Mikrotik e serviços de e-mail corporativo.

