param(
    [string]$GameRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-Win64Path {
    param([string]$Root)

    if (-not $Root) { return $null }

    $resolved = $null
    try {
        $resolved = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
    } catch {
        return $null
    }

    if ($resolved -match 'Binaries\\Win64$' -and (Test-Path -LiteralPath $resolved)) {
        return $resolved
    }

    $candidate = Join-Path $resolved 'SurrounDead\Binaries\Win64'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    $candidate = Join-Path $resolved 'Binaries\Win64'
    if (Test-Path -LiteralPath $candidate) {
        return $candidate
    }

    return $null
}

function Backup-IfExists {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        $bak = "$Path.bak"
        if (-not (Test-Path -LiteralPath $bak)) {
            Copy-Item -LiteralPath $Path -Destination $bak -Force
        }
    }
}

function Ensure-ConsoleKeys {
    $inputIni = Join-Path $env:LOCALAPPDATA 'SurrounDead\Saved\Config\Windows\Input.ini'

    if (-not (Test-Path -LiteralPath $inputIni)) {
        New-Item -ItemType File -Force -Path $inputIni | Out-Null
    }

    $lines = @()
    try {
        $lines = Get-Content -LiteralPath $inputIni
    } catch {
        $lines = @()
    }

    $section = '[/Script/Engine.InputSettings]'
    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[/Script/Engine.InputSettings\]\s*$') {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        $lines = $lines + $section
        $sectionIndex = $lines.Count - 1
    }

    $endIndex = $lines.Count
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[.*\]\s*$') {
            $endIndex = $i
            break
        }
    }

    $sectionLines = @()
    if ($endIndex -gt ($sectionIndex + 1)) {
        $sectionLines = $lines[($sectionIndex + 1)..($endIndex - 1)]
    }

    $desired = @('ConsoleKeys=Tilde', 'ConsoleKeys=F2')
    foreach ($line in $desired) {
        if (-not ($sectionLines -contains $line)) {
            $before = @()
            if ($endIndex -gt 0) {
                $before = $lines[0..($endIndex - 1)]
            }
            $after = @()
            if ($endIndex -lt $lines.Count) {
                $after = $lines[$endIndex..($lines.Count - 1)]
            }
            $lines = $before + $line + $after
            $endIndex += 1
            $sectionLines += $line
        }
    }

    Set-Content -LiteralPath $inputIni -Value $lines -Encoding ASCII
}

function Ensure-IniSectionLines {
    param(
        [string]$IniPath,
        [string]$SectionHeader,
        [string[]]$DesiredLines
    )

    if (-not (Test-Path -LiteralPath $IniPath)) {
        New-Item -ItemType File -Force -Path $IniPath | Out-Null
    }

    $lines = @()
    try {
        $lines = Get-Content -LiteralPath $IniPath
    } catch {
        $lines = @()
    }

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ("^\s*\[" + [regex]::Escape($SectionHeader.Trim('[', ']')) + "\]\s*$")) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        $lines = $lines + $SectionHeader
        $sectionIndex = $lines.Count - 1
    }

    $endIndex = $lines.Count
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[.*\]\s*$') {
            $endIndex = $i
            break
        }
    }

    $sectionLines = @()
    if ($endIndex -gt ($sectionIndex + 1)) {
        $sectionLines = $lines[($sectionIndex + 1)..($endIndex - 1)]
    }

    foreach ($line in $DesiredLines) {
        if (-not ($sectionLines -contains $line)) {
            $before = @()
            if ($endIndex -gt 0) {
                $before = $lines[0..($endIndex - 1)]
            }
            $after = @()
            if ($endIndex -lt $lines.Count) {
                $after = $lines[$endIndex..($lines.Count - 1)]
            }
            $lines = $before + $line + $after
            $endIndex += 1
            $sectionLines += $line
        }
    }

    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ASCII
}

function Ensure-IpNetDriverConfig {
    $engineIni = Join-Path $env:LOCALAPPDATA 'SurrounDead\Saved\Config\Windows\Engine.ini'

    Ensure-IniSectionLines -IniPath $engineIni -SectionHeader '[/Script/Engine.Engine]' -DesiredLines @(
        '!NetDriverDefinitions=ClearArray',
        '+NetDriverDefinitions=(DefName="GameNetDriver",DriverClassName="/Script/OnlineSubsystemUtils.IpNetDriver",DriverClassNameFallback="/Script/OnlineSubsystemUtils.IpNetDriver")'
    )

    Ensure-IniSectionLines -IniPath $engineIni -SectionHeader '[/Script/Engine.GameEngine]' -DesiredLines @(
        '!NetDriverDefinitions=ClearArray',
        '+NetDriverDefinitions=(DefName="GameNetDriver",DriverClassName="/Script/OnlineSubsystemUtils.IpNetDriver",DriverClassNameFallback="/Script/OnlineSubsystemUtils.IpNetDriver")'
    )

    Ensure-IniSectionLines -IniPath $engineIni -SectionHeader '[URL]' -DesiredLines @(
        'Port=7777'
    )
}

