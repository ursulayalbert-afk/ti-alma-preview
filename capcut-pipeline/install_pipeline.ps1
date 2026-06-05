<#
.SYNOPSIS
    Instalador del Pipeline CapCut TI para el taller (Windows).

.DESCRIPTION
    Automatiza los Bloques 1-3 de la mision:
      - Clona VectCutAPI, capcut-mcp-server-extended y SmartCut
      - Crea los venv y instala dependencias
      - Crea config.json (VectCutAPI) y verifica puerto 9001
      - Crea la tarea programada "TI-VectCutAPI"
      - Fusiona (merge) las entradas capcut + smartcut en claude_desktop_config.json
        SIN borrar entradas existentes
      - Localiza la carpeta real de drafts de CapCut

    Ejecutar desde PowerShell en el taller:
        cd C:\COMPARTIDO\Sauron\tools\capcut-pipeline
        powershell -ExecutionPolicy Bypass -File .\install_pipeline.ps1

.PARAMETER FindDraftsOnly
    Solo busca y reporta la carpeta de drafts de CapCut, no instala nada.

.PARAMETER SkipScheduledTask
    No crea la tarea programada (util si se prefiere arranque manual).
#>

[CmdletBinding()]
param(
    [string]$BaseDir = "C:\COMPARTIDO\Sauron\tools\capcut-pipeline",
    [switch]$FindDraftsOnly,
    [switch]$SkipScheduledTask
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "  !!  $msg" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# Localizador de carpeta de drafts de CapCut
# ---------------------------------------------------------------------------
function Find-CapCutDrafts {
    Write-Step "Buscando carpeta de drafts de CapCut"
    $roots = @(
        "$env:LOCALAPPDATA\CapCut\User Data\Projects\com.lveditor.draft",
        "$env:LOCALAPPDATA\CapCut\User Data\draft",
        "$env:LOCALAPPDATA\CapCut"
    ) | Where-Object { Test-Path $_ }

    $found = @()
    foreach ($root in $roots) {
        # Una carpeta "draft" valida contiene .json (draft_content.json, etc.)
        Get-ChildItem -Path $root -Recurse -Directory -Filter "draft*" -ErrorAction SilentlyContinue |
            ForEach-Object {
                $jsons = Get-ChildItem -Path $_.FullName -Filter "*.json" -File -ErrorAction SilentlyContinue
                if ($jsons.Count -gt 0) { $found += $_.FullName }
            }
    }
    $found = $found | Select-Object -Unique
    if ($found.Count -gt 0) {
        foreach ($f in $found) { Write-Ok "Drafts CapCut: $f" }
    } else {
        Write-Warn2 "No se encontro carpeta 'draft' con .json bajo $env:LOCALAPPDATA\CapCut"
        Write-Warn2 "CapCut puede no estar instalado o no haber creado proyectos todavia."
    }
    return $found
}

if ($FindDraftsOnly) { Find-CapCutDrafts | Out-Null; return }

# ---------------------------------------------------------------------------
# Comprobaciones previas
# ---------------------------------------------------------------------------
Write-Step "Comprobando prerrequisitos"
foreach ($cmd in @("git", "python", "node", "npm")) {
    $p = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($p) { Write-Ok "$cmd -> $($p.Source)" }
    else    { throw "Falta '$cmd' en PATH. Instalalo antes de continuar." }
}
$pyVer = (python --version) 2>&1
Write-Ok "Python: $pyVer"

New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
Set-Location $BaseDir

# ---------------------------------------------------------------------------
# BLOQUE 1 - VectCutAPI
# ---------------------------------------------------------------------------
Write-Step "BLOQUE 1 - VectCutAPI"
$vectDir = Join-Path $BaseDir "VectCutAPI"
if (-not (Test-Path $vectDir)) {
    git clone https://github.com/sun-guannan/VectCutAPI.git $vectDir
} else { Write-Warn2 "VectCutAPI ya existe, omito clone" }

Set-Location $vectDir
if (-not (Test-Path "venv-capcut")) { python -m venv venv-capcut }
$vectPy = Join-Path $vectDir "venv-capcut\Scripts\python.exe"

& $vectPy -m pip install --upgrade pip
if (Test-Path "requirements.txt")     { & $vectPy -m pip install -r requirements.txt }
if (Test-Path "requirements-mcp.txt") { & $vectPy -m pip install -r requirements-mcp.txt }

if ((Test-Path "config.json.example") -and (-not (Test-Path "config.json"))) {
    Copy-Item "config.json.example" "config.json"
    Write-Ok "config.json creado desde config.json.example"
}
if (Test-Path "config.json") {
    try {
        $cfg = Get-Content "config.json" -Raw | ConvertFrom-Json
        if ($cfg.PSObject.Properties.Name -contains "port") {
            if ([int]$cfg.port -ne 9001) {
                $cfg.port = 9001
                $cfg | ConvertTo-Json -Depth 20 | Set-Content "config.json" -Encoding UTF8
                Write-Ok "config.json: port ajustado a 9001"
            } else { Write-Ok "config.json: port ya es 9001" }
        } else { Write-Warn2 "config.json no tiene clave 'port'; revisar manualmente" }
    } catch { Write-Warn2 "No se pudo parsear config.json: $_" }
}

# Tarea programada TI-VectCutAPI
if (-not $SkipScheduledTask) {
    Write-Step "Creando tarea programada TI-VectCutAPI"
    $action  = New-ScheduledTaskAction -Execute $vectPy -Argument "capcut_server.py" -WorkingDirectory $vectDir
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName "TI-VectCutAPI" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Ok "Tarea 'TI-VectCutAPI' registrada (arranque al iniciar sesion)"
} else { Write-Warn2 "Omitida la tarea programada (-SkipScheduledTask)" }

# ---------------------------------------------------------------------------
# BLOQUE 2 - capcut-mcp-server-extended
# ---------------------------------------------------------------------------
Write-Step "BLOQUE 2 - capcut-mcp-server-extended"
$mcpDir = Join-Path $BaseDir "capcut-mcp-server"
Set-Location $BaseDir
if (-not (Test-Path $mcpDir)) {
    git clone https://github.com/MigueDuque/capcut-mcp-server-extended.git $mcpDir
} else { Write-Warn2 "capcut-mcp-server ya existe, omito clone" }
Set-Location $mcpDir
npm install
npm run build
$distIndex = Join-Path $mcpDir "dist\index.js"
if (Test-Path $distIndex) { Write-Ok "Build OK: $distIndex" }
else { Write-Warn2 "No existe dist\index.js tras el build; revisar salida de npm run build" }

# ---------------------------------------------------------------------------
# BLOQUE 3 - SmartCut
# ---------------------------------------------------------------------------
Write-Step "BLOQUE 3 - SmartCut"
$scDir = Join-Path $BaseDir "smartcut"
Set-Location $BaseDir
if (-not (Test-Path $scDir)) {
    git clone https://github.com/mrbuslov/capcut-ai-editor.git $scDir
} else { Write-Warn2 "smartcut ya existe, omito clone" }
Set-Location $scDir
if (-not (Test-Path "venv-smartcut")) { python -m venv venv-smartcut }
$scPy = Join-Path $scDir "venv-smartcut\Scripts\python.exe"
& $scPy -m pip install --upgrade pip
& $scPy -m pip install -e .

# ---------------------------------------------------------------------------
# Localizar drafts CapCut
# ---------------------------------------------------------------------------
$drafts = Find-CapCutDrafts
$draftsDir = if ($drafts.Count -gt 0) { $drafts[0] } else { $null }

# ---------------------------------------------------------------------------
# MERGE en claude_desktop_config.json (sin borrar entradas existentes)
# ---------------------------------------------------------------------------
Write-Step "Registrando MCP en claude_desktop_config.json"
$cfgPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
$cfgDir  = Split-Path $cfgPath -Parent
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null

if (Test-Path $cfgPath) {
    Copy-Item $cfgPath "$cfgPath.bak" -Force
    Write-Ok "Backup: $cfgPath.bak"
    $root = Get-Content $cfgPath -Raw | ConvertFrom-Json
} else {
    $root = [pscustomobject]@{}
}
if (-not ($root.PSObject.Properties.Name -contains "mcpServers")) {
    $root | Add-Member -NotePropertyName mcpServers -NotePropertyValue ([pscustomobject]@{})
}

$capcut = [pscustomobject]@{
    command = "node"
    args    = @($distIndex)
    env     = [pscustomobject]@{ CAPCUT_API_URL = "http://localhost:9001" }
}
$smartEnv = [pscustomobject]@{}
if ($draftsDir) { $smartEnv | Add-Member -NotePropertyName CAPCUT_DRAFTS_DIR -NotePropertyValue $draftsDir }
$smartcut = [pscustomobject]@{
    command = $scPy
    args    = @("-m", "smartcut.server")
}
if ($draftsDir) { $smartcut | Add-Member -NotePropertyName env -NotePropertyValue $smartEnv }

# upsert sin tocar el resto
$root.mcpServers | Add-Member -NotePropertyName capcut   -NotePropertyValue $capcut   -Force
$root.mcpServers | Add-Member -NotePropertyName smartcut -NotePropertyValue $smartcut -Force

$root | ConvertTo-Json -Depth 30 | Set-Content $cfgPath -Encoding UTF8
# validacion
try { Get-Content $cfgPath -Raw | ConvertFrom-Json | Out-Null; Write-Ok "JSON valido: $cfgPath" }
catch { Write-Warn2 "JSON INVALIDO tras escribir: $_  (restaurar desde $cfgPath.bak)" }

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
Write-Step "RESUMEN"
Write-Host "VectCutAPI : $vectDir  (tarea TI-VectCutAPI)"
Write-Host "MCP server : $distIndex"
Write-Host "SmartCut   : $scDir"
Write-Host "Config MCP : $cfgPath"
if ($draftsDir) { Write-Host "Drafts     : $draftsDir" } else { Write-Host "Drafts     : (no detectado)" }
Write-Host "`nSiguiente paso: reinicia Claude Desktop y verifica (BLOQUE 5):"
Write-Host "  curl http://localhost:9001"
Write-Host "  & '$vectPy' test_mcp_client.py"
