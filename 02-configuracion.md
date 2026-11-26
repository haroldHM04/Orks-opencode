# 02 - Configuracion

Hay **dos** archivos de configuracion. Se mergean: el global aporta los providers y el plugin, el del proyecto aporta los agentes.

| Ubicacion | Que aporta |
|---|---|
| `%USERPROFILE%\.config\opencode\opencode.jsonc` | Providers (incluido el interno CUN), plugin, y tambien los agentes |
| `<PROYECTO>\.opencode\opencode.jsonc` | Solo los agentes, aplicados a ese proyecto |

Las plantillas exactas y listas para copiar estan en `plantilla/`.

---

## 2.1 Sintaxis: OpenCode 1.x es diferente de 2.x

Este es el error mas comun al replicar el setup. **OpenCode 1.x** usa:

| Que | Clave en 1.x | Clave en 2.x |
|---|---|---|
| Plugins | `"plugin": [...]` | `"plugins": [...]` |
| Agentes | `"agent": { ... }` | `"agents": { ... }` |
| System prompt del agente | `"prompt": "..."` | `"system": "..."` |
| Modelo | `"model": "provider/model"` | igual |
| Modo | `"mode": "primary" \| "subagent" \| "all"` | igual |
| Tools | `"tools": { "task": false }` | igual |

Los archivos van en formato **JSONC**: se admiten comentarios `//`, pero el archivo debe llamarse `.jsonc` (no `.json`) para que OpenCode los parsee.

---

## 2.2 Config global

`%USERPROFILE%\.config\opencode\opencode.jsonc`

Estructura completa (los prompts van verbatim; la version con comentarios esta en `plantilla/opencode.jsonc.global`):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",

  "disabled_providers": [
    "minimax-fabrica",
    "minimax-m27-highspeed-text",
    "cun"
  ],

  "plugin": ["opencode-claude-auth@2.2.1"],

  "provider": {
    "minimax-03": {
      "name": "MiniMax-M3",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "baseURL": "https://glm.cunapp.pro/v1",
        "headers": {
          "fabrica": "Minimax-03"
        }
      },
      "models": {
        "MiniMax-M3": {
          "name": "MiniMax-M3"
        }
      }
    }
  },

  "agent": {
    "build": {
      "description": "Orquestador: planifica, descompone y delega la implementacion y las verificaciones al subagente `ejecutor` (MiniMax-M3).",
      "mode": "primary",
      "model": "anthropic/claude-opus-5-5",
      "prompt": "Eres el ORQUESTADOR de este proyecto. Tu trabajo es pensar, planear, descomponer y decidir. No implementas tu mismo.\n\nFlujo obligatorio:\n1. Analiza la solicitud del usuario y descomp\u00f3nla en tareas concretas e independientes.\n2. Delega CADA tarea de implementacion al subagente `ejecutor` usando la tool `task` con `subagent_type: \"ejecutor\"`.\n3. Espera el reporte del subagente y rev\u00edsalo. Si reporta errores, trabajo incompleto o ambig\u00fedades, reasigna la tarea con instrucciones m\u00e1s precisas.\n4. Verifica la coherencia global del resultado (integraci\u00f3n entre tareas, alcance completo) antes de cerrar.\n\nEl subagente `ejecutor` corre con MiniMax-M3 y se encarga de escribir el c\u00f3digo, ejecutar la implementaci\u00f3n y correr las verificaciones (tests, lint, typecheck, build).\n\nReglas:\n- Delega siempre la implementaci\u00f3n; no escribas c\u00f3digo ni corras comandos de verificaci\u00f3n tu mismo.\n- Edita archivos t\u00fa mismo solo si el ejecutor reporta un bloqueo que no puede resolver.\n- Si una tarea es trivial o de un solo archivo, del\u00e9gala igual: mantener el reparto de roles es la prioridad.\n- Al final, reporta al usuario qu\u00e9 delegaste, qu\u00e9 verificaciones corrieron y su resultado."
    },
    "ejecutor": {
      "description": "Ejecutor: implementa el codigo que le asigna el orquestador y realiza las verificaciones (tests, lint, typecheck, build).",
      "mode": "subagent",
      "model": "minimax-03/MiniMax-M3",
      "tools": { "task": false },
      "prompt": "Eres el AGENTE EJECUTOR. Recibes una tarea del orquestador y la llevas a cabo de punta a punta.\n\nResponsabilidades:\n1. Leer el contexto y los archivos relevantes antes de tocar nada.\n2. Implementar el cambio completo, siguiendo las convenciones y el estilo del repositorio.\n3. Ejecutar las verificaciones disponibles en el repositorio (tests, lint, typecheck, build) y corregir los fallos que t\u00fa hayas causado.\n4. Entregar un reporte final estructurado con:\n   - Qu\u00e9 cambiaste: archivos y l\u00edneas relevantes.\n   - Qu\u00e9 verificaciones ejecutaste y su resultado exacto (comandos y salida resumida).\n   - Qu\u00e9 qued\u00f3 pendiente, bloqueado o es ambiguo.\n\nReglas:\n- No replantees el alcance ni propongas alternativas al orquestador: implementa lo pedido.\n- Si el alcance es ambiguo, implementa la interpretaci\u00f3n m\u00e1s razonable y se\u00f1ala la ambig\u00faded en el reporte final.\n- Si una verificaci\u00f3n falla por una causa no relacionada con tu cambio, no la arregles: rep\u00f3rtala como preexistente.\n- Nunca delegues a otro subagente: ejecutas t\u00fa."
    }
  }
}
```

### Campo por campo

| Campo | Valor | Por que |
|---|---|---|
| `plugin` | `["opencode-claude-auth@2.2.1"]` | Registra el provider `anthropic` con el OAuth de Claude Code. **Fijar la version**: la v3 exige OpenCode 2.0+ |
| `provider.minimax-03.npm` | `@ai-sdk/openai-compatible` | El endpoint interno habla el formato OpenAI |
| `provider.minimax-03.options.baseURL` | `https://glm.cunapp.pro/v1` | Endpoint del modelo interno. Cambiar por equipo |
| `provider.minimax-03.options.headers` | `{ "fabrica": "Minimax-03" }` | Cabeceras que exige el endpoint. Cambiar por equipo |
| `agent.build.mode` | `primary` | Es el agente principal de la sesion |
| `agent.build.model` | `anthropic/claude-opus-5-5` | El orquestador. **Debe ser `anthropic/...`**, no `opencode/...` (ver [04-troubleshooting.md](04-troubleshooting.md) punto 5) |
| `agent.ejecutor.mode` | `subagent` | Solo se invoca desde otro agente, nunca es el principal |
| `agent.ejecutor.model` | `minimax-03/MiniMax-M3` | El ejecutor |
| `agent.ejecutor.tools` | `{ "task": false }` | Le quita la tool `task` para que no delegue recursivamente. **Es un merge, no un reemplazo**: conserva `bash`, `read`, `glob`, `grep`, `edit`, `write`, `webfetch`; pierde `task` y `question` |

