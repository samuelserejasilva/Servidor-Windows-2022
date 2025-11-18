# Segurança no hMailServer — Camadas, Scripts e Boas Práticas

> Este documento resume as principais **medidas de segurança** aplicadas ao
> servidor de e-mail baseado em **hMailServer + IIS + Roundcube**, com foco em:
>
> - evitar relay aberto;
> - proteger contra tentativas de força bruta;
> - melhorar reputação (SPF/DKIM/DMARC);
> - usar scripts auxiliares de forma segura (EventHandlers + Fail2Ban-like).

Todos os exemplos usam nomes genéricos como `mail.seudominio.com.br` e IPs
reservados para documentação (ex.: `203.0.113.10`, `10.0.0.10`), sem expor
endereços reais.

---

## 1. Visão geral de segurança

Camadas principais de proteção:

1. **Rede / borda**
   - Firewall e NAT no roteador (ex.: Mikrotik).
   - Exposição apenas das portas necessárias (25, 587, 993, 80, 443).

2. **Servidor Windows**
   - Firewall do Windows liberando apenas o essencial.
   - Serviços em execução mínima (sem roles desnecessárias).

3. **hMailServer**
   - IP Ranges bem configurados (sem open relay).
   - TLS para IMAP/SMTP.
   - Anti-spam interno (DNSBL, SPF, etc.).
   - Greylisting e Auto-ban (com cuidado).

4. **Nível de aplicação**
   - Webmail (Roundcube) com PHP endurecido.
   - Scripting no hMailServer (EventHandlers) usado apenas para lógica de filtro,
     sem executar comandos de sistema.
   - Script auxiliar em PowerShell, agendado via Task Scheduler, rodando em lote
     para alimentar listas de bloqueio.

5. **DNS / reputação**
   - Registros MX, SPF, DKIM, DMARC consistentes.
   - Endpoints de autoconfig (`autodiscover.xml`, `config-v1.1.xml`) bem configurados.

---

## 2. IP Ranges e proteção contra open relay

### 2.1 Conceito

Os **IP Ranges** do hMailServer definem:

- De onde o servidor aceita conexões.
- Quem pode enviar para quem (Local/External).
- Quando a autenticação é obrigatória.

O objetivo é:

- Permitir que a Internet envie e-mail **para o domínio** (External → Local),
  sem exigir autenticação.
- Exigir autenticação para qualquer envio **para fora** (Local → External),
  evitando relay aberto.

### 2.2 Configuração recomendada (genérica)

**IP Range: My Computer**

- IPs: `127.0.0.1` (localhost)
- Permite:
  - de Local/External → para Local/External
- Não exige autenticação (para webmail e processos internos).

**IP Range: LAN (opcional)**

- IPs: rede interna (ex.: `10.0.0.1-10.0.0.254`)
- Pode permitir envios sem autenticação apenas para hosts específicos,
  se estritamente necessário (impressoras, sistemas legados).

**IP Range: Internet**

- Engloba “todo o resto”.
- Recomendações:
  - Allow deliveries from:
    - `[x] External`
    - `[x] Local`
  - Allow deliveries to:
    - `[x] Local`
    - `[ ] External`  (evita relay aberto)
  - Require SMTP authentication:
    - `[ ] External to local`   (senão não recebe e-mail da Internet)
    - `[x] Local to external`
    - `[x] External to external`

Isso garante:

- Recebimento de e-mails externos → domínio local sem autenticação.
- Qualquer envio que sai do domínio para fora precisa de usuário/senha.

---

## 3. TLS, autenticação e portas

### 3.1 Portas expostas para clientes

Configuração típica para clientes:

- **IMAP (entrada)**
  - Servidor: `mail.seudominio.com.br`
  - Porta: `993`
  - Segurança: SSL/TLS
  - Autenticação: senha normal
  - Usuário: e-mail completo

- **SMTP (saída)**
  - Servidor: `mail.seudominio.com.br`
  - Porta: `587`
  - Segurança: STARTTLS
  - Autenticação: obrigatória
  - Usuário: e-mail completo

### 3.2 Certificados

No hMailServer:

- Certificado TLS configurado para IMAPS (993) e SMTP/STARTTLS (587).
- CN/SAN do certificado compatível com o host público (`mail.seudominio.com.br` ou similar).

Benefícios:

- Tráfego de credenciais e conteúdo protegido contra sniffing.
- Menor chance de o cliente marcar a conta como “não segura”.

---

## 4. Anti-spam interno (hMailServer)

O hMailServer possui filtros anti-spam básicos, como:

- Verificação de **SPF**.
- Integração com **DNSBLs** (listas de IPs spammers).
- Pontuação de spam com base em múltiplos critérios.

Boas práticas:

- Habilitar pelo menos:
  - SPF check.
  - 1–2 DNSBLs conhecidos (sem exagerar para não gerar falsos positivos).
- Definir uma **pontuação limite** para:
  - marcar como spam (mover para Junk),
  - ou rejeitar diretamente (550).

---

## 5. Greylisting e Auto-ban

### 5.1 Greylisting

- Primeira tentativa de entrega: recusada com código temporário.
- Servidor legítimo tenta novamente → mensagem é aceita.
- Prevê boa redução de spam.

Cuidados:

- Durante implantação/testes, pode ser melhor **desativar** provisoriamente.
- Alguns provedores podem demorar mais na primeira entrega para um endereço novo.

### 5.2 Auto-ban

- Conta quantas falhas de autenticação acontecem a partir do mesmo IP.
- Quando ultrapassa o limite configurado, bloqueia o IP.

Cuidados:

- Em ambiente com NAT (vários clientes atrás do mesmo IP), um usuário errando
  a senha repetidamente pode banir o IP de todos.
- É recomendável:
  - ajustar o limite para uma faixa razoável;
  - colocar IPs internos críticos em uma lista de exceção (quando possível);
  - monitorar logs de banimentos.

---

## 6. SPF, DKIM e DMARC

### 6.1 SPF

Registro TXT do tipo:

```txt
v=spf1 mx ip4:203.0.113.10 -all
