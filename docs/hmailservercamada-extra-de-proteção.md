## 10. Segurança avançada no hMailServer (EventHandlers / Aurea Black List)

> Esta seção descreve, em alto nível, o uso de um script de segurança
> em `EventHandlers.vbs` (Aurea/Black List) para reforçar o filtro de
> remetentes no **OnSMTPData** do hMailServer.
>
> ⚠️ Não expõe IPs reais nem detalhes de rede — apenas o comportamento lógico.

### 10.1 Objetivo do script

O script **Aurea/Black List** roda no evento:

- `Sub OnSMTPData(oClient, oMessage)`

Ele serve para:

- Ler **listas de whitelist/blacklist** gravadas em arquivos texto.
- Armazenar essas listas em cache (`Global.Value`) para não acessar disco a cada e-mail.
- Decidir se uma mensagem:
  - **é permitida** (ALLOW)  
  - ou **é rejeitada** (BLOCK com erro 550).

Nenhum trecho do script:

- altera autenticação SMTP,
- abre relay,
- executa comandos de sistema,
- ou mexe em configurações internas do hMailServer.

Ele apenas **lê arquivos de listas** e define `Result.Value`/`Result.Message` no fluxo SMTP.

---

### 10.2 Estrutura de arquivos (genérica)

Pasta sugerida (você pode ajustar):

