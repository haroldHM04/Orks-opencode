<#
    verify-opencode.ps1
    -----------------------------------------------------------------------------
    Verificacion del setup "Orquestador + Ejecutor" de OpenCode 1.x.
    SOLO LECTURA: no modifica ningun archivo ni ninguna credencial.

    Uso:
        powershell -NoProfile -ExecutionPolicy Bypass -File ".\verify-opencode.ps1"

    Codigo de salida:
        0 = todo correcto
        1 = hay problemas (se listan al final)
#>

$ErrorActionPreference = "Continue"
$problems = New-Object System.Collections.Generic.List[string]
$ok = New-Object System.Collections.Generic.List[string]

function Add-Ok($m)   { $ok.Add($m); Write-Host ("  [OK]   " + $m) -ForegroundColor Green }
function Add-Fail($m) { $problems.Add($m); Write-Host ("  [FALLA] " + $m) -ForegroundColor Red }
function Add-Info($m) { Write-Host ("  [--]   " + $m) -ForegroundColor Gray }

Write-Host ""
Write-Host "=== 1. Versiones ===" -ForegroundColor Cyan
$oc = (opencode --version 2>$null | Out-String).Trim()
if ($oc) {
    Add-Ok "OpenCode $oc"
    if ($oc -notmatch "^1\.") {
        Add-Fail "OpenCode $oc no es 1.x. La sintaxis de config de este setup es para 1.x (plugin/agent/prompt). En 2.x se usa plugins/agents/system."
    }
} else {
    Add-Fail "No se pudo ejecutar 'opencode --version'. OpenCode esta instalado y en el PATH?"
}

$cc = (claude --version 2>$null | Out-String).Trim()
if ($cc) { Add-Ok "Claude Code $cc" } else { Add-Fail "No se pudo ejecutar 'claude --version'. Claude Code CLI esta instalado?" }

Write-Host ""
Write-Host "=== 2. Autenticacion de Claude Code ===" -ForegroundColor Cyan
try {
    $status = (claude auth status 2>$null | Out-String) | ConvertFrom-Json
    if ($status.loggedIn) {
        Add-Ok "Claude Code autenticado (metodo: $($status.authMethod))"
    } else {
        Add-Fail "Claude Code SIN autenticacion. Ejecutar: claude auth login --claudeai"
    }
} catch {
    Add-Fail "No se pudo leer 'claude auth status': $($_.Exception.Message)"
}

$credPath = Join-Path $env:USERPROFILE ".claude\.credentials.json"
if (Test-Path $credPath) {
    try {
        $cred = (Get-Content $credPath -Raw | ConvertFrom-Json).claudeAiOauth
        if ($cred.accessToken.Length -gt 0) {
            Add-Ok "accessToken presente ($($cred.accessToken.Length) chars), expira $([DateTimeOffset]::FromUnixTimeMilliseconds([int64]$cred.expiresAt).LocalDateTime)"
        } else {
            Add-Fail "accessToken vacio en .credentials.json. Re-autenticar con: claude auth login --claudeai"
        }
    } catch {
        Add-Fail ".credentials.json ilegible: $($_.Exception.Message)"
    }
} else {
    Add-Fail "No existe $credPath. Ejecutar: claude auth login --claudeai"
}

