# ONE-TIME setup: register scheduled task for NFG Word Games auto-deploy
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DeployScript = Join-Path $ScriptDir "auto-deploy.ps1"
$TaskName = "NFG Word Games Auto Update"

if (-not (Test-Path $DeployScript)) {
    Write-Error "Missing $DeployScript"
    exit 1
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$DeployScript`""

$triggers = @(
    (New-ScheduledTaskTrigger -AtLogOn),
    (New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue))
)

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $triggers `
    -Settings $settings `
    -Principal $principal `
    -Force | Out-Null

Write-Host ""
Write-Host "Scheduled task registered: $TaskName"
Write-Host ""
Write-Host "Verify:"
Write-Host "  Get-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Get-Content (Join-Path '$ScriptDir' 'deploy.log') -Tail 20"
Write-Host ""
Write-Host "Optional manual run:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$DeployScript`""
Write-Host ""
Write-Host "Uninstall:"
Write-Host "  powershell -ExecutionPolicy Bypass -File `"$(Join-Path $ScriptDir 'uninstall-auto-update-task.ps1')`""
Write-Host ""
Write-Host "Note: Task runs while you are logged in (every 5 min + at logon)."
Write-Host "After Mac pushes, server auto-updates within 5 minutes."
