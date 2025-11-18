' ======================================================================
' Script Aurea/Black List para hMailServer (v3.4 - VERSÃO ESTÁVEL)
' Combina o cache Global.Value (v3.3) com o leitor de lista robusto (v3.2)
' ======================================================================
Option Explicit

' ================== CONFIGURACAO BASICA ==================
Const LOCAL_DOMAIN         = "portalauditoria.com.br"
Const LIST_BASE_PATH       = "C:\hmail-lists\lists"
Const LOG_FILE             = "C:\hmail-lists\logs\AureaBlack_Lists.log"
Const CACHE_RELOAD_MINUTES = 5

' === VARIAVEIS GLOBAIS (Dim) REMOVIDAS ===
' O cache agora é tratado 100% pelo objeto Global

' ================== CODIGOS DE DECISAO ==================
Const DECISION_NONE        = 0
Const DECISION_ALLOW_AUREA = 10
Const DECISION_ALLOW_AUTO  = 20
Const DECISION_BLOCK_BLACK = 30

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
   firstRecipientAddr = ""

   If rcpts.Count > 0 Then
      firstRecipientAddr = LCase(Trim(rcpts(0).Address))
   End If

   For i = 0 To rcpts.Count - 1
      If Not IsLocalAddress(rcpts(i).Address) Then
         allRecipientsInternal = False
       Exit For
      End If
      Next

      ' 1) AUTENTICACAO TEM PRIORIDADE MAXIMA
      If oClient.Username <> "" Then
         decision = DECISION_ALLOW_AUREA
         reason   = "ALLOW_AUREA: AUTHENTICATED_SENDER (" & oClient.Username & ")"
      Elseif IsLocalAddress(fromAddr) And allRecipientsInternal Then
         decision = DECISION_ALLOW_AUREA
         reason   = "ALLOW_AUREA: INTERNAL_LOCAL_MESSAGE"
      Else
         ' 2) WHITELIST (Lendo Do cache Global)
         If IsInList("g_WLEmails", fromAddr) Then
            decision = DECISION_ALLOW_AUREA
            reason   = "ALLOW_AUREA: FROM_EMAIL in whitelist"
         Elseif IsInList("g_WLDomains", fromDomain) Then
            decision = DECISION_ALLOW_AUREA
            reason   = "ALLOW_AUREA: FROM_DOMAIN in whitelist"
         Elseif IsInList("g_WLIPs", remoteIP) Then
            decision = DECISION_ALLOW_AUREA
            reason   = "ALLOW_AUREA: REMOTE_IP in whitelist"
         End If

         ' 3) BLACKLIST (Lendo Do cache Global)
         If decision = DECISION_NONE Then
            If IsInList("g_BLEmails", fromAddr) Then
               decision = DECISION_BLOCK_BLACK
               reason   = "BLOCK_BLACK: FROM_EMAIL in blacklist"
            Elseif IsInList("g_BLDomains", fromDomain) Then
               decision = DECISION_BLOCK_BLACK
               reason   = "BLOCK_BLACK: FROM_DOMAIN in blacklist"
            Elseif IsInList("g_BLIPs", remoteIP) Then
               decision = DECISION_BLOCK_BLACK
               reason   = "BLOCK_BLACK: REMOTE_IP in blacklist"
            End If
         End If

         ' 4) DEFAULT
         If decision = DECISION_NONE Then
            decision = DECISION_ALLOW_AUTO
            reason   = "ALLOW_AUTO: NOT_FOUND"
         End If
      End If

      ' LOG E HEADERS
      oMessage.HeaderValue("X-AureaBlack-Decision") = reason

      Dim isAuthenticated
      isAuthenticated = (oClient.Username <> "")

      Dim logLine
      logLine = Now & " | FROM=" & fromAddr & " | To=" & firstRecipientAddr & " | IP=" & remoteIP & " | AUTH=" & CStr(isAuthenticated) & " | DECISION=" & CStr(decision) & " | " & reason
      WriteAuditLog logLine

      ' ACAO FINAL
      Select Case decision
       Case DECISION_BLOCK_BLACK
         Result.Value   = 2
         Result.Message = "550 " & reason
         WriteAuditLog "SMTP_REJECT: " & fromAddr & " -> " & reason
       Case Else
         Result.Value   = 0
      End Select

      If Err.Number <> 0 Then
         WriteAuditLog "SCRIPT_ERROR: " & Err.Number & " - " & Err.Description
         Err.Clear
      End If
End Sub

