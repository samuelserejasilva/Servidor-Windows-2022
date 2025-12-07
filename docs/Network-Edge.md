# 🌐 Borda de Rede (Network Edge) - Mikrotik

> **Dispositivo:** Mikrotik RouterBOARD (RB750r2)
> **Função:** Firewall de Borda, NAT Hairpin, Roteamento e QoS.

Este documento detalha as configurações de rede aplicadas ao roteador de borda para garantir a publicação segura dos serviços do **Servidor de E-mail** e **IIS**, isolando a rede interna da internet pública.

---

## 🏗️ Topologia Lógica

A configuração utiliza uma topologia clássica de *Port Forwarding* (DNAT) com suporte a múltiplos IPs públicos na mesma interface WAN.

| Interface | Nome Lógico | Função | Endereçamento |
| :--- | :--- | :--- | :--- |
| `ether1` | WAN_FIBRA | Link com Operadora | `10.10.0.x/30` (Trânsito) |
| `ether3` | LAN_SERVERS | Rede DMZ/Servidores | `10.165.0.1/28` + IPs Públicos (VIPs) |
| `bridge1` | LAN_MGMT | Rede de Gerência | `192.168.x.x` |

### Objetos de Rede (Alias)
* **WAN_IP_MAIN:** IP Público Principal (E-mail/Web)
* **SERVER_IP:** IP Interno do Servidor Windows (`10.165.0.2`)

---

## 🛡️ Firewall & NAT

### 1. Port Forwarding (DNAT)
Apenas as portas estritamente necessárias são expostas.

```bash
# Regra 0: SMTP (Entrada de E-mails)
# Redireciona tráfego da porta 25 externa para o hMailServer interno
/ip firewall nat
add action=dst-nat chain=dstnat comment="SMTP25 -> hMail" \
    dst-address=WAN_IP_MAIN dst-port=25 protocol=tcp \
    to-addresses=SERVER_IP to-ports=25 log=yes log-prefix="SMTP25 "

# Serviços de E-mail Seguros (SSL/TLS)
add action=dst-nat chain=dstnat comment="SMTP Submission (TLS)" dst-address=WAN_IP_MAIN dst-port=587 protocol=tcp to-addresses=SERVER_IP
add action=dst-nat chain=dstnat comment="IMAP SSL" dst-address=WAN_IP_MAIN dst-port=993 protocol=tcp to-addresses=SERVER_IP
add action=dst-nat chain=dstnat comment="POP3 SSL" dst-address=WAN_IP_MAIN dst-port=995 protocol=tcp to-addresses=SERVER_IP

# Serviços Web (IIS Reverse Proxy)
add action=dst-nat chain=dstnat comment="HTTP" dst-address=WAN_IP_MAIN dst-port=80 protocol=tcp to-addresses=SERVER_IP
add action=dst-nat chain=dstnat comment="HTTPS" dst-address=WAN_IP_MAIN dst-port=443 protocol=tcp to-addresses=SERVER_IP
2. Hairpin NAT (Loopback)
Solução para Acesso Interno: Regra de Masquerade para permitir que a rede interna acesse o IP Público do servidor sem falhas de roteamento.

Bash

add action=masquerade chain=srcnat \
    src-address=10.165.0.0/28 dst-address=SERVER_IP \
    out-interface=ether3 protocol=tcp
3. Filtros de Segurança (Filter Rules)
Bash

# Bloqueio de Ataques de Amplificação DNS (Porta 53 UDP externa)
/ip firewall filter
add action=drop chain=input dst-port=53 log=yes log-prefix="DNS_ATTACK" protocol=udp

# Log de auditoria para conexões SMTP aceitas
add action=log chain=forward dst-address=SERVER_IP dst-port=25 protocol=tcp
⚡ Cheat Sheet: Comandos Operacionais (CLI)
Lista de comandos essenciais utilizados via terminal para diagnóstico em tempo real, validação de rotas e monitoramento de ataques.

🔍 1. Verificação de Ambiente
Bash

# Verificar Data/Hora (Essencial para correlação de logs com o Windows)
/system clock print

# Listar endereços IPs ativos e interfaces associadas
/ip address print

# Confirmar Rota Default (Gateway de Saída)
/ip route print where dst-address=0.0.0.0/0
🕵️ 2. Monitoramento de Tráfego (Troubleshooting)
Bash

# Monitorar logs de SMTP em tempo real (Igual 'tail -f')
# Útil para ver se o pacote SYN está chegando na borda
/log print follow where message~"SMTP25"

# Ver conexões ativas na porta 25 (Quem está conectado agora?)
/ip firewall connection print where dst-address~":25"

# Sniffer leve para validar tráfego na interface do servidor
/tool torch interface=ether3 port=25 src-address=0.0.0.0/0
📊 3. Estatísticas e Limpeza
Bash

# Ver contadores de pacotes nas regras de NAT (Para saber se a regra está sendo usada)
/ip firewall nat print stats

# Resetar contadores de uma regra específica (Para iniciar um teste limpo)
/ip firewall nat reset-counters [find comment="SMTP25 -> hMail"]
⚙️ Configurações Gerais
NTP Client: Sincronizado com a.ntp.br para garantir logs precisos.

Backup: Exportação diária de configuração (/export).

Serviços: Telnet e WWW (porta 80 do roteador) desabilitados para segurança.

Sanitization Note: IPs públicos reais, credenciais PPP e communities SNMP foram removidos deste documento público.
