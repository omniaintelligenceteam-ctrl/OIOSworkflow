# Agentic OS Watchdog - Windows version
# Runs scheduled jobs outside Claude Code sessions via Task Scheduler.
# Hardened: bounded per-job claude exec (a hung claude is killed by US, not by
# Task Scheduler force-killing the whole task), persistent run log, per-job
# failure tracking, and a heartbeat written every run so a dead watchdog is
# detectable from outside.

$ErrorActionPreference = "Stop"

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir     = Split-Path -Parent $ScriptDir
$JobsDir     = Join-Path $RepoDir "cron\jobs"
$LogsDir     = Join-Path $RepoDir "cron\logs"
$StateFile   = Join-Path $RepoDir "cron\watchdog.state.json"
$LockFile    = Join-Path $RepoDir "cron\.watchdog.lock"
$WatchdogLog = Join-Path $LogsDir "watchdog.log"
$Heartbeat   = Join-Path $RepoDir "cron\heartbeat.watchdog.json"
$PlatformLog = Join-Path $RepoDir "cron\platform_log.jsonl"
$DefaultJobTimeout = 600   # seconds per job; override per-job with `max_timeout_seconds:` in frontmatter

$Intervals = @{
    "every_10m" = 600
    "every_30m" = 1800
    "every_1h"  = 3600
    "every_2h"  = 7200
    "every_4h"  = 14400
}

# Logs dir must exist before the first Log() call (the lock check logs early).
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null

function Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Output $line
    Add-Content -Path $WatchdogLog -Value $line -ErrorAction SilentlyContinue
}

function Write-Heartbeat($result, $detail) {
    try {
        $hb = @{
            task         = "AgenticOS-Watchdog"
            last_run_iso = (Get-Date).ToString("o")
            last_result  = $result          # ok | partial | error
            detail       = $detail
            pid          = $PID
        }
        $tmp = "$Heartbeat.tmp"
        $hb | ConvertTo-Json | Set-Content -Path $tmp -Encoding UTF8
        Move-Item -Path $tmp -Destination $Heartbeat -Force
    } catch { }
}

function Add-PlatformLog($obj) {
    try {
        Add-Content -Path $PlatformLog -Value ($obj | ConvertTo-Json -Compress -Depth 10) -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch { }
}

# Lock check
if (Test-Path $LockFile) {
    $oldPid = Get-Content $LockFile -ErrorAction SilentlyContinue
    if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
        Log "Another watchdog is running (PID $oldPid). Exiting."
        exit 0
    }
    Log "Stale lock found. Removing."
    Remove-Item $LockFile -Force
}

