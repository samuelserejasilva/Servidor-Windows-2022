' ======================================================================
' Script Aurea/Black List para hMailServer (v3.8 - DEBUG SUPER DETALHADO)
'
' VERSAO DEBUG: Logs EXTREMAMENTE detalhados para diagnostico
' CORRECAO: Bug de wildcard CORRIGIDO (placeholder method)
' POLITICA: AUTH > BLACKLIST > WHITELIST > DEFAULT
'
' VERSAO: 3.8 DEBUG
' DATA: 25/11/2025
' AUTOR: Claude + Samuel Cereja
' ======================================================================

Option Explicit

' ================== CONFIGURACAO BASICA ==================
Const LOCAL_DOMAIN          = "portalauditoria.com.br"
Const LIST_BASE_PATH        = "C:\hmail-lists\lists"
Const LOG_FILE              = "C:\hmail-lists\logs\AureaBlack_Lists.log"
Const CACHE_RELOAD_MINUTES  = 5
Const DEBUG_MODE            = True  ' ← DEBUG ATIVADO!!!

' ================== CODIGOS DE DECISAO ==================
Const DECISION_NONE         = 0
Const DECISION_ALLOW_AUREA  = 10
Const DECISION_ALLOW_AUTO   = 20
Const DECISION_BLOCK_BLACK  = 30

' ================== CACHE GLOBAL ==================
Dim g_WLEmails, g_WLDomains, g_WLIPs
Dim g_BLEmails, g_BLDomains, g_BLIPs
Dim g_LastCacheLoad

