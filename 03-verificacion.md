# 03 - Verificacion

La verificacion se hace por capas. Cada capa comprueba una dependencia de la anterior.

| Capa | Que comprueba | Comando |
|---|---|---|
| 1 | Versiones instaladas | `opencode --version`, `claude --version` |
| 2 | Claude Code autenticado | `claude auth status` |
| 3 | Credenciales en `auth.json` sanas | `scripts\verify-opencode.ps1` |
| 4 | Config global valida y con los dos agentes | `opencode debug agent build` |
| 5 | Provider `anthropic` registrado por el plugin | `opencode models anthropic` |
| 6 | Delegacion real funcionando | `scripts\test-delegacion.ps1 -Port <puerto>` |

---

## 3.1 Script de diagnostico

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\verify-opencode.ps1"
```

Es de **solo lectura**. Imprime el resultado de cada comprobacion con `[OK]`, `[FALLA]` o `[--]`, y termina con:

```
RESULTADO: OK - N verificaciones correctas
```

o

```
RESULTADO: N problema(s) detectado(s):
  - <descripcion del problema>
```

| Codigo de salida | Significado |
|---|---|
| 0 | Todo correcto |
| 1 | Hay problemas: cada linea los describe y remite a [04-troubleshooting.md](04-troubleshooting.md) |

---

## 3.2 Verificacion capa por capa (comandos manuales)

### Capa 1 - Versiones

```powershell
opencode --version
claude --version
```

`opencode --version` debe empezar con `1.`. Con 2.x la sintaxis de config es otra (ver [02-configuracion.md](02-configuracion.md)).

### Capa 2 - Claude Code autenticado

```powershell
claude auth status
```

```json
{ "loggedIn": true, "authMethod": "claude.ai", ... }
```

Si `loggedIn` es `false`, el orquestador no va a poder llamar a Claude.

### Capa 3 - Credenciales de OpenCode

```powershell
Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json" -Raw
```

Debe haber tres entradas:

| Provider | `type` | Que es |
|---|---|---|
| `anthropic` | `oauth` | La crea el plugin `opencode-claude-auth` a partir de Claude Code |
| `minimax-03` | `api` | API key del modelo interno (`sk-...`) |
| `opencode` | `api` | Opcional. Si esta, la key debe ser real; una key corta o corrupta rompe **todos** los modelos `opencode/*` |

Validar una key de la consola OpenCode (200 = valida, 401 = invalida):

```powershell
$key = (Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json" -Raw | ConvertFrom-Json).opencode.key
curl.exe -s -w "`nHTTP:%{http_code}`n" "https://opencode.ai/inference/v1/models" -H "Authorization: Bearer $key"
```

### Capa 4 - Config cargada

```powershell
opencode debug agent build
opencode debug agent ejecutor
```

Verificar `mode`, `model` y (en el ejecutor) que `task` sea `false`.

### Capa 5 - Provider de Claude

```powershell
opencode models anthropic
```

Debe listar `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5`, `anthropic/claude-haiku-5-5` y demas.

Si devuelve `Error: Provider not found: anthropic`, el plugin no cargo o las credenciales de Claude Code estan vencidas. Ver [04-troubleshooting.md](04-troubleshooting.md) puntos 4, 5 y 6.

### Capa 6 - Delegacion real (la importante)

Requiere un servidor de OpenCode escuchando. Para pruebas, levantar uno dedicado:

```powershell
opencode serve --port 57556
```

Y en otra terminal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\test-delegacion.ps1" -Port 57556
```

El script crea una sesion, envia un prompt que obliga a delegar y revisa la traza. Salida esperada:

```
--- Traza ---
[msg] role=user agent=build model=/
[msg] role=assistant agent=build model=anthropic/claude-opus-5-5
   [tool] task status=completed subagent_type=ejecutor
   [out] <task_result> ... salida: test-delegacion-ok ...
[msg] role=assistant agent=build model=anthropic/claude-opus-5-5
   [text] Recibi el reporte del ejecutor y la delegacion funciono.

RESULTADO: OK - delegacion detectada (tool task -> subagent_type=ejecutor, status=completed)
```

| Codigo de salida | Significado |
|---|---|
| 0 | La delegacion funciona |
| 1 | El orquestador no invoco la tool `task`, o la invoco con otro `subagent_type` |

---

## 3.3 Como se accede a la API del servidor (para scripts propios)

El servidor de OpenCode expone una API HTTP que exige autenticacion basica con las variables de entorno que el propio opencode define:

| Variable | Valor por defecto |
|---|---|
| `OPENCODE_SERVER_USERNAME` | `opencode` |
| `OPENCODE_SERVER_PASSWORD` | UUID generado en cada instalacion |

```powershell
$pair = "opencode:$env:OPENCODE_SERVER_PASSWORD"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$h = @{ Authorization = "Basic $b64" }
```

Ver la password:

```powershell
(Get-ChildItem Env: | Where-Object { $_.Name -like "OPENCODE*" }).Value
```

Endpoints utiles:

| Endpoint | Metodo | Para que sirve |
|---|---|---|
| `/agent` | GET | Agentes cargados, con su modelo resuelto |
| `/session` | POST | Crear sesion |
| `/session/{id}/message` | POST | Enviar mensaje (body: `{"parts":[{"type":"text","text":"..."}],"model":{"providerID":"...","modelID":"..."}}`) |
| `/session/{id}/message` | GET | Traza completa de la sesion (mensajes y parts) |
| `/doc` | GET | OpenAPI: sirve para descubrir endpoints y schemas |
| `/provider/auth` | GET | Metodos de autenticacion disponibles por provider |
| `/provider/{id}/oauth/authorize` | POST | Iniciar OAuth (body: `{"method":<indice>,"inputs":{...}}`) |
| `/provider/{id}/oauth/callback` | POST | Completar OAuth (body: `{"method":<indice>,"code":"..."}`) |