$PID | Out-File $LockFile -Force
$hadError = $false
$runCount = 0
try {
    # Check claude CLI
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Log "ERROR: 'claude' CLI not found on PATH."
        Write-Heartbeat "error" "claude CLI not found on PATH"
        exit 1
    }

    # Init state
    if (-not (Test-Path $StateFile)) { "{}" | Out-File $StateFile }

    if (-not (Test-Path $JobsDir)) {
        Log "No jobs directory found. Nothing to do."
        Write-Heartbeat "ok" "no jobs directory"
        exit 0
    }

    $state = Get-Content $StateFile -Raw | ConvertFrom-Json
    $jobCount = 0

    foreach ($jobFile in Get-ChildItem "$JobsDir\*.md") {
        $content = Get-Content $jobFile.FullName -Raw

        # Parse YAML frontmatter
        if ($content -notmatch '(?s)^---\s*\n(.*?)\n---') { continue }
        $fm = @{}
        foreach ($line in ($Matches[1] -split "`n")) {
            if ($line -match '^(\w+):\s*(.*)$') {
                $fm[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
            }
        }

        $name       = $fm["name"]
        $schedule   = $fm["schedule"]
        $model      = if ($fm["model"]) { $fm["model"] } else { "sonnet" }
        $budget     = if ($fm["max_budget_usd"]) { $fm["max_budget_usd"] } else { "0.50" }
        $enabled    = if ($fm["enabled"]) { $fm["enabled"] } else { "true" }
        $jobTimeout = if ($fm["max_timeout_seconds"]) { [int]$fm["max_timeout_seconds"] } else { $DefaultJobTimeout }

        if ($enabled -ne "true") { continue }
        if ($schedule -eq "session_start") { continue }

        $jobCount++

        $interval = $Intervals[$schedule]
        if (-not $interval) {
            Log "WARN: Unknown schedule '$schedule' for $name"
            continue
        }

        $lastRun = 0
        if ($state.PSObject.Properties[$name]) {
            $lastRun = [int]$state.$name.last_run
        }
        $now = [int](Get-Date -UFormat %s)
        $elapsed = $now - $lastRun

        if ($elapsed -lt $interval) {
            $remaining = [math]::Round(($interval - $elapsed) / 60)
            Log "$name`: not due yet (${remaining}m remaining)"
            continue
        }

        # --- Execute (bounded) ---
        Log "$name`: RUNNING (model=$model, budget=`$$budget, timeout=${jobTimeout}s)"
        $runCount++

        # Prompt = everything after the second ---
        $promptBody = ($content -replace '(?s)^---.*?---\s*\n', '').Trim()
        $today = Get-Date -Format "yyyy-MM-dd"
        $logFile = Join-Path $LogsDir "${name}_${today}.log"
        Add-Content $logFile "=== Run at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="

        $jobStatus = "ok"
        $jobError = $null
        try {
            # Run claude in a child job so a hang can be bounded + killed cleanly.
            # (Direct PS invocation preserves the working .ps1-wrapper resolution.)
            $sb = {
                param($prompt, $jobModel, $allowed, $workdir)
                $ErrorActionPreference = "Continue"
                # Start-Job does NOT inherit the watchdog's working dir; without this,
                # claude runs in the wrong cwd, can't find outbox/, and writes a phantom one.
                Set-Location -LiteralPath $workdir
                $out = claude -p $prompt --model $jobModel --max-turns 25 --permission-mode bypassPermissions --allowedTools $allowed 2>&1 | Out-String
                [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $out }
            }
            $job = Start-Job -ScriptBlock $sb -ArgumentList $promptBody, $model, "Read,Write,Edit,Bash,Glob,Grep,WebSearch,WebFetch", $RepoDir
            if (Wait-Job $job -Timeout $jobTimeout) {
                $res = Receive-Job $job
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                if ($res -and $res.Output) { Add-Content $logFile $res.Output }
                $exitCode = if ($res -and $null -ne $res.ExitCode) { [int]$res.ExitCode } else { 0 }
                if ($exitCode -ne 0) { throw "claude exited with code $exitCode" }
            } else {
                Stop-Job $job -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                throw "claude timed out after ${jobTimeout}s (killed)"
            }
        } catch {
            $jobStatus = "error"
            $jobError = "$($_.Exception.Message)"
            $hadError = $true
            Add-Content $logFile "[watchdog] ERROR: $jobError"
            Log "$name`: ERROR - $jobError"
            Add-PlatformLog ([ordered]@{ timestamp=(Get-Date).ToString("o"); domain="watchdog"; task=$name; status="error"; message=$jobError })
        }

        Add-Content $logFile "=== End run ===`n"

        # Update state. Advance last_run even on error to avoid an hourly hot-loop
        # on a broken job; the health monitor surfaces the failure instead.
        $prevFails = 0
        if ($state.PSObject.Properties[$name] -and $state.$name.PSObject.Properties["consecutive_failures"]) {
            $prevFails = [int]$state.$name.consecutive_failures
        }
        $jobState = [PSCustomObject]@{
            last_run             = "$now"
            last_run_iso         = (Get-Date).ToString("o")
            last_status          = $jobStatus
            last_error           = $jobError
            consecutive_failures = if ($jobStatus -eq "error") { $prevFails + 1 } else { 0 }
        }
        if ($state.PSObject.Properties[$name]) {
            $state.$name = $jobState
        } else {
            $state | Add-Member -NotePropertyName $name -NotePropertyValue $jobState
        }
        $state | ConvertTo-Json -Depth 10 | Out-File $StateFile

        # Deterministically stamp the human-facing summary. claude mis-sets these
        # (it used midnight for generated_at and skipped health), so PowerShell owns them.
        if ($name -eq "daily-digest" -and $jobStatus -eq "ok") {
            $sumPath = Join-Path $RepoDir "outbox\status\daily-summary.json"
            if (Test-Path $sumPath) {
                try {
                    $s = Get-Content $sumPath -Raw | ConvertFrom-Json
                    $s.generated_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                    $s.date = (Get-Date).ToString("yyyy-MM-dd")
                    $hPath = Join-Path $RepoDir "cron\health.json"
                    $healthObj = if (Test-Path $hPath) {
                        $h = Get-Content $hPath -Raw | ConvertFrom-Json
                        [PSCustomObject]@{ status = $h.status; checked_at = $h.checked_at; stale_after_hours = $h.stale_after_hours }
                    } else {
                        [PSCustomObject]@{ status = "unknown"; checked_at = $null; stale_after_hours = 6 }
                    }
                    if ($s.PSObject.Properties["health"]) { $s.health = $healthObj }
                    else { $s | Add-Member -NotePropertyName health -NotePropertyValue $healthObj }
                    $sumTmp = "$sumPath.tmp"
                    $s | ConvertTo-Json -Depth 20 | Set-Content -Path $sumTmp -Encoding UTF8
                    Move-Item -Path $sumTmp -Destination $sumPath -Force
                    Log "$name`: stamped generated_at + health into daily-summary.json"
                } catch {
                    Log "$name`: WARN could not stamp summary: $($_.Exception.Message)"
                }
            }
        }
        Log "$name`: completed ($jobStatus). Log at $logFile"
    }

    Log "Done. $jobCount enabled jobs found, $runCount executed."
    if ($hadError) { Write-Heartbeat "partial" "$runCount run, >=1 job errored" }
    else { Write-Heartbeat "ok" "$jobCount checked, $runCount executed" }
} catch {
    Log "FATAL: $($_.Exception.Message)"
    Write-Heartbeat "error" "fatal: $($_.Exception.Message)"
    throw
} finally {
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