' ========================================================
' EVENTO PRINCIPAL: OnSMTPData
' ========================================================
Sub OnSMTPData(oClient, oMessage)
    On Error Resume Next

    WriteAuditLog ""
    WriteAuditLog "╔══════════════════════════════════════════════════════════════════╗"
    WriteAuditLog "║               NOVO EMAIL RECEBIDO - DEBUG MODE                   ║"
    WriteAuditLog "╚══════════════════════════════════════════════════════════════════╝"

    Dim decision, reason
    decision = DECISION_NONE
    reason   = "NO_DECISION"

    ' Carrega cache se necessario
    Call CheckAndLoadCache

    Dim remoteIP, fromAddr, fromDomain
    remoteIP   = LCase(Trim(oClient.IPAddress))
    fromAddr   = LCase(Trim(oMessage.FromAddress))
    fromDomain = GetDomain(fromAddr)

    ' ========== DEBUG: INFORMACOES DO EMAIL ==========
    WriteAuditLog "DEBUG [EMAIL_INFO]: ┌─ Informações do Remetente ─┐"
    WriteAuditLog "DEBUG [EMAIL_INFO]: │ FROM Email    : [" & fromAddr & "]"
    WriteAuditLog "DEBUG [EMAIL_INFO]: │ FROM Domain   : [" & fromDomain & "]"
    WriteAuditLog "DEBUG [EMAIL_INFO]: │ Remote IP     : [" & remoteIP & "]"
    WriteAuditLog "DEBUG [EMAIL_INFO]: │ Authenticated : [" & CStr(oClient.Username <> "") & "]"
    If oClient.Username <> "" Then
        WriteAuditLog "DEBUG [EMAIL_INFO]: │ Username      : [" & oClient.Username & "]"
    End If
    WriteAuditLog "DEBUG [EMAIL_INFO]: └────────────────────────────┘"

    Dim rcpts, i, allRecipientsInternal, firstRecipientAddr
    Set rcpts = oMessage.Recipients
    allRecipientsInternal = True

    If rcpts.Count > 0 Then
        firstRecipientAddr = LCase(Trim(rcpts(0).Address))
        WriteAuditLog "DEBUG [EMAIL_INFO]: TO (first): [" & firstRecipientAddr & "]"
    Else
        firstRecipientAddr = ""
        WriteAuditLog "DEBUG [EMAIL_INFO]: TO: [NO RECIPIENTS]"
    End If

    For i = 0 To rcpts.Count - 1
        If Not IsLocalAddress(rcpts(i).Address) Then
            allRecipientsInternal = False
            Exit For
        End If
    Next

    WriteAuditLog "DEBUG [EMAIL_INFO]: Recipients are ALL internal: [" & CStr(allRecipientsInternal) & "]"
    WriteAuditLog ""

    ' ========== DEBUG: CACHE STATUS ==========
    WriteAuditLog "DEBUG [CACHE_STATUS]: ┌─ Status do Cache ─┐"
    If IsArray(g_WLEmails) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_Emails  : " & (UBound(g_WLEmails) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_Emails  : NOT LOADED!"
    End If

    If IsArray(g_WLDomains) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_Domains : " & (UBound(g_WLDomains) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_Domains : NOT LOADED!"
    End If

    If IsArray(g_WLIPs) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_IPs     : " & (UBound(g_WLIPs) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ WL_IPs     : NOT LOADED!"
    End If

    If IsArray(g_BLEmails) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_Emails  : " & (UBound(g_BLEmails) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_Emails  : NOT LOADED!"
    End If

    If IsArray(g_BLDomains) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_Domains : " & (UBound(g_BLDomains) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_Domains : NOT LOADED!"
    End If

    If IsArray(g_BLIPs) Then
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_IPs     : " & (UBound(g_BLIPs) + 1) & " entries"
    Else
        WriteAuditLog "DEBUG [CACHE_STATUS]: │ BL_IPs     : NOT LOADED!"
    End If
    WriteAuditLog "DEBUG [CACHE_STATUS]: └───────────────────┘"
    WriteAuditLog ""

    ' 1) AUTENTICACAO / MENSAGENS INTERNAS TEM PRIORIDADE
    WriteAuditLog "DEBUG [STEP_1]: ▶ Verificando AUTENTICACAO..."

    If oClient.Username <> "" Then

        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: AUTHENTICATED_SENDER (" & oClient.Username & ")"
        WriteAuditLog "DEBUG [STEP_1]: ✅ AUTHENTICATED! User: [" & oClient.Username & "]"
        WriteAuditLog "DEBUG [STEP_1]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit

    ElseIf IsLocalAddress(fromAddr) And allRecipientsInternal Then

        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: INTERNAL_LOCAL_MESSAGE"
        WriteAuditLog "DEBUG [STEP_1]: ✅ INTERNAL MESSAGE! (local sender + all recipients local)"
        WriteAuditLog "DEBUG [STEP_1]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit

    Else
        WriteAuditLog "DEBUG [STEP_1]: ❌ NOT authenticated or internal message"
        WriteAuditLog ""
    End If

    ' 2) BLACKLIST TEM PRIORIDADE
    WriteAuditLog "DEBUG [STEP_2]: ▶ Verificando BLACKLIST (prioridade sobre whitelist)..."

    WriteAuditLog "DEBUG [STEP_2]: ┌─ Checking BL_Emails ─┐"
    If IsInListDebug("g_BLEmails", fromAddr, "BL_EMAIL") Then
        decision = DECISION_BLOCK_BLACK
        reason   = "BLOCK_BLACK: FROM_EMAIL in blacklist"
        WriteAuditLog "DEBUG [STEP_2]: 🔴 BLOQUEADO! Email encontrado na BLACKLIST"
        WriteAuditLog "DEBUG [STEP_2]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_2]: └─ BL_Emails: NO MATCH ─┘"
    WriteAuditLog ""

    WriteAuditLog "DEBUG [STEP_2]: ┌─ Checking BL_Domains ─┐"
    If IsInListDebug("g_BLDomains", fromDomain, "BL_DOMAIN") Then
        decision = DECISION_BLOCK_BLACK
        reason   = "BLOCK_BLACK: FROM_DOMAIN in blacklist"
        WriteAuditLog "DEBUG [STEP_2]: 🔴 BLOQUEADO! Domínio encontrado na BLACKLIST"
        WriteAuditLog "DEBUG [STEP_2]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_2]: └─ BL_Domains: NO MATCH ─┘"
    WriteAuditLog ""

    WriteAuditLog "DEBUG [STEP_2]: ┌─ Checking BL_IPs ─┐"
    If IsInListDebug("g_BLIPs", remoteIP, "BL_IP") Then
        decision = DECISION_BLOCK_BLACK
        reason   = "BLOCK_BLACK: REMOTE_IP in blacklist"
        WriteAuditLog "DEBUG [STEP_2]: 🔴 BLOQUEADO! IP encontrado na BLACKLIST"
        WriteAuditLog "DEBUG [STEP_2]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_2]: └─ BL_IPs: NO MATCH ─┘"
    WriteAuditLog "DEBUG [STEP_2]: ✅ Não encontrado em nenhuma BLACKLIST"
    WriteAuditLog ""

    ' 3) WHITELIST SO SE NAO ESTIVER EM BLACKLIST
    WriteAuditLog "DEBUG [STEP_3]: ▶ Verificando WHITELIST (apenas se não estiver em blacklist)..."

    WriteAuditLog "DEBUG [STEP_3]: ┌─ Checking WL_Emails ─┐"
    If IsInListDebug("g_WLEmails", fromAddr, "WL_EMAIL") Then
        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: FROM_EMAIL in whitelist"
        WriteAuditLog "DEBUG [STEP_3]: ✅ PERMITIDO! Email encontrado na WHITELIST"
        WriteAuditLog "DEBUG [STEP_3]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_3]: └─ WL_Emails: NO MATCH ─┘"
    WriteAuditLog ""

    WriteAuditLog "DEBUG [STEP_3]: ┌─ Checking WL_Domains ─┐"
    If IsInListDebug("g_WLDomains", fromDomain, "WL_DOMAIN") Then
        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: FROM_DOMAIN in whitelist"
        WriteAuditLog "DEBUG [STEP_3]: ✅ PERMITIDO! Domínio encontrado na WHITELIST"
        WriteAuditLog "DEBUG [STEP_3]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_3]: └─ WL_Domains: NO MATCH ─┘"
    WriteAuditLog ""

    WriteAuditLog "DEBUG [STEP_3]: ┌─ Checking WL_IPs ─┐"
    If IsInListDebug("g_WLIPs", remoteIP, "WL_IP") Then
        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: FROM_IP in whitelist"
        WriteAuditLog "DEBUG [STEP_3]: ✅ PERMITIDO! IP encontrado na WHITELIST"
        WriteAuditLog "DEBUG [STEP_3]: 🎯 DECISAO FINAL: " & reason
        WriteAuditLog ""
        GoTo LogAndExit
    End If
    WriteAuditLog "DEBUG [STEP_3]: └─ WL_IPs: NO MATCH ─┘"
    WriteAuditLog "DEBUG [STEP_3]: ❌ Não encontrado em nenhuma WHITELIST"
    WriteAuditLog ""

    ' 4) DEFAULT
    WriteAuditLog "DEBUG [STEP_4]: ▶ Nenhuma regra aplicada, usando DEFAULT..."
    decision = DECISION_ALLOW_AUTO
    reason   = "ALLOW_AUTO: NOT_FOUND"
    WriteAuditLog "DEBUG [STEP_4]: 🎯 DECISAO FINAL: " & reason
    WriteAuditLog ""