```text
C:\hmail-lists\
├─ lists\
│  ├─ whitelist_emails.txt
│  ├─ whitelist_domains.txt
│  ├─ whitelist_ips.txt
│  ├─ blacklist_emails.txt
│  ├─ blacklist_domains.txt
│  └─ blacklist_ips.txt
└─ logs\
   └─ AureaBlack_Lists.log

### No script, isso aparece como:
  LIST_BASE_PATH → pasta base das listas (ex.: C:\hmail-lists\lists)
  LOG_FILE → arquivo de log (ex.: C:\hmail-lists\logs\AureaBlack_Lists.log)
> Formato das listas:
    Uma entrada por linha.
    Linhas começando com # ou ; são comentários.
    Linhas em branco são ignoradas.
    Suporta:
      E-mail completo: usuario@dominio.com
      Domínio: dominio.com
      IP: 198.51.100.23
      Wildcards simples: *@dominio.com, spam*@exemplo.org

10.3 Lógica de decisão (resumida)
Dentro do OnSMTPData, o script aplica regras em camadas:
 > Autenticação tem prioridade máxima
    Se oClient.Username <> "" (remetente autenticado no SMTP):
     decisão = ALLOW_AUREA
     É aquele caso típico de cliente legítimo usando usuário/senha.

> Whitelist
     Se o remetente estiver em:
        whitelist_emails.txt (g_WLEmails)
        whitelist_domains.txt (g_WLDomains)
        whitelist_ips.txt (g_WLIPs)
     decisão = ALLOW_AUREA
     Serve para garantir entrega de fontes confiáveis, mesmo que caiam em outras verificações.

> Blacklist
   Se o remetente estiver em:
   blacklist_emails.txt (g_BLEmails)
   blacklist_domains.txt (g_BLDomains)
> blacklist_ips.txt (g_BLIPs)
   decisão = BLOCK_BLACK
   O script então faz:
> Result.Value = 2
> Result.Message = "550 BLOCK_BLACK: motivo..."
    Sem correspondência
    Se nenhuma regra bater:
> decisão permanece como ALLOW (Result.Value = 0)
   Ou seja, o script não cria bloqueios “mágicos” fora do que está nas listas.
   O script também grava logs de auditoria como:
> SMTP_REJECT: ...
> CACHE_RELOAD: ...
> SCRIPT_ERROR: ... (se der algum erro interno no VBS)

10.4 Cache em memória (desempenho)
Para não ficar abrindo arquivo a cada e-mail, o script usa:
  > Global.Value("g_WLEmails"), Global.Value("g_BLEmails"), etc.
  > Global.Value("AureaBlack_LastLoad") para guardar a hora do último carregamento.
Função chave:
> CheckAndLoadCache()
  > Carrega as listas para o cache se:
    > nunca carregou antes, ou
    > já passou mais que CACHE_RELOAD_MINUTES minutos, ou
    > o relógio do sistema foi ajustado para trás.
Isso reduz I/O em disco e melhora o desempenho em ambiente com bastante tráfego.

10.5 Como ativar o script no hMailServer
Abrir o Admin do hMailServer
  Ir em: Settings → Advanced → Scripts
Habilitar scripts
  Marcar: Enable scripting
Editar o EventHandlers.vbs
  Botão Edit... abre o arquivo EventHandlers.vbs da instalação.
  Substituir ou incluir o conteúdo do script Aurea/Black List dentro desse arquivo.
  Verificar se o evento Sub OnSMTPData(oClient, oMessage) está presente apenas uma vez.
  `Salvar e aplicar`
Salvar o EventHandlers.vbs.
  > Reiniciar o serviço hMailServer (ou o próprio servidor de e-mail) para garantir que o script foi recarregado.
Verificar o log
 > Olhar o arquivo de log configurado (ex.: AureaBlack_Lists.log) e os logs padrão do hMail:
    > confirmar mensagens como:
    > CACHE_RELOAD: Loading lists...
    > CACHE_RELOAD: Done.
    > SMTP_REJECT: ... BLOCK_BLACK ...
    > ALLOW_AUREA: ... etc.

### Integração com AUTO-BLOQUEIO-Fail2Ban (PowerShell + Agendador do Windows)

Além do `EventHandlers.vbs` (Aurea/Black List), existe uma segunda camada de proteção baseada em um
script PowerShell chamado **AUTO-BLOQUEIO-Fail2Ban.ps1**, que roda de **15 em 15 minutos**
via Agendador de Tarefas do Windows.

A ideia é parecida com o conceito do *Fail2Ban* em Linux:  
em vez de bloquear IP em tempo real via firewall, o script:

1. Lê o **log nativo do hMailServer** do dia.
2. Conta quantas falhas de autenticação cada IP teve (códigos 530/535).
3. Aplica regras simples:
   - Só considera IPs com **N falhas ou mais** (limite configurável, ex.: 5 falhas).
   - Ignora IPs que já estão em `whitelist_ips.txt`.
   - Ignora IPs que já estão em `blacklist_ips.txt`.
4. Adiciona os **novos IPs suspeitos** em `blacklist_ips.txt`.

Quem efetivamente bloqueia esses IPs é o **EventHandlers.vbs**, que lê o mesmo
`blacklist_ips.txt` em cache e devolve `Result.Value = 2` (550) quando um IP bloqueado tenta
mandar e-mail.

#### 10.x.1 Caminhos usados (genéricos)

Exemplo de layout (ajustável conforme o ambiente):

```text
C:\hmail-lists\
├─ lists\
│  ├─ blacklist_ips.txt
│  ├─ whitelist_ips.txt
│  ├─ blacklist_emails.txt
│  ├─ whitelist_emails.txt
│  └─ ...
└─ app-ant-spam\
   └─ bloqueio\
      └─ AUTO-BLOQUEIO-Fail2Ban.ps1

Manter whitelist_ips.txt com IPs de:
 > monitoramento;
 > VPN própria;
 > servidores confiáveis que não devem ser bloqueados.
Se algo sair errado:
 > basta editar/remover o blacklist_ips.txt (ou limpar algumas linhas)
 > e o script deixará de bloquear aqueles IPs nas próximas mensagens.
✅ Atua como alimentador de listas usado pelo EventHandlers.
> Isso torna o conjunto EventHandlers.vbs + AUTO-BLOQUEIO-Fail2Ban.ps1 uma camada extra de proteção comparável a um Fail2Ban simplificado, porém 100% controlado por arquivos de lista.


