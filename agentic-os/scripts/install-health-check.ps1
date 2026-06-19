# Installs AgenticOS-HealthCheck - an INDEPENDENT monitor (pure PowerShell, no claude).
# Runs every 15 minutes; watches the watchdog, heartbeats, and summary freshness.

param([int]$IntervalMinutes = 15)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir   = Split-Path -Parent $ScriptDir
$Script    = Join-Path $ScriptDir "health-check.ps1"
$TaskName  = "AgenticOS-HealthCheck"

Write-Host "Agentic OS Health Check Installer"
Write-Host "================================="
Write-Host ""

if (-not (Test-Path $Script)) {
    Write-Host "ERROR: health-check.ps1 not found at $Script"
    exit 1
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing health-check task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Script`"" `
    -WorkingDirectory $RepoDir

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 365)

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Agentic OS independent health monitor - watches the watchdog, heartbeats, and summary freshness" | Out-Null

Write-Host ""
Write-Host "Health check installed and running."
Write-Host "  Check interval: every $IntervalMinutes minutes"
Write-Host "  Task name:      $TaskName"
Write-Host "  Output:         cron\health.json"
Write-Host ""
Write-Host "To trigger immediately:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "To uninstall:            powershell $(Join-Path $RepoDir 'scripts\uninstall-health-check.ps1')"