LogAndExit:
    ' Log da decisao FINAL (formato de producao)
    WriteAuditLog "═══════════════════════════════════════════════════════════════════"
    WriteAuditLog "🎯 DECISAO FINAL: " & Now & " | FROM=" & fromAddr & " | To=" & firstRecipientAddr & _
        " | IP=" & remoteIP & " | AUTH=" & CStr(oClient.Username <> "") & _
        " | DECISION=" & CStr(decision) & " | " & reason
    WriteAuditLog "═══════════════════════════════════════════════════════════════════"
    WriteAuditLog ""

    ' Aplicar decisao – usa Result.Value / Result.Message
    If decision = DECISION_BLOCK_BLACK Then

        WriteAuditLog "DEBUG [ACTION]: 🔴 BLOQUEANDO EMAIL (oMessage.Delete + Result.Value=2)"

        oMessage.Body    = "BLOCKED BY AUREA/BLACK ANTI-SPAM SYSTEM" & vbCrLf & _
                           "Reason: " & reason & vbCrLf & vbCrLf & oMessage.Body
        oMessage.Subject = "[SPAM BLOCKED] " & oMessage.Subject

        WriteAuditLog "SMTP_REJECT: " & fromAddr & " -> " & reason

        Result.Value   = 2
        Result.Message = "550 " & reason

    Else

        WriteAuditLog "DEBUG [ACTION]: ✅ PERMITINDO EMAIL (Result.Value=0)"
        Result.Value = 0

    End If

    If Err.Number <> 0 Then
        WriteAuditLog "SCRIPT_ERROR: " & Err.Number & " - " & Err.Description
        Err.Clear
    End If
End Sub

' ========================================================
' FUNCOES AUXILIARES
' ========================================================

Function GetDomain(email)
    Dim pos
    pos = InStr(email, "@")
    If pos > 0 Then
        GetDomain = Mid(email, pos + 1)
    Else
        GetDomain = ""
    End If
End Function

Function IsLocalAddress(addr)
    IsLocalAddress = (InStr(LCase(addr), "@" & LOCAL_DOMAIN) > 0)
End Function

