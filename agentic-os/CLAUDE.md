# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Heartbeat

Before doing anything else in any session:
1. Read `context/SOUL.md` — who you are, how you behave
2. Read `context/USER.md` — who you're helping and their preferences
3. Read `context/memory/{today}.md` + `context/memory/{yesterday}.md` — recent session context. Pay special attention to `### Open threads` from the last session — these are your starting point.
4. **Create or open today's memory file** — if `context/memory/{YYYY-MM-DD}.md` doesn't exist, create it with a session start timestamp. If it already exists (second session today), append a new session header. See **Daily Memory** below.
5. Scan `brand_context/` — what exists? Flag anything older than 30 days: "Your [file] is from [date]. Want to refresh, or keep going?"
6. Scan `.claude/skills/` — know what skills are installed and available
7. **Sync check** — run the skill & MCP reconciliation (see below)
8. **Scheduled jobs** — check if the watchdog is installed (look for `~/Library/LaunchAgents/com.agentic-os.watchdog.plist` on Mac). If installed, report: *"Watchdog is active — your N enabled jobs run automatically in the background."* If not installed, scan `cron/jobs/` for enabled jobs and mention: *"You have N scheduled jobs. Install the watchdog to run them automatically: `bash scripts/install-watchdog.sh`"*

### Daily Memory

Every session writes to `context/memory/{YYYY-MM-DD}.md`. This is how continuity works across sessions.

**One file per day**, with numbered session blocks (`## Session 1`, `## Session 2`, etc.).

**At session start:** Create the file if it doesn't exist, or append a new session block if it does:
```
## Session N

### Goal
[One line — filled once the user states their goal]

### Deliverables
- `path/to/file` — what it is

### Decisions
- [Decision and rationale]

### Open threads
- [Anything unfinished for the next session]
```

**During the session:** Update the current session block incrementally as events happen. Don't wait for wrap-up — if a deliverable is produced or a decision is made, log it immediately.

**At session end (via /wrap-up):** The wrap-up skill finalises the session block — replacing any placeholder text with real content. Even without `/wrap-up`, the file should have useful context because it was written incrementally.

Keep entries concise — bullet points, not paragraphs. This file is read at the start of every future session.

### Skill & MCP Reconciliation

Compare what's on disk against what's registered in this file. Fix any drift silently for additions; confirm with the user for removals.

**Skills — compare `.claude/skills/` folders vs the Skill Registry and Context Matrix tables above:**

1. **New skill on disk, not in CLAUDE.md?** → Read its YAML frontmatter and full SKILL.md, then:
   - Add a row to the **Skill Registry** table (under the correct category heading)
   - Add a row to the **Context Matrix** table (read `## Context Needs` from its SKILL.md)
   - Add a `## {folder-name}` section to `context/learnings.md` under `# Individual Skills`
   - Add the skill to the **README.md** skill tables and file structure diagram
   - **Scan for external service dependencies** (see below)
   - Tell the user: "Registered `{skill-name}` — added to CLAUDE.md Skill Registry, Context Matrix, README.md, and context/learnings.md."

2. **Skill in CLAUDE.md but folder missing from disk?** → Ask the user: "`{skill-name}` is in the CLAUDE.md Skill Registry but the folder is gone. Remove it from CLAUDE.md Skill Registry, Context Matrix, README.md, and context/learnings.md?"

**MCPs — compare `.claude/settings.json` MCP server entries vs a tracked list:**

