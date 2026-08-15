[CmdletBinding()]
param(
    [string]$WowRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sourceRoot = Join-Path $projectRoot "addon\BetterQuestList"
$deployScript = Join-Path $PSScriptRoot "Deploy.ps1"

function Invoke-Deploy {
    if ($WowRoot) {
        & $deployScript -WowRoot $WowRoot
    } else {
        & $deployScript
    }
}

Invoke-Deploy

$watcher = [System.IO.FileSystemWatcher]::new($sourceRoot)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

Write-Host "Watching $sourceRoot. Press Ctrl+C to stop."
try {
    while ($true) {
        $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
        if (-not $change.TimedOut) {
            do {
                $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 250)
            } while (-not $change.TimedOut)
            Invoke-Deploy
        }
    }
} finally {
    $watcher.Dispose()
}
