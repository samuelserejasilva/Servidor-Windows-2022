# Servidor Windows Server 2022 — Ambiente de Produção

Servidor Windows Server 2022 para hospedagem de apps Java (Spring Boot/Tomcat), sites PHP em IIS e serviço de e-mail corporativo com hMailServer/Roundcube, integrado a Mikrotik e SSL Let's Encrypt.

---

## 🎯 Objetivo

Este repositório documenta uma infraestrutura **real em produção** para o domínio **portalauditoria.com.br**, executando em servidores Windows Server 2022.

Ele serve como:

* **Portfólio Técnico:** Demonstração prática de administração de sistemas, automação (DevOps) e segurança.
* **Base de Referência:** Documentação para provisionar e manter ambientes semelhantes (lab ou produção).
* **Diário de Bordo:** Histórico de scripts e soluções para problemas reais.

### 🔎 Resumo rápido (para recrutadores)

- 20+ anos de experiência com servidores Windows e redes.
- Ambiente completo de **e-mail corporativo** (hMailServer + Roundcube) com Autodiscover/Autoconfig e TLS.
- **Reverse proxy** com IIS + ARR + URL Rewrite para aplicações Java (Tomcat 11 / Spring Boot).
- Integração com **Mikrotik** (NAT, firewall, publicação de serviços) e DNS público.
- Automação em **PowerShell e VBScript** (Fail2Ban-like, renovação de certificados, rotinas de manutenção).
- Produção de **documentação técnica de back-end e front-end** (APIs REST, integração CSS, guias de desenvolvimento).

---

## 🧱 Arquitetura Geral

Este ambiente é construído sobre o **Windows Server 2022** e orquestra múltiplos serviços para entregar aplicações web e e-mail corporativo de forma segura e eficiente.

- **Sistema operacional:** Windows Server 2022
- **Web server / Proxy:**
  - IIS + ARR (Application Request Routing)
  - URL Rewrite enviando tráfego HTTP/HTTPS para Tomcat (reverse proxy)
- **Aplicações Java:**
  - Tomcat 11
  - Aplicações Java / Spring Boot publicadas atrás do IIS (cabeçalhos `X-Forwarded-*`)
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

## 🚀 Destaques do Projeto (Estudos de Caso)

Onde este projeto realmente brilha é na **automação** e na **segurança customizada**.  
Foram criados scripts em PowerShell e VBScript para resolver problemas que ferramentas prontas não cobrem.

### 1. 🛡️ Estudo de Caso: Segurança Anti-Spam e "Fail2Ban"

O hMailServer é poderoso, mas vulnerável a spam moderno e ataques de força bruta.  
A solução implementada tem duas camadas:

* **Camada 1 (VBScript):**  
  Filtro de eventos (`EventHandlers.vbs`) que intercepta e-mails no `OnSMTPData` e os valida contra:
  - whitelist/blacklist de IPs, domínios e e-mails;
  - regras de decisão (ALLOW / BLOCK) com logs de auditoria.

* **Camada 2 (PowerShell):**  
  Script "Fail2Ban" (`AUTO-BLOQUEIO-Fail2Ban.ps1`) que:
  - lê os logs do hMailServer;
  - conta falhas de autenticação (códigos 530/535) por IP;
  - identifica padrões de força bruta;
  - alimenta automaticamente a `blacklist_ips` utilizada pelo `EventHandlers.vbs`.

➡️ **[Documentação técnica desta solução](./docs/01-Seguranca-Anti-Spam.md)**

---

### 2. 🤖 Estudo de Caso: Automação de Certificados SSL (IIS + hMailServer)

O Win-ACME (Let’s Encrypt) automatiza certificados para o IIS, mas **não atualiza** o hMailServer.  
Para evitar intervenção manual a cada 90 dias, foi criada uma esteira 100% automatizada em PowerShell que:

1. É acionada pelo Win-ACME após a renovação (`post-renew.ps1` / `automacao-de-ce.ps1`).
2. Extrai o novo certificado e sua chave privada (`01-extract-keys.ps1`).
3. Atualiza o hMailServer usando a API COM (`02-update-hmail.ps1`).
4. Executa uma auditoria para garantir que o IIS e o hMailServer usam o **mesmo certificado** (`Comparar-Certificados-HMail-IIS.ps1`).

➡️ **[Documentação técnica desta solução](./docs/02-Automacao-SSL.md)**

---

## 📂 Estrutura do Repositório

* `docs/` — Documentação técnica:
  - Visão geral da arquitetura do ambiente.
  - Configurações principais de Windows, IIS, Tomcat, PHP, hMailServer, Mikrotik.
  - Estudos de caso:
    - `01-Seguranca-Anti-Spam.md`
    - `02-Automacao-SSL.md`
    - Outros guias (IIS + PHP + Roundcube, Autoconfig/Autodiscover, etc.).
* `scripts/hmail/` — Scripts PowerShell para automação de segurança e relatórios do hMailServer.
* `scripts/ssl/` — Scripts PowerShell para a esteira de renovação de certificados SSL.
* `config/` — Exemplos de arquivos de configuração **anonimizados**.
* `EventHandlers.vbs` — Script principal de anti-spam / anti-abuso do hMailServer.
* `autodiscover.xml` — Arquivo de configuração para Autodiscover do Outlook.
* `config-v1.1.xml` — Arquivo de configuração para Autoconfig do Thunderbird.
* `infra/` (opcional/futuro) — Diagramas e documentação de rede.

> **Atenção:** informações sensíveis (senhas, chaves privadas, IPs internos reais) **não** são versionadas aqui.

---

## 🌐 Serviços Publicados (Endpoints Principais)

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

## 🧾 Documentação de Back-end e Front-end

Além da infraestrutura, este repositório também referencia (em outros docs/projetos):

- **Documentação de APIs REST** (ex.: `api-documentation.md`, especificação de endpoints back-end).
- **Guia de integração CSS / front-end** (ex.: `CSS-INTEGRATION-GUIDE.md`).
- **Guias de desenvolvimento e arquitetura de módulos** (ex.: `GUIA_DESENVOLVIMENTO.md`, `Projeto_modulo_users.md`, `Projeto_tecnico_auth.md`).

Esses materiais mostram o outro lado do perfil: além de administrar servidores, também:
- dialoga com times de desenvolvimento;
- entende contratos de API e segurança de autenticação;
- produz documentação clara para front-end e back-end trabalharem em conjunto.

---

## 🌍 English Summary

```text
This repository documents a real **Windows Server 2022 production environment** for the domain portalauditoria.com.br.

It hosts:
- Java web applications (Spring Boot / Tomcat) behind IIS + ARR + URL Rewrite;
- PHP applications on IIS via FastCGI (Roundcube webmail and others);
- Corporate e-mail using hMailServer + Roundcube with Autodiscover/Autoconfig;
- Public exposure through a Mikrotik router (NAT, firewall, port forwarding) and public DNS;
- Automated TLS certificate renewal with Let’s Encrypt (win-acme) and PowerShell scripts to sync IIS and hMailServer.

The repository includes real-world automation examples:
- Anti-abuse / anti-spam logic using hMailServer EventHandlers (VBScript) + a Fail2Ban-like PowerShell script;
- Full SSL automation pipeline integrating win-acme, certificate export and hMailServer updates;
- Technical documentation for both infrastructure and application integration (APIs, front-end/back-end).


## 👤 Autor

**Samuel S.**
Administrador de Sistemas Sênior com mais de 20 anos de experiência em infraestrutura Windows, gerenciamento de redes (Mikrotik) e arquitetura de serviços de e-mail e web (hMailServer, IIS, Tomcat).