' ========================================================
' CACHE COM OBJETO GLOBAL (v3.3 - CORRETO E PERSISTENTE)
' ========================================================
Sub CheckAndLoadCache()
   On Error Resume Next
   Dim lastLoad, timeDiff

   ' Usar o objeto Global.Value para persistir a data
   lastLoad = Global.Value("AureaBlack_LastLoad")

   If IsEmpty(lastLoad) Or (TypeName(lastLoad) = "Null") Then 
      lastLoad = CDate("1/1/1900") ' Forca recarga inicial
   End If

   timeDiff = DateDiff("n", lastLoad, Now()) ' Diferenca em minutos

   ' Recarrega se expirou OU se relogio foi ajustado para tras
   If timeDiff >= CACHE_RELOAD_MINUTES Or timeDiff < 0 Then
      WriteAuditLog "CACHE_RELOAD: Loading lists..."

      ' Salva As listas no objeto Global
      Global.Value("g_WLEmails")  = LoadListToArray("whitelist_emails.txt")
      Global.Value("g_WLDomains") = LoadListToArray("whitelist_domains.txt")
      Global.Value("g_WLIPs")     = LoadListToArray("whitelist_ips.txt")

      Global.Value("g_BLEmails")  = LoadListToArray("blacklist_emails.txt")
      Global.Value("g_BLDomains") = LoadListToArray("blacklist_domains.txt")
      Global.Value("g_BLIPs")     = LoadListToArray("blacklist_ips.txt")

      Global.Value("AureaBlack_LastLoad") = Now()
      WriteAuditLog "CACHE_RELOAD: Done."
   End If
End Sub

' ========================================================
' CARREGAR LISTA (v3.2 - ROBUSTO, LINHA POR LINHA)
' ========================================================
Function LoadListToArray(Byval fileName)
   Dim fso, f, fullPath, line, cleanLines()
   Dim j
   ReDim cleanLines(0)
   j = -1

   On Error Resume Next
   fullPath = LIST_BASE_PATH & "\" & fileName
   Set fso = CreateObject("Scripting.FileSystemObject")

   If Not fso.FileExists(fullPath) Then
      WriteAuditLog "CACHE_LOAD_WARN: " & fileName & " Not found."
      LoadListToArray = Array()
    Exit Function
   End If

   Set f = fso.OpenTextFile(fullPath, 1, False) ' 1 = Read
   If Err.Number <> 0 Then
      WriteAuditLog "CACHE_LOAD_ERROR: " & fullPath & " - " & Err.Description
      Err.Clear
      LoadListToArray = Array()
    Exit Function
   End If
   On Error Goto 0 ' Desativa o "ignore erro"

      Do While Not f.AtEndOfStream
         line = LCase(Trim(f.ReadLine)) ' f.ReadLine lida com qualquer quebra de linha

         ' Limpa comentarios e linhas em branco
         If line <> "" And Left(line, 1) <> "#" And Left(line, 1) <> ";" Then
            j = j + 1
            ReDim Preserve cleanLines(j)
            cleanLines(j) = line
         End If
      Loop
      f.Close

      If j = -1 Then
         LoadListToArray = Array() ' Retorna array vazio se o arquivo so tiver comentarios
      Else
         LoadListToArray = cleanLines
      End If
End Function

' ========================================================
' VERIFICACAO SEGURA (LENDO Do CACHE GLOBAL)
' ========================================================
Function IsInList(Byref listCacheName, Byval key)
   Dim i, ub, regex, item, pattern, listArray
   IsInList = False
   key = LCase(Trim(key))
   If key = "" Then Exit Function

      ' Pega o array Do cache Global.Value
      listArray = Global.Value(listCacheName)
      If Not IsArray(listArray) Then Exit Function

         On Error Resume Next
         ub = UBound(listArray)
         If ub < 0 Then Exit Function

            Set regex = CreateObject("VBScript.RegExp")
            regex.IgnoreCase = True
            regex.Global = False

            For i = 0 To ub
               item = listArray(i)

               If InStr(item, "*") > 0 Or InStr(item, "?") > 0 Then
                  pattern = Replace(item, ".", "\.")
                  pattern = Replace(pattern, "*", ".*")
                  pattern = Replace(pattern, "?", ".")
                  regex.Pattern = "^" & pattern & "$"

                  If regex.Test(key) Then
                     IsInList = True
                   Exit Function
                  End If
               Else
                  If key = item Then
                     IsInList = True
                   Exit Function
                  End If
               End If
               Next
End Function

' ========================================================
' FUNCOES DE APOIO
' ========================================================
Function GetDomain(Byval addr)
   Dim atPos
   atPos = InStr(1, addr, "@")
   If atPos > 0 Then GetDomain = Mid(addr, atPos + 1) Else GetDomain = ""
End Function

Function IsLocalAddress(Byval addr)
   ' Nao precisa de LCase pois LOCAL_DOMAIN e constante
   If Right(LCase(addr), Len(LOCAL_DOMAIN) + 1) = "@" & LOCAL_DOMAIN Then IsLocalAddress = True Else IsLocalAddress = False
End Function

Sub WriteAuditLog(Byval text)
   Dim fso, f
   On Error Resume Next
   Set fso = CreateObject("Scripting.FileSystemObject")
   Set f = fso.OpenTextFile(LOG_FILE, 8, True) ' 8 = Append, True = Create
   If Err.Number = 0 Then
      f.WriteLine text
      f.Close
   Else
      Err.Clear
   End If
End Sub
