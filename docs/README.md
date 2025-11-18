### 🔁 Automação do hMailServer (EventHandlers, Fail2Ban e TLS)

Além da instalação padrão, o serviço de e-mail foi automatizado para reduzir intervenção manual e aumentar a segurança operacional.

#### 1. Anti-abuso com EventHandlers.vbs + “Fail2Ban” em PowerShell

- `EventHandlers.vbs` intercepta eventos do hMailServer (conexão SMTP, autenticação, entrega, spam).
- Os eventos relevantes são registrados em logs próprios, em formato fácil de processar por scripts.
- A cada 15 minutos, uma tarefa agendada executa o script `AUTO-BLOQUEIO-Fail2Ban.ps1`, que:
  - lê os logs do hMailServer;
  - conta tentativas de login inválidas por IP;
  - identifica IPs suspeitos por limiares configuráveis;
  - atualiza automaticamente listas de bloqueio (firewall do Windows e/ou firewall externo, como Mikrotik), **sem armazenar IPs fixos ou ranges sensíveis no código-fonte**.
- Configurações sensíveis (senhas, ranges internos, usuários administrativos) ficam fora do repositório, em arquivos locais protegidos ou variáveis de ambiente.

#### 2. Renovação automática de certificados TLS para e-mail

- O servidor usa **win-acme** para renovar automaticamente certificados Let's Encrypt do domínio de e-mail.
- Após cada renovação, uma cadeia de scripts PowerShell cuida do pós-processamento:
  - `post-renew.ps1` — disparado pelo win-acme após a renovação;
  - `01-extract-keys.ps1` — exporta o certificado renovado do repositório do Windows para arquivos/PFX temporários;
  - `02-update-hmail.ps1` — atualiza o certificado configurado no hMailServer (SMTP/IMAP/POP) e reinicia o serviço de forma controlada;
  - `Comparar-Certificados-HMail-IIS.ps1` — compara os certificados usados no IIS e no hMailServer para garantir que estão sincronizados.
- Objetivo: manter **TLS ativo e atualizado** no e-mail (SMTP/IMAP/POP) sem necessidade de ajustes manuais a cada renovação de certificado.

> 💡 Esses scripts fazem parte tanto da **automação operacional** quanto da **camada de segurança** (bloqueio automático e criptografia TLS).  
> Por isso, a documentação aparece junto da seção de hMailServer/Webmail, mas sem expor detalhes internos da rede.

#### Organização sugerida no repositório

- `docs/hmailserver/README.md`  
  - Visão geral do serviço de e-mail.  
  - Sub-seção **“Automação (EventHandlers + Fail2Ban + Certificados)”** com o conteúdo acima.

- `scripts/hmailserver/`  
  - `EventHandlers.vbs`  
  - `AUTO-BLOQUEIO-Fail2Ban.ps1`  
  - `01-extract-keys.ps1`  
  - `02-update-hmail.ps1`  
  - `Comparar-Certificados-HMail-IIS.ps1`  
  - `post-renew.ps1`
