<p align="center">
  <img src="https://raw.githubusercontent.com/karnel-termuxOFC/karnel-termux/main/assets/images/karnel-logo.png" alt="Karnel Termux Logo" width="400">
</p>

<p align="center">
  <strong>Transform your Android into a complete development workstation.</strong>
</p>

<p align="center">
  <a href="https://github.com/karnel-termuxOFC/karnel-termux">
    <img src="https://img.shields.io/badge/version-4.17.45-0078D4?style=for-the-badge" alt="Version">
  </a>
  <a href="https://www.npmjs.com/package/karnel-termux">
    <img src="https://img.shields.io/npm/v/karnel-termux?style=for-the-badge&logo=npm&color=cb3837" alt="npm">
  </a>
  <a href="https://www.npmjs.com/package/karnel-termux">
  <img src="https://img.shields.io/npm/dt/karnel-termux?style=for-the-badge&logo=npm&color=cb3837" alt="npm downloads">
</a>
  <a href="https://github.com/karnel-termuxOFC/karnel-termux/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-0078D4?style=for-the-badge" alt="License">
  </a>
  <a href="https://termux.dev/">
    <img src="https://img.shields.io/badge/platform-Termux%20%7C%20Android-0078D4?style=for-the-badge" alt="Platform">
  </a>
  <a href="https://karneltermux.vercel.app">
    <img src="https://img.shields.io/badge/Site-karneltermux.vercel.app-0078D4?style=for-the-badge" alt="Website">
  </a>
</p>

---

**Karnel Termux** is a modular development environment that transforms Termux into a complete workstation.

Created by **Israel Marques**.

With a single CLI (`karnel`), install and manage:

- **46 AI tools** — Claude, Gemini, OpenCode, Cactus, Hugging Face, Ollama, KeelCode, Goose, Factory Droid, 10Router and more
- **8 languages** — Node.js, Python, Go, Rust, C/C++, PHP, Perl, Bun
- **5 databases** — PostgreSQL, MariaDB, SQLite, MongoDB, Redis
- **22 dev tools** — gh, curl, fzf, bat, lsd, jq, tmux, openssh, snyk and more
- **13 utility tools** — fconv, notes, treex, qrcode, SuperFile, zork, herdr and more
- **2 network tools** — dark, dedsec-network
- **4 deploy CLIs** — Vercel, Railway, Netlify, Supabase
- **Responsible OSINT** — Robin v2.8 through Tor with a loopback-only web UI
- **3 editors** — code-server (VS Code in browser), Neovim, NvChad
- **Second brain** — Memory system with AI search and idea graph
- **Voice commands** — Speak to your AI agents
- **Plugin system** — Discover reviewed extensions: `karnel plugin search`
- **Security tools** — Nmap, Hydra, SQLMap, Metasploit and more: `karnel install security`

> [!IMPORTANT]
> Designed exclusively for **Termux on Android**. Does not work on other platforms.



---

## 🌟 Featured: Herdr — terminal AI assistant

