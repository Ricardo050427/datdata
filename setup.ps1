#Requires -Version 5.1
<#
.SYNOPSIS
    Instalador de la Metodología 2 de Datdata (Motor Automatizado) para Power BI.

.DESCRIPTION
    Instala y configura todo el sistema para Claude Code, Codex y Antigravity:
      [1] Node.js LTS (con winget, si falta)
      [2] CLIs de Fabric y MCP oficial de Power BI (npm global)
      [3] Las 12 skills, en cada agente detectado
      [4] El MCP de Power BI en cada agente detectado
      [5] Verificación final con resultado real (OK o CON PROBLEMAS)

    No borra nada: lo que reemplaza se respalda en %USERPROFILE%\.datdata\respaldos\<fecha>.
    Los archivos de configuración se leen y escriben en UTF-8 sin BOM, sin alterar acentos.

.PARAMETER Agentes
    Agentes a configurar: claude, codex, antigravity. Por defecto se detectan solos.

.PARAMETER SinNpm
    Omite Node.js y los paquetes de npm (solo para pruebas).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File setup.ps1
#>
param(
    [string[]]$Agentes = @(),
    [switch]$SinNpm
)

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$here      = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path $here "skills"
$perfil    = $env:USERPROFILE
$stamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$respaldos = Join-Path $perfil ".datdata\respaldos\$stamp"
$utf8      = New-Object System.Text.UTF8Encoding($false)
$TOTAL     = 5

$MCP_NOMBRE  = "powerbi-modeling-mcp"
$MCP_PAQUETE = "@microsoft/powerbi-modeling-mcp@latest"
$MARKETPLACE_URL = "https://github.com/microsoft/skills-for-fabric.git"
$PAQUETES    = @("@microsoft/powerbi-report-authoring-cli", "@microsoft/powerbi-desktop-bridge-cli", "@microsoft/powerbi-modeling-mcp")

$script:problemas = New-Object System.Collections.Generic.List[string]
$script:avisos    = New-Object System.Collections.Generic.List[string]

function Write-Step($n, $msg) { Write-Host ("`n" + "-" * 64) -ForegroundColor DarkGray; Write-Host "  [$n/$TOTAL] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "        OK  $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "        !   $msg" -ForegroundColor Yellow; $script:avisos.Add($msg) }
function Write-Fail($msg) { Write-Host "        X   $msg" -ForegroundColor Red; $script:problemas.Add($msg) }

function Update-Path {
    $rutas = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User"),
        (Join-Path $env:ProgramFiles "nodejs"),
        (Join-Path $env:APPDATA "npm")
    )
    $env:Path = ($rutas | Where-Object { $_ }) -join ";"
}

function Backup-Item($ruta, $grupo) {
    if (-not (Test-Path -LiteralPath $ruta)) { return }
    $destino = Join-Path $respaldos $grupo
    New-Item -ItemType Directory -Force $destino | Out-Null
    Copy-Item -LiteralPath $ruta -Destination $destino -Recurse -Force
}

function Read-JsonFile($ruta) {
    if (-not (Test-Path -LiteralPath $ruta)) { return [PSCustomObject]@{} }
    $texto = [IO.File]::ReadAllText($ruta, [Text.Encoding]::UTF8)
    if ($texto.Trim() -eq "") { return [PSCustomObject]@{} }
    return ($texto | ConvertFrom-Json -ErrorAction Stop)
}

function Write-TextFile($ruta, $texto) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $ruta) | Out-Null
    [IO.File]::WriteAllText($ruta, $texto, $utf8)
}

function Set-Prop($obj, $nombre, $valor) {
    $obj | Add-Member -NotePropertyName $nombre -NotePropertyValue $valor -Force
}

function Get-OrAddObject($obj, $nombre) {
    if (-not $obj.PSObject.Properties[$nombre]) { Set-Prop $obj $nombre ([PSCustomObject]@{}) }
    return $obj.$nombre
}

# Ejecuta un comando externo, devuelve su salida y deja el código de salida en $LASTEXITCODE
function Invoke-Externo($exe, [string[]]$argumentos) {
    $salida = & $exe @argumentos 2>&1 | ForEach-Object { "$_" }
    return $salida
}

Clear-Host
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Magenta
Write-Host "    Datdata - Metodología 2 (Motor Automatizado)" -ForegroundColor Magenta
Write-Host "    Claude Code · Codex · Antigravity" -ForegroundColor Magenta
Write-Host "  ================================================================" -ForegroundColor Magenta

