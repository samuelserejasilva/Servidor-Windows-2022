# Servidor Windows Server 2022 — Infraestrutura de Produção (Hardened)

> **Infraestrutura "Cloud-Native on-premise": IIS Reverse Proxy, SSL Automatizado e Hardening de Segurança.**

[![Windows Server](https://img.shields.io/badge/OS-Windows%20Server%202022-blue?logo=windows)](https://www.microsoft.com/en-us/windows-server)
[![SSL](https://img.shields.io/badge/SSL-A%2B%20Score-success)](https://www.ssllabs.com/)
[![CheckTLS](https://img.shields.io/badge/CheckTLS-100%25-success)](https://www.checktls.com/)

---

## 🏗️ Arquitetura de Borda e Aplicação

Este repositório documenta a infraestrutura real do **Portal Auditoria**. O ambiente aplica conceitos de nuvem (Gateway, Containerização Lógica, IaC) em um servidor Windows bare-metal.

### Fluxo de Requisição (Request Flow)

```mermaid
graph LR
    User((Usuário)) -->|HTTPS/443| Mikrotik[Firewall de Borda]
    Mikrotik -->|Port Forward| IIS[IIS + ARR (Reverse Proxy)]
    
    subgraph Windows Server 2022
        IIS -->|Static Files| Frontend[SPA Files (Vite)]
        IIS -->|/api/* (Proxy)| Tomcat[Spring Boot @ :8080]
        
        CertBot[Win-ACME] -->|Renovação Auto| IIS
        Fail2Ban[Scripts PowerShell] -->|Block IP| Firewall[Windows Firewall]
    end
> **Infraestrutura "Cloud-Native on-premise": IIS Reverse Proxy, SSL Automatizado e Hardening de Segurança.**

[![Windows Server](https://img.shields.io/badge/OS-Windows%20Server%202022-blue?logo=windows)](https://www.microsoft.com/en-us/windows-server)
[![SSL](https://img.shields.io/badge/SSL-A%2B%20Score-success)](https://www.ssllabs.com/)
[![CheckTLS](https://img.shields.io/badge/CheckTLS-100%25-success)](https://www.checktls.com/)

---

## 🏗️ Arquitetura de Borda e Aplicação

Este repositório documenta a infraestrutura real do **Portal Auditoria**. O ambiente aplica conceitos de nuvem (Gateway, Containerização Lógica, IaC) em um servidor Windows bare-metal.

### Fluxo de Requisição (Request Flow)

```mermaid
graph LR
    User((Usuário)) -->|HTTPS/443| Mikrotik[Firewall de Borda]
    Mikrotik -->|Port Forward| IIS[IIS + ARR (Reverse Proxy)]
    
    subgraph Windows Server 2022
        IIS -->|Static Files| Frontend[SPA Files (Vite)]
        IIS -->|/api/* (Proxy)| Tomcat[Spring Boot @ :8080]
        
        CertBot[Win-ACME] -->|Renovação Auto| IIS
        Fail2Ban[Scripts PowerShell] -->|Block IP| Firewall[Windows Firewall]
    end

> **Status de Segurança (Dez/2025):**
> 🟢 **CheckTLS Score:** [114/114 (100%)](https://www.checktls.com/)
> 🔒 **Criptografia:** TLS 1.3 & 1.2 (Strict Mode)
> 🛡️ **Anti-Spam:** Fail2Ban Customizado + Filtro de Borda

Este repositório documenta a infraestrutura **real em produção** do domínio **portalauditoria.com.br**. O projeto demonstra a administração avançada de um ambiente Windows Server 2022, atuando como controlador de domínio, servidor web e de e-mail, integrando serviços legados com stacks modernas (Spring Boot, SSL Automatizado).

---

## 🏗️ Arquitetura do Ambiente

## ☁️ Alinhamento com Conceitos Cloud-Native

Embora hospedada *On-Premise* (Local), esta infraestrutura aplica padrões de arquitetura utilizados em grandes provedores de nuvem (Azure/AWS), demonstrando domínio dos fundamentos que sustentam a nuvem:

| Componente Local (Windows) | Conceito de Nuvem Correspondente | O que isso demonstra? |
| :--- | :--- | :--- |
| **IIS + ARR (Reverse Proxy)** | **API Gateway / Ingress Controller** | Segurança de borda, SSL Offloading e roteamento de tráfego de aplicação. |
| **Spring Boot (Porta 8080)** | **Microserviço / Container** | Desacoplamento entre servidor web e aplicação, pronto para Dockerização. |
| **PowerShell + Win-ACME** | **DevOps / IaC / Automation** | Automação de infraestrutura e gestão de segredos (Certificados) sem intervenção humana. |
| **Active Directory** | **IAM (Identity Access Management)** | Gestão centralizada de identidade e controle de acesso (base para Azure AD). |

O servidor atua como um *Host* convergente (All-in-One) otimizado para performance e segurança, preparado para escalabilidade futura.

### 🔄 Fluxo de Aplicação (Reverse Proxy Architecture)
A infraestrutura utiliza o IIS como gateway de entrada, garantindo que o backend Java permaneça isolado da rede pública:

1.  **Frontend (SPA):** Aplicação Vite/TypeScript servida como arquivos estáticos pelo IIS.
2.  **Backend (API):** Spring Boot (Tomcat Embutido) rodando na porta interna `8080`.
3.  **Conexão Segura:** O IIS (via **ARR** + **URL Rewrite**) intercepta chamadas `/api/*` e faz o proxy reverso para `http://localhost:8080`.
    * *Benefício:* Centralização de Certificados SSL e proteção do servidor de aplicação.

### 🔑 Identity & Infraestrutura
* **Active Directory (AD DS):** Controlador de domínio para autenticação centralizada na rede interna (`contabilidade.local`).
* **DNS Interno:** Resolução de nomes integrada ao AD com zonas split-horizon.
* **Web Server:** IIS com suporte a **FastCGI** para executar PHP 8.x (utilizado pelo Webmail/Sistemas Legados).

### 📧 E-mail Corporativo
* **hMailServer:** SMTP/IMAP/POP3 com armazenamento em banco de dados relacional.
* **Webmail:** Roundcube rodando sobre IIS (PHP 8.x).
* **Autodiscover:** Configuração XML automática para Outlook e Thunderbird.

---

## 🛡️ Segurança e Hardening

### 1. Criptografia Blindada (TLS 1.3)
Atuação direta no registro do Windows (SChannel) para garantir nota máxima em segurança:
* **Protocolos:** TLS 1.0 e 1.1 **Desativados**. Apenas TLS 1.2 e 1.3 permitidos.
* **Cipher Suites:** Algoritmos restritivos (Elliptic Curves e AES-GCM), banindo RC4, MD5 e 3DES.

### 2. Defesa Ativa ("Fail2Ban" para Windows)
Solução proprietária de mitigação de ataques de força bruta:
* **VBScript (`EventHandlers.vbs`):** Intercepta conexões SMTP em tempo real, bloqueando TLDs maliciosos.
* **PowerShell (`AUTO-BLOQUEIO-Fail2Ban.ps1`):** Analisa logs de auditoria e bane IPs com falhas recorrentes de autenticação.

### 3. Borda de Rede (Mikrotik)
O roteador de borda implementa **Hairpin NAT**, permitindo que a rede interna acesse serviços pelo DNS público sem falhas de roteamento, além de Firewall Stateful na porta 25.

---

## 🤖 Automação SSL (Full Pipeline)

Para resolver a falta de integração nativa entre o Let's Encrypt e o hMailServer, foi criada uma esteira de renovação automática em PowerShell:

1.  **Trigger:** O cliente ACME (Win-ACME) renova o certificado do domínio.
2.  **Extração Segura:** Script extrai a chave privada e o certificado público do container PFX.
3.  **Deploy:**
    * Utiliza a API COM do hMailServer para injetar o novo certificado.
    * Reinicia os serviços afetados sem downtime perceptível.

---

## ✅ Checklist de Produção

Roteiro de validação aplicado para garantir a integridade do ambiente:

- [x] **Sistema:** Windows Server 2022 configurado como DC (`serv.contabilidade.local`).
- [x] **Rede:** Hairpin NAT ativo no Mikrotik (Acesso interno via DNS público).
- [x] **IIS/Proxy:** Regras de Rewrite redirecionando `/api` para `localhost:8080` com sucesso.
- [x] **E-mail:** Portas 25 (SMTP), 587 (Submission) e 993 (IMAP) validadas externamente.
- [x] **SSL:** Renovação automática via Win-ACME testada com sucesso.
- [x] **Backend:** Spring Boot iniciado e API respondendo via Proxy Reverso.

---

## 📂 Estrutura do Repositório

| Diretório/Arquivo | Descrição |
| :--- | :--- |
| `docs/` | Documentação técnica detalhada e procedimentos. |
| `scripts/hmail/` | Scripts de automação (Logs, Fail2Ban, Manutenção). |
| `raiz` | Pipeline de renovação e extração de certificados. |
| `EventHandlers.vbs` | Script de hook para filtragem de conexões SMTP. |
| `autodiscover.xml` | Configuração automática para clientes Microsoft Outlook. |

> **Nota de Segurança:** Todos os arquivos de configuração neste repositório foram anonimizados. Credenciais, chaves privadas e IPs reais foram removidos.

---

## 👤 Autor

**Samuel S.**
*SysAdmin Sênior & Especialista em Automação*
Focado em extrair máxima segurança e performance de infraestruturas Windows e integração de sistemas híbridos.formance de infraestruturas Windows e integração de sistemas híbridos.
