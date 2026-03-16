# Agentic OS Inbox Watcher
# Polls outbox/inbox/pending/ for OpenClaw requests and routes them to skills.
# Runs as a dedicated Task Scheduler job every 10 minutes.

param(
  [string]$Root = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"

# --- Paths ---
$outbox        = Join-Path $Root "outbox"
$inboxPending  = Join-Path $outbox "inbox\pending"
$inboxProc     = Join-Path $outbox "inbox\processing"
$inboxDone     = Join-Path $outbox "inbox\done"
$actionsPending = Join-Path $outbox "actions\pending"
$skillsDir     = Join-Path $Root ".claude\skills"
$configDir     = Join-Path $outbox "config"
$logDir        = Join-Path $Root "logs"
$logFile       = Join-Path $logDir "inbox-watcher.log"
$lockFile      = Join-Path $outbox "inbox\.watcher.lock"
$rateFile      = Join-Path $logDir "inbox-watcher-rate.json"

# --- Helpers ---
function Log($msg) {
  $line = "[{0}] {1}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"), $msg
  Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
}

function AtomicWriteJson($path, $obj) {
  $tmp = "$path.tmp"
  $json = $obj | ConvertTo-Json -Depth 20
  Set-Content -Path $tmp -Value $json -Encoding UTF8
  Move-Item -Path $tmp -Destination $path -Force
}

function ReadJson($path) {
  return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function NewErrorObj($code, $message, [bool]$retryable = $false) {
  return @{
    code      = $code
    message   = $message
    at        = (Get-Date).ToString("o")
    retryable = $retryable
  }
}

function GenerateId($prefix) {
  $ts = [int][double]::Parse((Get-Date -UFormat %s))
  $hex = (Get-Random -Maximum 0xffffff).ToString("x6")
  return "${prefix}_${ts}_${hex}"
}

function ComputeExecutionKey($id, $action, $content) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $payload = "${id}:${action}:${content}"
  $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
  $hash = $sha.ComputeHash($bytes)
  return ([BitConverter]::ToString($hash)).Replace("-", "").ToLower()
}

function Get-AllowedSkills() {
  if (!(Test-Path $skillsDir)) { return @() }
  return (Get-ChildItem -Path $skillsDir -Directory | Where-Object { $_.Name -ne "_catalog" } | Select-Object -ExpandProperty Name)
}

function Get-RateLimits() {
  $path = Join-Path $configDir "rate-limits.json"
  if (Test-Path $path) { return ReadJson $path }
  return @{ inbox = @{ max_requests_per_hour = 10 }; watcher = @{ wall_clock_timeout_seconds = 300; claude_max_turns = 25; stuck_processing_minutes = 30 } }
}

function IsRateLimited($limits) {
  $maxPerHour = $limits.inbox.max_requests_per_hour
  if (!(Test-Path $rateFile)) {
    @{ hour = (Get-Date).Hour; count = 0 } | ConvertTo-Json | Set-Content $rateFile
    return $false
  }
  $rate = ReadJson $rateFile
  $currentHour = (Get-Date).Hour
  if ($rate.hour -ne $currentHour) {
    # New hour — reset counter
    @{ hour = $currentHour; count = 0 } | ConvertTo-Json | Set-Content $rateFile
    return $false
  }
  return ($rate.count -ge $maxPerHour)
}

function IncrementRateCounter() {
  if (!(Test-Path $rateFile)) {
    @{ hour = (Get-Date).Hour; count = 1 } | ConvertTo-Json | Set-Content $rateFile
    return
  }
  $rate = ReadJson $rateFile
  $currentHour = (Get-Date).Hour
  if ($rate.hour -ne $currentHour) {
    @{ hour = $currentHour; count = 1 } | ConvertTo-Json | Set-Content $rateFile
  } else {
    $rate.count = [int]$rate.count + 1
    $rate | ConvertTo-Json | Set-Content $rateFile
  }
}

function BuildPrompt($skillHint, $requestText) {
  return @"
You are running as a scheduled job for Agentic OS.
Read CLAUDE.md for system context. Read context/SOUL.md for voice.

Use the $skillHint skill to fulfill this request:
---USER REQUEST START---
$requestText
---USER REQUEST END---

After generating the content, save it as a JSON action file in outbox/actions/pending/ using the ops-outbox skill's action schema.
The action file must include: schema_version, id, action, content, media, priority, created_at, created_by, approval_required, status, error, retries, execution_key, signature.
Use atomic write protocol: write to .tmp first, then rename to .json.
"@
}

function CleanStuckProcessing($limits) {
  $stuckMinutes = $limits.watcher.stuck_processing_minutes
  if (!(Test-Path $inboxProc)) { return }
  $cutoff = (Get-Date).AddMinutes(-$stuckMinutes)
  Get-ChildItem -Path $inboxProc -Filter *.json -File | ForEach-Object {
    if ($_.LastWriteTime -lt $cutoff) {
      try {
        $req = ReadJson $_.FullName
        $req.status = "error"
        $req | Add-Member -NotePropertyName "error" -NotePropertyValue (NewErrorObj "STUCK_TIMEOUT" "Processing exceeded ${stuckMinutes}m timeout" $true) -Force
        $dest = Join-Path $inboxDone $_.Name
        AtomicWriteJson $dest $req
        Remove-Item $_.FullName -Force
        Log "Cleaned stuck request: $($_.Name)"
      } catch {
        Log "Error cleaning stuck file $($_.Name): $($_.Exception.Message)"
      }
    }
  }
}

# --- Main ---

