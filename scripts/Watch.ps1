[CmdletBinding()]
param(
    [string]$WowRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$tocPath = Join-Path $projectRoot "BetterQuestList.toc"
$deployScript = Join-Path $PSScriptRoot "Deploy.ps1"

function Invoke-Deploy {
    if ($WowRoot) {
        & $deployScript -WowRoot $WowRoot
    } else {
        & $deployScript
    }
}

function Get-WatchedPaths {
    $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
    $paths = @("BetterQuestList.toc")
    $paths += Get-Content -LiteralPath $tocPath | Where-Object {
        $_ -and -not $_.StartsWith("##") -and -not $_.StartsWith("#")
    }

    $result = @{}
    foreach ($path in $paths) {
        $normalized = $path.Trim().Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator).ToLowerInvariant()
        $result[$normalized] = $true
    }
    return $result
}

Invoke-Deploy
$watchedPaths = Get-WatchedPaths

$watcher = [System.IO.FileSystemWatcher]::new($projectRoot)
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true

Write-Host "Watching BetterQuestList runtime files. Press Ctrl+C to stop."
try {
    while ($true) {
        $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
        if (-not $change.TimedOut) {
            $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
            $changedPath = $change.Name.Replace([char]92, $directorySeparator).Replace([char]47, $directorySeparator).ToLowerInvariant()
            if ($watchedPaths.ContainsKey($changedPath)) {
                do {
                    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 250)
                } while (-not $change.TimedOut)
                Invoke-Deploy
                $watchedPaths = Get-WatchedPaths
            }
        }
    }
} finally {
    $watcher.Dispose()
}
