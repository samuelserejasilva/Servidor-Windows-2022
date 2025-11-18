# 🔧 EventHandlers v3.5 - Correção de Bugs Críticos

## 📦 ARQUIVOS INCLUÍDOS

```
Servidor-Windows-2022/
│
├── EventHandlers_v3.5_CORRIGIDO.vbs     ⭐ Arquivo principal corrigido
├── APLICAR_ATUALIZACAO_v3.5.ps1         🤖 Script automatizado de instalação
├── TESTE_EventHandlers_v3.5.ps1         🧪 Script de validação/testes
├── GUIA_ATUALIZACAO_v3.5.md             📖 Guia passo a passo manual
├── RESUMO_CORRECOES_v3.5.md             📊 Resumo executivo das correções
└── README_ATUALIZACAO_v3.5.md           📄 Este arquivo
```

---

## 🚀 INSTALAÇÃO RÁPIDA (RECOMENDADO)

### **Opção 1: Instalação Automatizada** ✅ RECOMENDADO

```powershell
# Com testes e confirmações (SEGURO)
pwsh .\APLICAR_ATUALIZACAO_v3.5.ps1

# Pular testes (não recomendado)
pwsh .\APLICAR_ATUALIZACAO_v3.5.ps1 -SkipTests

# Modo não-interativo (automação completa)
pwsh .\APLICAR_ATUALIZACAO_v3.5.ps1 -AutoConfirm
```

**O que o script faz:**
1. ✅ Valida permissões de administrador
2. ✅ Executa testes automaticamente
3. ✅ Cria backup com timestamp
4. ✅ Para o serviço hMailServer
5. ✅ Substitui o arquivo
6. ✅ Reinicia o serviço
7. ✅ Valida a instalação
8. ✅ Fornece instruções de rollback

---

### **Opção 2: Instalação Manual**

Siga o guia: **GUIA_ATUALIZACAO_v3.5.md**

---

## 🐛 O QUE FOI CORRIGIDO?

### **Problema:**
Emails de domínios **BLACKLIST** estavam **ENTRANDO** na caixa de entrada.

**Exemplos:**
- ✉️ `no-reply@promovoo.xyz` (domínio `*.xyz` na blacklist)
- ✉️ `teste@econettreinamento.net.br` (na blacklist)
- ✉️ `alguem@inovti.com.br` (na blacklist)

**Log mostrava incorretamente:**
```
DECISION=10 | ALLOW_AUREA: FROM_EMAIL in whitelist
```

### **Causa:**
Dois bugs críticos no código VBScript:

1. **Bug #1:** Parâmetro `ByRef` causando corrupção de dados
2. **Bug #2:** Escape de regex malformado para wildcards

### **Solução:**
- ✅ Corrigido `ByRef` → `ByVal` (linha 235)
- ✅ Corrigido lógica de escape de regex (linhas 253-270)
- ✅ Adicionadas validações extras

**Detalhes completos:** Veja `RESUMO_CORRECOES_v3.5.md`

---

## 🧪 TESTES

### **Executar testes antes de instalar:**
```powershell
pwsh .\TESTE_EventHandlers_v3.5.ps1
```

### **Resultado esperado:**
```
🎉 TODOS OS TESTES PASSARAM!

✅ O EventHandlers v3.5 está pronto para produção!
```

**Casos de teste incluídos:**
- ✅ Emails blacklist devem ser bloqueados
- ✅ Emails whitelist devem passar
- ✅ Emails neutros devem passar
- ✅ Wildcards funcionam corretamente

---

## 📊 VALIDAÇÃO PÓS-INSTALAÇÃO

### **1. Monitorar logs:**
```powershell
Get-Content "C:\hmail-lists\logs\AureaBlack_Lists.log" -Wait -Tail 20
```

### **2. Enviar email de teste blacklist:**
- **De:** `teste@promovoo.xyz`
- **Para:** `contato@portalauditoria.com.br`
- **Esperado:** Rejeição com `550 BLOCK_BLACK: FROM_DOMAIN in blacklist`

### **3. Enviar email de teste whitelist:**
- **De:** `samuel.cereja@gmail.com`
- **Para:** `contato@portalauditoria.com.br`
- **Esperado:** Entrega com header `X-AureaBlack-Decision: ALLOW_AUREA: FROM_EMAIL in whitelist`

### **4. Verificar headers:**
Abrir email recebido e procurar por:
```
X-AureaBlack-Decision: ALLOW_AUREA: FROM_EMAIL in whitelist
```

---

## 🆘 ROLLBACK (REVERTER INSTALAÇÃO)

Se algo der errado, você pode reverter:

