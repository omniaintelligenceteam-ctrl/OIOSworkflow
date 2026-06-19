# Agentic OS Health Check - INDEPENDENT monitor (pure PowerShell, NO claude).
#
# Runs on its own Task Scheduler entry (AgenticOS-HealthCheck). A monitor that
# depends on the thing it watches is useless, so this shares no code path with
# the watchdog and needs no Claude/network. It:
#   - verifies the watchdog task last-result, heartbeat freshness, summary freshness
#   - writes cron/health.json (the durable truth: green | stale | down + reasons)
#   - logs degradations to cron/platform_log.jsonl
#   - fires a best-effort OS toast
#   - does ONE conservative self-heal (re-trigger the watchdog) per stale window
# It always exits 0 (a RED state lives in health.json, not in the task result).

param(
  [int]$StaleAfterHours       = 6,    # daily-summary.json considered stale past this
  [int]$HeartbeatStaleMinutes = 120   # watchdog heartbeat considered stale past this
)

$ErrorActionPreference = "Stop"

$ScriptDir     = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir       = Split-Path -Parent $ScriptDir
$Summary       = Join-Path $RepoDir "outbox\status\daily-summary.json"
$Heartbeat     = Join-Path $RepoDir "cron\heartbeat.watchdog.json"
$State         = Join-Path $RepoDir "cron\watchdog.state.json"
$HealthFile    = Join-Path $RepoDir "cron\health.json"
$PlatformLog   = Join-Path $RepoDir "cron\platform_log.jsonl"
$SelfHeartbeat = Join-Path $RepoDir "cron\heartbeat.health.json"
$WatchdogTask  = "AgenticOS-Watchdog"

$now     = Get-Date
$reasons = New-Object System.Collections.Generic.List[string]
$script:status = "green"

function Demote($level) {
  # one-way: green -> stale -> down
  if ($script:status -eq "down") { return }
  if ($level -eq "down") { $script:status = "down"; return }
  if ($level -eq "stale" -and $script:status -eq "green") { $script:status = "stale" }
}

function Read-JsonSafe($path) {
  # No -Encoding: let Get-Content auto-detect the BOM (state file is UTF-16,
  # our writes are UTF-8-BOM, claude's summary is plain UTF-8).
  try { if (Test-Path $path) { return (Get-Content $path -Raw | ConvertFrom-Json) } } catch { }
  return $null
}

# 1) Watchdog scheduled task last result
try {
  $task = Get-ScheduledTask -TaskName $WatchdogTask -ErrorAction SilentlyContinue
  if (-not $task) {
    Demote "down"; $reasons.Add("watchdog task '$WatchdogTask' not registered")
  } elseif ($task.State -eq "Disabled") {
    Demote "down"; $reasons.Add("watchdog task is Disabled")
  } else {
    $info = $task | Get-ScheduledTaskInfo
    $rc = [uint32]([int64]$info.LastTaskResult -band 0xFFFFFFFF)
    # 0 = success; 0x41300-0x41329 = SCHED_S_* informational (ready/running/queued/not-yet-run).
    # Anything else (e.g. 0xC000013A force-kill, or an app error code) is a real failure.
    $benign = ($rc -eq 0) -or ($rc -ge 0x41300 -and $rc -le 0x41329)
    if (-not $benign) {
      Demote "down"; $reasons.Add(("watchdog last task result 0x{0:X} (failure)" -f $rc))
    }
  }
} catch { Demote "stale"; $reasons.Add("could not query watchdog task: $($_.Exception.Message)") }

# 2) Watchdog heartbeat freshness
$hb = Read-JsonSafe $Heartbeat
if (-not $hb) {
  Demote "down"; $reasons.Add("watchdog heartbeat missing (cron/heartbeat.watchdog.json)")
} else {
  try {
    $hbAge = ($now - [datetime]::Parse($hb.last_run_iso)).TotalMinutes
    if ($hbAge -gt $HeartbeatStaleMinutes) {
      Demote "down"; $reasons.Add(("watchdog heartbeat stale ({0}m old, limit {1}m)" -f [math]::Round($hbAge), $HeartbeatStaleMinutes))
    } elseif ($hb.last_result -eq "error") {
      Demote "stale"; $reasons.Add("watchdog heartbeat last_result=error: $($hb.detail)")
    }
  } catch { Demote "stale"; $reasons.Add("unparseable watchdog heartbeat timestamp") }
}

# 3) digest freshness — authoritative source is the watchdog's OWN run record
#    (watchdog.state.json), NOT claude's self-reported generated_at, which an LLM
#    can mis-stamp. This stays correct even if claude writes a bad summary or none.
$st = Read-JsonSafe $State
if (-not (Test-Path $Summary)) { Demote "down"; $reasons.Add("daily-summary.json missing") }
$digest = if ($st -and $st.PSObject.Properties["daily-digest"]) { $st."daily-digest" } else { $null }
if (-not $digest) {
  Demote "stale"; $reasons.Add("no daily-digest run recorded in watchdog state")
} else {
  if ($digest.last_status -and $digest.last_status -ne "ok") {
    Demote "down"; $reasons.Add("last daily-digest status=$($digest.last_status): $($digest.last_error)")
  }
  try {
    $digAge = ($now - [datetime]::Parse([string]$digest.last_run_iso)).TotalHours
    if ($digAge -gt $StaleAfterHours) {
      Demote "stale"; $reasons.Add(("daily-digest last ran {0}h ago (limit {1}h)" -f [math]::Round($digAge,1), $StaleAfterHours))
    }
  } catch { Demote "stale"; $reasons.Add("daily-digest last_run_iso unparseable") }
}

