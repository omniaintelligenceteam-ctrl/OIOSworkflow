---
name: daily-digest
schedule: every_4h
description: Compile daily outbox activity into status/daily-summary.json
model: haiku
max_budget_usd: 0.25
enabled: true
---

You are running as a scheduled job for Agentic OS.

Task: Compile the daily outbox activity summary.

1. Count files in each outbox directory:
   - `outbox/actions/pending/` (exclude .gitkeep and .tmp files)
   - `outbox/actions/processing/`
   - `outbox/actions/completed/` (only files dated today)
   - `outbox/actions/failed/` (only files dated today)
   - `outbox/inbox/pending/`
   - `outbox/inbox/done/` (only files dated today)

2. Read completed action files from today to extract content summaries.

3. Read or create `outbox/status/daily-summary.json` using this schema:
   ```json
   {
     "schema_version": "1.0",
     "date": "{today YYYY-MM-DD}",
     "generated_at": "{ISO 8601 timestamp}",
     "content": {
       "posts_published": 0,
       "posts_pending": 0,
       "content_generated": []
     },
     "actions": {
       "completed": 0,
       "failed": 0,
       "pending": 0
     },
     "inbox": {
       "requests_received": 0,
       "requests_processed": 0
     },
     "highlights": [],
     "errors": []
   }
   ```

4. Update counts from the file scans. Preserve existing `highlights` entries.

5. Extract errors from today's failed action files and add to `errors` array.

6. Purge old files:
   - Delete files in `outbox/actions/completed/` older than 30 days
   - Delete files in `outbox/actions/failed/` older than 7 days
   - Delete files in `outbox/inbox/done/` older than 30 days

7. Write the summary using atomic protocol: write to `.tmp` then rename to `.json`.

8. If no outbox directory exists, exit silently without creating the file.