Write-Host ""
Write-Host "=== 3. Credenciales de opencode (auth.json) ===" -ForegroundColor Cyan
$authPath = Join-Path $env:USERPROFILE ".local\share\opencode\auth.json"
if (-not (Test-Path $authPath)) {
    Add-Fail "No existe $authPath"
} else {
    try {
        $auth = Get-Content $authPath -Raw | ConvertFrom-Json
        foreach ($p in $auth.PSObject.Properties) {
            $key = $p.Value.key
            $keyStr = if ($key -is [string]) { $key } else { ($key | ConvertTo-Json -Compress) }
            if ($p.Name -eq "anthropic") {
                if ($p.Value.type -eq "oauth") { Add-Ok "anthropic: tipo oauth (creada por el plugin opencode-claude-auth)" }
                else { Add-Info "anthropic: tipo $($p.Value.type)" }
                continue
            }
            if ($keyStr.Length -lt 10) {
                Add-Fail "provider '$($p.Name)': key suspecta de corrupta ($($keyStr.Length) chars, valor: '$keyStr'). Corregir con: opencode auth login -p $($p.Name)"
            } else {
                Add-Ok "provider '$($p.Name)': key de $($keyStr.Length) chars"
            }
        }
        if (-not ($auth.PSObject.Properties.Name -contains "minimax-03")) {
            Add-Fail "Falta el provider 'minimax-03' en auth.json. Conectarlo con: opencode auth login -p minimax-03"
        }
    } catch {
        Add-Fail "auth.json ilegible: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "=== 4. Config global ===" -ForegroundColor Cyan
$globalCfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.jsonc"
if (-not (Test-Path $globalCfg)) {
    Add-Fail "No existe $globalCfg"
} else {
    try {
        $raw = [System.IO.File]::ReadAllText($globalCfg)
        $clean = (($raw -split "`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        $cfg = $clean | ConvertFrom-Json
        Add-Ok "$globalCfg es JSON valido"

        $plugin = @($cfg.plugin)
        if ($plugin.Count -gt 0) {
            foreach ($pl in $plugin) {
                if ($pl -match "opencode-claude-auth") {
                    if ($pl -match "2\.2\.1|@1\.|@2\.") { Add-Ok "plugin '$pl' (version compatible con OpenCode 1.x)" }
                    elseif ($pl -match "@latest") { Add-Fail "plugin '$pl' instala v3, que exige OpenCode 2.0+. Fijar: opencode-claude-auth@2.2.1" }
                    else { Add-Info "plugin '$pl'" }
                } else { Add-Info "plugin '$pl'" }
            }
        } else {
            Add-Info "Sin bloque 'plugin'. Si el orquestador usa anthropic/*, agregar: opencode-claude-auth@2.2.1"
        }

        foreach ($name in @("build", "ejecutor")) {
            if ($cfg.agent.$name) {
                $a = $cfg.agent.$name
                Add-Ok "agente '$name': mode=$($a.mode) model=$($a.model)"
            } else {
                Add-Fail "Falta el agente '$name' en el bloque 'agent'"
            }
        }
        if ($cfg.agent.ejecutor -and $cfg.agent.ejecutor.tools -and ($cfg.agent.ejecutor.tools.task -eq $false)) {
            Add-Ok "ejecutor sin tool 'task' (no delega recursivamente)"
        }
    } catch {
        Add-Fail "Config global invalido: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "=== 5. Modelos y agentes visibles ===" -ForegroundColor Cyan
$anthropic = (opencode models anthropic 2>$null | Out-String)
if ($anthropic -match "anthropic/claude-opus-5-5") { Add-Ok "anthropic/claude-opus-5-5 disponible" }
else { Add-Fail "anthropic/claude-opus-5-5 NO aparece. Revisar que el plugin este en 'plugin' y que Claude Code este autenticado." }

foreach ($nombre in @("build", "ejecutor")) {
    try {
        $ag = (opencode debug agent $nombre 2>$null | Out-String) | ConvertFrom-Json
        if ($ag.name) {
            Add-Ok "agente '$nombre' visible (mode=$($ag.mode) model=$($ag.model.providerID)/$($ag.model.modelID))"
        } else {
            Add-Fail "el agente '$nombre' no se resuelve"
        }
    } catch {
        Add-Fail "No se pudo resolver el agente '$nombre' (existe en el config global?)"
    }
}

Write-Host ""
Write-Host "=== 6. Config del proyecto (opcional) ===" -ForegroundColor Cyan
$projCfg = Join-Path $PWD ".opencode\opencode.jsonc"
if (Test-Path $projCfg) {
    try {
        $praw = [System.IO.File]::ReadAllText($projCfg)
        $pclean = (($praw -split "`n") | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
        $pcfg = $pclean | ConvertFrom-Json
        if ($pcfg.agent.build -and $pcfg.agent.ejecutor) { Add-Ok "$projCfg define build y ejecutor" }
        else { Add-Fail "$projCfg no define los dos agentes" }
    } catch {
        Add-Fail "$projCfg invalido: $($_.Exception.Message)"
    }
} else {
    Add-Info "Sin .opencode\opencode.jsonc en el proyecto (opcional: solo el config global alcanza)"
}

Write-Host ""
if ($problems.Count -eq 0) {
    Write-Host "RESULTADO: OK - $($ok.Count) verificaciones correctas" -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULTADO: $($problems.Count) problema(s) detectado(s):" -ForegroundColor Red
    foreach ($p in $problems) { Write-Host ("  - " + $p) -ForegroundColor Red }
    Write-Host ""
    Write-Host "Ver 04-troubleshooting.md para la solucion de cada caso." -ForegroundColor Yellow
    exit 1
}
