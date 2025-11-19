' ========================================================================
' EventHandlers.vbs - VERSÃO 3.7 FINAL
' hMailServer Event Handlers with Aurea Black/White Lists
'
' CORREÇÃO DEFINITIVA: Lógica de wildcard corrigida
' BUG CORRIGIDO: Ordem de escape de regex (v3.4/v3.5/v3.6 tinham bug)
'
' VERSÃO: 3.7 FINAL
' DATA: 19/11/2025
' AUTOR: Claude + Samuel Cereja
' ========================================================================

' ===== CONFIGURAÇÕES GLOBAIS =====
Const DEBUG_MODE = False  ' ← Desative debug em produção (performance)
Const LOG_PATH = "C:\hmail-lists\logs\AureaBlack_Lists.log"
Const LISTS_PATH = "C:\hmail-lists\lists\"

' Cache global para listas (melhora performance)
Const CACHE_WHITELIST_EMAILS   = "AUREA_WL_EMAILS"
Const CACHE_WHITELIST_DOMAINS  = "AUREA_WL_DOMAINS"
Const CACHE_WHITELIST_IPS      = "AUREA_WL_IPS"
Const CACHE_BLACKLIST_EMAILS   = "AUREA_BL_EMAILS"
Const CACHE_BLACKLIST_DOMAINS  = "AUREA_BL_DOMAINS"
Const CACHE_BLACKLIST_IPS      = "AUREA_BL_IPS"

' Arquivos das listas
Const FILE_WHITELIST_EMAILS   = "whitelist_emails.txt"
Const FILE_WHITELIST_DOMAINS  = "whitelist_domains.txt"
Const FILE_WHITELIST_IPS      = "whitelist_ips.txt"
Const FILE_BLACKLIST_EMAILS   = "blacklist_emails.txt"
Const FILE_BLACKLIST_DOMAINS  = "blacklist_domains.txt"
Const FILE_BLACKLIST_IPS      = "blacklist_ips.txt"

' Decisões (valores retornados)
Const DECISION_ALLOW_WL_EMAIL  = 10  ' Whitelist email
Const DECISION_ALLOW_WL_DOMAIN = 11  ' Whitelist domínio
Const DECISION_ALLOW_WL_IP     = 12  ' Whitelist IP
Const DECISION_BLOCK_BL_EMAIL  = 20  ' Blacklist email
Const DECISION_BLOCK_BL_DOMAIN = 21  ' Blacklist domínio
Const DECISION_BLOCK_BL_IP     = 22  ' Blacklist IP
Const DECISION_NEUTRAL         = 0   ' Não está em nenhuma lista


' ========================================================================
' EVENTO PRINCIPAL: OnSMTPData
' ========================================================================
Sub OnSMTPData(oClient, oMessage)
   On Error Resume Next

   Dim senderEmail, senderDomain, clientIP
   Dim decision, reason

   ' Extrair informações do remetente
   senderEmail = LCase(Trim(oMessage.FromAddress))
   clientIP = oClient.IPAddress

   ' Extrair domínio do email
   If InStr(senderEmail, "@") > 0 Then
      senderDomain = LCase(Mid(senderEmail, InStr(senderEmail, "@") + 1))
   Else
      senderDomain = ""
   End If

   ' Validação básica
   If senderEmail = "" Or senderDomain = "" Then
      WriteAuditLog "SCRIPT_ERROR: Email ou domínio vazio | FROM=" & senderEmail & " | IP=" & clientIP
      Exit Sub
   End If

   ' Recarregar cache (se necessário)
   Call ReloadCacheIfNeeded()

   ' ===== VERIFICAÇÃO 1: WHITELIST (prioridade máxima) =====

   ' 1.1 - Whitelist de emails (exato)
   If IsInList(CACHE_WHITELIST_EMAILS, senderEmail) Then
      decision = DECISION_ALLOW_WL_EMAIL
      reason = "ALLOW_AUREA: FROM_EMAIL in whitelist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      Exit Sub
   End If

   ' 1.2 - Whitelist de domínios (suporta wildcards)
   If IsInList(CACHE_WHITELIST_DOMAINS, senderDomain) Then
      decision = DECISION_ALLOW_WL_DOMAIN
      reason = "ALLOW_AUREA: FROM_DOMAIN in whitelist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      Exit Sub
   End If

   ' 1.3 - Whitelist de IPs (suporta wildcards)
   If IsInList(CACHE_WHITELIST_IPS, clientIP) Then
      decision = DECISION_ALLOW_WL_IP
      reason = "ALLOW_AUREA: FROM_IP in whitelist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      Exit Sub
   End If

   ' ===== VERIFICAÇÃO 2: BLACKLIST =====

   ' 2.1 - Blacklist de emails (exato)
   If IsInList(CACHE_BLACKLIST_EMAILS, senderEmail) Then
      decision = DECISION_BLOCK_BL_EMAIL
      reason = "BLOCK_AUREA: FROM_EMAIL in blacklist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      oMessage.Delete
      Exit Sub
   End If

   ' 2.2 - Blacklist de domínios (suporta wildcards)
   If IsInList(CACHE_BLACKLIST_DOMAINS, senderDomain) Then
      decision = DECISION_BLOCK_BL_DOMAIN
      reason = "BLOCK_AUREA: FROM_DOMAIN in blacklist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      oMessage.Delete
      Exit Sub
   End If

   ' 2.3 - Blacklist de IPs (suporta wildcards)
   If IsInList(CACHE_BLACKLIST_IPS, clientIP) Then
      decision = DECISION_BLOCK_BL_IP
      reason = "BLOCK_AUREA: FROM_IP in blacklist"
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
      oMessage.Delete
      Exit Sub
   End If

   ' ===== NEUTRO: Não está em nenhuma lista =====
   decision = DECISION_NEUTRAL
   reason = "NEUTRAL_AUREA: Not in any list"

   If DEBUG_MODE Then
      WriteAuditLog FormatLog(senderEmail, oMessage.To, clientIP, oClient.Username <> "", decision, reason)
   End If

