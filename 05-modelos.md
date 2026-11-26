# 05 - Modelos disponibles

El catalogo de OpenCode viene de [models.dev](https://models.dev). Cada provider expone un conjunto de modelos distinto segun como se autenticaste.

---

## 5.1 Provider `anthropic` (el que usa el orquestador)

Habilitado por el plugin `opencode-claude-auth`, con la suscripcion de Claude Code. Sin costo por token (consume la cuota de la suscripcion).

| Modelo | Contexto | Salida | Costo in/out por 1M |
|---|---|---|---|
| `anthropic/claude-opus-5-5` | 1.000.000 | 128.000 | 4 / 20 |
| `anthropic/claude-opus-5` | 1.000.000 | 128.000 | 5 / 25 |
| `anthropic/claude-opus-4-8` | 1.000.000 | 128.000 | 5 / 25 |
| `anthropic/claude-opus-4-7` | 1.000.000 | 128.000 | 5 / 25 |
| `anthropic/claude-opus-4-6` | 1.000.000 | 128.000 | 5 / 25 |
| `anthropic/claude-opus-4-5` | 200.000 | 64.000 | 5 / 25 |
| `anthropic/claude-sonnet-5-5` | 1.000.000 | 128.000 | 2 / 10 |
| `anthropic/claude-sonnet-5` | 1.000.000 | 128.000 | 2 / 10 |
| `anthropic/claude-sonnet-4-6` | 1.000.000 | 128.000 | 3 / 15 |
| `anthropic/claude-sonnet-4-5` | 200.000 | 64.000 | 3 / 15 |
| `anthropic/claude-haiku-5-5` | 1.000.000 | 128.000 | 0.1 / 0.5 |
| `anthropic/claude-haiku-4-5` | 200.000 | 64.000 | 1 / 5 |
| `anthropic/claude-fable-5-2` | 1.000.000 | 128.000 | 8 / 40 |
| `anthropic/claude-fable-5-1` | 1.000.000 | 128.000 | 10 / 50 |
| `anthropic/claude-fable-5` | 1.000.000 | 128.000 | 10 / 50 |
| `anthropic/claude-opus-4-5-20251101` | 200.000 | 64.000 | 5 / 25 |
| `anthropic/claude-sonnet-4-5-20250929` | 200.000 | 64.000 | 3 / 15 |
| `anthropic/claude-haiku-4-5-20251001` | 200.000 | 64.000 | 1 / 5 |

Los costos son de referencia (precios de lista de Anthropic). Con suscripcion el cargo real es contra la cuota de la suscripcion.

### Variantes de effort

Los modelos con razonamiento aceptan un sufijo:

```jsonc
"model": "anthropic/claude-opus-5-5#high"
```

Variantes: `#low`, `#medium`, `#high`, `#max`. En la TUI, `/models` las muestra agrupadas.

---

## 5.2 Otros providers con modelos Claude

| Provider | Modelos Claude | Como se conecta | Notas |
|---|---|---|---|
| `github-copilot` | 10 (`claude-opus-5.5`, `claude-sonnet-5.5`, `claude-haiku-5.5`, `claude-fable-5.2`...) | `opencode auth login -p github-copilot` (device OAuth) | Usa la suscripcion de GitHub Copilot. **Los IDs llevan punto**, no guion: `claude-opus-5.5` |
| `opencode` | 18 (Claude Opus 5.5, Sonnet 5.5, Haiku 5.5, Fable 5.2...) | `opencode auth login -p opencode` (API key de la consola) | Pay-as-you-go. Ver [04-troubleshooting.md](04-troubleshooting.md) punto 3 |
| `openrouter` | 20 + alias (`~anthropic/claude-opus-latest`...) | `OPENROUTER_API_KEY` | Gateway con markup |
| `amazon-bedrock` | ~80 (con variantes regionales `us.`, `eu.`, `jp.`...) | AWS credential chain | Requiere perfil AWS configurado |
| `google-vertex` | Claude via Vertex | Google ADC | Provider unico `google-vertex` |

Lista completa en cada maquina:

```powershell
opencode models anthropic
opencode models github-copilot
opencode models opencode
```

---

## 5.3 Reparto recomendado por rol de agente

| Rol | Modelo | Razon |
|---|---|---|
| Orquestador | `anthropic/claude-opus-5-5` | Razonamiento profundo para descomponer y decidir; 1M de contexto |
| Ejecutor | `minimax-03/MiniMax-M3` | Modelo interno: costo cero para la organizacion |
| Revision / critica | `anthropic/claude-opus-5#high` | Revision adversarial con effort alto |
| Exploracion / lectura | `anthropic/claude-haiku-5-5` | El mas barato (0.1 / 0.5) |

---

## 5.4 Alternativas al orquestador con Claude

Si el equipo no tiene suscripcion de Claude Code, el orquestador puede usar otro provider sin cambiar nada mas que el `model`:

| Opcion | Modelo | Requisito |
|---|---|---|
| GitHub Copilot | `github-copilot/claude-opus-5.5` | Suscripcion de Copilot, device OAuth |
| Consola OpenCode | `opencode/claude-opus-5-5` | API key de opencode.ai con creditos |
| Anthropic directo | `anthropic/claude-opus-5-5` | API key de Anthropic, **sin plugin** |

Ojo con el prefijo `anthropic/...`: sin el plugin `opencode-claude-auth`, ese provider necesita una API key de Anthropic cargada en `auth.json` con `opencode auth login -p anthropic`.
