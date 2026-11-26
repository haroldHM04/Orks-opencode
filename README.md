# Orquestador + Ejecutor en OpenCode

Configuracion replicable para OpenCode **1.x** con dos agentes que se complementan:

| Agente | Modo | Modelo | Rol |
|---|---|---|---|
| `build` | `primary` | `anthropic/claude-opus-5-5` | **Orquestador**: piensa, planifica, descompone, decide y delega. No escribe codigo. |
| `ejecutor` | `subagent` | `minimax-03/MiniMax-M3` | **Ejecutor**: implementa el codigo y corre las verificaciones (tests, lint, typecheck, build). |

El orquestador usa la **suscripcion de Claude Code** (sin API key de Anthropic) y el ejecutor usa el **modelo interno de Fabrica CUN**.

---

## Que logra

Un unico agente (Claude Opus 5.5) hace todo el trabajo de pensar y decide que portions de la tarea se ejecutan de forma concreta; esas porciones las implementa un segundo agente (MiniMax-M3) que devuelve un reporte estructurado con los archivos modificados y las verificaciones ejecutadas. El orquestador revisa ese reporte y reasigna si hace falta.

```
    Usuario
       |
       v
  +-------------+
  |   build     |  Claude Opus 5.5   <- decide, no programa
  | (orquestador)|
  +--+---+---+
     |   |
     |   +--> tool "task"  (subagent_type: "ejecutor")
     |              |
     |              v
     |        +-----------+   MiniMax-M3
     |        | ejecutor  |   <- implementa + verifica
     |        +-----------+
     |              |
     |              v
     |        reporte estructurado
     |        (cambios + verificaciones)
     |
     +--> revisa el reporte
              |
              v
         respuesta al usuario
```

---

## Documentacion

| Archivo | Contenido |
|---|---|
| [01-instalacion.md](01-instalacion.md) | Prerrequisitos, instalacion y autenticacion (OpenCode, Claude Code, provider CUN, plugin) |
| [02-configuracion.md](02-configuracion.md) | Los dos archivos de configuracion, campo por campo, y diferencias entre OpenCode 1.x y 2.x |
| [03-verificacion.md](03-verificacion.md) | Como comprobar que todo quedo bien, por capas, con scripts incluidos |
| [04-troubleshooting.md](04-troubleshooting.md) | Errores reales encontrados durante la puesta en marcha y su solucion |
| [05-modelos.md](05-modelos.md) | Catalogo de modelos Claude disponibles por provider, con contexto y costos |

### Plantillas y scripts

```
plantilla/
  opencode.jsonc.global     <- config global, listo para copiar
  opencode.jsonc.proyecto   <- config por proyecto, listo para copiar
scripts/
  verify-opencode.ps1       <- diagnostico de solo lectura (exit 0 = OK, 1 = problemas)
  test-delegacion.ps1       <- prueba real de la delegacion contra un servidor (exit 0 = OK)
```

---

## Checklist de replicacion en otro equipo

- [ ] 1. Instalar OpenCode 1.x y Claude Code CLI (ver [01-instalacion.md](01-instalacion.md))
- [ ] 2. Autenticar Claude Code: `claude auth login --claudeai`
- [ ] 3. Conectar el provider interno: `opencode auth login -p minimax-03` (API key `sk-...`)
- [ ] 4. Copiar `plantilla/opencode.jsonc.global` a `%USERPROFILE%\.config\opencode\opencode.jsonc` y ajustar baseURL / headers / modelos
- [ ] 5. Copiar `plantilla/opencode.jsonc.proyecto` a `<PROYECTO>\.opencode\opencode.jsonc` (opcional)
- [ ] 6. Reiniciar OpenCode (el config global no se recarga en caliente)
- [ ] 7. Ejecutar `scripts\verify-opencode.ps1` hasta obtener `RESULTADO: OK`
- [ ] 8. Probar la delegacion: `scripts\test-delegacion.ps1 -Port <puerto>`

### Tiempo estimado

| Paso | Tiempo |
|---|---|
| Instalacion y autenticacion | 15 min (incluye login en el navegador) |
| Configuracion | 10 min |
| Verificacion | 5 min |

---

## Requisitos previos

- Windows con PowerShell 5.1 o superior
- Node.js y npm (para instalar Claude Code CLI)
- **OpenCode 1.x**. Este setup usa la sintaxis de configuracion de 1.x. En 2.x cambian las claves (ver [02-configuracion.md](02-configuracion.md))
- Una suscripcion activa de Claude Code (o Claude.ai) para el orquestador
- Una API key del modelo interno (Fabrica CUN) para el ejecutor

---

## Como se usa en la practica

1. Abrir `opencode` en el proyecto.
2. El agente por defecto es `build`, o sea el orquestador.
3. Escribir el pedido con normalidad. El orquestador decide si delega.
4. En pantalla se ve la tool `task` con su propio progreso y el reporte del ejecutor anidado.
5. Al final responde el orquestador con el resultado global.

Comandos utiles:

| Comando | Para que sirve |
|---|---|
| `/agents` | Listar los agentes disponibles y cambiar de agente |
| `Tab` | Ciclar entre agentes en la TUI |
| `opencode agent list` | Listar agentes desde la terminal |
| `opencode agent create` | Crear un agente nuevo de forma interactiva |
| `opencode models anthropic` | Ver los modelos Claude disponibles |
| `opencode debug agent build` | Ver la configuracion resuelta de un agente |