Karnel now ships **[Herdr](https://herdr.dev)**, a blazing-fast terminal AI assistant CLI, as a first-class utility. Install it with:

```bash
karnel install utils --herdr
```

Why it's great:
- **Checksum-verified** download from the official Herdr release manifest (`https://herdr.dev/latest.json`).
- **Atomic, safe install** into `$PREFIX/bin/herdr` with a Karnel ownership marker — so `karnel uninstall utils --herdr` is clean and never touches files it didn't manage.
- Pairs perfectly with the 46 AI agents Karnel manages.

> Open its docs anytime with `karnel open herdr`.

---

## Installation

### Via checksummed GitHub release (recommended)

```bash
version=4.17.45
tmpdir=$(mktemp -d) && trap 'rm -rf "$tmpdir"' EXIT
base="https://github.com/karnel-termuxOFC/karnel-termux/releases/download/v$version"
curl -fsSL "$base/karnel-termux-install.sh" -o "$tmpdir/karnel-termux-install.sh"
curl -fsSL "$base/karnel-termux-install.sh.sha256" -o "$tmpdir/karnel-termux-install.sh.sha256"
(cd "$tmpdir" && sha256sum -c karnel-termux-install.sh.sha256) && bash "$tmpdir/karnel-termux-install.sh" --ref "v$version"
```

### Via npm

```bash
npm install -g karnel-termux
```

### Via pnpm

```bash
pnpm add -g karnel-termux
```

After installation, run:

```bash
karnel
```

### Noninteractive mode

Use `--auto` before or after a command to approve supported confirmations and
select the recommended installation method without prompting. With no tool
flags, the whole module is installed:

```bash
karnel --auto install ai
karnel install security --auto
karnel --auto update ai
```

`--auto` does not invent required values such as API tokens, passwords, project
names, or voice input. It also does not replace explicit trust and legal opt-in
flags such as `--unsafe` or `--accept-responsible-use`.

In a terminal, running `karnel` without a command opens a curated menu for
common workflows. The menu is not a complete inventory of CLI commands,
aliases, or options; use `karnel help` and the CLI reference for the full set.

---

## Usage

### Main Commands

| Command | Description |
|---------|-------------|
| `karnel install <module>` | Install modules and tools |
| `karnel list <module>` | List available tools |
| `karnel show <module> --<tool>` | Show tool documentation |
| `karnel open <module>` | Open documentation in browser |
| `karnel update <module>` | Update modules or karnel |
| `karnel uninstall <module>` | Remove installed modules |
| `karnel reinstall <module>` | Reinstall modules |
| `karnel upgrade` | Upgrade the framework (self-update) |
| `karnel ia` | Manage AI agent sessions, install tools, show launchers |
| `karnel search <query>` | Search tools and Brain memories |
| `karnel stats` | System overview: versions, modules, disk usage, tool counts |
| `karnel status` | System health dashboard (disk, RAM, services, connectivity) |
| `karnel start editor [port]` | Start code-server (VS Code in browser) |
| `karnel start robin` | Start Robin OSINT (Tor + web UI) |
| `karnel doctor termux` | Diagnose the Termux environment (30+ sections) |
| `karnel doctor code` | Detect project ecosystems and run code checks |
| `karnel doctor robin` | Diagnose Robin, Tor, dependencies, and local UI |
| `karnel brain` | Second brain — memories and search |
| `karnel env` | Manage environment variables |
| `karnel voice` | Voice commands for AI agents |
| `karnel agent` | Local AI assistant — chat (`ask`) and task agent (`run`) |
| `karnel pg` | PostgreSQL manager |
| `karnel init <template>` | Initialize projects with templates |
| `karnel deploy` | Run Vercel, Railway, Netlify, or Supabase CLI commands |
| `karnel supabase` | Manage the Supabase CLI and remote-project helpers |
| `karnel robin` | Manage the Robin OSINT service |
| `karnel backup` | Backup Termux configs and package metadata |
| `karnel restore` | Restore Termux from a backup |
| `karnel cleanup` | Clean caches, logs, and temp files |
| `karnel plugin` | Plugin manager — search, install, enable, disable, config |
| `karnel --version` | Show installed version |

### Modules

| Module | Description | Installation |
|--------|-------------|--------------|
| `lang` | Node.js, Python, Go, Rust, C/C++, PHP, Perl, Bun | `karnel install lang` |
| `db` | PostgreSQL, MariaDB, SQLite, MongoDB, Redis | `karnel install db` |
| `ai` | 46 AI tools, agents, and local inference clients | `karnel install ai` |
| `editor` | code-server (VS Code in browser), Neovim, NvChad | `karnel install editor` |
| `dev` | gh, curl, fzf, bat, lsd, jq and more | `karnel install dev` |
| `npm` | TypeScript, NestJS CLI, Prettier and more | `karnel install npm` |
| `shell` | ZSH + Oh My Zsh + 10 plugins | `karnel install shell` |
| `ui` | Font, cursor, extra-keys, banner | `karnel install ui` |
| `auto` | Automation with n8n | `karnel install auto` |
| `deploy` | Vercel, Railway, Netlify, Supabase | `karnel install deploy` |
| `games` | Buzz, CTF God, Detective, Tamagotchi and more | `karnel install games` |
| `network` | Dark Web OSINT, DedSec Network Toolkit | `karnel install network` |
| `utils` | fconv, notes, treex, SuperFile, passman, applaunch, qrcode, zork and more | `karnel install utils` |
| `osint` | Robin v2.8, Tor, Streamlit, and LLM providers | `karnel install osint` |
| `voice` | Speech-to-agent through Termux:API | `karnel install voice` |
| `plugin` | Built-in plugin manager — reviewed registry and local plugins | `karnel plugin search` |
| `security` | Nmap, Hydra, SQLMap, Metasploit, Gobuster and more | `karnel install security` |

---

### KeelCode and SuperFile

```bash
# Install the KeelCode coding agent
karnel install ai --keelcode

# Install the SuperFile terminal file manager
karnel install utils --superfile --herdr
```

Both tools support `update`, `reinstall`, and `uninstall` with the same module and flag.

---

## Plugin System

Discover and install reviewed plugins from the official registry:

```bash
karnel plugin search
karnel plugin search backup --compatible
karnel plugin install karnel-hello
karnel plugin update karnel-hello
karnel plugin enable karnel-hello
karnel plugin disable karnel-hello
karnel plugin config karnel-hello greeting "Hello"
karnel plugin list
karnel plugin remove karnel-hello
karnel plugin create my-plugin
```

Plugins are Bash code loaded by the Karnel process and run with the current
user's permissions. They are not sandboxed. Registry plugins have reviewed
metadata and are staged, validated, and atomically activated, but you should
still review code you do not trust.

Use `karnel plugin disable` to temporarily stop a plugin without removing it,
and `karnel plugin enable` to reactivate it. Per-plugin configuration is
supported with `karnel plugin config <name> [key] [value]`.

Each Karnel release pins and verifies one reviewed registry snapshot. New
registry entries become available after updating Karnel to a release that
includes that snapshot.

Installing an arbitrary GitHub repository requires both `--unsafe` and an
interactive confirmation:

```bash
karnel plugin install owner/repo --unsafe
```

`--unsafe` is not a sandbox or an approval. It is intentionally required again
when updating an unsafe plugin. The plugin manager never creates a missing
manifest for a cloned repository.

Every plugin requires a strict `karnel-plugin.json`, a `LICENSE` or
`LICENSE.md`, and exact files in `commands/`. The manifest declares Schema v1,
safe name, SemVer version, description, `commands`, `minKarnelVersion`, license,
optional checksum, and informational capabilities. Native command names and
plugin-to-plugin command collisions are rejected.

The installed plugin directory is `${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data/plugins`.
See the [official plugin registry](https://github.com/karnel-termuxOFC/karnel-plugins)
for schemas, review policy, and safe publication requirements.

## AI CLIs

Supercode CLI and Puter CLI are available in the `ai` module. They require
Node.js 18 or newer and install their official npm packages.

```bash
karnel install ai --supercode-cli
supercode
```

## Puter CLI

Puter CLI is available in the `ai` module for managing Puter sites and workers.

```bash
karnel install ai --puter
puter login
puter whoami
puter site deploy [directory] [subdomain]
puter worker deploy [file] [name]
```

For noninteractive automation, configure `PUTER_AUTH_TOKEN` in your own
environment. Do not place tokens in the repository, shell history, screenshots,
or issue reports.

## Security Tools

Install security auditing tools:

```bash
karnel install security                           # Install all
karnel install security --nmap --hydra --sqlmap    # Install specific ones
```

Includes 30 tools: Nmap, Hydra, Nikto, SQLMap, Gobuster, Dirb, WPScan, John the
Ripper, Aircrack-ng, Metasploit, Burp Suite, OWASP ZAP, FFUF, Amass, Hashcat and
more. Use only on systems you own or are authorized to test.

---

## Robin OSINT

Robin is an independent AI-assisted dark-web OSINT project. Karnel pins the
tested `v2.8` release, installs native Termux scientific dependencies, binds the
web interface only to `127.0.0.1`, and keeps application code separate from
provider configuration and saved investigations.

```bash
karnel install osint --robin
karnel robin config
karnel robin start
karnel robin doctor --network
```

Open `http://127.0.0.1:8501` only after the health check succeeds. Use Robin
solely for lawful, authorized, and ethical research. Tor does not guarantee
anonymity, external LLM traffic normally bypasses Tor, providers may process
submitted data, and AI output is not verified evidence.

Uninstall and reinstall preserve `$KARNEL_CONFIG/robin/.env` and
`$KARNEL_DATA/robin/investigations`. Permanent deletion requires the explicit
`karnel robin purge-data` command.

See the bundled reference with `karnel show osint --robin`.

---

## AI Tools (46)

```bash
karnel install ai                             # Install all
karnel install ai --opencode --ollama         # Install specific agents
```

<details>
<summary><strong>View complete agent list</strong></summary>

| Agent | Flag | Description |
|-------|------|-------------|
| **10Router** | `--10router` | Start and manage a 10Router server |
| **Qwen Code** | `--qwen-code` | Alibaba coding assistant |
| **Gemini CLI** | `--gemini-cli` | Google Gemini assistant |
| **Claude Code** | `--claude-code` | Anthropic CLI with Claude AI |
| **Mistral Vibe** | `--mistral-vibe` | Mistral command-line assistant |
| **OpenClaude** | `--openclaude` | Open source Claude Code alternative |
| **OpenClaw** | `--openclaw` | Personal AI assistant |
| **Ollama** | `--ollama` | Run open source LLMs locally |
| **Cactus** | `--cactus` | On-device ARM64 inference through an isolated Ubuntu runtime |
| **Hugging Face** | `--hugging-face` | Official Hugging Face Hub CLI (`hf`) |
| **Codex CLI** | `--codex` | OpenAI coding agent |
| **OpenCode** | `--opencode` | Open source terminal agent |
| **MiMoCode** | `--mimocode` | Fast open source AI agent |
| **Engram** | `--engram` | Persistent memory system |
| **CodeGraph** | `--codegraph` | Code structure analysis |
| **Pi** | `--pi` | Minimalist terminal harness |
| **Qoder** | `--qoder` | Terminal-native AI coding partner and agent engine |
| **Antigravity CLI** | `--antigravity-cli` | Terminal interface for Antigravity |
| **MiniMax CLI** | `--minimax-cli` | Generate text, image, video and audio |
| **Gentle AI** | `--gentle-ai` | AI workflow ecosystem |
| **GGA** | `--gga` | Multi-provider automated code review |
| **Hermes Agent** | `--hermes-agent` | Nous Research self-improving agent |
| **Kimi Code** | `--kimi-code` | Kimi Code CLI |
| **Command Code** | `--command-code` | Agent that learns your style |
| **Codebuff** | `--codebuff` | Free community coding agent |
| **Freebuff** | `--freebuff` | Free AI coding agent |
| **Kilo Code CLI** | `--kilocode-cli` | Native glibc CLI for Termux |
| **Kiro CLI** | `--kiro` | AWS AI coding assistant |
| **Crush CLI** | `--crush` | Charm AI agents CLI |
| **Odysseus** | `--odysseus` | Odysseus coding assistant |
| **Kimchi CLI** | `--kimchi-code` | Kimchi AI agent |
| **Cline CLI** | `--cline` | Autonomous coding agent (via proot-distro) |
| **omniRoute** | `--omni-route` | AI gateway with 236+ providers |
| **Context7** | `--ctx7` | Documentation for AI assistants |
| **OpenSpec** | `--openspec` | Spec-Driven Development |
| **Copilot-Termux** | `--copilot-termux` | GitHub Copilot CLI adapted for Termux |
| **AMP Code CLI** | `--ampcode` | AI coding agent by Sourcegraph (glibc) |
| **Cursor CLI** | `--cursor-cli` | Official Cursor AI agent adapted for Termux (glibc) |
| **Oh-My-Pi** | `--oh-my-pi` | Enhanced Pi agent with native Rust addons |
| **Goose CLI** | `--goose` | AI agent framework by Block (native Termux musl) |
| **Factory Droid** | `--droid` | Enterprise AI agent (Ubuntu proot-distro with pinned npm package) |
| **Supercode CLI** | `--supercode-cli` | Supercode CLI — official npm package |
| **Puter CLI** | `--puter` | Puter CLI for sites and workers |
| **KeelCode** | `--keelcode` | Hosted coding-agent CLI |
| **Cactus Needle** | `--cactus-needle` | Lightweight Cactus inference helper |
| **Walkie Agent** | `--walkie` | Voice-first Walkie AI agent |
  
</details>

---

## karnel doctor

Doctor has three operational subcommands:

```bash
karnel doctor termux                 # 30+ Termux/Karnel diagnostic sections
karnel doctor termux --quick         # Run essential system/package checks only
karnel doctor termux --fix           # Apply queued fixes without group confirmation

karnel doctor code                   # Quick project analysis
karnel doctor code --standard .      # Add security, deps, dead-code and complexity
karnel doctor code --deep --json .   # All 76 definitions as standalone JSON
karnel doctor code --fix .           # Apply fixes classified as safe
karnel doctor robin                  # Robin/Tor/dependency diagnostics
karnel doctor robin --network        # Also verify traffic through Tor
```

Running `karnel doctor` without a subcommand defaults to `termux`.

The code analyzer recognizes 25 ecosystem labels and contains 76 check
definitions across 68 distinct tool labels. It detects subprojects, executes
checks in the matching project or subproject directory, preserves command exit status, and writes
timestamped text reports under `$KARNEL_DATA/doctor_code_reports/`.

Read the **[complete Doctor reference](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/doctor/index.md)** for modes,
supported ecosystems, tool coverage, JSON schema, reports, and auto-fix safety.

---

## karnel brain — Second Brain

Integrated memory system with text search, AI-assisted questions, and graph visualization.

```bash
karnel brain save "my idea"         # Save a thought
karnel brain search "postgres"     # Search local memories by text
karnel brain graph                 # Visualize idea connections
karnel brain sync                  # Sync with private GitHub
```

---

## karnel voice

Capture audio from the microphone, optionally review it in an editor, copy it
to the clipboard, and dispatch an AI agent with the transcribed prompt. If an
editor is unavailable or no TTY is attached, Karnel uses the raw transcript.

```bash
karnel voice opencode              # Record -> edit -> opencode run
karnel voice text                  # Record -> edit -> print to terminal
karnel voice claude-code --lang en # Speak in English -> claude -p
karnel voice "!"                   # Shortcut for "text"
```

### Supported Agents (14)

| Agent | Command executed |
|-------|-----------------|
| `kilo` | `kilo --prompt "..."` |
| `opencode` | `opencode run "..."` |
| `claude-code` | `claude -p "..."` |
| `codex` | `codex "..."` |
| `gemini-cli` | `gemini -p "..."` |
| `hermes-agent` | `hermes chat -q "..."` |
| `kimi-code` | `kimi -p "..."` |
| `mimocode` | `mimo run "..."` |
| `mistral-vibe` | `vibe --prompt "..."` |
| `openclaude` | `openclaude --bg "..."` |
| `pi` | `pi -p "..."` |
| `qwen-code` | `qwen -p "..."` |
| `crush` | `crush "..."` |
| `kiro` | `kiro-cli "..."` |
| `text` | Prints prompt to terminal |
| `!` | Alias for `text` |

### Options

| Flag | Description |
|------|-------------|
| `--lang <code>` | Speech language: `pt-BR`, `en-US`, `es`, etc |
| `--raw` | Skip editor, use raw capture |
| `--no-clip` | Don't copy prompt to clipboard |

### Flow

```
Microphone -> termux-speech-to-text -> editor (edit) -> clipboard -> AI agent
```

1. Speak the prompt
2. Review and correct in editor
3. Prompt is copied to clipboard
4. AI agent is dispatched with the prompt

### Requirements

- Termux:API: `pkg install termux-api`
- App Termux:API: https://github.com/termux/termux-api
- Editor (optional): `karnel install editor`; otherwise use `--raw` or the automatic raw fallback

---

## karnel pg — PostgreSQL

Manage PostgreSQL databases with simple commands:

```bash
karnel pg init && karnel pg start      # Initialize and start server
karnel pg create myapp               # Create a database
karnel pg shell                      # Open psql console
```

---

## karnel init — Project Templates

Configure existing projects in seconds:

```bash
cd my-next-app && karnel init next    # Next.js + TypeScript + Tailwind
cd my-api && karnel init express      # Express + TypeORM
cd backend && karnel init nest        # NestJS + authentication
```

| Template | Description |
|----------|-------------|
| `next` | Next.js with webpack, TypeScript, Tailwind, React Query, Zustand |
| `react` | React + Vite with modern structure |
| `express` | Express API with TypeScript + TypeORM + migrations |
| `nest` | NestJS with TypeORM and JWT auth |
| `python` | FastAPI with SQLModel/SQLAlchemy |
| `go` | Go with Gin or Fiber |
| `rust` | Rust with Axum or Actix Web |

---

## karnel env

Manage environment variables securely:

```bash
karnel env set                       # Add key (hidden input)
karnel env list                      # List variables
karnel env ls                        # List variables
```

---

## karnel deploy

Run an installed platform CLI through Karnel; arguments after the tool name are
forwarded unchanged:

```bash
karnel deploy vercel                  # Deploy to Vercel
karnel deploy railway                 # Deploy to Railway
karnel deploy netlify                 # Deploy to Netlify
karnel supabase doctor                # Check Supabase CLI and project setup
karnel supabase link --project-ref <ref> # Link the current project
```

Install a platform CLI first with `karnel install deploy --<tool>`.

---

## karnel open

Open documentation for any module in browser:

```bash
karnel open ai                        # Open AI module docs
karnel open db                        # Open DB module docs
```

Documentation loads from https://karneltermux.vercel.app.

---

## Documentation

- [Documentation index](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/index.md)
- [CLI reference](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/cli/index.md)
- [Doctor reference](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/doctor/index.md)
- [Troubleshooting](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/troubleshooting/index.md)
- [Architecture](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/ARCHITECTURE/index.md)
- [Documentation changelog](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/docs/CHANGELOG.md)
- [Official website](https://karneltermux.vercel.app)

---

## Examples

```bash
# Install databases
karnel install db --postgresql --sqlite

# Install specific AI agents
karnel install ai --opencode --ollama --claude-code

# View available tools
karnel list ai

# View tool documentation
karnel show ai --opencode

# Update everything
karnel update karnel

# Reinstall a module
karnel reinstall shell

# Full diagnosis
karnel doctor

# Deploy directly
karnel deploy vercel
```

---

## Project Structure

```
karnel/
├── karnel/
│   ├── bin/           # Binary (karnel)
│   ├── cli/
│   │   ├── commands/  # CLI commands (install, list, show, etc.)
│   │   └── karnel.sh    # Main CLI (with TUI)
│   ├── modules/       # Module orchestrators
│   ├── tools/         # Tool installers
│   │   ├── ai/        # 46 AI tools
│   │   ├── lang/      # 8 languages
│   │   ├── db/        # 5 databases
│   │   ├── dev/       # 22 dev tools
│   │   ├── editor/    # 3 editors
│   │   ├── npm/       # 11 global npm packages
│   │   ├── shell/     # 10 ZSH plugins
│   │   ├── ui/        # 4 UI components
│   │   ├── auto/      # 1 automation tool
│   │   ├── network/   # 2 network tools
│   │   ├── utils/     # 13 utility tools
│   │   ├── games/     # 6 games
│   │   ├── security/  # 30 security tools
│   │   ├── osint/     # Robin OSINT (Tor + LLM)
│   │   ├── voice/     # Speech-to-agent via Termux:API
│   │   ├── plugins/   # Plugin manager
│   │   └── deploy/    # 4 deploy CLIs
│   └── utils/         # Utilities (banner, log, env, etc.)
├── install.sh         # Installation script
├── package.json       # npm/pnpm publishing
└── .github/workflows/ # CI/CD
```

---

## Configuration

### Environment Variables

```bash
export KARNEL_DEBUG=1      # Debug logs
```

### Directories

| Directory | Description |
|-----------|-------------|
| `~/.local/share/karnel-data/` | Persistent tool data |
| `~/.cache/karnel/` | Logs and cache |
| `~/.config/karnel/` | User configuration |

---

## Automatic Updates

The framework checks for updates every 24 hours in background.

```bash
karnel update karnel     # Update the framework
```

`karnel update` requires a target such as `karnel`, `ai`, or `security`.
`karnel update karnel` first runs the official curl installer, then falls back to
the local Git checkout if needed. Package-manager fallback is used only when the
active framework was installed by that package manager. The curl installer is
pinned to the latest GitHub release tag, and its SHA-256 checksum is verified
before it runs. The framework checks for a new version in the background at most
once every 24 hours; the check can use npm or GitHub and writes state under
`$KARNEL_CACHE`.

---

## Verification And Limits

The repository CI validates Bash/Zsh syntax, ShellCheck errors, CLI smoke tests,
version behavior, Robin contracts, plugin lifecycle contracts, and npm package
contents. The `Publish Docs` workflow builds the GitHub Pages documentation
mirror with `actions/jekyll-build-pages`; the official Vite documentation site
is built and deployed separately through Vercel.

These checks do not install every external tool or prove behavior on every Android
device. Before relying on a new installer, test it in native Termux aarch64 with
a disposable environment and verify network, storage, PRoot, and Termux:API behavior
for your device.

---

## Support the Project

If Karnel Termux has been useful to you, consider supporting via Pix or starring on GitHub — it helps other developers discover the project.

**Pix:** `037f07bd-a326-42b6-a5a3-f29b36e703db`

---

## License

MIT © Israel Marques

---

<p align="center">
  <a href="https://karneltermux.vercel.app">
    <img src="https://img.shields.io/badge/Full%20Documentation-0078D4?style=for-the-badge" alt="Documentation">
  </a>
</p>
