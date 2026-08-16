[CmdletBinding()]
param(
    [string]$ExpectedVersion
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$addonRoot = $projectRoot
$tocPath = Join-Path $projectRoot "BetterQuestList.toc"

if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
    throw "Missing TOC file: $tocPath"
}

$tocLines = Get-Content -LiteralPath $tocPath
$versionLine = $tocLines | Where-Object { $_ -match '^## Version:\s*(.+?)\s*$' } | Select-Object -First 1
$interfaceLine = $tocLines | Where-Object { $_ -match '^## Interface:\s*(\d+)\s*$' } | Select-Object -First 1

if (-not $versionLine) {
    throw "BetterQuestList.toc does not contain a Version field."
}
if (-not $interfaceLine) {
    throw "BetterQuestList.toc does not contain a numeric Interface field."
}

$version = ([regex]::Match($versionLine, '^## Version:\s*(.+?)\s*$')).Groups[1].Value
if ($ExpectedVersion -and $version -ne $ExpectedVersion.TrimStart('v')) {
    throw "TOC version '$version' does not match expected version '$ExpectedVersion'."
}

$manifestEntries = $tocLines | Where-Object {
    $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
}
$runtimeAssets = @("Media\BetterQuestListIcon.tga")

$missingFiles = @()
$directorySeparator = [System.IO.Path]::DirectorySeparatorChar
$addonPrefix = $addonRoot.TrimEnd([char[]]@([char]92, [char]47)) + $directorySeparator
foreach ($entry in $manifestEntries) {
    $relativePath = $entry.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $relativePath))
    if (-not $fullPath.StartsWith($addonPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "TOC entry escapes the addon directory: $entry"
    }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $missingFiles += $entry
    }
}

foreach ($entry in $runtimeAssets) {
    $relativePath = $entry.Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $addonRoot $relativePath))
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $missingFiles += $entry
    }
}

if ($missingFiles.Count -gt 0) {
    throw "TOC references missing files: $($missingFiles -join ', ')"
}

$luaFiles = @(
    foreach ($entry in $manifestEntries) {
        if ([System.IO.Path]::GetExtension($entry.Trim()) -ieq ".lua") {
            $relativePath = $entry.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
            Get-Item -LiteralPath (Join-Path $addonRoot $relativePath)
        }
    }
)
if ($luaFiles.Count -eq 0) {
    throw "No Lua source files found under $addonRoot"
}

foreach ($luaFile in $luaFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($luaFile.FullName)
    if ($bytes -contains 0) {
        throw "Lua source contains a NUL byte: $($luaFile.FullName)"
    }
}

$npxCommand = Get-Command "npx.cmd" -ErrorAction SilentlyContinue
if (-not $npxCommand) {
    $npxCommand = Get-Command "npx" -ErrorAction SilentlyContinue
}
if (-not $npxCommand) {
    throw "Lua syntax validation requires Node.js/npx."
}

& $npxCommand.Source --yes luaparse@0.3.1 --quiet @($luaFiles.FullName)
if ($LASTEXITCODE -ne 0) {
    throw "Lua syntax validation failed."
}

Write-Host "Validated BetterQuestList $version ($($luaFiles.Count) parsed Lua files, $($manifestEntries.Count) TOC entries)."
