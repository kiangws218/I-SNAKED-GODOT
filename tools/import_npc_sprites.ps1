param(
    [string]$Character = '',
    [switch]$Force,
    [string]$GodotPath = ''
)
$ErrorActionPreference = 'Stop'
$spriteProjectDir = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $spriteGodotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($spriteGodotCommand) { $GodotPath = $spriteGodotCommand.Source }
    else { $GodotPath = 'D:\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe' }
}
if (-not (Test-Path -LiteralPath $GodotPath)) { throw 'Provide -GodotPath pointing to Godot 4.7.2.' }
$spriteImportArgs = @('--headless', '--path', $spriteProjectDir, '--script', 'res://tools/import_npc_sprites.gd', '--')
if ($Character) { $spriteImportArgs += "--character=$Character" }
if ($Force) { $spriteImportArgs += '--force' }
& $GodotPath @spriteImportArgs
if ($LASTEXITCODE -ne 0) { throw "NPC import failed: $LASTEXITCODE" }
& $GodotPath --headless --path $spriteProjectDir --editor --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed: $LASTEXITCODE" }