### **Método 1: Usando backup automático**
```powershell
# Parar serviço
Stop-Service -Name "hMailServer" -Force

# Localizar backup (na pasta C:\hmail-backup\)
Get-ChildItem "C:\hmail-backup\" | Sort-Object LastWriteTime -Descending

# Restaurar (ajuste o nome do arquivo)
Copy-Item "C:\hmail-backup\EventHandlers_v3.4_YYYYMMDD_HHMMSS.vbs" `
          "C:\Program Files (x86)\hMailServer\Events\EventHandlers.vbs" -Force

# Reiniciar serviço
Start-Service -Name "hMailServer"
```

### **Método 2: Reinstalar versão v3.4 original**
Se você tem o arquivo original, copie de volta.

---

## 📁 ESTRUTURA DE PASTAS

### **Antes da instalação:**
```
C:\Program Files (x86)\hMailServer\
└── Events\
    └── EventHandlers.vbs  (v3.4 - bugado)
```

### **Depois da instalação:**
```
C:\Program Files (x86)\hMailServer\
└── Events\
    └── EventHandlers.vbs  (v3.5 - corrigido)

C:\hmail-backup\
└── EventHandlers_v3.4_20251118_143025.vbs  (backup)

C:\hmail-lists\logs\
└── AureaBlack_Lists.log  (log do script)
```

---

## ❓ FAQ

### **Q: Preciso parar emails durante a atualização?**
**R:** Sim, o serviço hMailServer será parado por ~10 segundos durante a atualização.

### **Q: E se eu tiver customizações no EventHandlers.vbs?**
**R:** ⚠️ **CUIDADO!** O script sobrescreve o arquivo. Se você tem customizações:
1. Faça backup manual primeiro
2. Compare as versões depois
3. Reaplique suas customizações

### **Q: Como sei se a atualização funcionou?**
**R:** Envie um email de teste de domínio blacklist. Ele deve ser rejeitado com `550 BLOCK_BLACK`.

### **Q: O cache será limpo?**
**R:** Sim, ao reiniciar o hMailServer, o cache é recarregado automaticamente.

### **Q: Posso aplicar em horário comercial?**
**R:** Sim, a parada é rápida (~10 segundos). Mas recomendamos horário de baixo tráfego.

---

## 📞 SUPORTE

### **Problemas durante instalação:**
1. Verifique se está rodando como **Administrador**
2. Verifique se o serviço **hMailServer** está instalado
3. Restaure o backup se necessário
4. Consulte os logs em `C:\hmail-lists\logs\AureaBlack_Lists.log`

### **Problemas pós-instalação:**
1. Procure por `SCRIPT_ERROR` no log
2. Verifique se o cache foi recarregado (`CACHE_RELOAD`)
3. Teste manualmente enviando emails

### **Se tudo falhar:**
Restaure o backup conforme instruções de **ROLLBACK** acima.

---

## 📈 CHANGELOG

### v3.5 (18/11/2025)
- 🔧 **FIX:** Corrigido parâmetro `ByRef` → `ByVal` na função `IsInList()`
- 🔧 **FIX:** Corrigida lógica de escape de regex para wildcards
- ✨ **NEW:** Validação de chaves vazias
- ✨ **NEW:** Validação de entradas vazias no array
- 📝 **DOCS:** Adicionados comentários explicativos

### v3.4 (anterior)
- ❌ **BUG:** Parâmetro `ByRef` causando matches incorretos
- ❌ **BUG:** Escape de regex malformado

---

## ✅ CHECKLIST DE INSTALAÇÃO

- [ ] Executei como **Administrador**
- [ ] Rodei os **testes** (`TESTE_EventHandlers_v3.5.ps1`)
- [ ] Todos os testes **passaram**
- [ ] Apliquei a atualização (`APLICAR_ATUALIZACAO_v3.5.ps1`)
- [ ] Serviço hMailServer foi **reiniciado**
- [ ] Log mostra `CACHE_RELOAD: Loading lists...`
- [ ] Enviei email de teste **blacklist** → Foi **rejeitado** ✅
- [ ] Enviei email de teste **whitelist** → Foi **aceito** ✅
- [ ] Headers `X-AureaBlack-Decision` estão **corretos**

---

## 🎯 RESULTADO FINAL

**ANTES (v3.4):**
- ❌ Spam de `*.xyz`, `promovoo.xyz`, `econettreinamento.net.br` passava
- ❌ Log mostrava "in whitelist" incorretamente
- ❌ Blacklist não funcionava

**DEPOIS (v3.5):**
- ✅ Spam é bloqueado corretamente
- ✅ Log mostra decisão correta
- ✅ Blacklist funciona 100%
- ✅ Whitelist funciona 100%
- ✅ Wildcards funcionam corretamente

---

**Versão do README:** 1.0
**Data:** 18/11/2025
**Status:** ✅ PRONTO PARA PRODUÇÃO