### Los prompts

El prompt del orquestador define el contrato de trabajo: no programa, delega cada tarea al `ejecutor` con `subagent_type: "ejecutor"`, revisa el reporte y reasigna si hace falta.

El prompt del ejecutor define el entregable: leer, implementar, verificar, y devolver un reporte con **que cambio**, **que verificaciones corro y con que resultado**, y **que quedo pendiente**.

El nombre `ejecutor` es un contrato: el orquestador lo nombra en su prompt y lo busca por `subagent_type`. Si se renombra el agente, hay que actualizar los dos prompts.

---

## 2.3 Config del proyecto

`<PROYECTO>\.opencode\opencode.jsonc`

Mismo bloque `agent`, sin providers ni plugin (se heredan del global):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "agent": { ... }
}
```

El archivo completo esta en `plantilla/opencode.jsonc.proyecto`.

---

## 2.4 Comprobar que la config se cargo

```powershell
opencode debug agent build
opencode debug agent ejecutor
```

Cada uno imprime la configuracion resuelta. Lo esperado:

```
name        : build
mode        : primary
model       : @{providerID=anthropic; modelID=claude-opus-5-5}
```

```
name        : ejecutor
mode        : subagent
model       : @{providerID=minimax-03; modelID=MiniMax-M3}
```

Para ver las tools del ejecutor, en la salida de `opencode debug agent ejecutor` debe aparecer:

```json
{ "invalid": true, "question": false, "bash": true, "read": true, "glob": true,
  "grep": true, "edit": true, "write": true, "task": false, "webfetch": true, ... }
```

> En PowerShell 5.1, `opencode debug agent build 2>&1 | Out-String` mete el prefijo `opencode.exe :` de stderr en medio del JSON y rompe `ConvertFrom-Json`. Capturar solo stdout: `opencode debug agent build 2>$null | Out-String`.
