# Servidor Windows Server 2022 — Ambiente de Produção (Hardened)

> **Status de Segurança (Dez/2025):** \
> 🟢 **CheckTLS Score:** 114/114 (100%) \
> 🔒 **Criptografia:** TLS 1.3 & 1.2 (Strict) \
> 🛡️ **Anti-Spam:** Fail2Ban Customizado + Filtro de Borda

Servidor Windows Server 2022 para hospedagem de apps Java (Spring Boot/Tomcat), sites PHP em IIS e serviço de e-mail corporativo com hMailServer/Roundcube, integrado a Mikrotik e SSL Let's Encrypt.

---

## 🎯 Objetivo

Este repositório documenta uma infraestrutura **real em produção** para o domínio **portalauditoria.com.br**. Ele serve como:

* **Portfólio Técnico:** Demonstração prática de administração de sistemas, automação (DevOps) e segurança ofensiva/defensiva.
* **Base de Referência:** Documentação para provisionar ambientes Windows seguros (Hardening).
* **Diário de Bordo:** Scripts PowerShell e VBScript para resolver limitações nativas do ambiente Windows.

### 🔎 Resumo Técnico
* **OS:** Windows Server 2022.
* **E-mail:** hMailServer (Hardened) + Roundcube + Autodiscover.
* **Web:** IIS (Reverse Proxy) + Tomcat 11 (Java/Spring) + PHP 8.x.
* **Rede:** Mikrotik (Firewall/NAT) + Integração Cloudflare/Registro.br.
* **Automação:** PowerShell (Fail2Ban, SSL Renew) e VBScript (Event Handlers).

---

## 🛡️ Destaque 2025: hMailServer Hardening Kit

Um dos maiores desafios deste projeto foi modernizar o **hMailServer** (software legado) para atender aos requisitos de segurança de 2025 exigidos por Gmail, Outlook e Yahoo.

Implementamos um **Hardening Kit** que elevou a segurança de transporte ao nível máximo.

### 1. Criptografia de Elite (TLS 1.3)
Substituímos a stack padrão de criptografia do Windows/hMailServer por uma configuração restritiva.
* **Protocolos:** TLS 1.0 e 1.1 **Desativados**. Apenas TLS 1.2 e 1.3 permitidos.
* **Ciphers:** Forçamos o uso de algoritmos modernos (Elliptic Curves e AES-GCM), banindo RC4, MD5 e 3DES.

**Resultado Comprovado:**
> *O servidor atingiu a pontuação **114 de 114 (100%)** no teste internacional CheckTLS, garantindo "Verde" em todos os quesitos de segurança, certificado e criptografia.*

*(Inserir aqui o print do CheckTLS 100% se desejar)*

### 2. Defesa Ativa Anti-Spam ("Fail2Ban" para Windows)
Como o hMailServer não possui proteção nativa contra força bruta moderna, desenvolvi duas camadas de defesa:

* **Camada 1 (VBScript - `EventHandlers.vbs`):**
    * Intercepta a conexão SMTP (`OnSMTPData`).
    * Consulta listas de bloqueio em tempo real (`blacklist_domains.txt` com suporte a wildcard `*.dominio.com` e `blacklist_ips.txt`).
    * Rejeita conexões vindas de TLDs ou provedores de spam conhecidos antes mesmo de processar a mensagem.

* **Camada 2 (PowerShell - `AUTO-BLOQUEIO-Fail2Ban.ps1`):**
    * Lê os logs do hMailServer a cada X minutos.
    * Identifica IPs com múltiplas falhas de autenticação (Erro 535).
    * Adiciona automaticamente o IP ofensivo à blacklist do Firewall ou do script VBS.

➡️ **[Ver Documentação Detalhada de Segurança](/docs/01-Seguranca-Anti-Spam.md)**

---

## 🤖 Automação de Certificados SSL (Full Pipeline)

O Win-ACME (Let’s Encrypt) renova o certificado do IIS, mas não atualiza nativamente o serviço de e-mail. Para resolver isso, criei uma esteira automatizada em PowerShell:

1.  **Trigger:** O Win-ACME renova o certificado.
2.  **Extração (`01-extract-keys.ps1`):** O script localiza o novo `.pfx`, extrai a Chave Privada e o Certificado Público.
3.  **Aplicação (`02-update-hmail.ps1`):** Interage com a API COM do hMailServer para substituir o certificado nas portas SMTP (587) e IMAP (993).
4.  **Auditoria (`Comparar-Certificados.ps1`):** Verifica se o Thumbprint do certificado do IIS bate com o do hMailServer, garantindo sincronia.

➡️ **[Ver Documentação de Automação SSL](/docs/02-Automacao-SSL.md)**

---

## 📂 Estrutura do Repositório

* `docs/` — Documentação técnica detalhada.
* `scripts/hmail/` — Scripts de automação (Fail2Ban, Logs, Manutenção).
* `scripts/ssl/` — Pipeline de renovação de certificados.
* `EventHandlers.vbs` — O "cérebro" da segurança do hMailServer.
* `autodiscover.xml` & `config-v1.1.xml` — Arquivos para configuração automática de Outlook e Thunderbird.

---

## 🌐 Serviços Publicados

### Aplicação Web (Java / Tomcat)
* Reverse Proxy via **IIS + ARR**.
* Tráfego HTTP redirecionado para HTTPS.
* Cabeçalhos de segurança (`X-Forwarded-Proto`, `HSTS`) configurados.

### Webmail (Roundcube)
* Rodando sobre IIS + PHP FastCGI.
* URL: `https://www.portalauditoria.com.br/webmail/`
* Hardening no `web.config` bloqueando acesso a diretórios sensíveis do Roundcube.

---

## 👤 Autor

**Samuel S.**
*Administrador de Sistemas Sênior & Desenvolvedor*
Especialista em infraestrutura Windows, Redes e integração de sistemas legados com segurança moderna.
