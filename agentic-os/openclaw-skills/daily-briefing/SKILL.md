---
name: daily-briefing
description: >
  Morning briefing skill that reads the Agentic OS daily summary and presents
  it conversationally to the CEO. Covers posts published, actions completed/failed,
  inbox activity, highlights, and errors. Can be triggered manually or scheduled
  as a morning routine. Triggers on: "morning briefing", "daily report",
  "what happened yesterday", "give me the rundown".
metadata: {"openclaw":{"emoji":"📋","os":["win32","darwin","linux"]}}
---

# Daily Briefing

Reads the Agentic OS daily summary and delivers a conversational morning report to the CEO.

## Configuration

Outbox path: `C:\Users\default.DESKTOP-ON29PVN\OIOS\agentic-os\outbox`
Status file: `{outbox}/status/daily-summary.json`

## When to Run

- **On command:** CEO says "morning briefing", "daily report", "what happened yesterday"
- **Scheduled:** Can be configured as a morning routine in OpenClaw

## Briefing Flow

### Step 1: Read Summary
- Load `{outbox}/status/daily-summary.json`
- If file doesn't exist or is stale (date != today and date != yesterday):
  - Fall back to scanning outbox directories for counts
  - Note: "Full summary isn't available yet — here's what I can see from the files."

### Step 2: Compile Report

Read the summary and format conversationally. Template:

> **Good morning — here's your rundown for {date}:**
>
> **Content:**
> - {posts_published} posts published, {posts_pending} still pending
> - Generated: {content_generated list, comma-separated}
>
> **Actions:**
> - {completed} completed, {failed} failed, {pending} still queued
>
> **Inbox:**
> - {requests_received} requests came in, {requests_processed} processed
>
> {If highlights exist:}
> **Highlights:**
> - {each highlight as a bullet}
>
> {If errors exist:}
> **Heads up:**
> - {each error: code + message}
>
> What do you want to focus on today?

### Step 3: Offer Next Actions

Based on the summary, suggest relevant actions:
- If failed actions exist → "Want me to retry the failed {action_type}?"
- If pending actions exist → "You have {N} pending actions — want to review them?"
- If no content generated yesterday → "No content went out yesterday. Want to queue something?"
- If highlights mention engagement → "Your {topic} post did well — want to repurpose it?"

## Handling Missing Data

If `daily-summary.json` is missing entirely:
- Scan `actions/completed/` for files dated today/yesterday
- Scan `actions/failed/` for recent failures
- Scan `inbox/done/` for processed requests
- Build an approximate summary from file counts
- Deliver the briefing with a note that the full digest hasn't run yet

## Tone

Conversational, concise, action-oriented. Match the OIOS brand voice: warm, practical, direct. Don't read data — interpret it. "3 posts went out, your LinkedIn piece on missed calls is getting traction" not "posts_published: 3, content_generated: ['LinkedIn post on missed calls']".