3. **New MCP server in settings.json, not documented?** → Add it to the README.md under a Connected Tools section (create the section if it doesn't exist). Tell the user what was added.

4. **Documented MCP removed from settings.json?** → Ask the user: "`{mcp-name}` is documented but no longer in settings.json. Remove from README.md?"

**External service detection — runs as part of step 1 above (new skill registration):**

5. **Scan the new skill's SKILL.md and references/ for external API dependencies.** Look for:
   - Environment variable references (e.g. `FIRECRAWL_API_KEY`, `OPENAI_API_KEY`, any `*_API_KEY` or `*_SECRET` pattern)
   - API endpoint URLs (e.g. `api.firecrawl.dev`, `api.openai.com`)
   - SDK imports (e.g. `from firecrawl import`, `import openai`)
   - Explicit mentions of requiring API keys or external services

6. **For each external service found**, check if it's already documented:
   - **Not in CLAUDE.md Service Registry?** → Add a row to the **External Services & API Keys → Service Registry** table with: service name, key name, which skills use it, what it enables, fallback without it
   - **Not in `.env.example`?** → Add the key with a comment explaining the service, signup URL if found, and which skill uses it
   - **Not in README.md External Services table?** → Add a row
   - Tell the user: "Found external dependency: `{service}` (`{KEY_NAME}`). Added to Service Registry, `.env.example`, and README. Add your key to `.env` when ready — the skill works without it using [fallback]."

7. **If a skill is removed** and was the last skill using a particular service → ask the user: "`{service}` is no longer used by any skill. Remove from Service Registry, `.env.example`, and README?"

### Task Routing

When the user asks a question or requests a task:
1. **Search installed skills first.** Check `.claude/skills/` frontmatter for a matching skill.
2. **Skill found** → invoke it. Always prefer the dedicated skill over base knowledge.
3. **No matching skill** → inform the user explicitly and offer the choice:
   - **(a) Find or build a skill** — search for an existing skill to install, or build one with `meta-skill-creator`, so the system handles this task well every time
   - **(b) Handle it now with base knowledge** — complete the task without a skill, understanding output won't benefit from a tested methodology or the learnings loop

Never silently fall back to base knowledge when a skill exists. Never silently handle a task without telling the user a skill gap was found.

### Before Major Deliverables
- Is the relevant brand_context file loaded per the context matrix below?
- Are there learnings in `context/learnings.md` for this skill's section?
- If brand_context is missing, offer to run `/start-here` — never block work because context is missing

### After Major Deliverables
- Ask: "How did this land? Any adjustments?"
- Log feedback to `context/learnings.md` under the skill's section
- If gaps were spotted, mention once with opportunity framing: "I can make this more targeted once we build your ICP profile — want to do that now or after?"

---

## What This Project Is

Agentic OS is a Claude Code project template that turns any client folder into an intelligent business assistant. It is **agent-first**: personality lives in `context/SOUL.md`, user preferences in `context/USER.md`, session continuity in `context/memory/`, accumulated learnings in `context/learnings.md`, brand memory in `brand_context/`, and functionality in `.claude/skills/`.

**One command to start: `/start-here`**. Everything else is a skill that triggers automatically or gets invoked by the orchestrator.

The full specification lives in `PRD.md`. Read it when building any new component.

---

## Three-Layer Architecture

| Layer | Files | Purpose |
|-------|-------|---------|
| **Agent Identity** | CLAUDE.md, `context/SOUL.md`, `context/USER.md` | Who the agent is and how it behaves |
| **Skills Pack** | `.claude/skills/{category}-{skill-name}/` | Capabilities. Grows over time. |
| **Brand Context** | `brand_context/` | Client brand data. Version controlled. |

`.env`, `.mcp.json`, `installed.json`, user data dirs (`context/memory/`, `projects/`, `brand_context/*.md`) are gitignored. See `.gitignore` for full list.

---

## Skill Categories

Every skill and its output folder uses a category prefix. This keeps skills, outputs, and learnings sections consistently named.

| Prefix | Domain | Examples |
|--------|--------|----------|
| `mkt` | Marketing | `mkt-brand-voice`, `mkt-positioning`, `mkt-icp`, `mkt-email-sequence` |
| `str` | Strategy | `str-keyword-plan`, `str-competitor-analysis` |
| `ops` | Operations / File Mgmt | `ops-client-onboarding`, `ops-gdrive-sync` |
| `viz` | Visual / Video | `viz-thumbnail-creator`, `viz-ugc-generator` |
| `acc` | Accounting | `acc-invoice-generator`, `acc-expense-tracker` |
| `meta` | System / Meta | `meta-skill-creator`, `meta-wrap-up` |
| `tool` | Utility / Integration | `tool-firecrawl-scraper` — backend tools used by other skills |

**Rules:**
- Skill folder name = `{category}-{skill-name}` in kebab-case
- YAML frontmatter `name` field must match the folder name exactly
- Output folders use the same category prefix: `projects/{category}-{output-type}/`
- Learnings sections in `context/learnings.md` use `## {folder-name}` (e.g., `## mkt-brand-voice`)
- Add new categories only when the first skill in a new domain is built

---

## Skill Registry

*Auto-populated as skills are installed. Each entry includes: name, trigger conditions, context needs.*

### Meta Skills

| Skill | Triggers on |
|-------|------------|
| `meta-skill-creator` | "create a skill", "build a skill", "new skill", "make a skill", "optimize skill description" |
| `meta-wrap-up` | "wrap up", "close session", "end session", "we're done", "session done" |

### Foundation Skills (build first — these write brand_context/)

| Skill | Triggers on | Writes to |
|-------|------------|-----------|
| `mkt-brand-voice` | "tone", "writing style", "brand voice", "how we sound" | `voice-profile.md`, `samples.md` |
| `mkt-positioning` | "differentiation", "angle", "hooks", "USP" | `positioning.md` |
| `mkt-icp` | "target audience", "buyer persona", "ideal customer" | `icp.md` |

*Optional skills are auto-registered by the Heartbeat reconciliation when their folders appear on disk. Install optional skills with `bash scripts/add-skill.sh <name>`. See `.claude/skills/_catalog/catalog.json` for the full list.*

*Add new skills to this table when built and registered.*

---

## Context Matrix

Which `brand_context/` files each skill reads. Load only what's listed — no skill gets more context than it needs.

| Skill | voice-profile | positioning | icp | samples | assets | learnings |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|
| `mkt-brand-voice` | **writes** | summary | — | **writes** | **writes** (via firecrawl branding) | `## mkt-brand-voice` |
| `mkt-positioning` | — | **writes** | full | — | — | `## mkt-positioning` |
| `mkt-icp` | — | summary | **writes** | — | — | `## mkt-icp` |
| `meta-wrap-up` | — | — | — | — | — | `## meta-wrap-up` |

*Optional skills auto-add their row here via Heartbeat reconciliation when installed. New skills declare their own row when added.*

**Matrix key:** `writes` = creates file | `full` = entire file | `summary` = 1-2 sentences | `angle only` = chosen angle | `tone only` = tone + vocabulary | `language section` = words-they-use section | `## skill-name` = read only that section from context/learnings.md | `—` = don't load

**Learnings rule:** Every skill reads and writes to its own section in `context/learnings.md`. Section headings match the skill's folder name exactly (e.g., `## mkt-brand-voice`). Cross-skill insights go under `# General` (`## What works well` / `## What doesn't work well`). Skill-specific entries go under `# Individual Skills` → `## {folder-name}`.

---

## Output Standards

- Save all generated content to `projects/{category}-{output-type}/`
- The category prefix in the output folder matches the skill's category (e.g., `mkt-brand-voice` skill → `projects/mkt-*/` outputs)
- Folder naming: `{category}-{output-type}` in kebab-case (e.g., `mkt-linkedin-carousel`, `str-keyword-plan`)
- Filename format: `{descriptive-name}_{YYYY-MM-DD}.md` (folder provides context, no skill-name prefix needed)
- Folders are created on first use by the skill. No empty pre-scaffolding.
- Default format: markdown unless user specifies otherwise
- After major deliverables: ask for feedback, log to `context/learnings.md`
- **Auto-download binary outputs.** After saving any non-markdown file (PNG, PDF, SVG, video, JSON diagrams, etc.), copy it to `~/Downloads/` using `cp <filepath> ~/Downloads/`. This applies to all skills — the user should never have to manually navigate to a generated file.
- **Show clickable file path.** After saving any output, show the user the full absolute file path so they can click it directly to open the file. Example: "Saved to `/Users/simoncoton/Desktop/agentic-os/projects/mkt-copywriting/landing-page_2026-03-14.md`". This applies to all skills — the user should never have to navigate to find what was just created.

### Humanizer Gate

**Every skill that produces publishable text must run its output through `tool-humanizer` as a final step before saving.** This is not optional.

- Execution skills (copywriting, content repurposing, email sequences, blog posts, etc.) call the humanizer in pipeline mode after generating content
- The humanizer uses `deep` mode when `brand_context/voice-profile.md` exists, `standard` mode otherwise
- Only show the score summary to the user if the change was significant (delta > 2 points)
- Skills that produce non-publishable output (research briefs, ICP profiles, positioning docs) skip this step

When building new skills, include a humanizer step in the methodology if the skill writes content meant for an audience. Reference `tool-humanizer` in pipeline mode.

### Schemas

Schemas live inside the skill that owns them, under `references/`. This keeps them version-controlled with the skill and out of user data directories.

| Schema | Location | Used by |
|--------|----------|---------|
| `voice-profile.schema.json` | `.claude/skills/mkt-brand-voice/references/` | `mkt-brand-voice` |

When a skill produces structured output, it should read the relevant schema before generating data to ensure all required fields are present.

---

## Building New Skills

**Always ask for reference skills first.** Never guess at methodology — the user provides examples, Claude Code learns the pattern, then scaffolds. Use the `meta-skill-creator` skill to scaffold and iterate.

### Skill structure
```
.claude/skills/{category}-{skill-name}/
├── SKILL.md          ← YAML frontmatter + methodology (~200 lines max)
├── references/       ← Depth material, one topic per file (~200-300 lines each)
├── scripts/          ← Executable scripts including setup.sh for auto-install (optional)
└── assets/           ← Example outputs, design references, templates (optional)
```

### Auto-Setup Convention

Skills that need external binaries (e.g. `uv`, `yt-dlp`, `ffmpeg`) must include a `scripts/setup.sh` that auto-detects and installs them. The SKILL.md should include a **Step 0: Auto-Setup** that runs this script before any other operation.

**Rules:**
- The setup script checks `command -v` first — never reinstall what already exists
- Uses `brew` on macOS if available, falls back to `curl`/`pip`/other package managers
- Reports clear success/failure per dependency
- Only runs once per machine — skip on subsequent calls if all binaries are present
- Never requires user interaction (no prompts, no sudo unless absolutely necessary)

### YAML frontmatter rules
- ~100 words, under 1024 characters
- Include trigger phrases AND negative triggers
- No XML angle brackets

### Skill Dependencies

Skills can depend on other skills. Declare dependencies in a `## Dependencies` section in SKILL.md so the system knows what's needed.

```markdown
## Dependencies

| Skill | Required? | What it provides | Without it |
|-------|-----------|-----------------|------------|
| `tool-youtube` | Optional | YouTube transcript fetching | Ask user to paste content manually |
```

**Rules:**
- **Required** dependencies must be installed for the skill to function at all
- **Optional** dependencies enhance the skill but it works without them — always declare the fallback
- At session start, if a skill is invoked and a required dependency is missing, tell the user which skill to install
- Dependencies are one-way — utility (`tool-`) skills never depend on execution skills

### Registration checklist
- [ ] Folder name = `{category}-{skill-name}` matching the Skill Categories table
- [ ] `name` field in frontmatter matches the folder name exactly
- [ ] Add to skill registry table above
- [ ] Add row to context matrix above
- [ ] Frontmatter < 1024 chars
- [ ] SKILL.md < 200 lines
- [ ] References are self-contained
- [ ] If the skill depends on other skills: add a `## Dependencies` section to SKILL.md
- [ ] If the skill produces structured/repeatable output: add a schema to the skill's `references/` folder and reference it from SKILL.md
- [ ] Declare which `projects/` subfolder(s) the skill writes to (must use same category prefix)
- [ ] **External services**: If the skill uses any external API, ensure the key is in the Service Registry (CLAUDE.md), `.env.example`, and README.md External Services table. The reconciliation does this automatically, but verify it ran.
- [ ] **Humanizer gate**: If the skill produces publishable text (blog posts, social content, copy, emails), include a step that runs output through `tool-humanizer` in pipeline mode before saving

### Folder naming
- Format: `{category}-{skill-name}` in kebab-case (e.g., `mkt-brand-voice`, `ops-client-onboarding`)
- Cannot contain "claude" or "anthropic"

---

## Build Order (from PRD)

1. **Phase 1 — Agent Identity:** context/SOUL.md → context/USER.md ✓
2. **Phase 2 — Command + Foundation Skills:** `start-here.md` ✓ → `mkt-brand-voice/` ✓ → `mkt-positioning/` ✓ → `mkt-icp/` ✓
3. **Phase 3 — Validate:** End-to-end test with a real business
4. **Phase 4 — Execution Skills:** Build incrementally, each with reference skills
5. **Phase 5 — Expand:** First non-marketing skill proves architecture is domain-agnostic

---

## Graceful Degradation

Skills work at all context levels:
- **No brand_context/**: Standalone mode — ask what's needed, produce solid generic output
- **Partial**: Use what exists, default for the rest
- **Full**: Fully personalised

Brand context **enhances**. It never gates functionality.

---

## External Services & API Keys

Some skills use external services for enhanced functionality. API keys are stored in `.env` (gitignored). `.env.example` documents all available keys.

### Service Registry

| Service | API Key | Used by | What it enables | Without it |
|---------|---------|---------|----------------|------------|
| Firecrawl | `FIRECRAWL_API_KEY` | `tool-firecrawl-scraper`, `mkt-brand-voice` (Auto-Scrape) | JS-heavy site scraping, anti-bot bypass, brand asset extraction (logo, colors, fonts) | Falls back to WebFetch (free). If that also fails, asks user to paste content manually |
| OpenAI | `OPENAI_API_KEY` | `str-trending-research` | Reddit search via Responses API with `web_search` tool — real upvotes, comments, top comment insights | Falls back to WebSearch (free, no engagement metrics) |
| xAI | `XAI_API_KEY` | `str-trending-research` | X/Twitter search via xAI API with `x_search` tool — real likes, reposts, reply counts | Falls back to WebSearch (free, no engagement metrics) |
| YouTube Data API v3 | `YOUTUBE_API_KEY` | `tool-youtube` | Channel video listing, @handle resolution, search | Transcript mode still works with direct URLs (free via yt-dlp). Channel listing unavailable |
| Google Gemini | `GEMINI_API_KEY` | `viz-nano-banana` | Image generation via Gemini 3 Pro Image | No fallback — image generation requires the API key. Free tier available |
| HeyGen | `HEYGEN_API_KEY` | `viz-ugc-heygen` | AI avatar video generation with cloned avatars and custom voices | No fallback — video generation requires the API key and HeyGen plan credits |

*Add new services to this table and to `.env.example` when skills are built that use them.*

### Rules for Skills Using External Services

1. **Check before using.** Before calling any external API, check `.env` for the required key. Never assume it's there.
2. **Tell the user what they're missing.** If the key is absent, explain clearly:
   - What the service does
   - What they'll miss without it
   - How to get a key (signup URL, free tier info)
   - Where to put it: "Add `KEY_NAME=your-key` to your `.env` file"
3. **Always have a fallback.** No skill should break because an API key is missing. Degrade gracefully — use free tools first, then prompt for the key only when the free path fails.
4. **Don't block work.** If the fallback produces usable (even if less rich) output, proceed and note what would improve with the API key.
5. **Update `.env.example`** when adding a new external service dependency.

---

## Permissions

`.claude/settings.json` allows: `cat`, `ls`, `npm run *`, basic git commands, edits to `/src/**`

Denied: package installs, `rm`/`curl`/`wget`/`ssh`, reading `.env`/`.env.local` or credential files. `.env.example` is readable and editable (it's a template, not secrets).
