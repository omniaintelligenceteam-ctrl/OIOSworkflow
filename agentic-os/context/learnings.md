# Learnings Journal

> Auto-maintained by Agentic OS skills. Newest entries at the bottom of each section.
> Skills append here after deliverable feedback. Never delete entries.
> Section headings match skill folder names exactly. New skills add their own section when created.
> Skills read only their own section before running. Cross-skill insights go in `general`.

# General
## What works well

## What doesn't work well


# Individual Skills
## mkt-brand-voice

- 2026-03-15: Don't lead with features (missed calls, call answering). Lead with the role — OIOS is an AI COO. The three pillars: (1) knows your business inside and out, (2) automates the back office, (3) always available to think through decisions with you. Landing page style (headline + tight support copy) resonated most in voice test.

## mkt-positioning

- 2026-03-15: "Your AI COO" is the primary frame. Two key value props that must always be present: (1) a COO at a fraction of the cost, (2) you don't pay until it pays for itself. The decision-support angle (someone to think with, not just a tool) is what separates OIOS from every other automation play.

## mkt-icp

## meta-wrap-up

## tool-firecrawl-scraper

## str-trending-research

## viz-nano-banana

## viz-ugc-heygen

- 2026-03-10: MCP `generate_avatar_video` tool doesn't support dimensions, captions, or background config. Always use precise API (`POST /v2/video/generate` via python3 urllib) for platform-specific content. MCP tool only good for quick defaults.
- 2026-03-10: MCP `get_remaining_credits` and `get_voices` have Pydantic validation bugs — some HeyGen responses have null/s3 URLs that fail validation. Use direct API via python3 as fallback.
- 2026-03-10: `MOVIO_PAYMENT_INSUFFICIENT_CREDIT` error — check credits before generating. Credits endpoint also buggy via MCP, use direct API.
- 2026-03-10: HeyGen video URLs are signed and expire quickly. Always download the MP4 immediately after generation completes. Save to `projects/viz-ugc-heygen/` as `.mp4` alongside the metadata `.md` file.
- 2026-03-12: Do NOT use `video_url_caption` — HeyGen's baked-in captions are unreliable (didn't show in test). Use `video_url` (no captions) + download `.ass` from `caption_url`, restyle with branded template, burn with ffmpeg libass via `scripts/burn-captions.py --restyle`.
- 2026-03-12: API `caption` field is boolean only — no styling options. Styled caption object (font_family, font_size, etc.) was hallucinated and has been removed from api-reference.md.
- 2026-03-12: Voice speed 1.2x confirmed as preferred over 1.1x. Voice speed range is 0.5–1.5 (not 0.5–2.0 as previously documented).
- 2026-03-12: Best voice settings confirmed: `emotion: Friendly` + `elevenlabs_settings: {stability: 0.3, similarity_boost: 0.75, style: 0.7}`. Noticeably less robotic than defaults. Locked into avatar-config.md.

## mkt-ugc-scripts

- 2026-03-10: Scripts must be spoken-words-only (no timestamps, no stage directions) for HeyGen compatibility. Use SSML `<break time="Xs"/>` sparingly. On-screen text goes in a separate section after the script body.
- 2026-03-10: Personal experience framing works better than teaching/selling. "I will never use X again because..." beats "Stop using X. Here's why." Reference script saved in assets/ as quality bar.
- 2026-03-10: Max 90s duration. Every script ends with soft Skool CTA (vary phrasing across batches).

## ops-cron

## mkt-content-repurposing

## mkt-copywriting

## tool-humanizer

## tool-youtube

## ops-outbox

## viz-excalidraw-diagram
