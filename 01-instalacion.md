# 01 - Instalacion y autenticacion

Todos los comandos son de PowerShell 5.1. Si una ruta tiene espacios, entrecomillala.

---

## 1.1 Prerrequisitos

| Componente | Version | Como se instala |
|---|---|---|
| OpenCode | **1.x** | `opencode upgrade` (ya instalado en el equipo) |
| Claude Code CLI | 2.x | `npm install -g @anthropic-ai/claude-code` |
| Node.js | 18 o superior | `winget install OpenJS.NodeJS.LTS` |

Comprobar:

```powershell
opencode --version
claude --version
```

Si `opencode --version` devuelve algo que no empieza con `1.`, la sintaxis de configuracion de este documento no aplica. Ver [02-configuracion.md](02-configuracion.md).

---

## 1.2 Autenticar Claude Code (orquestador)

El orquestador usa Claude a traves de la suscripcion de Claude Code, sin API key de Anthropic.

```powershell
claude auth login --claudeai
```

El comando abre el navegador en el login de Anthropic. En las pruebas realizadas **el codigo de autorizacion se pega solo** y el proceso termina con `Login successful.` Si el navegador no se abre, el comando imprime la URL para pegar a mano.

Verificar:

```powershell
claude auth status
```

Salida esperada:

```json
{
  "loggedIn": true,
  "authMethod": "claude.ai",
  ...
}
```

Las credenciales quedan en `%USERPROFILE%\.claude\.credentials.json`. Ese archivo es el que lee el plugin `opencode-claude-auth` para obtener el token.

> Si `loggedIn` es `false` o el `accessToken` esta vacio, el plugin va a avisar `Claude credentials are expired and could not be refreshed`. Ver [04-troubleshooting.md](04-troubleshooting.md) punto 4.

---

## 1.3 Conectar el provider interno (ejecutor)

El ejecutor usa el modelo interno de Fabrica CUN, un endpoint OpenAI-compatible.

```powershell
opencode auth login -p minimax-03
```

Ingresar la API key (`sk-...`) cuando la pida. Queda guardada en `%USERPROFILE%\.local\share\opencode\auth.json` con el campo `type: "api"`.

Alternativa si el equipo usa variables de entorno: el provider `minimax-03` acepta la variable `ANTHROPIC_API_KEY` no aplica, pero cualquier providercustom acepta `env`. Ver la documentacion de providers de OpenCode.

Comprobar:

```powershell
opencode models minimax-03
```

Debe listar `minimax-03/MiniMax-M3`.

---

## 1.4 Instalar el plugin que habilita Claude en OpenCode

El plugin `opencode-claude-auth` registra el provider `anthropic` en OpenCode usando el OAuth de Claude Code. Sin el, `anthropic/claude-opus-5-5` no existe como modelo.

Se instala **agregandolo al bloque `plugin` del config global** (ver [02-configuracion.md](02-configuracion.md)):

```jsonc
"plugin": ["opencode-claude-auth@2.2.1"]
```

En OpenCode 1.x no hace falta `npm install`: al arrancar, OpenCode autoinstala los plugins npm con Bun y los deja en `%USERPROFILE%\.cache\opencode\packages\`.

> **Importante: fijar la version.** La v3 del plugin exige OpenCode 2.0+ y no carga en 1.x. `@latest` instala la v3. Hay que escribir `opencode-claude-auth@2.2.1`.

Comprobar que el plugin cargo (el aviso de credenciales vencidas indica que el plugin esta vivo):

```powershell
opencode models anthropic
```

Si lista `anthropic/claude-opus-5-5` y similares, el plugin quedo bien instalado y con credenciales validas.

---

## 1.5 Copiar la configuracion

```powershell
$global = Join-Path $env:USERPROFILE ".config\opencode"
New-Item -ItemType Directory -Path $global -Force | Out-Null
Copy-Item ".\plantilla\opencode.jsonc.global" (Join-Path $global "opencode.jsonc") -Force
```

Luego ajustar en el archivo copiado:

1. `provider.minimax-03.options.baseURL` -> el endpoint del modelo interno de su equipo
2. `provider.minimax-03.options.headers` -> las cabeceras que exija ese endpoint
3. `agent.build.model` -> el modelo del orquestador
4. `agent.ejecutor.model` -> el modelo del ejecutor

Opcionalmente, en cada proyecto:

```powershell
New-Item -ItemType Directory -Path ".\.opencode" -Force | Out-Null
Copy-Item ".\plantilla\opencode.jsonc.proyecto" ".\.opencode\opencode.jsonc" -Force
```

---

## 1.6 Reiniciar OpenCode

El servidor de OpenCode **no recarga el config global en caliente**. Hay que reiniciarlo.

Opciones:

```powershell
# Opcion A: cerrar la TUI / la app desktop y volver a abrirla
opencode

# Opcion B: servidor dedicado en otro puerto y cliente conectado a ese
opencode serve --port 57556
opencode attach http://127.0.0.1:57556
```

La opcion B es util para hacer pruebas sin tocar la sesion de trabajo.

---

## 1.7 Verificar

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\verify-opencode.ps1"
```

Debe terminar con `RESULTADO: OK`. Si no, ir a [04-troubleshooting.md](04-troubleshooting.md).