# Ensure directories exist
@($inboxPending, $inboxProc, $inboxDone, $actionsPending, $logDir) | ForEach-Object {
  if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# Lock check — prevent overlapping runs
if (Test-Path $lockFile) {
  $oldPid = Get-Content $lockFile -ErrorAction SilentlyContinue
  if ($oldPid -and (Get-Process -Id $oldPid -ErrorAction SilentlyContinue)) {
    Log "Another inbox watcher is running (PID $oldPid). Exiting."
    exit 0
  }
  Log "Stale lock found. Removing."
  Remove-Item $lockFile -Force
}

$PID | Out-File $lockFile -Force

try {
  # Check claude CLI
  if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Log "ERROR: 'claude' CLI not found on PATH."
    exit 1
  }

  $limits = Get-RateLimits
  $allowedSkills = Get-AllowedSkills
  $timeout = if ($limits.watcher.wall_clock_timeout_seconds) { $limits.watcher.wall_clock_timeout_seconds } else { $TimeoutSeconds }
  $maxTurns = if ($limits.watcher.claude_max_turns) { $limits.watcher.claude_max_turns } else { 25 }

  # Clean stuck processing files first
  CleanStuckProcessing $limits

  # Process inbox requests
  $files = Get-ChildItem -Path $inboxPending -Filter *.json -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime
  if (-not $files) {
    Log "No pending inbox requests."
    exit 0
  }

  $processed = 0
  $skipped = 0

  foreach ($file in $files) {
    try {
      # Rate limit check
      if (IsRateLimited $limits) {
        $req = ReadJson $file.FullName
        $req.status = "rate_limited"
        $req | Add-Member -NotePropertyName "error" -NotePropertyValue (NewErrorObj "RATE_LIMIT" "Max inbox requests/hour exceeded." $false) -Force
        $dest = Join-Path $inboxDone $file.Name
        AtomicWriteJson $dest $req
        Remove-Item $file.FullName -Force
        Log "Rate limited: $($file.Name)"
        $skipped++
        continue
      }

      # Claim the request — move to processing
      $processingPath = Join-Path $inboxProc $file.Name
      Move-Item -Path $file.FullName -Destination $processingPath -Force

      $req = ReadJson $processingPath

      # Validate schema version
      if ($req.schema_version -notmatch "^1\.\d+$") {
        throw "Unsupported schema_version: $($req.schema_version)"
      }

      # Validate skill hint against allowlist
      if ($allowedSkills -notcontains $req.skill_hint) {
        throw "Invalid skill_hint: '$($req.skill_hint)'. Allowed: $($allowedSkills -join ', ')"
      }

      # Validate request length
      $maxChars = if ($limits.inbox.max_request_chars) { $limits.inbox.max_request_chars } else { 8000 }
      if ($req.request.Length -gt $maxChars) {
        throw "Request exceeds max length ($($req.request.Length) > $maxChars chars)"
      }

      # Build prompt and write to temp file (avoids shell escaping issues)
      $prompt = BuildPrompt $req.skill_hint $req.request
      $promptFile = Join-Path $env:TEMP ("inbox_prompt_" + [guid]::NewGuid().ToString() + ".txt")
      Set-Content -Path $promptFile -Value $prompt -Encoding UTF8

      Log "Processing: $($file.Name) [skill=$($req.skill_hint), priority=$($req.priority)]"

      # Execute claude with timeout, reading prompt from temp file
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = "claude"
      $psi.Arguments = "-p --max-turns $maxTurns --allowedTools `"Read,Write,Edit,Bash,Glob,Grep,WebSearch,WebFetch`""
      $psi.RedirectStandardInput = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $psi.UseShellExecute = $false
      $psi.WorkingDirectory = $Root

      $proc = [System.Diagnostics.Process]::Start($psi)
      $proc.StandardInput.Write($prompt)
      $proc.StandardInput.Close()

      if (-not $proc.WaitForExit($timeout * 1000)) {
        $proc.Kill()
        throw "claude timeout after ${timeout}s"
      }

      $stderr = $proc.StandardError.ReadToEnd()
      if ($proc.ExitCode -ne 0) {
        throw "claude failed (exit $($proc.ExitCode)): $stderr"
      }

      # Increment rate counter on successful execution
      IncrementRateCounter

      # Mark request as done
      $req.status = "done"
      if ($req.PSObject.Properties["error"]) { $req.error = $null }
      else { $req | Add-Member -NotePropertyName "error" -NotePropertyValue $null }
      $donePath = Join-Path $inboxDone $file.Name
      AtomicWriteJson $donePath $req
      Remove-Item $processingPath -Force

      # Clean up temp file
      Remove-Item $promptFile -Force -ErrorAction SilentlyContinue

      Log "Completed: $($file.Name)"
      $processed++
    }
    catch {
      $errMsg = $_.Exception.Message
      Log "ERROR $($file.Name): $errMsg"

      # Move to done with error status
      try {
        $src = if (Test-Path $processingPath) { $processingPath } else { $file.FullName }
        if (Test-Path $src) {
          $req = ReadJson $src
          $req.status = "error"
          $req | Add-Member -NotePropertyName "error" -NotePropertyValue (NewErrorObj "INBOX_WATCHER_ERROR" $errMsg $false) -Force
          $donePath = Join-Path $inboxDone (Split-Path $src -Leaf)
          AtomicWriteJson $donePath $req
          Remove-Item $src -Force
        }
      } catch {
        Log "Secondary error persisting failure for $($file.Name): $($_.Exception.Message)"
      }

      # Clean up temp file if it exists
      if ($promptFile -and (Test-Path $promptFile)) {
        Remove-Item $promptFile -Force -ErrorAction SilentlyContinue
      }
    }
  }

  Log "Done. Processed: $processed, Skipped: $skipped"
}
finally {
  Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
