[CmdletBinding()]
param(
    [string]$WowRoot,
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRoot = $projectRoot
$tocPath = Join-Path $sourceRoot "BetterQuestList.toc"
$localConfigPath = Join-Path $projectRoot ".deploy.local.ps1"
$BetterQuestListWowRoot = $null

if (-not $WowRoot -and $env:WOW_RETAIL_PATH) {
    $WowRoot = $env:WOW_RETAIL_PATH
}

if (-not $WowRoot -and (Test-Path -LiteralPath $localConfigPath -PathType Leaf)) {
    . $localConfigPath
    $WowRoot = $BetterQuestListWowRoot
}

if (-not $WowRoot) {
    throw "WoW Retail path is not configured. Pass -WowRoot, set WOW_RETAIL_PATH, or create .deploy.local.ps1."
}

& (Join-Path $PSScriptRoot "Validate.ps1")

$resolvedWowRoot = [System.IO.Path]::GetFullPath($WowRoot)
$interfaceRoot = Join-Path $resolvedWowRoot "Interface"
$addOnsRoot = [System.IO.Path]::GetFullPath((Join-Path $interfaceRoot "AddOns"))
if (-not (Test-Path -LiteralPath $addOnsRoot -PathType Container)) {
    throw "WoW AddOns directory does not exist: $addOnsRoot"
}

$destinationRoot = [System.IO.Path]::GetFullPath((Join-Path $addOnsRoot "BetterQuestList"))
$destinationParent = [System.IO.Directory]::GetParent($destinationRoot).FullName
if (
    [System.IO.Path]::GetFileName($destinationRoot) -ne "BetterQuestList" -or
    -not $destinationParent.Equals($addOnsRoot, [System.StringComparison]::OrdinalIgnoreCase)
) {
    throw "Refusing unsafe deployment target: $destinationRoot"
}

if ((Test-Path -LiteralPath $destinationRoot) -and -not $NoClean) {
    Remove-Item -LiteralPath $destinationRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $destinationRoot -Force | Out-Null

$addonEntries = @("BetterQuestList.toc")
$addonEntries += Get-Content -LiteralPath $tocPath | Where-Object {
    $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
}
$addonEntries += @("Media\BetterQuestListIcon.tga")

foreach ($entry in $addonEntries) {
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
    $relativePath = $entry.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
    $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $relativePath))
    $destinationPath = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot $relativePath))
    $destinationDirectory = [System.IO.Directory]::GetParent($destinationPath).FullName
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

Write-Host "Deployed BetterQuestList to $destinationRoot"
