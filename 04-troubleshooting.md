# 04 - Troubleshooting

Todos los problemas de esta lista se encontraron durante la puesta en marcha real de este setup. Cada uno incluye la causa raiz y la solucion.

---

## 1. `opencode run "..."` devuelve `Error: Session not found`

**Sintoma**

```powershell
opencode run "explica este repositorio"
# Error: Session not found
```

**Causa**

No es un problema de configuracion. En OpenCode **1.x no existe el comando `opencode service`**: lo que se escribe despues se interpreta como el mensaje a enviar, y el comando intenta continuar una sesion que no existe.

**Solucion**

Para tareas automatizadas usar la API HTTP del servidor (ver [03-verificacion.md](03-verificacion.md) seccion 3.3) en lugar de `opencode run`.

---

## 2. Los cambios del config no se ven hasta reiniciar

**Sintoma**

Se edito `%USERPROFILE%\.config\opencode\opencode.jsonc` o el `.opencode\opencode.jsonc` del proyecto, se recarga la TUI y el agente nuevo sigue sin aparecer.

**Causa**

El servidor de OpenCode **no recarga el config global en caliente**. Tampoco el de proyecto, en el caso del servidor compartido. El config se lee cuando el proceso del servidor arranca.

**Solucion**

Reiniciar el servidor:

```powershell
# Cerrar la TUI o la app desktop y volver a abrirla
opencode

# O levantar un servidor dedicado y conectarse a ese
opencode serve --port 57556
opencode attach http://127.0.0.1:57556
```

Diagnostico: comparar lo que ve el servidor con lo que ve un proceso nuevo.

```powershell
# Un proceso NUEVO lee el config actual
opencode debug agent build

# El servidor compartido puede estar viejo
Invoke-RestMethod -Uri "http://127.0.0.1:57335/agent" -Headers @{ Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("opencode:$env:OPENCODE_SERVER_PASSWORD")))" }
```

---

## 3. Todos los modelos `opencode/*` devuelven 401 `Invalid credential`

**Sintoma**

```json
{ "error": { "type": "authentication_error", "message": "Invalid credential" } }
```

En la traza de la sesion:

```json
"error": { "name": "APIError", "data": { "statusCode": 401, "responseBody": "{\"type\":\"error\",\"error\":{\"type\":\"authentication_error\",\"message\":\"Invalid credential\"}}" } }
```

**Causa**

La credencial guardada en `%USERPROFILE%\.local\share\opencode\auth.json` esta corrupta. En este caso concreto era:

```json
{ "opencode": { "type": "api", "key": "/models" } }
```

Siete caracteres, el string `/models`, no una API key.

**Por que es confuso**

El catalogo de modelos de la consola OpenCode es **publico**:

```powershell
curl.exe -s -o NUL -w "HTTP:%{http_code}" "https://opencode.ai/inference/v1/models"
# HTTP:200  <- sin ninguna credencial
```

Por eso `opencode models opencode` listaba 40+ modelos aunque la key estuviera rota: la lista viene del catalogo, no de tu credencial. Solo falla al inferir.

**Solucion**

```powershell
# Detectar
(Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json" -Raw | ConvertFrom-Json).opencode

# Validar una key
$key = (Get-Content "$env:USERPROFILE\.local\share\opencode\auth.json" -Raw | ConvertFrom-Json).opencode.key
curl.exe -s -w "`nHTTP:%{http_code}`n" "https://opencode.ai/inference/v1/models" -H "Authorization: Bearer $key"
# 200 = valida   401 = invalida o corrupta

# Reemplazar
opencode auth login -p opencode
```

---

## 4. El plugin avisa `Claude credentials are expired and could not be refreshed`

**Sintoma**

Al arrancar OpenCode:

```
opencode-claude-auth: Claude credentials are expired and could not be refreshed. Run `claude` to re-authenticate.
```

y despues `opencode models anthropic` devuelve `Error: Provider not found: anthropic`.

**Causa**

La sesion OAuth de Claude Code caduco. En `%USERPROFILE%\.claude\.credentials.json`:

| Campo | Valor vencido |
|---|---|
| `accessToken` | cadena vacia |
| `refreshToken` | cadena vacia |
| `refreshTokenExpiresAt` | fecha ya pasada |

**Solucion**

```powershell
claude auth login --claudeai
claude auth status   # debe decir loggedIn: true
```

El proceso abre el navegador; en las pruebas el codigo se pegó solo y terminó con `Login successful.`.