# 4) per-job consecutive failures recorded by the watchdog
if ($st) {
  foreach ($p in $st.PSObject.Properties) {
    $v = $p.Value
    if ($v.PSObject.Properties["consecutive_failures"] -and [int]$v.consecutive_failures -ge 2) {
      Demote "stale"; $reasons.Add(("job '{0}' has {1} consecutive failures" -f $p.Name, $v.consecutive_failures))
    }
  }
}

if ($reasons.Count -eq 0) { $reasons.Add("all checks passed") }

# --- Conservative self-heal: re-trigger watchdog at most once per stale window ---
$prior = Read-JsonSafe $HealthFile
$lastHealIso = if ($prior -and $prior.PSObject.Properties["last_heal_iso"]) { [string]$prior.last_heal_iso } else { $null }
$canHeal = $true
if ($lastHealIso) {
  try { if (($now - [datetime]::Parse($lastHealIso)).TotalMinutes -lt ($StaleAfterHours * 60)) { $canHeal = $false } } catch { }
}
$healed = $false
if ($script:status -ne "green" -and $canHeal) {
  try {
    $t = Get-ScheduledTask -TaskName $WatchdogTask -ErrorAction SilentlyContinue
    if ($t -and $t.State -ne "Disabled") {
      Start-ScheduledTask -TaskName $WatchdogTask
      $healed = $true
      $reasons.Add("self-heal: re-triggered $WatchdogTask")
    }
  } catch { $reasons.Add("self-heal failed: $($_.Exception.Message)") }
}

# --- Write health.json (atomic) ---
$health = [ordered]@{
  status            = $script:status
  reasons           = $reasons
  checked_at        = $now.ToString("o")
  stale_after_hours = $StaleAfterHours
  last_heal_iso     = if ($healed) { $now.ToString("o") } else { $lastHealIso }
}
try {
  $tmp = "$HealthFile.tmp"
  $health | ConvertTo-Json -Depth 6 | Set-Content -Path $tmp -Encoding UTF8
  Move-Item -Path $tmp -Destination $HealthFile -Force
} catch { }

# Keep the human-facing summary's health block current. We own health; the watchdog
# owns generated_at, so update ONLY .health (freshness signals stay untouched).
try {
  if (Test-Path $Summary) {
    $sumObj = Get-Content $Summary -Raw | ConvertFrom-Json
    $hb2 = [PSCustomObject]@{ status = $script:status; checked_at = $now.ToString("o"); stale_after_hours = $StaleAfterHours }
    if ($sumObj.PSObject.Properties["health"]) { $sumObj.health = $hb2 }
    else { $sumObj | Add-Member -NotePropertyName health -NotePropertyValue $hb2 }
    $sumTmp = "$Summary.tmp"
    $sumObj | ConvertTo-Json -Depth 20 | Set-Content -Path $sumTmp -Encoding UTF8
    Move-Item -Path $sumTmp -Destination $Summary -Force
  }
} catch { }

# --- Self heartbeat (so we can tell the monitor itself is alive) ---
try {
  $tmp2 = "$SelfHeartbeat.tmp"
  @{ task = "AgenticOS-HealthCheck"; last_run_iso = $now.ToString("o"); status = $script:status; pid = $PID } |
    ConvertTo-Json | Set-Content -Path $tmp2 -Encoding UTF8
  Move-Item -Path $tmp2 -Destination $SelfHeartbeat -Force
} catch { }

# --- Log + alert only when not green (avoid steady-state spam) ---
if ($script:status -ne "green") {
  $msg = "Agentic OS health=$($script:status) :: " + ($reasons -join "; ")
  try {
    $entry = [ordered]@{ timestamp = $now.ToString("o"); domain = "health"; task = "health-check"; status = $script:status; message = $msg; healed = $healed }
    Add-Content -Path $PlatformLog -Value ($entry | ConvertTo-Json -Compress -Depth 6) -Encoding UTF8 -ErrorAction SilentlyContinue
  } catch { }
  # Best-effort OS toast (never fatal).
  try {
    Import-Module BurntToast -ErrorAction Stop
    New-BurntToastNotification -Text "Agentic OS: $($script:status)", $msg | Out-Null
  } catch {
    try {
      Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
      Add-Type -AssemblyName System.Drawing -ErrorAction Stop
      $ni = New-Object System.Windows.Forms.NotifyIcon
      $ni.Icon = [System.Drawing.SystemIcons]::Warning
      $ni.Visible = $true
      $ni.ShowBalloonTip(10000, "Agentic OS: $($script:status)", $msg, [System.Windows.Forms.ToolTipIcon]::Warning)
      Start-Sleep -Milliseconds 300
      $ni.Dispose()
    } catch { }
  }
}

Write-Output "health=$($script:status); reasons: $($reasons -join '; ')"
exit 0
