[CmdletBinding()]
param(
    [string]$WowRoot,
    [switch]$NoClean
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "addon\BetterQuestList"))
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
$addOnsRoot = [System.IO.Path]::GetFullPath((Join-Path $resolvedWowRoot "Interface\AddOns"))
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

foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
    Copy-Item -LiteralPath $item.FullName -Destination $destinationRoot -Recurse -Force
}

Write-Host "Deployed BetterQuestList to $destinationRoot"
