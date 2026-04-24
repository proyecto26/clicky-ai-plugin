# clicky-ai-plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://code.claude.com/docs/en/plugins)
[![macOS](https://img.shields.io/badge/macOS-14.2%2B-black)](https://developer.apple.com/macos/)
[![TypeScript](https://img.shields.io/badge/TypeScript-Bun-blue)](https://bun.sh)

**Give Claude Code the "Clicky" persona — a friendly, lowercase macOS
companion that captures your screens, answers in short conversational
replies, flags UI elements with a `[POINT:x,y:label:screenN]` protocol,
and installs + launches the full native Clicky.app on demand.**

Runs entirely off your existing Claude Code subscription. No Anthropic
API key. No Cloudflare Worker. Zero npm dependencies — everything is
bundled as TypeScript scripts executed via `npx -y bun`.

**macOS only for v1. Apple Silicon only for the DMG install path** —
Intel Macs can run the plugin scripts but must install the native app
manually (the `install` subcommand looks for arm64 DMGs on GitHub
Releases). Linux and Windows are not targets.

---

## Quick Start

### Installation

#### Option 1: CLI Install (Recommended)

Use [npx skills](https://github.com/vercel-labs/skills) to install the
skill directly into your Claude Code setup:

```bash
# Install the skill
npx skills add proyecto26/clicky-ai-plugin

# List what's inside the package
npx skills add proyecto26/clicky-ai-plugin --list
```

This drops the skill into your `.claude/skills/` directory.

#### Option 2: Claude Code Plugin

Install via Claude Code's built-in plugin system:

```bash
# Add the marketplace
/plugin marketplace add proyecto26/clicky-ai-plugin

# Install the plugin
/plugin install clicky-ai
```

#### Option 3: Clone and Copy

Clone the repo and copy the skills folder into your project's Claude
config:

```bash
git clone https://github.com/proyecto26/clicky-ai-plugin.git
cp -r clicky-ai-plugin/skills/* .claude/skills/
```

#### Option 4: Git Submodule

Add as a submodule for easy updates:

```bash
git submodule add https://github.com/proyecto26/clicky-ai-plugin.git .claude/clicky-ai-plugin
```

Then reference skills from `.claude/clicky-ai-plugin/skills/`.

#### Option 5: Fork and Customize

1. Fork this repository.
2. Customize the persona, subcommands, or install flow for your needs.
3. Clone your fork and use any of the options above.

### Prerequisites

- **macOS 14.2+** (for native screen capture APIs).
- **`npx`** — ships with any recent Node.js install. `bun` does not need
  to be pre-installed; `#!/usr/bin/env -S npx -y bun` downloads it on
  first run (~5–10 s delay once) and caches it.
- **Screen Recording permission** — grant it to the terminal emulator
  that hosts `bun` (or to Claude Code itself) in
  `System Settings → Privacy & Security → Screen Recording`. Without
  this, `capture` fails with *"could not create image from display"*.
- *(Optional)* **Accessibility permission** — grant it to the same
  terminal so the `status` subcommand's accessibility probe returns
  `granted`.

### First run

Just talk to Claude:

> *"clicky, what's on my screen?"*

The skill captures every connected display, reads the JPEGs, replies in
a sentence or two, and optionally appends a `[POINT:x,y:label:screenN]`
tag flagging a relevant UI element.

---

## What you get

- **A skill** (`skills/clicky/SKILL.md`) that loads when you say
  "clicky", ask "what's on my screen", request "point at the save
  button", etc.
- **A CLI dispatcher** (`skills/clicky/scripts/main.ts`) with six
  subcommands that the skill tells Claude to invoke via Bash:

  | Subcommand | What it does |
  |---|---|
  | `install` | Install the native `Clicky.app` on demand |
  | `launch` | Launch the installed app |
  | `capture` | Screenshot every connected display, emit a JSON manifest |
  | `point` | Render a POINT coordinate as a human-readable line |
  | `speak` | Speak text aloud (say / VibeVoice / ElevenLabs) |
  | `status` | Environment health report |

## Use

### From Claude Code

Just talk to Claude:

> **You:** clicky, what's on my screen?
>
> **Claude:** *(invokes capture, reads the manifest, replies)* looks
> like you're in figma with the components panel on the left. that
> rectangle in the middle is your current selection.
> `[POINT:960,540:selected rectangle]`

### From the terminal

```bash
# All subcommands are directly runnable:
bun skills/clicky/scripts/main.ts help
bun skills/clicky/scripts/main.ts status --json
bun skills/clicky/scripts/main.ts capture
bun skills/clicky/scripts/main.ts point --x 1100 --y 42 --label "color inspector"
bun skills/clicky/scripts/main.ts speak "hello from clicky"
bun skills/clicky/scripts/main.ts install --dry-run
bun skills/clicky/scripts/main.ts launch
```

## The native app upgrade path

`install` tries, in order:

1. `brew install proyecto26/tap/clicky-ai` (preferred).
2. Download the latest signed DMG from
   [github.com/proyecto26/clicky/releases](https://github.com/proyecto26/clicky/releases),
   verify SHA256, mount, copy `.app` into `/Applications/`.
3. Print a manual URL as a last resort.

Once installed, `launch` opens the app (or you can click it from
`/Applications/`). The native app gives you the full "teacher" Clicky
experience:

- **Always-on cursor buddy** — a blue triangle follows the mouse at
  60 Hz with a spring animation, offset below-right of the cursor.
- **Push-to-talk** (`⌃⌥`) — the triangle becomes a live waveform while
  you're speaking, then a spinner while Claude thinks, then speaks the
  reply through macOS Speech or ElevenLabs.
- **Streaming response bubble** — Claude's reply appears in a rounded
  bubble beside the buddy, updating as tokens stream in. Auto-fades
  ~6 s after the turn finishes.
- **POINT flight** — when Claude emits a `[POINT:x,y:label]` tag, the
  buddy flies along a Bézier arc to that pixel on the correct display,
  holds with a label chip for 3 s, then flies back to the cursor.
- **Esc to cancel** — works from any app. Stops the Claude roundtrip,
  halts TTS mid-sentence, kills any in-flight POINT flight, and clears
  the bubble. A 250 ms debounce on voice dispatch means rapid re-presses
  of `⌃⌥` always resolve to exactly one Claude call, for your most
  recent utterance.
- **Menu-bar panel** — status icon with a typed "Test Claude" input,
  permission guidance, an ElevenLabs settings pane (API key + voice ID
  stored in the macOS Keychain), and a session history clear.

The plugin and the native app do not talk to each other — they're
independent experiences you choose between.

## Voice

Default engine is macOS `say`. Two optional upgrades:

### VibeVoice (local, free)

Run VibeVoice yourself from its
[repo](https://github.com/microsoft/VibeVoice) and point the
plugin at it:

```bash
export CLICKY_VIBEVOICE_URL=http://localhost:3000
export CLICKY_VIBEVOICE_SPEAKER=Carter   # optional, default Carter
```

If the server is unreachable the plugin falls back to `say` with a
one-line warning.

### ElevenLabs (paid, your own key)

```bash
export CLICKY_ELEVENLABS_API_KEY=sk-...
export CLICKY_ELEVENLABS_VOICE_ID=kPzsL2i3teMYv0FxEYQ6   # optional
```

The plugin never ships, bundles, or exfiltrates any API key.

## Environment variables

| Variable | Effect |
|---|---|
| `CLICKY_DATA_DIR` | Override state dir (default `~/Library/Application Support/clicky-ai/`) |
| `CLICKY_APP_PATH` | Explicit path to an installed `Clicky.app` |
| `CLICKY_VIBEVOICE_URL` | Local VibeVoice HTTP server URL |
| `CLICKY_VIBEVOICE_SPEAKER` | VibeVoice speaker name |
| `CLICKY_ELEVENLABS_API_KEY` | User-supplied ElevenLabs key |
| `CLICKY_ELEVENLABS_VOICE_ID` | ElevenLabs voice ID |

State written under `$CLICKY_DATA_DIR`:

```
clicky-ai/
├── screenshots/       # multi-display JPEGs emitted by `capture`
├── downloads/         # DMGs downloaded by `install` (kept for inspection)
└── config.json        # future: plugin config
```

## Troubleshooting

- **`capture` errors with "could not create image from display"** —
  Screen Recording permission isn't granted. Grant it to the terminal
  that runs `bun`, then re-run.
- **`install` reports "brew available → brew install failed"** — the
  cask `proyecto26/tap/clicky-ai` isn't published yet (or the tap isn't
  tapped). The script automatically falls back to the DMG download.
- **`status` says `claudeCLI.installed: false`** — the `claude` binary
  isn't in `$PATH`. Install it from
  [claude.com/claude-code](https://claude.com/claude-code).
- **`/clicky … ` doesn't trigger the skill** — make sure the plugin is
  loaded. Run `claude --debug` to see skill discovery logs, or add the
  plugin via `--plugin-dir`.

## Architecture

- **Zero npm dependencies.** All scripts use Node/bun built-ins
  (`node:fs`, `node:child_process`, `node:crypto`, `node:stream/promises`).
  No `package.json`, no `bun.lockb`.
- **Structure mirrors notebooklm-ai-plugin** exactly — shebang at the
  top of `main.ts`, per-subcommand modules, hand-rolled arg parser.
- **macOS-only** via explicit `assertDarwin()` gates.
- **No LLM calls from the plugin** — the host Claude Code session is
  the LLM. Plugin scripts are pure tool invocations.

See `docs/specs/clicky-ai-plugin.md` for the full spec and
`docs/plan/implementation-plan.md` for milestones + dependencies.

## License

MIT. See [LICENSE](LICENSE).