if (-not (Test-Path $skillsSrc)) {
    Write-Host "`n  X No se encontró la carpeta 'skills' junto a setup.ps1." -ForegroundColor Red
    Write-Host "    Descomprime EXPORTAR.zip completo y ejecuta setup.ps1 desde esa carpeta." -ForegroundColor Red
    Write-Host "`nRESULTADO: CON PROBLEMAS (falta la carpeta skills)"
    exit 1
}

# Agentes a configurar. Claude siempre recibe las skills: las rutas de los assets apuntan a .claude\skills.
$detectados = @()
if ($Agentes.Count -gt 0) {
    $detectados = $Agentes | ForEach-Object { $_.ToLower().Trim() }
} else {
    $detectados += "claude"
    if ((Test-Path (Join-Path $perfil ".codex")) -or (Get-Command codex -ErrorAction SilentlyContinue)) { $detectados += "codex" }
    if (Test-Path (Join-Path $perfil ".gemini")) { $detectados += "antigravity" }
}
if ($detectados -notcontains "claude") { $detectados += "claude" }
Write-Host "`n  Agentes que se configurarán: $($detectados -join ', ')" -ForegroundColor Gray

# ==============================================================================
# PASO 1 - Node.js
# ==============================================================================
Write-Step 1 "Node.js LTS"
Update-Path
if ($SinNpm) {
    Write-Warn "Omitido (-SinNpm)."
} elseif (Get-Command node -ErrorAction SilentlyContinue) {
    Write-OK "Node.js ya estaba instalado ($(& node --version))."
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "        Instalando Node.js LTS con winget..." -ForegroundColor Gray
    $out = Invoke-Externo "winget" @("install", "--id", "OpenJS.NodeJS.LTS", "-e", "--silent", "--accept-source-agreements", "--accept-package-agreements")
    Update-Path
    if (Get-Command node -ErrorAction SilentlyContinue) {
        Write-OK "Node.js instalado ($(& node --version))."
    } else {
        Write-Fail "No se pudo instalar Node.js con winget. Instálalo desde https://nodejs.org/ y vuelve a ejecutar setup.ps1."
        $out | Select-Object -Last 8 | ForEach-Object { Write-Host "            $_" -ForegroundColor DarkGray }
    }
} else {
    Write-Fail "Falta Node.js y winget no está disponible. Instálalo desde https://nodejs.org/ y vuelve a ejecutar setup.ps1."
}

# ==============================================================================
# PASO 2 - CLIs de Fabric y MCP oficial
# ==============================================================================
Write-Step 2 "CLIs de Fabric y MCP oficial de Power BI (npm)"
if ($SinNpm) {
    Write-Warn "Omitido (-SinNpm)."
} elseif (Get-Command npm.cmd -ErrorAction SilentlyContinue) {
    Write-Host "        npm install -g $($PAQUETES -join ' ')" -ForegroundColor Gray
    $out = Invoke-Externo "npm.cmd" (@("install", "-g") + $PAQUETES)
    $codigo = $LASTEXITCODE
    Update-Path
    # Carpeta real de los comandos globales de npm (puede no ser %APPDATA%\npm, p. ej. con nvm)
    $prefijo = & npm.cmd prefix -g 2>$null | Select-Object -First 1
    if ($prefijo -and (Test-Path $prefijo)) { $env:Path = "$prefijo;$env:Path" }
    if ($codigo -ne 0) {
        Write-Fail "npm install terminó con error (código $codigo); el detalle está en las líneas de abajo."
        $out | Select-Object -Last 12 | ForEach-Object { Write-Host "            $_" -ForegroundColor DarkGray }
    }
    foreach ($cmd in @("powerbi-report-author", "powerbi-desktop", "powerbi-modeling-mcp")) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) { Write-OK "$cmd" }
        else { Write-Fail "$cmd no quedó disponible en el PATH." }
    }
} else {
    Write-Fail "npm no está disponible. Instala Node.js LTS, cierra y reabre la terminal y vuelve a ejecutar setup.ps1."
}

# ==============================================================================
# PASO 3 - Skills
# ==============================================================================
Write-Step 3 "Skills de la metodología"
$destinosSkills = [ordered]@{}
$destinosSkills["claude"] = Join-Path $perfil ".claude\skills"
if ($detectados -contains "codex")       { $destinosSkills["codex"]       = Join-Path $perfil ".codex\skills" }
if ($detectados -contains "antigravity") { $destinosSkills["antigravity"] = Join-Path $perfil ".gemini\config\skills" }

