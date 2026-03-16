# Agentic OS

Turn Claude Code into your business assistant.

Agentic OS gives Claude Code personality, memory, and skills so it works like a team member, not a chatbot. It remembers your brand voice, learns your preferences over time, and runs proven methodologies instead of winging it every session.

---

## Quickstart

```bash
git clone https://<YOUR-TOKEN>@github.com/simonc602/agentic-os.git
cd agentic-os
bash scripts/install.sh
```

Replace `<YOUR-TOKEN>` with the access token from the [Agentic Academy classroom](https://www.skool.com/scrapes/classroom/d1cfafed?md=552b0ba753df4c738843913fb3eb8312).

The installer checks your system, sets up dependencies, and lets you pick which skills to install.

When it finishes, open Claude Code and say **"start here"**. That walks you through building your brand foundation -- voice, positioning, and ideal customer profile.

---

## What You Get

Agentic OS is built on three layers:

1. **Agent Identity** -- Personality (SOUL.md), your profile (USER.md), and session memory. This is what makes it feel like working with someone who knows your business.

2. **Skills** -- Modular capabilities that can be added or removed. Each skill follows a tested methodology and self-improves as you give feedback -- corrections go directly into the skill, not just a note.

3. **Brand Context** -- Your voice, positioning, and ideal customer profile. Skills load only what they need, so output stays focused and on-brand.

---

## Core Skills (always installed)

| Skill | What it does |
|-------|-------------|
| `meta-skill-creator` | Build custom skills for your business |
| `meta-wrap-up` | End-of-session memory and learning capture |
| `mkt-brand-voice` | Extract your brand voice from content or build it from scratch |
| `mkt-positioning` | Find angles that make your offer stand out |
| `mkt-icp` | Define your ideal customer so every skill speaks to them |

---

## Optional Skills

| Skill | What it does | API key needed |
|-------|-------------|----------------|
| `tool-humanizer` | Strip AI patterns from any output | -- |
| `tool-firecrawl-scraper` | Scrape JS-heavy websites | `FIRECRAWL_API_KEY` |
| `tool-youtube` | Pull YouTube transcripts and channel listings | `YOUTUBE_API_KEY` (channel mode only) |
| `str-trending-research` | Research trending topics across Reddit, X, and the web | `OPENAI_API_KEY` + `XAI_API_KEY` |
| `mkt-copywriting` | Sales copy with 7-dimension scoring | -- |
| `mkt-content-repurposing` | Turn one piece of content into posts for 8 platforms | -- |
| `mkt-ugc-scripts` | Short-form video scripts with hook library | -- |
| `viz-excalidraw-diagram` | Architecture and workflow diagrams | -- |
| `viz-nano-banana` | AI image generation in 5 visual styles | `GEMINI_API_KEY` |
| `viz-ugc-heygen` | AI avatar videos via HeyGen | `HEYGEN_API_KEY` |
| `ops-cron` | Schedule recurring Claude Code tasks | -- |

---

## GSD (Get Stuff Done)

GSD is a project management framework for Claude Code. It's a separate install (not bundled with Agentic OS) that adds structured planning, execution, and verification for complex multi-step projects.

**Install GSD:**
```bash
npx get-shit-done-cc@latest
```

Use it when you're building something with multiple phases -- a product launch, a new feature, a migration. It handles planning, execution, verification, and session continuity.

**Key commands:**

| Command | What it does |
|---------|-------------|
| `/gsd:new-project` | Start a new project with deep context gathering |
| `/gsd:plan-phase` | Plan a phase with research, task breakdown, and verification |
| `/gsd:execute-phase` | Execute a plan with atomic commits and state tracking |
| `/gsd:progress` | Check where you are and what's next |
| `/gsd:debug` | Systematic debugging with persistent state |
| `/gsd:quick` | Quick task with GSD guarantees (commits, tracking) |
| `/gsd:verify-work` | Validate features through conversational testing |
| `/gsd:pause-work` | Save context for resuming later |
| `/gsd:resume-work` | Pick up where you left off |
| `/gsd:help` | See all available commands |

GSD and Agentic OS complement each other. Agentic OS handles brand context and skill-driven content production. GSD handles structured project execution when you're building something with phases and milestones.

---

## Managing Skills

```bash
bash scripts/list-skills.sh                  # See what's installed and available
bash scripts/add-skill.sh mkt-copywriting    # Add a skill
bash scripts/remove-skill.sh viz-nano-banana # Remove a skill
```

Dependencies are resolved automatically. If you add a skill that needs another skill, both get installed.

---

## Updating

```bash
bash scripts/update.sh
```

This pulls the latest changes from upstream -- new skills, improved methodologies, bug fixes. Your brand context, memory, projects, and API keys are never overwritten.

If you've customised any skills (via feedback, Rules additions, or direct edits), the update script detects this and shows you a diff for each changed skill. You choose per skill: accept our upstream changes, or keep your version. Either way, your version is backed up.

If new skills are available, the script tells you what was added and how to install them.

**If the update fails with an authentication error**, the access token has been rotated. Grab the latest token from the [Agentic Academy classroom](https://www.skool.com/scrapes/classroom/d1cfafed?md=552b0ba753df4c738843913fb3eb8312) and update your remote:

```bash
git remote set-url origin https://<NEW-TOKEN>@github.com/simonc602/agentic-os.git
bash scripts/update.sh
```

---

## API Keys

Most skills work without any API keys. Some are enhanced with external services (web scraping, image generation, video creation). All keys go in your `.env` file.

To see every available key with descriptions and signup links:

```bash
cat .env.example
```

Skills will tell you when they could use a key you haven't added yet, and they always offer a fallback so your work isn't blocked.

---

## Always-On Scheduled Jobs

Want your jobs to run even when Claude Code is closed? Install the watchdog:

**Mac:**
```bash
bash scripts/install-watchdog.sh
```

**Windows (PowerShell as admin):**
```powershell
powershell scripts/install-watchdog.ps1
```

That's it. The watchdog checks your jobs every hour in the background. It runs them using your Claude plan credits -- each job has a built-in spending cap (`max_budget_usd` in the job file).

To stop it:
- **Mac:** `bash scripts/uninstall-watchdog.sh`
- **Windows:** `powershell scripts/uninstall-watchdog.ps1`

Your job files in `cron/jobs/` are never deleted -- only the background scheduler is removed.

---

## File Structure

```
├── context/
│   ├── SOUL.md            <- Agent personality and behaviour rules
│   ├── USER.md            <- Your preferences and working style
│   ├── learnings.md       <- Accumulated skill feedback (gets smarter over time)
│   └── memory/            <- Daily session logs (one file per day)
├── brand_context/         <- Your brand data (voice, positioning, ICP)
├── .claude/skills/        <- Installed skill packs
├── cron/jobs/             <- Scheduled job definitions
├── projects/              <- All generated output
├── scripts/               <- Install, update, manage skills, watchdog
└── CLAUDE.md              <- Agent orchestration (don't edit manually)
```

---

## Quality of Life

A few things baked in to make the day-to-day smoother:

- **CC Notify** -- native OS notifications (Mac & Windows) when Claude finishes a task, needs permission, or is waiting for input. No more checking back every 30 seconds.
- **Auto-download** -- binary outputs (images, videos, PDFs) auto-copy to your Downloads folder.
- **Humanizer gate** -- every skill that produces publishable text automatically strips AI writing patterns before saving.
- **Clickable file paths** -- every saved file shows the full path so you can click to open it.
- **Graceful degradation** -- no skill breaks because something is missing. No API key? Free fallback. No brand context? Solid generic output.

---

## Your Data is Safe

These are yours and are never overwritten by updates:

- **brand_context/** -- your voice profile, positioning, ICP
- **context/** -- your memory, learnings, session history
- **projects/** -- everything the system generates for you
- **.env** -- your API keys (gitignored, never leaves your machine)

---

## Need Help?

Head to the Agentic Academy Skool community. Post your question and the team or another member will help you out.

---

Built by Simon Scrapes @ Agentic Academy
