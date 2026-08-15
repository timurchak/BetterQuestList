[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "addon\BetterQuestList"))
$tocPath = Join-Path $sourceRoot "BetterQuestList.toc"

& (Join-Path $PSScriptRoot "Validate.ps1")

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot "dist"
} elseif (-not [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot $OutputDirectory
}
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$toc = Get-Content -LiteralPath $tocPath
$versionLine = $toc | Where-Object { $_ -match '^## Version:\s*(.+?)\s*$' } | Select-Object -First 1
$version = ([regex]::Match($versionLine, '^## Version:\s*(.+?)\s*$')).Groups[1].Value
$zipPath = Join-Path $OutputDirectory "BetterQuestList-$version.zip"

$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("BetterQuestList-package-" + [guid]::NewGuid().ToString("N"))
$stagedAddon = Join-Path $temporaryRoot "BetterQuestList"

try {
    New-Item -ItemType Directory -Path $stagedAddon -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $sourceRoot -Force) {
        Copy-Item -LiteralPath $item.FullName -Destination $stagedAddon -Recurse -Force
    }

    if (Test-Path -LiteralPath $zipPath -PathType Leaf) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -LiteralPath $stagedAddon -DestinationPath $zipPath -CompressionLevel Optimal
} finally {
    $resolvedTemporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
    $systemTemporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (
        $resolvedTemporaryRoot.StartsWith($systemTemporaryRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        [System.IO.Path]::GetFileName($resolvedTemporaryRoot).StartsWith("BetterQuestList-package-") -and
        (Test-Path -LiteralPath $resolvedTemporaryRoot)
    ) {
        Remove-Item -LiteralPath $resolvedTemporaryRoot -Recurse -Force
    }
}

Write-Host "Created package: $zipPath"