$listaSkills = Get-ChildItem $skillsSrc -Directory
foreach ($agente in $destinosSkills.Keys) {
    $destBase = $destinosSkills[$agente]
    try {
        New-Item -ItemType Directory -Force $destBase | Out-Null
        foreach ($dir in $listaSkills) {
            $dest = Join-Path $destBase $dir.Name
            if (Test-Path -LiteralPath $dest) {
                # El respaldo va fuera de la carpeta de skills para que el agente no lo cargue como duplicado
                $bak = Join-Path $respaldos "skills-$agente"
                New-Item -ItemType Directory -Force $bak | Out-Null
                Move-Item -LiteralPath $dest -Destination (Join-Path $bak $dir.Name) -Force -ErrorAction Stop
            }
            Copy-Item -LiteralPath $dir.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
        }
        # Respaldos .bak_* que dejaron versiones anteriores del instalador dentro de la carpeta de skills
        Get-ChildItem $destBase -Directory | Where-Object { $_.Name -match '\.bak_\d{8}_\d{6}$' } | ForEach-Object {
            $bak = Join-Path $respaldos "skills-$agente-bak-anteriores"
            New-Item -ItemType Directory -Force $bak | Out-Null
            Move-Item -LiteralPath $_.FullName -Destination (Join-Path $bak $_.Name) -Force
        }
        $ok = ($listaSkills | Where-Object { Test-Path (Join-Path (Join-Path $destBase $_.Name) "SKILL.md") }).Count
        if ($ok -eq $listaSkills.Count) { Write-OK "$agente : $ok skills en $destBase" }
        else { Write-Fail "$agente : solo $ok de $($listaSkills.Count) skills quedaron completas en $destBase" }
    } catch {
        Write-Fail "$agente : no se pudieron copiar las skills a $destBase ($($_.Exception.Message))"
    }
}

# ==============================================================================
# PASO 4 - MCP de Power BI en cada agente
# ==============================================================================
Write-Step 4 "MCP de Power BI en cada agente"

# 4.1 Claude Code: plugin oficial de Microsoft (trae el MCP y las skills de Fabric)
$claudeListo = $false
if (Get-Command claude -ErrorAction SilentlyContinue) {
    $lista = (Invoke-Externo "claude" @("plugin", "marketplace", "list")) -join "`n"
    if ($lista -notmatch "fabric-collection") {
        # URL HTTPS: el atajo "microsoft/skills-for-fabric" clona por SSH y falla sin llaves SSH de GitHub
        $out = Invoke-Externo "claude" @("plugin", "marketplace", "add", $MARKETPLACE_URL)
    }
    $out = Invoke-Externo "claude" @("plugin", "install", "powerbi-authoring@fabric-collection", "--scope", "user")
    $instalados = (Invoke-Externo "claude" @("plugin", "list")) -join "`n"
    if ($instalados -match "powerbi-authoring@fabric-collection") {
        $claudeListo = $true
        Write-OK "claude : plugin powerbi-authoring@fabric-collection instalado (incluye el MCP)."
    }
}
if (-not $claudeListo) {
    # Sin la CLI de Claude: se deja declarado en settings.json y Claude Code lo instala al abrirse
    $settingsFile = Join-Path $perfil ".claude\settings.json"
    try {
        $cfg = Read-JsonFile $settingsFile
        Backup-Item $settingsFile "claude"
        $mk = Get-OrAddObject $cfg "extraKnownMarketplaces"
        Set-Prop $mk "fabric-collection" ([PSCustomObject]@{ source = [PSCustomObject]@{ source = "git"; url = $MARKETPLACE_URL } })
        $ep = Get-OrAddObject $cfg "enabledPlugins"
        Set-Prop $ep "powerbi-authoring@fabric-collection" $true
        Write-TextFile $settingsFile ($cfg | ConvertTo-Json -Depth 20)
        Write-OK "claude : plugin declarado en $settingsFile (se instala al abrir Claude Code)."
    } catch {
        Write-Fail "claude : no se pudo actualizar $settingsFile ($($_.Exception.Message)). No se modificó el archivo."
    }
}

