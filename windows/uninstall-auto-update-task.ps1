# Remove NFG Word Games auto-update scheduled task
$ErrorActionPreference = "Stop"

$TaskName = "NFG Word Games Auto Update"

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "Task '$TaskName' is not installed."
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Removed scheduled task: $TaskName"
