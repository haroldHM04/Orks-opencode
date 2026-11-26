<#
    test-delegacion.ps1
    -----------------------------------------------------------------------------
    Prueba real end-to-end de la delegacion: orquestador (build) -> ejecutor.
    Levanta una sesion contra un servidor opencode, envia un prompt que obliga a
    delegar y verifica en la traza que aparezca la tool 'task' con
    subagent_type = "ejecutor" y estado completado.

    Requisitos:
      - Un servidor opencode escuchando (por ejemplo: opencode serve --port 57556)
      - Variable de entorno OPENCODE_SERVER_PASSWORD (la exporta el propio opencode)
      - Las credenciales del provider del ejecutor cargadas en auth.json

    Uso:
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\test-delegacion.ps1" -Port 57556

    Codigo de salida:
        0 = delegacion detectada correctamente
        1 = fallo (se explica al final)
#>

param(
    [int]$Port = 57556,
    [string]$Host_ = "127.0.0.1",
    [string]$ModeloOrquestador = "",
    [string]$ModeloEjecutor = ""
)

$ErrorActionPreference = "Continue"

# Si no se pasan modelos, se deduce del config global.
if (-not $ModeloOrquestador -or -not $ModeloEjecutor) {
    $cfgPath = Join-Path $env:USERPROFILE ".config\opencode\opencode.jsonc"
    if (Test-Path $cfgPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($cfgPath)
            $clean = (($raw -split "`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
            $cfg = $clean | ConvertFrom-Json
            if (-not $ModeloOrquestador) {
                $m = $cfg.agent.build.model
                if ($m -match "/") { $partes = $m -split "/"; $ModeloOrquestador = "$($partes[0])/$($partes[1])" }
            }
            if (-not $ModeloEjecutor) {
                $m2 = $cfg.agent.ejecutor.model
                if ($m2 -match "/") { $partes2 = $m2 -split "/"; $ModeloEjecutor = "$($partes2[0])/$($partes2[1])" }
            }
        } catch {
            Write-Host "No se pudo leer el config global: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "=== Test de delegacion contra $Host_`:$Port ===" -ForegroundColor Cyan
Write-Host "  Orquestador: $ModeloOrquestador"
Write-Host "  Ejecutor   : $ModeloEjecutor"
Write-Host ""

$base = "http://${Host_}:$Port"
$password = $env:OPENCODE_SERVER_PASSWORD
if (-not $password) {
    Write-Host "Falta la variable OPENCODE_SERVER_PASSWORD. Sin ella la API responde 401." -ForegroundColor Red
    Write-Host "  La define el propio opencode. Para verla:"
    Write-Host '    powershell -c "(Get-ChildItem Env: | Where-Object { $_.Name -like ''OPENCODE*'' }).Value"'
    exit 1
}
$user = if ($env:OPENCODE_SERVER_USERNAME) { $env:OPENCODE_SERVER_USERNAME } else { "opencode" }
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${password}"))
$jh = @{ Authorization = "Basic $b64"; "Content-Type" = "application/json" }

# --- comprobacion de conectividad -------------------------------------------
try {
    $null = Invoke-RestMethod -Uri "$base/agent" -Headers @{ Authorization = "Basic $b64" } -TimeoutSec 15
} catch {
    Write-Host "No se pudo conectar con $base : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Levantar un servidor con: opencode serve --port $Port" -ForegroundColor Yellow
    exit 1
}

# --- crear sesion -----------------------------------------------------------
$sid = (Invoke-RestMethod -Method Post -Uri "$base/session" -Headers $jh -Body '{}' -TimeoutSec 30).id
Write-Host "Sesion creada: $sid"

# --- enviar prompt que obliga a delegar ------------------------------------
$prompt = "Delega al subagente ejecutor esta tarea: ejecutar en la terminal el comando `echo test-delegacion-ok` y reportar la salida exacta. Luego confirma que recibiste el reporte."
$body = @{ parts = @(@{ type = "text"; text = $prompt }) }
if ($ModeloOrquestador) {
    $p = $ModeloOrquestador -split "/"
    $body.model = @{ providerID = $p[0]; modelID = $p[1] }
}
$resp = Invoke-RestMethod -Method Post -Uri "$base/session/$sid/message" -Headers $jh -Body ($body | ConvertTo-Json -Depth 8) -TimeoutSec 300

if ($resp.info.error) {
    Write-Host "ERROR del modelo: $($resp.info.error.name) - $($resp.info.error.data.message)" -ForegroundColor Red
    exit 1
}

# --- analizar la traza ------------------------------------------------------
$msgs = Invoke-RestMethod -Uri "$base/session/$sid/message" -Headers $jh -TimeoutSec 60
$encontroTask = $false
$encontroEjecutor = $false
$estado = ""

Write-Host ""
Write-Host "--- Traza ---" -ForegroundColor Cyan
foreach ($m in $msgs) {
    Write-Host ("[msg] role={0} agent={1} model={2}/{3}" -f $m.info.role, $m.info.agent, $m.info.providerID, $m.info.modelID) -ForegroundColor DarkGray
    foreach ($part in $m.parts) {
        if ($part.type -eq "tool") {
            $sub = if ($part.state.input) { $part.state.input.subagent_type } else { "" }
            Write-Host ("   [tool] {0} status={1} subagent_type={2}" -f $part.tool, $part.state.status, $sub) -ForegroundColor DarkGray
            if ($part.tool -eq "task") {
                $encontroTask = $true
                $estado = $part.state.status
                if ($sub -eq "ejecutor") { $encontroEjecutor = $true }
                $out = if ($part.state.output) { ($part.state.output -replace "`r?`n", " | ") } else { "" }
                if ($out.Length -gt 300) { $out = $out.Substring(0, 300) + "..." }
                if ($out) { Write-Host ("   [out] {0}" -f $out) -ForegroundColor DarkGray }
            }
        } elseif ($part.type -eq "text") {
            $t = $part.text
            if ($t.Length -gt 260) { $t = $t.Substring(0, 260) + "..." }
            Write-Host ("   [text] {0}" -f $t) -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
if ($encontroTask -and $encontroEjecutor -and $estado -eq "completed") {
    Write-Host "RESULTADO: OK - delegacion detectada (tool task -> subagent_type=ejecutor, status=completed)" -ForegroundColor Green
    exit 0
} elseif ($encontroTask) {
    Write-Host "RESULTADO: PARCIAL - se invoco la tool task pero sin subagent_type=ejecutor (estado: $estado)" -ForegroundColor Yellow
    Write-Host "  Revisar que el agente ejecutor exista con mode=subagent y el prompt del orquestador lo nombre como 'ejecutor'." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "RESULTADO: FALLA - el orquestador no invoco la tool task" -ForegroundColor Red
    Write-Host "  Posibles causas:" -ForegroundColor Red
    Write-Host "   - el prompt del orquestador no instruye delegar (ver agent.build.prompt)" -ForegroundColor Red
    Write-Host "   - el tool task esta deshabilitado para el agente build (permission)" -ForegroundColor Red
    Write-Host "   - el modelo del orquestador no respeta la instruccion de delegar" -ForegroundColor Red
    exit 1
}
