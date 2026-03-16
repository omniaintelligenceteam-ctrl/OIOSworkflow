---
name: approval-gate
description: >
  Handles approval workflows for high-stakes actions in the Agentic OS outbox.
  When an action requires CEO approval (per approval-policy.json), this skill
  presents a preview and waits for approve/reject. Manages approval timeouts
  and expiration. Works with agentic-os-bridge for command routing.
metadata: {"openclaw":{"emoji":"🔐","os":["win32","darwin","linux"]}}
---

# Approval Gate

Manages CEO approval for actions that are too important to auto-execute.

## Configuration

Outbox path: `C:\Users\default.DESKTOP-ON29PVN\OIOS\agentic-os\outbox`
Policy file: `{outbox}/config/approval-policy.json`

## When Actions Need Approval

An action needs approval when ANY of these are true:
1. `approval_required: true` on the action file (set by ops-outbox based on policy)
2. The action type has `approval_required: true` in `approval-policy.json`
3. Content matches any keyword in `high_risk_rules.require_approval_if_contains`
4. Priority matches `force_approval_for_priorities`

## Preview Format

When presenting an action for approval:

> **Action needs your approval:**
>
> **Type:** {action} (e.g., "Send Email")
> **Created by:** {created_by} skill
> **Priority:** {priority}
>
> **Content preview:**
> > {first 300 characters of content}
>
> **Why approval is needed:** {reason — e.g., "Email actions require approval per policy" or "Content contains keyword 'legal'"}
>
> Reply `approve act_{id}` to execute, or `reject act_{id}` to cancel.

## Approval Flow

### On `approve act_XXXX`:
1. Find the action file (may be in `actions/pending/` with approval marker)
2. Set `approval_required` to `false` (approval given)
3. Ensure `status` is `pending`
4. Leave in `actions/pending/` for the action-executor to pick up
5. Confirm: "Approved — {action_type} will execute on next cycle."

### On `reject act_XXXX`:
1. Find the action file
2. Set `status` to `failed`
3. Set `error`: `{"code": "REJECTED", "message": "Rejected by CEO", "at": "{timestamp}", "retryable": false}`
4. Move to `actions/failed/`
5. Confirm: "Rejected — {action_type} has been cancelled."

## Timeout Handling

Check all actions in `actions/pending/` where `approval_required: true`:
- Read `approval_timeout_minutes` from the action's policy (default 720 = 12h)
- If `created_at` + timeout < now:
  - Set `status` to `failed`
  - Set `error`: `{"code": "APPROVAL_EXPIRED", "message": "No response within {timeout}h window", "at": "{timestamp}", "retryable": true}`
  - Move to `actions/failed/`
  - Notify CEO: "Approval expired for {action_type}: '{content preview}'. Say `retry act_XXX` to re-queue."

## Bulk Operations

If multiple actions await approval:

> **{N} actions waiting for approval:**
>
> 1. `act_XXX` — Send Email: "Follow-up: scheduling demo..."
> 2. `act_YYY` — Send Message: "Welcome to OIOS..."
>
> Reply `approve all` to approve everything, or `approve act_XXX` / `reject act_XXX` individually.

### On `approve all`:
- Process each pending-approval action as if individually approved
- Confirm: "Approved {N} actions — they'll execute on the next cycle."