Sub CheckAndLoadCache()
    Dim needReload
    needReload = False

    If IsEmpty(g_LastCacheLoad) Then
        WriteAuditLog "DEBUG [CACHE]: Cache vazio, forçando reload inicial..."
        needReload = True
    Else
        Dim diffMinutes
        diffMinutes = DateDiff("n", g_LastCacheLoad, Now)

        WriteAuditLog "DEBUG [CACHE]: Last reload: " & g_LastCacheLoad & " (diff: " & diffMinutes & " minutos)"

        If diffMinutes >= CACHE_RELOAD_MINUTES Then
            WriteAuditLog "DEBUG [CACHE]: Cache expirado (>= " & CACHE_RELOAD_MINUTES & " min), recarregando..."
            needReload = True
        ElseIf diffMinutes < 0 Then
            WriteAuditLog "DEBUG [CACHE]: ⚠️ Relógio ajustado para trás! Forçando reload..."
            needReload = True
        End If
    End If

    If needReload Then
        WriteAuditLog "CACHE_RELOAD: ▶ Loading lists..."

        g_WLEmails  = LoadListFile("whitelist_emails.txt")
        g_WLDomains = LoadListFile("whitelist_domains.txt")
        g_WLIPs     = LoadListFile("whitelist_ips.txt")

        g_BLEmails  = LoadListFile("blacklist_emails.txt")
        g_BLDomains = LoadListFile("blacklist_domains.txt")
        g_BLIPs     = LoadListFile("blacklist_ips.txt")

        g_LastCacheLoad = Now

        WriteAuditLog "CACHE_RELOAD: ✅ Done at " & Now
    Else
        WriteAuditLog "DEBUG [CACHE]: ✅ Cache OK (não precisa reload)"
    End If

    WriteAuditLog ""
End Sub

Function LoadListFile(filename)
    On Error Resume Next

    Dim fso, f, line, arr()
    Dim count, fullPath

    count    = 0
    fullPath = LIST_BASE_PATH & "\" & filename

    Set fso = CreateObject("Scripting.FileSystemObject")

    WriteAuditLog "DEBUG [LOAD_FILE]: Tentando carregar: " & fullPath

    If Not fso.FileExists(fullPath) Then
        WriteAuditLog "DEBUG [LOAD_FILE]: ⚠️ ARQUIVO NÃO EXISTE: " & fullPath
        LoadListFile = Array()
        Exit Function
    End If

    Set f = fso.OpenTextFile(fullPath, 1)

    Do While Not f.AtEndOfStream
        line = Trim(f.ReadLine)

        ' Ignora linhas vazias e comentarios (# ou ;)
        If Len(line) > 0 And Left(line, 1) <> "#" And Left(line, 1) <> ";" Then
            ReDim Preserve arr(count)
            arr(count) = LCase(line)
            count      = count + 1
        End If
    Loop

    f.Close

    If count > 0 Then
        WriteAuditLog "DEBUG [LOAD_FILE]: ✅ Carregado: " & filename & " (" & count & " entries)"
        LoadListFile = arr
    Else
        WriteAuditLog "DEBUG [LOAD_FILE]: ⚠️ Arquivo vazio ou só comentários: " & filename
        LoadListFile = Array()
    End If
End Function

' ========================================================
' VERIFICACAO COM DEBUG DETALHADO
' ========================================================
Function IsInListDebug(ByVal listCacheName, ByVal key, ByVal debugContext)
    On Error Resume Next

    IsInListDebug = False

    Dim arr, i, item
    arr = Eval(listCacheName)

    If Not IsArray(arr) Then
        WriteAuditLog "DEBUG [" & debugContext & "]: ⚠️ Lista não é array: " & listCacheName
        Exit Function
    End If

    key = LCase(Trim(key))

    If key = "" Then
        WriteAuditLog "DEBUG [" & debugContext & "]: ⚠️ Chave VAZIA, pulando verificação"
        Exit Function
    End If

    Dim totalEntries
    totalEntries = UBound(arr) + 1

    WriteAuditLog "DEBUG [" & debugContext & "]: 🔍 Procurando [" & key & "] em " & totalEntries & " entradas..."

    For i = 0 To UBound(arr)
        item = LCase(Trim(arr(i)))

        If item = "" Then
            ' Ignora entradas vazias
        ElseIf InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then
            ' Tem wildcard
            WriteAuditLog "DEBUG [" & debugContext & "]:   [" & i & "] Testando WILDCARD: [" & item & "] vs [" & key & "]"

            If MatchWildcardDebug(item, key, debugContext) Then
                WriteAuditLog "DEBUG [" & debugContext & "]: ✅✅✅ MATCH! WILDCARD [" & item & "] matched [" & key & "]"
                IsInListDebug = True
                Exit Function
            End If

        Else
            ' Match exato
            If item = key Then
                WriteAuditLog "DEBUG [" & debugContext & "]:   [" & i & "] ✅✅✅ MATCH EXATO! [" & item & "] == [" & key & "]"
                IsInListDebug = True
                Exit Function
            End If
        End If
    Next

    WriteAuditLog "DEBUG [" & debugContext & "]: ❌ NO MATCH para [" & key & "] (" & totalEntries & " entradas verificadas)"
