# Agentic OS Inbox Watcher Uninstaller
# Removes the inbox watcher scheduled task.

param(
  [string]$TaskName = "AgenticOS-InboxWatcher"
)

$ErrorActionPreference = "Stop"

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -eq $task) {
    Write-Host "Task not found: $TaskName"
    Write-Host "Nothing to uninstall."
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Write-Host "Removed scheduled task: $TaskName"
Write-Host "Inbox watcher has been uninstalled."
