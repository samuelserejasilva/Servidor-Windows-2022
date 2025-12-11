## Servidor Windows Server 2022 — Estrutura de Produção

## 1. Visão geral do servidor

- **Sistema operacional:** Windows Server 2022
- **Hostname interno:** `serv`
- **Domínio AD interno:** `contabilidade.local`
- **Papel principal:** servidor unificado para:
  - Controlador de Domínio (AD DS) e DNS interno
  - IIS (sites HTTP/HTTPS + reverse proxy)
  - **Backend Java (Spring Boot com Tomcat embutido)**
  - hMailServer (servidor de e-mail)
  - Roundcube (webmail)
  - PHP (aplicações legadas / painéis administrativos)

> Observação: embora várias funções coexistam no mesmo host, a arquitetura foi pensada para permitir futura separação em múltiplos servidores ou VMs, caso necessário.

---

## 2. Camada de rede e Mikrotik

- **Roteador de borda:** Mikrotik
- **Funções principais:**
  - Roteamento e NAT para a rede interna
  - **Hairpin NAT** para permitir acesso, a partir da rede interna, usando o mesmo domínio público do ambiente externo
  - Firewall com regras de proteção (anti–brute force, listas de origem, etc.)

- **Endereçamento público:**
  - Bloco público com IP principal terminando em **`.278`**
  - IP **`.259`** reservado para uso futuro (balanceamento, serviços dedicados, etc.)

- **DNS público:**
  - Registros **A** para:
    - `portalauditoria.com.br` → IP público `.278`
    - `www.portalauditoria.com.br` → IP público `.278`
    - `mail.portalauditoria.com.br` → IP público `.278`
  - Registro **MX** apontando para `mail.portalauditoria.com.br`

> Toda entrada pública atinge primeiro o Mikrotik, que faz NAT/forward para o servidor `serv` (Windows Server 2022).

---

## 3. Active Directory e DNS interno

- **Domínio interno:** `contabilidade.local`
- **Controlador de Domínio:** servidor `serv`
- **Serviços configurados:**
  - Active Directory Domain Services (AD DS)
  - DNS interno integrado ao AD

- **Resoluções internas típicas:**
  - `serv.contabilidade.local`
  - Outras entradas internas conforme necessário (ex: aliases para serviços internos, se forem criados)

> O DNS interno resolve nomes do domínio `contabilidade.local` e, opcionalmente, pode ter zonas/forwarders configurados para resolução externa.

---

## 4. IIS — Servidor Web, SPA e Reverse Proxy

- **IIS instalado com os seguintes componentes principais:**
  - Web Server (HTTP/HTTPS)
  - **Application Request Routing (ARR)**
  - **URL Rewrite**
  - Suporte a **FastCGI** para PHP

- **Papéis do IIS:**

  1. **Hospedar sites públicos/privados** em HTTP/HTTPS:
     - `portalauditoria.com.br`
     - `www.portalauditoria.com.br`
     - `webmail.portalauditoria.com.br` (Roundcube)
     - Painéis PHP ou ferramentas administrativas, se necessários

  2. **Servir o Frontend SPA (Vite / TypeScript)**:
     - Build estático (HTML, JS, CSS) gerado pelo frontend
     - Publicado em um site dedicado no IIS (ex.: `portal-frontend`)
     - Executado no navegador do usuário, consumindo APIs do backend

  3. **Reverse proxy para a API backend (Spring Boot)**:
     - Requisições para rotas de API (ex.: `/api/...`) são encaminhadas para `http://localhost:8080`
     - Configuração através de regras no **URL Rewrite** + ARR
     - Mantém:
       - Centralização de certificados no IIS
       - URL pública amigável
       - Possibilidade de camadas adicionais (WAF, logging, throttling, etc.) no IIS

- **PHP (via FastCGI):**
  - PHP 8.x configurado via FastCGI no IIS
  - Utilizado por:
    - Roundcube (webmail)
    - Qualquer aplicação PHP adicional (sistema legado, painéis internos, etc.)

---

## 5. Backend Java — Spring Boot com Tomcat embutido

- **Tecnologia:** Spring Boot (aplicação empacotada em arquivo `JAR` executável)
- **Servidor HTTP:** Tomcat **embutido** no próprio `JAR` (não é um Tomcat standalone)
- **Porta interna padrão:** `8080` (acessível apenas internamente; exposição externa é via IIS/ARR)
- **Função principal:**
  - Disponibilizar a API do **Portal Auditoria 2.0 (portalweb)**
  - Implementar regras de negócio, autenticação, multi-tenant, etc.

- **Características importantes:**
  - Backend e frontend são **módulos independentes**:
    - Backend expõe apenas **APIs REST** (JSON) na porta `8080`
    - Frontend SPA (no IIS) consome essas APIs via HTTP/HTTPS
  - Facilita:
    - Deploy separado (JAR do backend x build do frontend)
    - Escalonamento independente em arquiteturas futuras
    - Substituição/atualização de camadas sem acoplamento rígido

- **Integração com IIS:**
  - IIS atua como reverse proxy, encaminhando chamadas de API (ex.: `/api/**`) para `http://localhost:8080`
  - Permite que todas as chamadas externas passem por HTTPS no IIS
  - Mantém o backend isolado atrás do proxy, acessível apenas internamente

---

## 6. Servidor de e-mail: hMailServer + Roundcube

### 6.1. hMailServer

