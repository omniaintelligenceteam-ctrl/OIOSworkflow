# Removes the AgenticOS-HealthCheck scheduled task. Leaves cron/health.json in place.

$ErrorActionPreference = "Stop"
$TaskName = "AgenticOS-HealthCheck"

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task: $TaskName"
} else {
    Write-Host "$TaskName not found (nothing to remove)."
}