# 4.2 Codex: ~/.codex/config.toml
if ($detectados -contains "codex") {
    $tomlFile = Join-Path $perfil ".codex\config.toml"
    try {
        $toml = ""
        if (Test-Path -LiteralPath $tomlFile) { $toml = [IO.File]::ReadAllText($tomlFile, [Text.Encoding]::UTF8) }
        if ($toml -match "(?m)^\s*\[mcp_servers\.`"?$([regex]::Escape($MCP_NOMBRE))`"?\]") {
            Write-OK "codex : el MCP ya estaba en $tomlFile (no se modificó)."
        } else {
            Backup-Item $tomlFile "codex"
            $bloque = @(
                "",
                "[mcp_servers.$MCP_NOMBRE]",
                "command = `"cmd`"",
                "args = [`"/c`", `"npx`", `"-y`", `"$MCP_PAQUETE`", `"--start`"]",
                "startup_timeout_sec = 120",
                ""
            ) -join "`n"
            $toml = $toml.TrimEnd() + "`n" + $bloque
            Write-TextFile $tomlFile $toml.TrimStart()
            Write-OK "codex : MCP agregado a $tomlFile"
        }
    } catch {
        Write-Fail "codex : no se pudo actualizar $tomlFile ($($_.Exception.Message))."
    }
}

# 4.3 Antigravity: ~/.gemini/config/mcp_config.json
if ($detectados -contains "antigravity") {
    $mcpFile = Join-Path $perfil ".gemini\config\mcp_config.json"
    try {
        $mcpCfg = Read-JsonFile $mcpFile
        $servers = Get-OrAddObject $mcpCfg "mcpServers"
        if ($servers.PSObject.Properties[$MCP_NOMBRE]) {
            Write-OK "antigravity : el MCP ya estaba en $mcpFile (no se modificó)."
        } else {
            Backup-Item $mcpFile "antigravity"
            Set-Prop $servers $MCP_NOMBRE ([PSCustomObject]@{ command = "npx"; args = @("-y", $MCP_PAQUETE, "--start"); type = "stdio" })
            Write-TextFile $mcpFile ($mcpCfg | ConvertTo-Json -Depth 20)
            Write-OK "antigravity : MCP agregado a $mcpFile"
        }
    } catch {
        Write-Fail "antigravity : no se pudo actualizar $mcpFile ($($_.Exception.Message)). No se modificó el archivo."
    }
}

# ==============================================================================
# PASO 5 - Verificación final
# ==============================================================================
Write-Step 5 "Verificación final"
$hybrid = Join-Path $perfil ".claude\skills\powerbi-dashboard\assets\hybrid.js"
$pbiviz = Join-Path $perfil ".claude\skills\powerbi-dashboard\assets\FiltroGeneralUniversal.pbiviz"
if ((Test-Path $hybrid) -and (Get-Command node -ErrorAction SilentlyContinue)) {
    $out = Invoke-Externo "node" @("--check", $hybrid)
    if ($LASTEXITCODE -eq 0) { Write-OK "hybrid.js válido." } else { Write-Fail "hybrid.js tiene errores de sintaxis: $($out -join ' ')" }
} elseif (-not (Test-Path $hybrid)) {
    Write-Fail "No se encontró hybrid.js en $hybrid"
}
if (Test-Path $pbiviz) { Write-OK "Visual Filtro listo en $pbiviz" } else { Write-Fail "No se encontró el visual Filtro en $pbiviz" }
if (Test-Path $respaldos) { Write-OK "Respaldo de lo reemplazado en $respaldos" }

# ==============================================================================
# RESUMEN
# ==============================================================================
Write-Host ("`n" + "-" * 64) -ForegroundColor DarkGray
if ($script:problemas.Count -eq 0) {
    Write-Host "`n  INSTALACIÓN COMPLETA" -ForegroundColor Green
} else {
    Write-Host "`n  LA INSTALACIÓN TERMINÓ CON $($script:problemas.Count) PROBLEMA(S):" -ForegroundColor Red
    $script:problemas | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
Write-Host ""
Write-Host "  SIGUIENTE PASO: cierra y vuelve a abrir tu agente (Claude Code, Codex o Antigravity)" -ForegroundColor Yellow
Write-Host "  para que cargue las skills y el MCP." -ForegroundColor Yellow
Write-Host ""
Write-Host "  POR CADA REPORTE NUEVO:" -ForegroundColor Cyan
Write-Host "    1. Guarda el reporte como proyecto .pbip en Power BI Desktop." -ForegroundColor White
Write-Host "    2. Importa Deneb y HTML Content desde AppSource." -ForegroundColor White
Write-Host "    3. Importa el visual Filtro desde archivo: $pbiviz" -ForegroundColor White
Write-Host "    4. Guarda con Ctrl+S y pide: `"Crea un dashboard del reporte que tengo abierto`"" -ForegroundColor White
Write-Host ""

if ($script:problemas.Count -eq 0) {
    Write-Host "RESULTADO: OK (agentes: $($detectados -join ', '))"
    exit 0
} else {
    Write-Host "RESULTADO: CON PROBLEMAS ($($script:problemas.Count)) - $($script:problemas -join ' | ')"
    exit 1
}
