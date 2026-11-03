[CmdletBinding()]
param(
    [string]$GodotPath,
    [switch]$Editor
)

$ErrorActionPreference = 'Stop'
$project = $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
    throw "No se encontro el proyecto en: $project"
}

if (-not $GodotPath) { $GodotPath = $env:GODOT_BIN }
if (-not $GodotPath) { $GodotPath = [Environment]::GetEnvironmentVariable('GODOT_BIN', 'User') }
if (-not $GodotPath) {
    foreach ($name in @('godot4.exe', 'godot.exe')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { $GodotPath = $command.Source; break }
    }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'No se encontro Godot. Instale Godot 4.7 o superior, defina GODOT_BIN o use -GodotPath "C:\ruta\godot.exe".'
}

if (-not $Editor -and -not (Test-Path -LiteralPath (Join-Path $project '.godot\uid_cache.bin'))) {
    Write-Host 'Importando recursos del proyecto por primera vez...'
    & $GodotPath --headless --path $project --editor --import
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$arguments = @('--path', $project)
if ($Editor) { $arguments += '--editor' }
& $GodotPath @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
