---
name: action-executor
description: >
  Executes pending actions from the Agentic OS outbox. Polls actions/pending/ for
  new action files, validates schemas, checks idempotency index, enforces approval
  policy, then executes the action (post to social media, send email, update CRM,
  etc.). Moves completed actions to completed/ or failed/. Reports results to CEO.
  Runs on a polling interval or triggered by the bridge skill.
metadata: {"openclaw":{"emoji":"⚡","os":["win32","darwin","linux"]}}
---

# Action Executor

Picks up action files from the Agentic OS outbox and executes them against external services.

## Configuration

Outbox path: `C:\Users\default.DESKTOP-ON29PVN\OIOS\agentic-os\outbox`

Key paths:
- Actions pending: `{outbox}/actions/pending/`
- Actions processing: `{outbox}/actions/processing/`
- Actions completed: `{outbox}/actions/completed/`
- Actions failed: `{outbox}/actions/failed/`
- Executed index: `{outbox}/actions/executed-index.jsonl`
- Approval policy: `{outbox}/config/approval-policy.json`
- Rate limits: `{outbox}/config/rate-limits.json`

## Execution Flow

For each `.json` file in `actions/pending/` (sorted by `created_at`):

### Step 1: Validate
- Parse JSON, check `schema_version` starts with `1.`
- Verify `action` is a known type
- Verify `content` is non-empty

### Step 2: Check Idempotency
- Read `execution_key` from action file
- Search `executed-index.jsonl` for matching key
- If found → skip, move to `completed/` with note "duplicate", notify CEO
- If not found → proceed

### Step 3: Check Approval Policy
- Read `approval-policy.json`
- Check `action_overrides` for this action type
- Scan `content` against `high_risk_rules.require_approval_if_contains`
- Check if `priority` is in `force_approval_for_priorities`
- If approval required:
  - Send preview to CEO in chat
  - Set `approval_required: true` on the action file
  - Do NOT execute yet — wait for `approve act_XXX` command via bridge
  - Move to a holding state (keep in `pending/` with a marker)
  - Return — do not process further

### Step 4: Claim (Lease)
- Set `locked_by` to this worker's identifier
- Set `locked_at` to current timestamp
- Set `lease_expires_at` to current time + 30 minutes
- Set `status` to `processing`
- Move file to `actions/processing/`

### Step 5: Execute
Route based on `action` field:

| Action | Execution method |
|--------|-----------------|
| `post_linkedin` | Use browser automation or LinkedIn API to publish post |
| `post_x` | Use X/Twitter API or browser automation to publish |
| `post_tiktok` | Use TikTok API or browser automation to publish |
| `send_email` | Use email client/API to send. Include content as body. |
| `update_crm` | Use CRM API (ActiveCampaign/Zoho) to update record |
| `schedule_calendar` | Use calendar API to create event |
| `send_message` | Send via appropriate messaging platform |

If `media` array is non-empty, attach/upload the referenced files.

### Step 6: Record Result

**On success:**
- Set `status` to `completed`
- Clear `locked_by`, `locked_at`, `lease_expires_at`
- Move to `actions/completed/`
- Append `execution_key` to `executed-index.jsonl` with timestamp
- Notify CEO: "Posted to LinkedIn: '{first 60 chars of content}...'"

**On failure:**
- Set `status` to `failed`
- Populate `error` object: `{"code": "{ERROR_TYPE}", "message": "{details}", "at": "{timestamp}", "retryable": {true|false}}`
- Increment `retries`
- Clear lease fields
- Move to `actions/failed/`
- Notify CEO: "Failed to {action}: {error.message}. {retryable instructions}"

## Stale Lease Recovery

On each poll, also scan `actions/processing/`:
- If `lease_expires_at` is past → the action is stuck
- Move to `actions/failed/` with error code `LEASE_EXPIRED`
- Notify CEO

## Executed Index Format

`executed-index.jsonl` — one JSON object per line:
```
{"execution_key":"abc123...","action_id":"act_1710590400_a7f3e2","executed_at":"2026-03-16T10:35:00-05:00","result":"completed"}
{"execution_key":"def456...","action_id":"act_1710590800_c3d4e5","executed_at":"2026-03-16T11:00:00-05:00","result":"completed"}
```

## Retry Handling

When an action is retried (moved back to `pending/` by the bridge):
- `retries` has been incremented
- Check `rate-limits.json` → `executor.max_retries_per_action`
- If `retries` exceeds max → reject, move to `failed/` with `MAX_RETRIES_EXCEEDED`
- If within limit → wait `retry_backoff_seconds`, then execute normally