End Sub


' ========================================================================
' FUNÇÃO: IsInList - Verifica se chave está na lista (cache)
'
' CORREÇÃO v3.7: Lógica de wildcard CORRIGIDA!
'
' BUG ANTERIOR (v3.4/v3.5/v3.6):
'   pattern = Replace(item, ".", "\.")      ← Escapava ANTES
'   pattern = Replace(pattern, "*", ".*")   ← Processava wildcard DEPOIS
'   Resultado: *.xyz virava .*\.xyz (ERRADO!)
'
' CORREÇÃO v3.7:
'   1. Substituir wildcards por placeholders
'   2. Escapar caracteres especiais de regex
'   3. Restaurar wildcards com regex corretos
'   Resultado: *.xyz vira .*\.xyz (CORRETO!)
'
' PARÂMETROS:
'   - listCacheName: Nome do cache (ex: AUREA_WL_EMAILS)
'   - key: Chave para procurar (ex: teste@exemplo.com)
'
' RETORNO:
'   - True: Chave encontrada na lista
'   - False: Chave não encontrada
' ========================================================================
Function IsInList(Byval listCacheName, Byval key)
   On Error Resume Next

   IsInList = False

   ' Validar parâmetros
   If IsEmpty(key) Or Trim(key) = "" Then
      Exit Function
   End If

   ' Obter lista do cache
   Dim listData, items, item, pattern, regex
   listData = oApp.Globals.Value(listCacheName)

   If IsEmpty(listData) Or Trim(listData) = "" Then
      Exit Function
   End If

   ' Dividir em linhas
   items = Split(listData, vbCrLf)

   Dim lb, ub, i
   lb = LBound(items)
   ub = UBound(items)

   ' Criar objeto Regex
   Set regex = New RegExp
   regex.IgnoreCase = True
   regex.Global = False

   ' Iterar sobre cada entrada da lista
   For i = lb To ub
      item = Trim(items(i))

      ' Pular linhas vazias
      If item = "" Then
         ' Nada a fazer, próxima iteração

      ' *** CORREÇÃO v3.7: WILDCARD LOGIC CORRIGIDA! ***
      ElseIf InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then
         ' Item contém wildcards - processar como regex

         ' PASSO 1: Substituir wildcards por placeholders temporários
         pattern = Replace(item, "*", "__WILDCARD_STAR__")
         pattern = Replace(pattern, "?", "__WILDCARD_QUESTION__")

         ' PASSO 2: Escapar caracteres especiais de regex
         ' (agora os pontos literais serão escapados corretamente!)
         pattern = Replace(pattern, ".", "\.")
         pattern = Replace(pattern, "(", "\(")
         pattern = Replace(pattern, ")", "\)")
         pattern = Replace(pattern, "[", "\[")
         pattern = Replace(pattern, "]", "\]")
         pattern = Replace(pattern, "+", "\+")
         pattern = Replace(pattern, "^", "\^")
         pattern = Replace(pattern, "$", "\$")
         pattern = Replace(pattern, "|", "\|")
         pattern = Replace(pattern, "{", "\{")
         pattern = Replace(pattern, "}", "\}")

         ' PASSO 3: Restaurar wildcards como regex
         pattern = Replace(pattern, "__WILDCARD_STAR__", ".*")
         pattern = Replace(pattern, "__WILDCARD_QUESTION__", ".")

         ' EXEMPLO DE TRANSFORMAÇÃO:
         ' Input: *.xyz
         ' Passo 1: __WILDCARD_STAR__.xyz
         ' Passo 2: __WILDCARD_STAR__\.xyz (ponto escapado!)
         ' Passo 3: .*\.xyz (wildcard restaurado!)
         ' Regex: ^.*\.xyz$ → Combina com "teste.xyz", "abc.xyz"

         ' Adicionar âncoras para match completo
         pattern = "^" & pattern & "$"

         ' Aplicar regex
         regex.Pattern = pattern

         If regex.Test(key) Then
            If DEBUG_MODE Then
               WriteAuditLog "DEBUG: MATCH! Wildcard '" & item & "' (regex: " & pattern & ") matched '" & key & "'"
            End If
            IsInList = True
            Exit Function
         End If

      Else
         ' Item sem wildcards - comparação exata (case-insensitive)
         If LCase(item) = LCase(key) Then
            If DEBUG_MODE Then
               WriteAuditLog "DEBUG: MATCH! Exact match '" & item & "' == '" & key & "'"
            End If
            IsInList = True
            Exit Function
         End If
      End If
   Next

   ' Não encontrou match
   If DEBUG_MODE Then
      WriteAuditLog "DEBUG: NO MATCH for '" & key & "' in cache '" & listCacheName & "' (" & (ub-lb+1) & " entries checked)"
   End If

   IsInList = False