---

## 5. El orquestador no debe usar `opencode/...` sino `anthropic/...`

**Sintoma**

Con `agent.build.model = "opencode/claude-opus-5-5"` el modelo existe en el catalogo pero cualquier llamada devuelve 401.

**Causa**

Dos motivos encadenados:

1. El plugin `opencode-claude-auth` intercepta las peticiones cuyo `providerID` es exactamente `anthropic`. Si el modelo esta en `opencode/`, el plugin no interviene.
2. El provider `opencode` usa la API key de la consola OpenCode (pay-as-you-go), que es distinta de tu suscripcion de Claude Code.

**Solucion**

Usar el prefijo `anthropic`:

```jsonc
"model": "anthropic/claude-opus-5-5"
```

Con el plugin instalado, el provider `anthropic` usa tu OAuth de Claude Code. Ver [05-modelos.md](05-modelos.md) para las alternativas.

---

## 6. El plugin no carga: `opencode-claude-auth@latest` instala la version equivocada

**Sintoma**

`opencode models anthropic` no lista nada y no aparece ningun aviso del plugin. En los logs:

```
opencode-claude-auth: ...
```

no aparece, y el cache tiene `opencode-claude-auth@3.x`.

**Causa**

La v3 del plugin **exige OpenCode 2.0+** y no se carga en 1.x. Como `@latest` instala la v3, el plugin nunca llega a ejecutarse.

**Solucion**

Fijar la version:

```jsonc
"plugin": ["opencode-claude-auth@2.2.1"]
```

| Version | OpenCode requerido | Clave de config |
|---|---|---|
| 2.2.1 e anteriores | 1.x | `plugin` |
| 3.0.0 en adelante | 2.0+ | `plugins` |

Si queda una version vieja cacheada, borrarla y reiniciar:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.cache\opencode\packages\opencode-claude-auth@latest"
```

---

## 7. El device auth de GitHub Copilot via API falla con 500

**Sintoma**

```powershell
POST http://127.0.0.1:57335/provider/github-copilot/oauth/callback
# {"name":"UnknownError","data":{"message":"Unexpected server error..."}}
```

**Causa**

Bug de OpenCode 1.x en ese camino. El flujo por API no es confiable para este provider.

**Solucion**

Usar el CLI, que si funciona:

```powershell
opencode auth login -p github-copilot
```

El prompt pide el tipo de despliegue (GitHub.com / GitHub Enterprise). Ver punto 8 para responderlo automaticamente.

---

## 8. La TUI ignora la entrada estandar redirigida

**Sintoma**

Al lanzar `opencode auth login -p github-copilot` con stdin redirigido desde un archivo, la TUI se queda mostrando el prompt de seleccion sin avanzar.

**Causa**

La TUI lee de la consola, no de un archivo redirigido. Necesita una pulsacion de teclado real.

**Solucion**

Enviar la tecla con `WScript.Shell` (Windows):

```powershell
$inFile = "$env:TEMP\opencode-in.txt"
Set-Content -Path $inFile -Value "" -NoNewline
$out = "$env:TEMP\opencode-login.log"

$p = Start-Process -FilePath "opencode" -ArgumentList "auth","login","-p","github-copilot" `
    -RedirectStandardInput $inFile -RedirectStandardOutput $out -PassThru

Start-Sleep -Seconds 6
$ws = New-Object -ComObject WScript.Shell
$null = $ws.AppActivate($p.Id)
Start-Sleep -Milliseconds 800
$ws.SendKeys("{ENTER}")
```

La salida del log muestra el codigo del device flow y la URL para autorizarlo.

---

## 9. `Start-Process` con `opencode.exe` falla

**Sintoma**

```powershell
Start-Process -FilePath "...\opencode-ai\bin\opencode.exe" -ArgumentList "serve","--port","57556"
# Start-Process : El ejecutable especificado no es una aplicacion valida para esta plataforma de sistema operativo.
```

**Causa**

El binario de OpenCode ronda los 213 MB y falla al lanzarse de esa forma con `-WindowStyle Hidden` en esta version de Windows.

**Solucion**

Usar `cmd /c start /b`, que lo deja desacoplado:

```powershell
cmd /c 'start /b "" opencode serve --port 57556'
```

---

## 10. La API del servidor responde 401