function Get-ModConfigSnapshot {
    param([string]$ModDir)

    $snapshot = @{}
    $files = @('join_ip.txt', 'host_map.txt')
    foreach ($file in $files) {
        $path = Join-Path $ModDir $file
        if (Test-Path -LiteralPath $path) {
            try {
                $snapshot[$file] = Get-Content -LiteralPath $path -Raw
            } catch {
                # Ignore read errors
            }
        }
    }
    return $snapshot
}

function Restore-ModConfigSnapshot {
    param([string]$ModDir, [hashtable]$Snapshot)

    if (-not $Snapshot) { return }
    foreach ($key in $Snapshot.Keys) {
        $path = Join-Path $ModDir $key
        try {
            Set-Content -LiteralPath $path -Value $Snapshot[$key] -Encoding ASCII
        } catch {
            # Ignore write errors
        }
    }
}

$payloadWin64 = Join-Path $PSScriptRoot 'payload\Win64'
if (-not (Test-Path -LiteralPath $payloadWin64)) {
    Write-Error "Payload not found: $payloadWin64"
    exit 1
}

$candidates = @()
if ($GameRoot) {
    $candidates += $GameRoot
}

$candidates += @(
    'F:\SteamLibrary\steamapps\common\SurrounDead',
    'E:\SteamLibrary\steamapps\common\SurrounDead',
    'D:\SteamLibrary\steamapps\common\SurrounDead',
    'C:\Program Files (x86)\Steam\steamapps\common\SurrounDead',
    'C:\Program Files\Steam\steamapps\common\SurrounDead'
)

$targetWin64 = $null
foreach ($cand in $candidates) {
    $targetWin64 = Resolve-Win64Path -Root $cand
    if ($targetWin64) { break }
}

if (-not $targetWin64) {
    $inputPath = Read-Host 'Enter the path to SurrounDead (folder containing SurrounDead\Binaries\Win64)'
    $targetWin64 = Resolve-Win64Path -Root $inputPath
}

if (-not $targetWin64) {
    Write-Error 'Could not locate SurrounDead\Binaries\Win64. Aborting.'
    exit 1
}

$destMods = Join-Path $targetWin64 'Mods'
New-Item -ItemType Directory -Force -Path $destMods | Out-Null

$loaderFiles = @('dwmapi.dll', 'UE4SS.dll', 'UE4SS-settings.ini')
foreach ($file in $loaderFiles) {
    $src = Join-Path $payloadWin64 $file
    $dst = Join-Path $targetWin64 $file
    if (Test-Path -LiteralPath $src) {
        Backup-IfExists -Path $dst
        Copy-Item -LiteralPath $src -Destination $dst -Force
    }
}

$modSrc = Join-Path $payloadWin64 'Mods\SurrounDeadMPMenu'
$modDst = Join-Path $destMods 'SurrounDeadMPMenu'
if (Test-Path -LiteralPath $modSrc) {
    $snapshot = $null
    if (Test-Path -LiteralPath $modDst) {
        $snapshot = Get-ModConfigSnapshot -ModDir $modDst
        Backup-IfExists -Path $modDst
    }
    Copy-Item -Recurse -Force -LiteralPath $modSrc -Destination $destMods
    if ($snapshot) {
        Restore-ModConfigSnapshot -ModDir $modDst -Snapshot $snapshot
    }
}

$modsTxt = Join-Path $destMods 'mods.txt'
$modsLines = @()
if (Test-Path -LiteralPath $modsTxt) {
    $modsLines = Get-Content -LiteralPath $modsTxt
}

$needsMenu = -not ($modsLines -match '^\s*SurrounDeadMPMenu\s*:')
$needsKeybinds = -not ($modsLines -match '^\s*Keybinds\s*:')

if ($needsMenu -or $needsKeybinds) {
    Backup-IfExists -Path $modsTxt
}

if ($needsMenu) { $modsLines += 'SurrounDeadMPMenu : 1' }
if ($needsKeybinds) { $modsLines += 'Keybinds : 1' }

if (-not (Test-Path -LiteralPath $modsTxt) -or $needsMenu -or $needsKeybinds) {
    Set-Content -LiteralPath $modsTxt -Value $modsLines -Encoding ASCII
}

Ensure-ConsoleKeys
Ensure-IpNetDriverConfig

Write-Host "Installed to: $targetWin64"
Write-Host 'Done. Configure host_map.txt and join_ip.txt if needed.'
