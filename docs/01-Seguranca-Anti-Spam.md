# Estudo de Caso 1: Sistema de Defesa Anti-Spam (EventHandlers + Fail2Ban)

## O Problema
O hMailServer é um excelente servidor de e-mail, mas sua proteção anti-spam nativa é limitada. Mesmo com DNS Blacklists ativadas, o servidor sofria com dois problemas graves:
1.  **Spam de Domínios:** Milhares de e-mails de spam vindos de TLDs maliciosos (como `.xyz`, `.store`, `.cfd`, `.link`) que mudavam de IP e passavam pelos filtros.
2.  **Ataques de Força Bruta:** Tentativas constantes de adivinhar senhas (Brute-Force) nos protocolos SMTP e IMAP, gerando logs de erro (530/535) e consumindo recursos do servidor.

## A Solução
Desenvolvi uma solução de defesa em duas camadas que integra VBScript e PowerShell para criar um sistema de bloqueio dinâmico e centralizado.

### Camada 1: O Filtro Customizado (EventHandlers.vbs)
O hMailServer permite executar um script VBScript em eventos específicos. Utilizei o evento `OnSMTPData` (que é disparado *antes* de um e-mail ser aceito) para criar um porteiro inteligente.

**O que ele faz:**
1.  **Intercepta o E-mail:** Todo e-mail que chega passa por este script.
2.  **Prioridade para Confiáveis:** E-mails de usuários autenticados (`AUTH=True`) ou de IPs na `whitelist_ips.txt` são liberados imediatamente (bypass).
3.  **Verificação Centralizada:** O script lê um conjunto de listas de bloqueio (`blacklist_ips.txt`, `blacklist_domains.txt`) que são mantidas em um local central.
4.  **Bloqueio por Curinga (Wildcard):** A verificação de domínio suporta curingas (ex: `*.xyz`, `*.azurecomm.net`), permitindo bloquear TLDs inteiros ou subdomínios de spam, algo que o hMailServer não faz nativamente.
5.  **Decisão:** O script retorna a decisão (Bloquear ou Permitir) para o hMailServer.

➡️ **Link para o script:** [`/EventHandlers.vbs`](../EventHandlers.vbs)

### Camada 2: O "Fail2Ban" Automatizado (AUTO-BLOQUEIO-Fail2Ban.ps1)
O filtro VBScript é ótimo para bloquear spam *conhecido*. Para bloquear *novos* atacantes, criei um script PowerShell que age como um "Fail2Ban".

**O que ele faz:**
1.  **Monitora o Log Nativo:** O script lê o log `hmailserver_YYYY-MM-DD.log` em tempo real (ou via tarefa agendada).
2.  **Detecta Falhas:** Ele procura por padrões de falha de login (códigos de erro SMTP `530` e `535`).
3.  **Conta as Tentativas:** Agrupa as falhas por IP e conta quantas tentativas cada IP fez.
4.  **Bloqueia o Atacante:** Se um IP ultrapassa o limite (ex: 5 falhas), o script automaticamente:
    * Verifica se o IP não está na `whitelist_ips.txt` (para evitar auto-bloqueio).
    * Adiciona o IP malicioso diretamente ao arquivo `blacklist_ips.txt`.
5.  **Ciclo Fechado:** Em até 5 minutos (`CACHE_RELOAD_MINUTES` do VBScript), o `EventHandlers.vbs` recarrega a `blacklist_ips.txt` e passa a bloquear o novo atacante.

➡️ **Link para o script:** [`/AUTO-BLOQUEIO-Fail2Ban.ps1`](../AUTO-BLOQUEIO-Fail2Ban.ps1)

## O Resultado
Com esta arquitetura, o servidor agora possui um sistema de defesa "inteligente":
* **Defesa Proativa:** Bloqueia TLDs inteiros de spam.
* **Defesa Reativa:** Detecta e bane automaticamente IPs de força bruta.
* **Gerenciamento Centralizado:** Toda a segurança é controlada por arquivos de texto simples, sem necessidade de mexer no firewall.