- **Serviço de e-mail principal do ambiente**
- **Portas típicas configuradas:**
  - **25/TCP** — SMTP (recebimento de e-mails externos)
  - **587/TCP** — Submission SMTP autenticado (envio por clientes)
  - **993/TCP** — IMAP sobre SSL

- **Integrações e configurações importantes:**
  - Domínio de e-mail: `portalauditoria.com.br` (ou equivalentes configurados)
  - Relacionamento com o DNS público (registros MX e SPF)
  - Regras de **IP Ranges** ajustadas para:
    - Permitir **recebimento externo → local** sem exigir autenticação quando apropriado
    - Controlar **relay** (evitar uso do servidor como open relay)
  - Possível uso de:
    - Greylisting
    - Auto-ban por falhas de autenticação
    - Logs SMTP/IMAP para diagnósticos

### 6.2. Roundcube (Webmail)

- **Aplicação:** Roundcube Webmail
- **Hospedagem:** IIS com PHP (via FastCGI)
- **URL típica:** `https://webmail.portalauditoria.com.br/`
- **Conexão com hMailServer:**
  - IMAP (porta 993, SSL/TLS)
  - SMTP (porta 587, com autenticação)

> O Roundcube oferece uma interface amigável de webmail para usuários internos/externos, utilizando as credenciais e caixas postais configuradas no hMailServer.

---

## 7. Certificados TLS (HTTPS) e Win-ACME

- **Emissor dos certificados:** Let’s Encrypt, automatizado via **Win-ACME**
- **Tipos de certificados:**
  - Certificados individuais ou SAN cobrindo:
    - `portalauditoria.com.br`
    - `www.portalauditoria.com.br`
    - `mail.portalauditoria.com.br`
    - Outros subdomínios, conforme necessário

- **Integração com IIS:**
  - Certificados instalados no **Windows Certificate Store**
  - Bindings HTTPS configurados no IIS (com SNI, quando aplicável)
  - Renovação automática dos certificados via script/agenda do Win-ACME

> A centralização de TLS no IIS simplifica a renovação e o gerenciamento de certificados, mantendo o backend Java (Spring Boot com Tomcat embutido) atrás do proxy reverso sem preocupação direta com HTTPS.

---

## 8. Checklist rápido de validação

Esta seção serve como roteiro para confirmar se o servidor está configurado conforme o desenho estrutural.

### 8.1. Sistema e domínio

- [x] Servidor está com **Windows Server 2022** instalado
- [x] Hostname configurado como `serv`
- [x] Domínio **`contabilidade.local`** criado e funcional
- [x] Servidor `serv` atuando como **Controlador de Domínio (AD DS)**
- [x] DNS interno resolvendo corretamente `serv.contabilidade.local`

### 8.2. Rede e Mikrotik

- [x] Mikrotik com NAT configurado para o IP interno do servidor
- [x] Hairpin NAT habilitado para acesso interno via domínios públicos
- [x] IP público `.254` apontando para o Mikrotik e deste para o servidor
- [x] Registros A/MX/SPF ajustados para `portalauditoria.com.br` e `mail.portalauditoria.com.br`

### 8.3. IIS, SPA e aplicações web

- [x] IIS instalado com **ARR** e **URL Rewrite**
- [x] Sites configurados:
  - [x] `portalauditoria.com.br`
  - [x] `www.portalauditoria.com.br`
  - [x] `webmail.portalauditoria.com.br`
- [x] PHP 8.x configurado via FastCGI
- [x] Roundcube acessível em `https://webmail.portalauditoria.com.br`
- [x] Frontend SPA publicado e respondendo normalmente
- [x] Regras de reverse proxy para a API (`/api/**`) funcionando

### 8.4. Backend Java (Spring Boot / API)

- [x] Aplicação backend empacotada em `JAR` está instalada e configurada
- [x] Serviço do backend em execução ouvindo na porta `8080`
- [x] Endpoints de API respondendo corretamente em `http://localhost:8080`
- [x] Reverse proxy do IIS encaminha corretamente as chamadas de `/api/**` para o backend

### 8.5. hMailServer e e-mail

- [x] hMailServer instalado e rodando
- [x] Porta 25 acessível externamente (teste de recebimento)
- [x] Porta 587 funcionando para envio autenticado
- [x] Porta 993 (IMAP SSL) funcionando para leitura de e-mails
- [x] Domínios e contas configuradas no hMailServer
- [x] Roundcube consegue autenticar e listar mensagens normalmente

### 8.6. Certificados TLS

- [x] Win-ACME configurado para emitir certificados válidos de Let’s Encrypt
- [x] Certificados instalados no Windows Certificate Store
- [x] Bindings HTTPS configurados corretamente no IIS (sem warnings de certificado inválido)
- [x] Rotina de renovação automática testada (ou pelo menos validada em um ciclo de emissão)

---

## 9. Notas finais

Este documento resume a **arquitetura estrutural** do servidor Windows Server 2022 que concentra:

- controle de domínio,
- serviços web (IIS + PHP + SPA),
- backend Java (Spring Boot com Tomcat embutido, exposto como API),
- e-mail (hMailServer + Roundcube),
- e terminação TLS centralizada no IIS.

Ele pode servir como:

- Base para documentação técnica do ambiente
- Guia de replicação da infraestrutura em outro servidor/VM
- Checklist de auditoria de configuração em produções futuras