End Function

' ========================================================
' FUNCAO DE MATCH COM WILDCARD - VERSÃO CORRIGIDA + DEBUG!
'
' CORREÇÃO CRÍTICA v3.8:
' - Usa placeholders para proteger wildcards
' - Escapa caracteres especiais DEPOIS
' - Restaura wildcards como regex
'
' BUG ANTERIOR:
'   regexPattern = Replace(pattern, ".", "\.")  ← Escapava PRIMEIRO
'   regexPattern = Replace(regexPattern, "*", ".*")  ← Wildcard DEPOIS
'   Resultado: *.xyz → *\.xyz → .*\.xyz (ERRADO!)
'
' CORREÇÃO:
'   1. pattern = Replace(pattern, "*", "__STAR__")  ← Placeholder
'   2. pattern = Replace(pattern, ".", "\.")  ← Escapa pontos
'   3. pattern = Replace(pattern, "__STAR__", ".*")  ← Restaura
'   Resultado: *.xyz → __STAR__.xyz → __STAR__\.xyz → .*\.xyz (CORRETO!)
' ========================================================
Function MatchWildcardDebug(pattern, text, debugContext)
    On Error Resume Next

    Dim regex, regexPattern, originalPattern
    Set regex = New RegExp

    originalPattern = pattern

    WriteAuditLog "DEBUG [" & debugContext & "]:     ┌─ Wildcard Processing ─┐"
    WriteAuditLog "DEBUG [" & debugContext & "]:     │ Input   : [" & pattern & "]"

    ' *** CORREÇÃO v3.8: ORDEM CORRIGIDA! ***

    ' PASSO 1: Substituir wildcards por placeholders temporários
    regexPattern = Replace(pattern, "*", "__WILDCARD_STAR__")
    regexPattern = Replace(regexPattern, "?", "__WILDCARD_QUESTION__")
    WriteAuditLog "DEBUG [" & debugContext & "]:     │ Step 1  : [" & regexPattern & "] (placeholders)"

    ' PASSO 2: Escapar caracteres especiais de regex
    regexPattern = Replace(regexPattern, ".", "\.")
    regexPattern = Replace(regexPattern, "^", "\^")
    regexPattern = Replace(regexPattern, "$", "\$")
    regexPattern = Replace(regexPattern, "+", "\+")
    regexPattern = Replace(regexPattern, "(", "\(")
    regexPattern = Replace(regexPattern, ")", "\)")
    regexPattern = Replace(regexPattern, "[", "\[")
    regexPattern = Replace(regexPattern, "]", "\]")
    regexPattern = Replace(regexPattern, "{", "\{")
    regexPattern = Replace(regexPattern, "}", "\}")
    regexPattern = Replace(regexPattern, "|", "\|")
    WriteAuditLog "DEBUG [" & debugContext & "]:     │ Step 2  : [" & regexPattern & "] (escaped)"

    ' PASSO 3: Restaurar wildcards como regex
    regexPattern = Replace(regexPattern, "__WILDCARD_STAR__", ".*")
    regexPattern = Replace(regexPattern, "__WILDCARD_QUESTION__", ".")
    WriteAuditLog "DEBUG [" & debugContext & "]:     │ Step 3  : [" & regexPattern & "] (wildcards restored)"

    ' Adicionar âncoras
    regexPattern = "^" & regexPattern & "$"
    WriteAuditLog "DEBUG [" & debugContext & "]:     │ Final   : [" & regexPattern & "] (with anchors)"

    regex.Pattern    = regexPattern
    regex.IgnoreCase = True
    regex.Global     = False

    Dim testResult
    testResult = regex.Test(text)

    If testResult Then
        WriteAuditLog "DEBUG [" & debugContext & "]:     │ Test    : ✅ MATCH! [" & text & "] matches [" & regexPattern & "]"
    Else
        WriteAuditLog "DEBUG [" & debugContext & "]:     │ Test    : ❌ NO MATCH [" & text & "] vs [" & regexPattern & "]"
    End If

    WriteAuditLog "DEBUG [" & debugContext & "]:     └───────────────────────┘"

    MatchWildcardDebug = testResult
End Function

' ========================================================
' FUNCAO DE LOG
' ========================================================
Sub WriteAuditLog(msg)
    On Error Resume Next

    Dim fso, f
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f   = fso.OpenTextFile(LOG_FILE, 8, True)

    If Err.Number = 0 Then
        f.WriteLine msg
        f.Close
    Else
        Err.Clear
    End If
End Sub
