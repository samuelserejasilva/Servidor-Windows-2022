# hMailServer — Diagnóstico Rápido (SMTP/IMAP)

> Guia prático para testar **envio e recebimento de e-mail** em um servidor
> hMailServer rodando em Windows, sem expor IPs reais ou detalhes sensíveis.
>
> Nos exemplos abaixo, use sempre:
> - `mail.seudominio.com.br` → substitua pelo FQDN real do seu servidor de e-mail;
> - `203.0.113.10` → exemplo de IP público (faixa reservada para documentação);
> - `10.0.0.10` → exemplo de IP interno (LAN).

---

## 1. Objetivo

Este guia ajuda a responder rapidamente:

1. **O serviço está escutando nas portas corretas?**
2. **O firewall está liberando as conexões?**
3. **O hMailServer está aceitando ou rejeitando as mensagens?**
4. **O problema é de rede, autenticação, TLS ou anti-spam?**

---

## 2. Testes no próprio servidor (localhost)

### 2.1 Verificar se as portas estão “LISTENING”

No Windows (Prompt ou PowerShell como admin):

```powershell
netstat -ano | findstr /R "25 587 993"

# 2.2 Testar conexões locais com Test-NetConnection
Test-NetConnection -ComputerName 127.0.0.1 -Port 25
Test-NetConnection -ComputerName 127.0.0.1 -Port 587
Test-NetConnection -ComputerName 127.0.0.1 -Port 993

# 3. Testes a partir de outra máquina da LAN
Test-NetConnection -ComputerName mail.seudominio.com.br -Port 25
Test-NetConnection -ComputerName mail.seudominio.com.br -Port 587
Test-NetConnection -ComputerName mail.seudominio.com.br -Port 993


# Verificar regras de firewall:
Get-NetFirewallRule |
  Where-Object { $_.DisplayName -like "*SMTP*" -or $_.DisplayName -like "*IMAP*" } |
  Select DisplayName, Enabled, Direction, Action

# 4. Testes a partir da Internet (máquina externa) Em uma máquina fora da rede (pode ser outro servidor, VPS, etc.):
nc -vz mail.seudominio.com.br 25
nc -vz mail.seudominio.com.br 587
nc -vz mail.seudominio.com.br 993
# ou
telnet mail.seudominio.com.br 25
Test-NetConnection -ComputerName mail.seudominio.com.br -Port 25

# 5. Testando a conversa SMTP (linha de comando)
telnet mail.seudominio.com.br 25
220 mail.seudominio.com.br ESMTP

HELO teste
MAIL FROM:<teste@seudominio.com.br>
RCPT TO:<conta-de-teste@seudominio.com.br>
DATA
Subject: teste smtp manual

corpo da mensagem de teste
.
QUIT

# 5.2 Teste SMTP com TLS (openssl)
openssl s_client -connect mail.seudominio.com.br:587 -starttls smtp

```