**Sintoma**

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:57335/agent"
# No se puede conectar / 401 No autorizado
```

**Causa**

La API exige autenticacion basica. Las credenciales estan en variables de entorno que define el propio OpenCode.

**Solucion**

```powershell
$pair = "opencode:$env:OPENCODE_SERVER_PASSWORD"
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
$h = @{ Authorization = "Basic $b64" }
Invoke-RestMethod -Uri "http://127.0.0.1:57335/agent" -Headers $h
```

Si `OPENCODE_SERVER_PASSWORD` no esta definida en la shell actual, exportarla desde el entorno donde corre el desktop.

---

## 11. `ConvertFrom-Json` falla al parsear la salida de opencode

**Sintoma**

```powershell
$o = opencode debug agent build 2>&1 | Out-String
$o | ConvertFrom-Json
# Primitivo JSON no valido: opencode.exe.
```

**Causa**

En PowerShell 5.1, `2>&1` fusiona el stream de error, que lleva el prefijo `opencode.exe :` de las wrappers `.ps1` de npm. Ese texto queda dentro del JSON y rompe el parseo.

**Solucion**

Capturar solo stdout:

```powershell
$o = opencode debug agent build 2>$null | Out-String
$j = $o | ConvertFrom-Json
```

---

## 12. El ejecutor sigue teniendo la tool `task` activa

**Sintoma**

El ejecutor puede lanzar subagentes y se produce una cadena de delegaciones.

**Causa**

`tools` hace **merge** con los defaults, no reemplazo. Si se define `tools` con `task: false` explicito, la tool se apaga y el resto se conserva.

**Solucion**

```jsonc
"tools": { "task": false }
```

Comprobar el resultado:

```powershell
$j = (opencode debug agent ejecutor 2>$null | Out-String) | ConvertFrom-Json
$j.tools | ConvertTo-Json
```

Esperado: `bash`, `read`, `glob`, `grep`, `edit`, `write`, `webfetch` en `true`; `task` y `question` en `false`.

---

## 13. El plugin `opencode-claude-auth` queda instalado pero sin usarse

**Sintoma**

El cache tiene el paquete pero el provider `anthropic` no aparece.

**Solucion**

Confirmar que el bloque `plugin` (singular en 1.x) esta en el config global y que la version esta fijada. Ver punto 6.

---

## 14. El script de verificacion marca el provider `opencode` como corrupto

**Sintoma**

```
[FALLA] provider 'opencode': key suspecta de corrupta (7 chars, valor: '/models')
```

**Causa**

Es una deteccion real, no un falso positivo: el script marca cualquier key de menos de 10 caracteres. Si ese provider no se usa, se puede borrar la entrada del `auth.json` para que no genere ruido:

```powershell
$path = "$env:USERPROFILE\.local\share\opencode\auth.json"
$auth = Get-Content $path -Raw | ConvertFrom-Json
$auth.PSObject.Properties.Remove("opencode")
$auth | ConvertTo-Json -Depth 10 | Set-Content $path
```

---

## 15. La auto-actualizacion de OpenCode deja el CLI fuera del PATH

**Sintoma**

```
opencode : El termino 'opencode' no se reconoce como nombre de un cmdlet, funcion,
           archivo de script o programa ejecutable.
```

y `where.exe opencode` no encuentra nada, aunque `%APPDATA%\npm` exista en el PATH.

**Causa**

Opencode se auto-actualiza en segundo plano. Durante la actualizacion desinstala el paquete npm `opencode-ai` y lo reinstala; si el proceso se corta en medio (o se cierra la app mientras actualiza), los wrappers `opencode.cmd` y `opencode.ps1` quedan borrados y el comando desaparece del PATH.

Pasó en este equipo: la version paso de 1.16.2 a 1.19.6 a mitad de sesion y el paquete quedo sin instalar.

**Diagnostico**

```powershell
Get-ChildItem "$env:APPDATA\npm" -Filter "opencode*"
Test-Path "$env:APPDATA\npm\node_modules\opencode-ai"
```

**Solucion**

Reinstalar **fijando la rama 1.x**, porque `latest` instalaria la 2.x, que usa otra sintaxis de configuracion:

```powershell
npm install -g opencode-ai@1
opencode --version
```

El rango `@1` instala la ultima version 1.x (por ejemplo 1.19.6) y deja la configuracion de este documento intacta.

Si la auto-actualizacion vuelve a romper la instalacion, se puede desactivar. Revisar las opciones de actualizacion con:

```powershell
opencode upgrade --help
```