End Function


' ========================================================================
' FUNÇÃO: ReloadCacheIfNeeded - Recarrega cache das listas
' ========================================================================
Sub ReloadCacheIfNeeded()
   On Error Resume Next

   ' Verificar se cache está vazio
   If IsEmpty(oApp.Globals.Value(CACHE_WHITELIST_EMAILS)) Then
      WriteAuditLog "CACHE_RELOAD: Loading lists into memory..."

      Call LoadListToCache(FILE_WHITELIST_EMAILS, CACHE_WHITELIST_EMAILS)
      Call LoadListToCache(FILE_WHITELIST_DOMAINS, CACHE_WHITELIST_DOMAINS)
      Call LoadListToCache(FILE_WHITELIST_IPS, CACHE_WHITELIST_IPS)
      Call LoadListToCache(FILE_BLACKLIST_EMAILS, CACHE_BLACKLIST_EMAILS)
      Call LoadListToCache(FILE_BLACKLIST_DOMAINS, CACHE_BLACKLIST_DOMAINS)
      Call LoadListToCache(FILE_BLACKLIST_IPS, CACHE_BLACKLIST_IPS)

      WriteAuditLog "CACHE_RELOAD: All lists loaded successfully"
   End If
End Sub


' ========================================================================
' FUNÇÃO: LoadListToCache - Carrega arquivo para cache global
' ========================================================================
Sub LoadListToCache(Byval fileName, Byval cacheName)
   On Error Resume Next

   Dim fso, file, filePath, content
   filePath = LISTS_PATH & fileName

   Set fso = CreateObject("Scripting.FileSystemObject")

   If Not fso.FileExists(filePath) Then
      WriteAuditLog "CACHE_WARNING: File not found: " & filePath
      oApp.Globals.Value(cacheName) = ""
      Exit Sub
   End If

   Set file = fso.OpenTextFile(filePath, 1)
   content = file.ReadAll
   file.Close

   oApp.Globals.Value(cacheName) = content

   ' Contar entradas
   Dim lineCount
   lineCount = UBound(Split(content, vbCrLf)) + 1

   WriteAuditLog "CACHE_LOAD: " & fileName & " → " & cacheName & " (" & lineCount & " entries)"

End Sub


' ========================================================================
' FUNÇÃO: FormatLog - Formata linha de log
' ========================================================================
Function FormatLog(Byval fromEmail, Byval toEmail, Byval ipAddress, Byval isAuth, Byval decision, Byval reason)
   Dim timestamp, authStatus, firstTo

   timestamp = Now()
   authStatus = "False"
   If isAuth Then authStatus = "True"

   ' Pegar primeiro destinatário
   firstTo = "unknown"
   If Not IsEmpty(toEmail) And toEmail <> "" Then
      firstTo = toEmail
   End If

   FormatLog = timestamp & " | FROM=" & fromEmail & " | To=" & firstTo & " | IP=" & ipAddress & " | AUTH=" & authStatus & " | DECISION=" & decision & " | " & reason
End Function


' ========================================================================
' FUNÇÃO: WriteAuditLog - Escreve no log de auditoria
' ========================================================================
Sub WriteAuditLog(Byval message)
   On Error Resume Next

   Dim fso, file
   Set fso = CreateObject("Scripting.FileSystemObject")

   ' Criar arquivo se não existir
   If Not fso.FileExists(LOG_PATH) Then
      Set file = fso.CreateTextFile(LOG_PATH, True)
      file.Close
   End If

   ' Append no arquivo
   Set file = fso.OpenTextFile(LOG_PATH, 8, True)
   file.WriteLine message
   file.Close

End Sub


' ========================================================================
' EVENTO: Application_OnClientConnect (opcional)
' ========================================================================
Sub OnClientConnect(oClient)
   ' Pode ser usado para logging adicional se necessário
End Sub
