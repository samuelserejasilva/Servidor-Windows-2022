' ======================================================================
' Script Aurea/Black List para hMailServer (v3.8 - PRODUCAO, FIX Result)
'
' - Removidos logs DEBUG excessivos
' - Otimizado para performance
' - Politica: AUTH > BLACKLIST > WHITELIST > DEFAULT
' - Suporte a wildcards (* e ?) em todas as listas
' - Integracao correta com hMailServer via Result.Value / Result.Message
' ======================================================================

Option Explicit

' ================== CONFIGURACAO BASICA ==================
Const LOCAL_DOMAIN          = "portalauditoria.com.br"
Const LIST_BASE_PATH        = "C:\hmail-lists\lists"
Const LOG_FILE              = "C:\hmail-lists\logs\AureaBlack_Lists.log"
Const CACHE_RELOAD_MINUTES  = 5

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

    Dim decision, reason
    decision = DECISION_NONE
    reason   = "NO_DECISION"

    ' Carrega cache se necessario
    Call CheckAndLoadCache

    Dim remoteIP, fromAddr, fromDomain
    remoteIP   = LCase(Trim(oClient.IPAddress))
    fromAddr   = LCase(Trim(oMessage.FromAddress))
    fromDomain = GetDomain(fromAddr)

    Dim rcpts, i, allRecipientsInternal, firstRecipientAddr
    Set rcpts = oMessage.Recipients
    allRecipientsInternal = True

    If rcpts.Count > 0 Then
        firstRecipientAddr = LCase(Trim(rcpts(0).Address))
    Else
        firstRecipientAddr = ""
    End If

    For i = 0 To rcpts.Count - 1
        If Not IsLocalAddress(rcpts(i).Address) Then
            allRecipientsInternal = False
            Exit For
        End If
    Next

    ' 1) AUTENTICACAO / MENSAGENS INTERNAS TEM PRIORIDADE
    If oClient.Username <> "" Then

        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: AUTHENTICATED_SENDER (" & oClient.Username & ")"

    ElseIf IsLocalAddress(fromAddr) And allRecipientsInternal Then

        decision = DECISION_ALLOW_AUREA
        reason   = "ALLOW_AUREA: INTERNAL_LOCAL_MESSAGE"

    Else
        ' 2) BLACKLIST TEM PRIORIDADE
        If IsInList("g_BLEmails", fromAddr) Then

            decision = DECISION_BLOCK_BLACK
            reason   = "BLOCK_BLACK: FROM_EMAIL in blacklist"

        ElseIf IsInList("g_BLDomains", fromDomain) Then

            decision = DECISION_BLOCK_BLACK
            reason   = "BLOCK_BLACK: FROM_DOMAIN in blacklist"

        ElseIf IsInList("g_BLIPs", remoteIP) Then

            decision = DECISION_BLOCK_BLACK
            reason   = "BLOCK_BLACK: REMOTE_IP in blacklist"

        End If

        ' 3) WHITELIST SO SE NAO ESTIVER EM BLACKLIST
        If decision = DECISION_NONE Then

            If IsInList("g_WLEmails", fromAddr) Then

                decision = DECISION_ALLOW_AUREA
                reason   = "ALLOW_AUREA: FROM_EMAIL in whitelist"

            ElseIf IsInList("g_WLDomains", fromDomain) Then

                decision = DECISION_ALLOW_AUREA
                reason   = "ALLOW_AUREA: FROM_DOMAIN in whitelist"

            ElseIf IsInList("g_WLIPs", remoteIP) Then

                decision = DECISION_ALLOW_AUREA
                reason   = "ALLOW_AUREA: FROM_IP in whitelist"

            End If
        End If

        ' 4) DEFAULT
        If decision = DECISION_NONE Then
            decision = DECISION_ALLOW_AUTO
            reason   = "ALLOW_AUTO: NOT_FOUND"
        End If
    End If

    ' Log da decisao (audit)
    WriteAuditLog Now & " | FROM=" & fromAddr & " | To=" & firstRecipientAddr & _
        " | IP=" & remoteIP & " | AUTH=" & CStr(oClient.Username <> "") & _
        " | DECISION=" & CStr(decision) & " | " & reason

    ' Aplicar decisao – AQUI usamos Result.Value / Result.Message
    If decision = DECISION_BLOCK_BLACK Then

        oMessage.Body    = "BLOCKED BY AUREA/BLACK ANTI-SPAM SYSTEM" & vbCrLf & _
                           "Reason: " & reason & vbCrLf & vbCrLf & oMessage.Body
        oMessage.Subject = "[SPAM BLOCKED] " & oMessage.Subject

        WriteAuditLog "SMTP_REJECT: " & fromAddr & " -> " & reason

        Result.Value   = 2
        Result.Message = "550 " & reason

    Else

        Result.Value = 0

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
        needReload = True
    Else
        Dim diffMinutes
        diffMinutes = DateDiff("n", g_LastCacheLoad, Now)
        If diffMinutes >= CACHE_RELOAD_MINUTES Then
            needReload = True
        End If
    End If

    If needReload Then
        WriteAuditLog "CACHE_RELOAD: Loading lists..."

        g_WLEmails  = LoadListFile("whitelist_emails.txt")
        g_WLDomains = LoadListFile("whitelist_domains.txt")
        g_WLIPs     = LoadListFile("whitelist_ips.txt")

        g_BLEmails  = LoadListFile("blacklist_emails.txt")
        g_BLDomains = LoadListFile("blacklist_domains.txt")
        g_BLIPs     = LoadListFile("blacklist_ips.txt")

        g_LastCacheLoad = Now

        WriteAuditLog "CACHE_RELOAD: Done."
    End If
