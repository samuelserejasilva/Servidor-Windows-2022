# Servidor Windows Server 2022 — Infraestrutura de Produção (Hardened)

> **Status de Segurança (Dez/2025):**
> 🟢 **CheckTLS Score:** [114/114 (100%)](https://www.checktls.com/)
> 🔒 **Criptografia:** TLS 1.3 & 1.2 (Strict Mode)
> 🛡️ **Anti-Spam:** Fail2Ban Customizado + Filtro de Borda

Este repositório documenta a infraestrutura **real em produção** do domínio **portalauditoria.com.br**. O projeto demonstra a administração avançada de um ambiente Windows Server 2022, integrando serviços legados (hMailServer) com stacks modernas (Spring Boot, SSL Automatizado), focando em segurança e automação.

### 🌐 Borda de Rede (Network Edge)

A segurança do servidor Windows começa no roteador de borda (**Mikrotik RB750**). 
A configuração implementa **NAT Hairpin**, **Port Forwarding** restrito e **Firewall Stateful**.

**Destaques da Configuração Mikrotik:**

* **Hairpin NAT:** Permite que clientes internos acessem os serviços (Webmail/ERP) usando o DNS público sem falhas de roteamento.
* **Port Forwarding:**
    * `TCP 25, 587, 465` -> hMailServer (SMTP)
    * `TCP 80, 443` -> IIS Reverse Proxy
    * `TCP 3389` -> Bloqueado (Acesso restrito apenas via VPN ou IP Whitelist)
* **Monitoramento:** Scripts de *Netwatch* e *Log* para identificar ataques de força bruta na porta SMTP.

➡️ **[Ver Configuração do Mikrotik (Sanitized)](./docs/Network-Edge.md)**

---

## 🎯 Objetivo

* **Portfólio de Engenharia:** Demonstração prática de automação (Scripting), segurança defensiva e administração de sistemas.
* **Base de Conhecimento:** Documentação de referência para *Hardening* de servidores Windows expostos à internet.
* **DevOps on Windows:** Uso de PowerShell e VBScript para orquestrar serviços, certificados e logs.

---

## 🛡️ Destaque: hMailServer Hardening Kit

Um dos maiores desafios deste projeto foi modernizar o stack de e-mail para atender aos requisitos de segurança de 2025 (Gmail/Outlook), mantendo o software *Self-Hosted*.

### 1. Criptografia Blindada (TLS 1.3)
Atuamos no registro do Windows (SChannel) e nas configurações do OpenSSL para garantir nota máxima em segurança:
* **Protocolos:** TLS 1.0 e 1.1 **Desativados** via Registro. Apenas TLS 1.2 e 1.3 permitidos.
* **Cipher Suites:** Implementação de algoritmos restritivos (Elliptic Curves e AES-GCM), banindo RC4, MD5 e 3DES.
* **Resultado:** Score **100% no CheckTLS**, garantindo entrega de e-mails sem rejeição por segurança.

### 2. Defesa Ativa ("Fail2Ban" para Windows)
Desenvolvi uma solução própria de mitigação de ataques de força bruta e spam:
* **Camada 1 (VBScript):** O script `EventHandlers.vbs` intercepta conexões SMTP em tempo real, bloqueando TLDs e padrões de domínios maliciosos (ex: `*.promovoo.xyz`) antes do processamento.
* **Camada 2 (PowerShell):** O script `AUTO-BLOQUEIO-Fail2Ban.ps1` analisa logs de auditoria, identifica IPs com falhas recorrentes de autenticação (Erro 535) e os bane automaticamente.

---

## 🏗️ Arquitetura do Ambiente

O servidor atua como um *Host* convergente para múltiplas aplicações, otimizado para performance e segurança:

* **Sistema Operacional:** Windows Server 2022.
* **Web Proxy (IIS + ARR):**
    * Atua como Reverse Proxy para aplicações Java (Tomcat 11/Spring Boot).
    * Gerencia o SSL Offloading e cabeçalhos de segurança (`HSTS`, `X-Forwarded-Proto`).
* **E-mail Corporativo:**
    * **hMailServer:** SMTP/IMAP/POP3 com armazenamento em banco de dados.
    * **Roundcube:** Webmail rodando sobre IIS via PHP 8.x (FastCGI).
    * **Autodiscover:** Configuração XML automática para Outlook e Thunderbird.
* **Rede & Borda:**
    * Integração com **Mikrotik** para NAT/Firewall de borda.
    * DNS gerenciado (Cloudflare/Registro.br).

---

## 🤖 Automação SSL (Full Pipeline)

Para resolver a falta de integração nativa entre o Let's Encrypt e o hMailServer, foi criada uma esteira de renovação automática em PowerShell:

1.  **Trigger:** O cliente ACME renova o certificado do domínio.
2.  **Extração Segura (`01-extract-keys.ps1`):** Extrai a chave privada e o certificado público do container PFX.
3.  **Deploy (`02-update-hmail.ps1`):**
    * Utiliza a API COM do hMailServer para injetar o novo certificado.
    * Utiliza **DPAPI** para leitura segura de credenciais (sem senhas expostas no código).
    * Reinicia os serviços afetados sem downtime perceptível.
4.  **Auditoria (`Comparar-Certificados.ps1`):** Valida se o *Thumbprint* do IIS corresponde ao do serviço de e-mail.

---

## 📂 Estrutura do Repositório

| Diretório/Arquivo | Descrição |
| :--- | :--- |
| `docs/` | Documentação técnica detalhada e procedimentos. |
| `scripts/hmail/` | Scripts de automação (Logs, Fail2Ban, Manutenção). |
| `scripts/ssl/` | Pipeline de renovação e extração de certificados. |
| `EventHandlers.vbs` | Script de hook para filtragem de conexões SMTP. |
| `autodiscover.xml` | Configuração automática para clientes Microsoft Outlook. |
| `config-v1.1.xml` | Configuração automática para clientes Mozilla Thunderbird. |

> **Nota de Segurança:** Todos os arquivos de configuração neste repositório foram anonimizados. Credenciais, chaves privadas e IPs de gerenciamento foram removidos ou substituídos por variáveis de ambiente/arquivos seguros.

---

## 👤 Autor

**Samuel S.**
*SysAdmin Sênior & Especialista em Automação*
Focado em extrair máxima segurança e performance de infraestruturas Windows e integração de sistemas híbridos.
