[CmdletBinding()]
param(
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRoot = $projectRoot
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

    $addonEntries = @("BetterQuestList.toc")
    $addonEntries += Get-Content -LiteralPath $tocPath | Where-Object {
        $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
    }
    $addonEntries += @("Media\BetterQuestListIcon.tga")
    foreach ($entry in $addonEntries) {
        $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
        $relativePath = $entry.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator)
        $sourcePath = [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $relativePath))
        $stagedPath = [System.IO.Path]::GetFullPath((Join-Path $stagedAddon $relativePath))
        $stagedDirectory = [System.IO.Directory]::GetParent($stagedPath).FullName
        New-Item -ItemType Directory -Path $stagedDirectory -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $stagedPath -Force
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