End Sub

Function LoadListFile(filename)
    On Error Resume Next

    Dim fso, f, line, arr()
    Dim count, fullPath

    count    = 0
    fullPath = LIST_BASE_PATH & "\" & filename

    Set fso = CreateObject("Scripting.FileSystemObject")

    If Not fso.FileExists(fullPath) Then
        LoadListFile = Array()
        Exit Function
    End If

    Set f = fso.OpenTextFile(fullPath, 1)

    Do While Not f.AtEndOfStream
        line = Trim(f.ReadLine)

        ' Ignora linhas vazias e comentarios
        If Len(line) > 0 And Left(line, 1) <> "#" Then
            ReDim Preserve arr(count)
            arr(count) = LCase(line)
            count      = count + 1
        End If
    Loop

    f.Close

    If count > 0 Then
        LoadListFile = arr
    Else
        LoadListFile = Array()
    End If
End Function

' ========================================================
' VERIFICACAO COM SUPORTE A WILDCARDS
' ========================================================
Function IsInList(ByVal listCacheName, ByVal key)
    On Error Resume Next

    IsInList = False

    Dim arr, i, item
    arr = Eval(listCacheName)

    If Not IsArray(arr) Then
        Exit Function
    End If

    key = LCase(Trim(key))

    For i = 0 To UBound(arr)
        item = LCase(Trim(arr(i)))

        ' Suporte a wildcards (* e ?)
        If InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then

            If MatchWildcard(item, key) Then
                IsInList = True
                Exit Function
            End If

        Else
            ' Match exato
            If item = key Then
                IsInList = True
                Exit Function
            End If
        End If
    Next
End Function

' ========================================================
' FUNCAO DE MATCH COM WILDCARD
' ========================================================
Function MatchWildcard(pattern, text)
    On Error Resume Next

    Dim regex
    Set regex = New RegExp

    ' Converte wildcard para regex
    ' * vira .*
    ' ? vira .
    Dim regexPattern
    regexPattern = Replace(pattern, ".", "\.")
    regexPattern = Replace(regexPattern, "*", ".*")
    regexPattern = Replace(regexPattern, "?", ".")
    regexPattern = "^" & regexPattern & "$"

    regex.Pattern    = regexPattern
    regex.IgnoreCase = True
    regex.Global     = False

    MatchWildcard = regex.Test(text)
End Function

' ========================================================
' FUNCAO DE LOG
' ========================================================
Sub WriteAuditLog(msg)
    On Error Resume Next

    Dim fso, f
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f   = fso.OpenTextFile(LOG_FILE, 8, True)
    f.WriteLine msg
    f.Close
End Sub
