# Estudo de Caso 2: Automação de Certificados SSL (IIS + hMailServer)

## O Desafio
Manter certificados SSL atualizados é crucial para a segurança. Em um ambiente Windows, o **Win-ACME (Let's Encrypt)** é a ferramenta padrão para automatizar a renovação de certificados para o **IIS**.

O problema é que o **hMailServer** (que serve SMTP/IMAP) não lê o repositório de certificados do IIS. Ele requer que o caminho para o certificado e a chave privada (PFX) seja configurado manualmente em seu painel.

Isso cria um fluxo de trabalho manual e arriscado:
1.  O Win-ACME renova o certificado para o site (IIS).
2.  O hMailServer continua usando o certificado *antigo*.
3.  O administrador precisa (a cada 60-90 dias) exportar manualmente o novo PFX, salvá-lo em um local seguro, atualizar o caminho no hMailServer e reiniciar o serviço.
4.  Se esquecido, os certificados de e-mail expiram, e clientes (Outlook, Thunderbird) param de funcionar.

## A Solução
Desenvolvi uma esteira 100% automatizada em PowerShell que se integra ao hook de "pós-renovação" do Win-ACME, garantindo que o hMailServer receba o novo certificado no mesmo instante em que o IIS é atualizado.

### A Esteira de Automação
O processo é acionado pelo Win-ACME, que chama o script `post-renew.ps1` após uma renovação bem-sucedida.

**1. Extração do Certificado (`01-extract-keys.ps1`)**
Este script é a primeira etapa. Ele é chamado pelo `post-renew.ps1`.
* **O que faz:** Localiza o novo certificado PFX no repositório do Win-ACME, o exporta usando uma senha segura (armazenada fora do Git) e o salva em um local fixo onde o hMailServer possa acessá-lo (ex: `C:\hmail-lists\ssl\certificate.pfx`).

**2. Atualização do hMailServer (`02-update-hmail.ps1`)**
Este é o coração da automação, também chamado pelo `post-renew.ps1`.
* **O que faz:**
    * Instancia o objeto `hMailServer.Application` (API COM).
    * Autentica-se no servidor de e-mail.
    * Acessa as configurações de domínio (ex: `mail.portalauditoria.com.br`).
    * Atualiza os campos `SSLCertificateFile` e `SSLKeyFile` para apontar para o novo PFX exportado.
    * Salva as configurações.
    * (Opcional) Envia um comando de `Reload` ou reinicia o serviço se necessário.

**3. Auditoria Diária (`Comparar-Certificados-HMail-IIS.ps1`)**
Este é um script de verificação, executado via Tarefa Agendada, para garantir que a automação não falhou.
* **O que faz:**
    * Lê o thumbprint (impressão digital) do certificado atualmente em uso no *Binding* 443 do IIS.
    * Lê o thumbprint do certificado configurado no hMailServer (via API COM).
    * Compara os dois.
    * Se forem iguais, registra "OK" no log.
    * Se forem diferentes, envia um e-mail de alerta para o `adm@portalauditoria.com.br`, avisando sobre a dessincronização.

➡️ **Links para os Scripts:**
* [`/post-renew.ps1`](../post-renew.ps1) (O orquestrador)
* [`/01-extract-keys.ps1`](../01-extract-keys.ps1) (O extrator)
* [`/02-update-hmail.ps1`](../02-update-hmail.ps1) (O atualizador do hMail)
* [`/Comparar-Certificados-HMail-IIS.ps1`](../Comparar-Certificados-HMail-IIS.ps1) (O auditor)

## O Resultado
Com esta esteira de automação, o gerenciamento de SSL para **todos** os serviços (Web, SMTP, IMAP) é "zero-touch". O Let's Encrypt renova, o PowerShell sincroniza, e os serviços nunca expiram, eliminando a necessidade de intervenção manual e garantindo a confiança dos clientes de e-mail.
