# Agentic OS Inbox Watcher Installer — Windows Task Scheduler
# Runs inbox-watcher.ps1 every 10 minutes to process OpenClaw requests.

param(
  [int]$IntervalMinutes = 10
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$WatcherScript = Join-Path $ScriptDir "inbox-watcher.ps1"
$TaskName = "AgenticOS-InboxWatcher"

Write-Host "Agentic OS Inbox Watcher Installer"
Write-Host "===================================="
Write-Host ""

# Check claude CLI
$claudePath = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudePath) {
    Write-Host "ERROR: 'claude' CLI not found."
    Write-Host "Install it first: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
}

# Check watcher script exists
if (-not (Test-Path $WatcherScript)) {
    Write-Host "ERROR: inbox-watcher.ps1 not found at $WatcherScript"
    exit 1
}

# Ensure logs directory
$LogsDir = Join-Path $RepoDir "logs"
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null

# Ensure outbox directories
$outboxDirs = @(
    "outbox\inbox\pending",
    "outbox\inbox\processing",
    "outbox\inbox\done",
    "outbox\actions\pending",
    "outbox\actions\processing",
    "outbox\actions\completed",
    "outbox\actions\failed",
    "outbox\status"
)
foreach ($dir in $outboxDirs) {
    $fullPath = Join-Path $RepoDir $dir
    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing inbox watcher task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create scheduled task
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$WatcherScript`" -Root `"$RepoDir`"" `
    -WorkingDirectory $RepoDir

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType InteractiveToken `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes $IntervalMinutes)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Agentic OS inbox watcher — processes OpenClaw requests every $IntervalMinutes min" | Out-Null

Write-Host ""
Write-Host "Inbox watcher installed and running."
Write-Host ""
Write-Host "  Check interval:  every $IntervalMinutes minutes"
Write-Host "  Task name:       $TaskName"
Write-Host "  Logs:            $LogsDir\inbox-watcher.log"
Write-Host ""
Write-Host "To trigger immediately:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "To uninstall:            powershell $RepoDir\scripts\uninstall-inbox-watcher.ps1"
