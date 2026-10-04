---
title: CLI Commands
permalink: /cli/
layout: base
---

# Karnel CLI Reference

```bash
karnel <command> [arguments]
```

With no command, Karnel opens a curated interactive menu (TUI) when a terminal
is available and prints help in noninteractive contexts. The menu exposes common
workflows, not every command, alias, or option documented below.

---

## install — Install modules and tools

```bash
karnel install <module>              # Install all tools in a module
karnel install <module> --tool1 --tool2  # Install specific tools only
```

### Available modules

| Module    | Description |
|-----------|-------------|
| `lang`    | Node.js, Python, Go, Rust, C/C++, PHP, Perl, Bun |
| `db`      | PostgreSQL, MariaDB, SQLite, MongoDB, Redis |
| `ai`      | 46 AI tools (OpenCode, Cactus, Hugging Face, Claude Code, KeelCode, Goose, Factory Droid, 10Router, Ollama, etc.) |
| `editor`  | code-server (VS Code in browser), Neovim, NvChad |
| `dev`     | gh, curl, fzf, bat, lsd, jq, tmux, openssh, snyk (22 tools) |
| `npm`     | TypeScript, NestJS CLI, Prettier, Vercel CLI, etc. |
| `shell`   | ZSH + Oh My Zsh + 10 plugins |
| `ui`      | Font, cursor, extra-keys, banner |
| `auto`    | n8n automation |
| `deploy`  | Vercel, Railway, Netlify, Supabase CLIs |
| `games`   | Buzz, CTF God, Detective, Tamagotchi, Arcade, Pet Friends |
| `network` | Dark-web and anonymity tooling, plus the DedSec Network Toolkit |
| `utils`   | fconv, filecheck, websites, notes, treex, passman, applaunch, splash, httptmux, zork, qrcode, superfile, herdr (13 scripts) |
| `osint`   | Robin v2.8 — dark web OSINT via Tor + LLM |
| `voice`   | Speech-to-agent via Termux:API |
| `security`| Nmap, Hydra, SQLMap, Metasploit, and 26 other tools |
| `plugin`  | Built-in manager for plugins from the official registry |

### Per-module tool flags

| Module    | Flags |
|-----------|-------|
| `ai`      | `--qwen-code`, `--gemini-cli`, `--claude-code`, `--mistral-vibe`, `--openclaude`, `--openclaw`, `--ollama`, `--codex`, `--opencode`, `--mimocode`, `--engram`, `--codegraph`, `--pi`, `--antigravity-cli`, `--minimax-cli`, `--gentle-ai`, `--gga`, `--hermes-agent`, `--kimi-code`, `--command-code`, `--codebuff`, `--freebuff`, `--kilocode-cli`, `--kiro`, `--crush`, `--cline`, `--odysseus`, `--kimchi-code`, `--omni-route`, `--ctx7`, `--openspec`, `--supercode-cli`, `--puter`, `--keelcode`, `--copilot-termux`, `--qoder`, `--ampcode`, `--cursor-cli`, `--oh-my-pi`, `--goose`, `--droid`, `--cactus`, `--cactus-needle`, `--walkie`, `--hugging-face` |
| `db`      | `--postgresql`, `--mariadb`, `--sqlite`, `--mongodb`, `--redis` |
| `dev`     | `--gh`, `--wget`, `--curl`, `--lsd`, `--bat`, `--proot`, `--ncurses`, `--tmate`, `--openssh`, `--tmux`, `--cloudflared`, `--translate`, `--html2text`, `--jq`, `--bc`, `--tree`, `--fzf`, `--imagemagick`, `--shfmt`, `--make`, `--udocker`, `--snyk` |
| `lang`    | `--bun`, `--nodejs`, `--python`, `--perl`, `--php`, `--rust`, `--clang`, `--golang` |
| `npm`     | `--typescript`, `--nestjs`, `--prettier`, `--live-server`, `--localtunnel`, `--vercel`, `--markserv`, `--psqlformat`, `--ncu`, `--ngrok`, `--turbopack` |
| `shell`   | `--powerlevel10k`, `--zsh-defer`, `--zsh-autosuggestions`, `--zsh-syntax-highlighting`, `--history-substring`, `--zsh-completions`, `--fzf-tab`, `--you-should-use`, `--zsh-autopair`, `--better-npm` |
| `editor`  | `--code-server`, `--neovim`, `--nvchad` |
| `ui`      | `--font`, `--extra-keys`, `--cursor`, `--banner` |
| `auto`    | `--n8n` |
| `deploy`  | `--vercel`, `--railway`, `--netlify`, `--supabase` |
| `osint`   | `--robin` |
| `games`   | `--buzz`, `--ctfgod`, `--detective`, `--pet-friends`, `--tamagotchi`, `--arcade` |
| `network` | `--dark`, `--dedsec-network` |
| `utils`   | `--fconv`, `--filecheck`, `--websites`, `--notes`, `--treex`, `--passman`, `--applaunch`, `--splash`, `--httptmux`, `--zork`, `--qrcode`, `--superfile`, `--herdr` |
| `security`| Run `karnel list security` for the 30 supported tool flags |

```bash
karnel install ai --opencode --ollama
karnel install db --postgresql --sqlite
karnel install dev --gh --fzf --jq
karnel install network --dark
karnel install utils --fconv --notes --qrcode
```

---

## uninstall — Remove modules and tools

```bash
karnel uninstall <module>
karnel uninstall <module> --tool1 --tool2
```

Same modules and flags as `install`. Removes installed packages and binaries.
User configuration is preserved by default; Karnel asks for confirmation before
removing configuration paths it manages. `ui --extra-keys` adds and removes
only its marked block in `~/.termux/termux.properties`.

```bash
karnel uninstall ai --opencode --ollama
karnel uninstall db --postgresql --sqlite
```

---

## reinstall — Uninstall + install a module

```bash
karnel reinstall <module>
karnel reinstall <module> --tool1 --tool2
```

Performs `uninstall` followed by `install` for the selected module or tools.

---

## update — Update modules or framework

```bash
karnel update <module>            # Update all tools in a module
karnel update <module> --tool1    # Update specific tools
karnel update karnel              # Update the Karnel-Termux package only
```

`karnel update karnel` first downloads and runs the official installer with
`curl`. If that fails, it tries the local Git checkout and then npm or pnpm.

---

## upgrade — Upgrade the Karnel framework

```bash
karnel upgrade
```

No arguments. Uses the same curl-first framework update flow as
`karnel update karnel`, then re-sources the environment, verifies the `karnel`
symlink, runs cleanup, and shows the new version.

---

## list — List available tools in a module

```bash
karnel list <module>
```

Displays a formatted table of all tools in a module with their install flag,
binary/command name, and current install status.

| Module    | Lists |
|-----------|-------|
| `lang`    | 8 languages |
| `db`      | 5 databases |
| `ai`      | 46 AI tools |
| `editor`  | 3 editor components |
| `dev`     | 22 development tools |
| `npm`     | 11 npm global modules |
| `shell`   | 10 ZSH plugins |
| `ui`      | 4 UI components |
| `auto`    | 1 automation tool (n8n) |
| `deploy`  | 4 deploy CLIs |
| `games`   | 6 games |
| `network` | 2 network tools |
| `osint`   | Robin OSINT (Tor + LLM) |
| `voice`   | Voice command |
| `security`| 30 security tools |
| `utils`   | 13 utility scripts |
| `plugin`  | Installed plugins |

```bash
karnel list ai
karnel list dev
karnel list network
karnel list utils
```

---

## show — Show documentation for a tool

```bash
karnel show <module> --<tool>      # Show README for a specific tool
karnel show <module>               # List all tools in the module
karnel show backup                 # Show backup documentation
karnel show restore                # Show restore documentation
```

Renders the tool's `README.md` with `glow` (if installed), `pygmentize`, or
plain `cat`.

```bash
karnel show ai --opencode
karnel show db --postgresql
karnel show dev --gh
karnel show osint --robin
karnel show network --dark
karnel show utils --zork
```

---

## open — Open documentation in browser

```bash
karnel open <target>
```

Opens the official documentation page for a module using
`termux-open-url`. Base URL: `https://karneltermux.vercel.app`

| Target           | Opens |
|------------------|-------|
| `karnel` / `help` | Overview |
| `lang`           | Language modules |
| `db`             | Database modules |
| `ai`             | AI tools |
| `editor`         | Code editor |
| `dev`            | Dev tools |
| `npm`            | Node.js tools |
| `shell`          | ZSH shell |
| `ui`             | Termux UI |
| `auto`           | Automation tools |
| `deploy`         | Deploy CLIs |
| `supabase`       | Supabase CLI |
| `games`          | Games |
| `cleanup`        | Cache cleanup |
| `network`        | Network tools |
| `utils`          | Utility tools |
| `herdr`          | Herdr terminal AI assistant |
| `voice`          | Voice command |
| `plugin`          | Plugin system |
| `security`        | Security tools |
| `osint` / `robin` | OSINT tools |

```bash
karnel open ai
karnel open db
karnel open network
karnel open utils
```

---

## search — Search tools and memories

```bash
karnel search <query>
```

Searches:
1. **Tool registries** — matches tool IDs and names across all modules
2. **Brain memories** — full-text search of stored memories via `grep -ri`

```bash
karnel search postgres
karnel search react hooks
```

---

## status — System overview

```bash
karnel status
```

No arguments. Displays:
- Disk free space
- RAM usage (total, free, low-memory warning)
- System uptime
- Service status: PostgreSQL, code-server, omni-route, Robin
- Internet connectivity (ping to 8.8.8.8)
- Karnel version and last update check

---

## doctor — Diagnostics

```bash
karnel doctor                       # Defaults to termux
karnel doctor termux [--quick] [--fix]
karnel doctor code [options] [directory]
karnel doctor robin [--network]
```

### termux

```bash
karnel doctor termux                # 30+ health sections
karnel doctor termux --quick        # Essential checks only
karnel doctor termux --fix          # Apply fixes without confirmation
```

Covers: Android, Termux, CPU, RAM, disk, locale, battery, GPU, storage,
permissions, 11 critical commands, package managers, runtimes, PostgreSQL,
Karnel, AI commands, shell config, processes, networking.

### code

```bash
karnel doctor code                              # Quick registry set (default)
karnel doctor code --standard /path/to/project   # + security, deps, dead-code
karnel doctor code --deep --json /path/to/project # All 76 definitions
karnel doctor code --fix /path/to/project        # Apply safe fixes
```

| Option | Description |
|--------|-------------|
| `--quick`, `-q` | 64 definitions; default |
| `--standard`, `-s` | 74 definitions; adds security, deps, dead-code, complexity |
| `--deep`, `-d` | All 76 definitions |
| `--fix`, `--safe-fix` | Apply fixes classified as safe |
| `--aggressive-fix` | Also apply unclassified fixes |
| `--json`, `-j` | Standalone JSON output |
| `--help`, `-h` | Print help |

Recognizes 25 ecosystem labels. Writes timestamped reports to
`$KARNEL_DATA/doctor_code_reports/`.

### robin

```bash
karnel doctor robin                 # Source, venv, Tor, Streamlit, config
karnel doctor robin --network       # Also verify HTTPS through Tor
```

Never calls an LLM. `--network` adds a small HTTPS request routed through Tor.

---

## robin — OSINT tool management

```bash
karnel robin <subcommand> [options]
```

| Subcommand | Description |
|------------|-------------|
| `start`    | Start Tor + Robin web interface on 127.0.0.1:8501 |
| `stop`     | Stop the managed Robin interface |
| `status`   | Show installation and runtime state |
| `config`   | Show protected provider configuration |
| `doctor`   | Run local diagnostics |
| `update`   | Reconcile with Karnel's pinned Robin release |
| `purge-data` | Permanently delete config and investigations |

| Flag | Applies to | Description |
|------|------------|-------------|
| `--accept-responsible-use` | `start` | Skip the responsible-use acknowledgement prompt |
| `--network` | `doctor` | Test Tor traffic with an HTTPS request |
| `--yes` | `purge-data` | Non-interactive confirmation |

```bash
karnel robin start
karnel robin start --accept-responsible-use
karnel robin doctor --network
karnel robin purge-data --yes
```

See the [Robin reference](https://github.com/karnel-termuxOFC/karnel-termux/blob/main/karnel/tools/osint/robin/README.md) for detailed
lifecycle, data locations, and troubleshooting.

---

## brain — Second brain / personal memory

```bash
karnel brain <subcommand> [options]
```

| Subcommand | Description |
|------------|-------------|
| `init`     | Initialize brain directory and GitHub repo |
| `save`     | Save a new memory (interactive) |
| `search`   | Search memories by keywords or tags |
| `ls` / `list` | List memories, optionally filtered by category |
| `edit`     | Edit a memory in `$EDITOR` |
| `delete` / `rm` | Delete a specific memory |
| `reset` / `destroy` | Delete the entire brain |
| `show` / `view` | View a memory with its relations |
| `graph` / `map` | Visualize memory connections |
| `skill` / `skills` | Create an AI skill from related memories |
| `relate`   | Link two memories by slug |
| `sync`     | Push/pull to a private GitHub repo |
| `ask`      | Ask AI a question with brain context |
| `config` / `ai-config` | Configure AI provider for `ask` |

### brain ask

```bash
karnel brain ask "What did I learn about React?"
karnel brain ask --only-memories "How to configure PostgreSQL?"
```

| Flag | Description |
|------|-------------|
| `--only-memories`, `-m` | Answer from memory only (no live AI generation) |

### brain config

```bash
karnel brain config                    # Show current config
karnel brain config <key> <value>      # Set a config value
```

Keys: `provider`, `default_model`, `context_max_size`, `cache_enabled`,
`only_memories`.

### brain ls

```bash
karnel brain ls                        # All memories by category
karnel brain ls react                  # Filter by category
```

### brain relate

```bash
karnel brain relate <slug-a> <slug-b>  # Link two memories
```

### brain edit / delete / show

```bash
karnel brain edit <slug>
karnel brain delete <slug>
karnel brain show <slug>
```

---

## env — Environment variables

```bash
karnel env <subcommand>
```

| Subcommand | Description |
|------------|-------------|
| `set`      | Create or update a variable (interactive, hidden input) |
| `unset`    | Remove a variable (interactive) |
| `ls` / `list` | List all user-defined variables |

Targets `~/.zshrc` (falls back to `~/.bashrc`). Sensitive values (containing
`SECRET`, `TOKEN`, `API`, `KEY`, `PASSWORD`, `CREDENTIAL`) are masked when
listed.

```bash
karnel env set
karnel env unset
karnel env ls
```

---

## voice — Speech-to-agent

```bash
karnel voice [agent] [options]
```

Captures audio via `termux-speech-to-text`, optionally opens the transcript in
`$EDITOR`, copies it to the clipboard, and dispatches the AI agent. If no editor
is installed or no TTY is available, Karnel continues with the raw transcript.

### Agent targets

| Agent         | Command executed |
|---------------|-----------------|
| `kilo`        | `kilo --prompt "..."` |
| `opencode`    | `opencode run "..."` |
| `claude-code` | `claude -p "..."` |
| `codex`       | `codex "..."` |
| `gemini-cli`  | `gemini -p "..."` |
| `hermes-agent` | `hermes chat -q "..."` |
| `kimi-code`   | `kimi -p "..."` |
| `mimocode`    | `mimo run "..."` |
| `mistral-vibe` | `vibe --prompt "..."` |
| `openclaude`  | `openclaude --bg "..."` |
| `pi`          | `pi -p "..."` |
| `qwen-code`   | `qwen -p "..."` |
| `crush`       | `crush "..."` |
| `kiro`        | `kiro-cli "..."` |
| `text`        | Print prompt to stdout (no agent) |
| `!`           | Alias for `text` |

### Options

| Flag | Description |
|------|-------------|
| `--lang <code>` | Speech language: `pt-BR`, `en-US`, `es`, etc. |
| `--raw` | Skip the editor step |
| `--no-clip` | Skip clipboard copy |
| `--help`, `-h` | Show help |

### Flow

```
Microphone → termux-speech-to-text → editor (edit) → clipboard → AI agent
```

```bash
karnel voice opencode                 # Speak → edit → opencode run
karnel voice claude-code --lang pt-BR # Portuguese → claude -p
karnel voice text --raw               # Capture → print (no edit)
karnel voice text --no-clip           # Capture → edit → print
```

---

## ia — AI agent manager

```bash
karnel ia <command> [options]
```

| Command | Description |
|---------|-------------|
| `sessions` | List all AI conversation sessions |
| `install`  | Install an AI tool (`karnel ia install <tool>`) |
| `routes` / `launchers` | Show all available AI CLI methods with paths |

```bash
karnel ia sessions
karnel ia install omni-route
karnel ia routes
```

---

## agent — Local AI assistant

```bash
karnel agent <ask|run|config> [options]
```

| Subcommand | Description |
|------------|-------------|
| `ask`  | Streamed AI chat assistant (markdown TUI). With no prompt, opens an interactive chat. |
| `run`  | Task agent: the LLM answers in a plan/build/execute loop and can run shell commands. |
| `config` | Show or set the assistant configuration. |

### Options (ask / run)

| Flag | Description |
|------|-------------|
| `-p`, `--prompt <text>` | Task or question (omit for interactive mode) |
| `-m`, `--model <name>` | Model id (default from config) |
| `-u`, `--endpoint <url>` | OpenAI-compatible endpoint (default from config) |
| `-t`, `--temperature <n>` | Sampling temperature |
| `--max-tokens <n>` | Maximum output tokens |
| `-n`, `--max-iterations <n>` | Agent loop iteration limit (`run`) |
| `-y`, `--yes` | Auto-approve commands, skip the y/N prompt (`run`) |
| `-w`, `--workspace <dir>` | Working directory for the task agent (`run`) |

```bash
karnel agent ask -p "Explain rsync"
karnel agent ask                       # interactive chat
karnel agent run -p "create a backup script"
karnel agent run -p "..." -m gemma-4-e2b-it-cq4 -u http://127.0.0.1:8000/v1
karnel agent config                    # show current settings
karnel agent config model gpt-4o        # set the default model id
```

`karnel agent ask` connects to the configured OpenAI-compatible endpoint; if it is
unreachable and Cactus is not installed, it offers to install Cactus on the spot.

---

## init — Project configuration

```bash
karnel init <template>
karnel init                          # Auto-detect an existing project
```

| Template | Project type |
|----------|-------------|
| `next` / `nextjs` | Next.js + TypeScript + Tailwind |
| `react` / `vite` | React + Vite |
| `nest` / `nestjs` | NestJS + TypeORM + JWT |
| `express` / `exp` | Express + TypeScript + TypeORM |
| `python` / `fastapi` | FastAPI + SQLModel/SQLAlchemy |
| `go` / `gin` | Go with Gin or Fiber |
| `rust` / `axum` | Rust with Axum or Actix Web |

Auto-detection checks for `package.json`, `requirements.txt`, `go.mod`,
`Cargo.toml`.

```bash
cd my-next-app && karnel init next
cd my-api && karnel init express
cd . && karnel init                   # Auto-detect
```

---

## deploy — Run deployment CLIs

```bash
karnel deploy <tool> [args...]
```

`deploy` checks that the selected executable exists, then replaces Karnel with
that CLI and forwards all remaining arguments.

| Tool | Executable |
|------|------------|
| `vercel` | `vercel` |
| `railway` | `railway` |
| `netlify` | `netlify` |
| `supabase` | `supabase`; this is a generic CLI pass-through, not a deployment action by itself |

```bash
karnel deploy vercel
karnel deploy vercel --prod
karnel deploy railway
karnel deploy netlify
karnel deploy supabase
```

---

## supabase — Remote-project helpers

```bash
karnel supabase <subcommand> [options]
```

The top-level command manages the pinned Supabase CLI installation and provides
thin wrappers for linked-project workflows. It does not start the local Supabase
stack on Termux; `supabase start` requires Docker on a Linux host.

| Subcommand | Description |
|------------|-------------|
| `doctor` | Check the CLI, `supabase/config.toml`, Docker expectations, and API reachability |
| `types` | Run `supabase gen types typescript --linked`; extra arguments are not forwarded |
| `migrate` | Forward arguments to `supabase db` |
| `link` | Forward arguments to `supabase link` |
| `remote-start` / `remote` | Print a guide for running the Docker-backed local stack on a Linux host |
| `remote-status` / `status` | Run `supabase status`, which reports the local stack rather than hosted-project health |
| `install` / `uninstall` | Install or remove Karnel's pinned Supabase CLI binary |

```bash
karnel supabase install
karnel supabase link --project-ref abcdef
karnel supabase types
karnel supabase migrate push
```

The downloaded Linux binary may still fail on Android because of unsupported
system calls. The wrapper reports a `SIGSYS` failure and recommends PRoot or a
Linux host; installation alone does not guarantee native Android compatibility.

---

## plugin — Plugin manager

```bash
karnel plugin <subcommand> [options]
```

| Subcommand | Description |
|------------|-------------|
| `search [query]` | Search the pinned approved registry snapshot |
| `install <name>` | Install a plugin from that registry |
| `install <owner/repo> --unsafe` | Install an unreviewed repository after confirmation |
| `update <name>` | Atomically update an installed plugin |
| `remove` / `uninstall <name>` | Remove an installed plugin |
| `list` / `ls` | List installed plugins and their trust source |
| `create` / `scaffold <name>` | Create and activate a validated local plugin scaffold |

Search accepts `--command <name>`, `--compatible`, and `--capability <name>`.
Capabilities are `network`, `filesystem-read`, `filesystem-write`, `process`,
and `environment`. `--unsafe` applies only to `install` and `update`.

Plugins are Bash code, run with the current user's permissions, and are not
sandboxed. Registry review and manifest validation are not isolation boundaries.

```bash
karnel plugin search backup --compatible
karnel plugin install karnel-hello
karnel plugin install owner/repo --unsafe
karnel plugin update karnel-hello
karnel plugin remove karnel-hello
```

---

## pg — PostgreSQL manager

```bash
karnel pg <command> [args]
```

| Command | Description |
|---------|-------------|
| `start` | Start PostgreSQL server |
| `stop` | Stop PostgreSQL server |
| `restart` | Restart PostgreSQL server |
| `status` | Check PostgreSQL status |
| `init` | Initialize PostgreSQL database |
| `create <name>` | Create a database |
| `drop <name>` | Drop a database (interactive confirmation) |
| `backup [name]` | Backup a database (gzip + SHA256) |
| `restore [name] [file]` | Restore a database from backup |
| `list` / `ls` | List all databases |
| `list-backups` / `backups` | List backups with size, date, integrity |
| `schedule` | Schedule automatic backups via cron |
| `shell` / `psql` | Open psql shell |

Backup uses `pg_dump -F c -b` piped through `gzip` with SHA256 checksum.
Retains the last 10 backups per database. Schedule supports Daily (2:00 AM),
Weekly (Sundays 2:00 AM), or Hourly.

```bash
karnel pg init && karnel pg start
karnel pg create myapp
karnel pg shell
karnel pg backup myapp
karnel pg restore myapp /path/to/backup.gz
karnel pg schedule
```

---

## start — Start services

```bash
karnel start <target> [args]
```

| Target | Description |
|--------|-------------|
| `editor [port]` | Start code-server (default port: 8080) |
| `robin` | Start Tor + Robin (delegates to `karnel robin start`) |

```bash
karnel start editor
karnel start editor 8080
karnel start robin
```

---

## backup — Full Termux backup

```bash
karnel backup [--cloud]
karnel backup snapshot <name>
karnel backup list
karnel backup info [file]
karnel backup --cron
karnel backup restore [file]
```

Creates `$KARNEL_DATA/backups/termux-<timestamp>.tar.gz` with SHA256 checksum.
Concurrent runs reserve distinct names atomically instead of overwriting a
backup created in the same second.

### Included in backup

- Package selections embedded under `metadata/packages.list` (`dpkg --get-selections`)
- A catalog snapshot of tool installer directories, not a record of which tools are installed
- Selected shell configs (`.bashrc`, `.zshrc`, `.profile`, `.zshenv`, `.inputrc`)
- Termux configs (fonts, colors, properties)
- SSH configuration, known hosts, authorized keys, and public keys; private keys are excluded
- Selected `~/.config` application directories; `github-copilot`, `nvm`, `coc`, `Code`, and `yarn` are excluded, as are symbolic links and all `.env`, credential, auth, and token files matched by the backup filter
- `$PREFIX/etc/apt/sources.list` only; files under `sources.list.d` and APT keys are not included

Backups are gzip-compressed, not encrypted. API environment variables and SSH
private keys are not exported, but copied application configuration can still
contain credentials. Protect local and cloud copies as sensitive plaintext data.

### Options

| Flag | Description |
|------|-------------|
| `--cloud` | Upload to a configured rclone remote named `karnel` (e.g. Google Drive); archives are unencrypted at rest, so the `KARNEL_ALLOW_PLAINTEXT_CLOUD_BACKUP=1` acknowledgement is required |
| `snapshot <name>` | Create a timestamped named snapshot using the same contents and secret filter as a full backup; names accept 1-64 letters, numbers, dots, underscores, or hyphens |
| `list` / `ls` | List full backups and snapshots |
| `info` / `show [file]` | Show a backup's contents (latest if omitted) |
| `--cron` | Schedule a daily backup at 3:00 AM |
| `restore [file]` | Restore configuration from a full backup |
| `--help`, `-h` | Show help |

```bash
karnel backup
karnel backup --cloud
karnel backup snapshot before-update
karnel backup list
```

Cloud backup is disabled by default because the archive is not encrypted or
signed. The legacy opt-in uploads both archive and checksum, but they share the
same remote trust boundary. Package selections and the informational tool
catalog are embedded in the archive.

---

## restore — Full Termux restore

```bash
karnel restore [--cloud] [--list] [<file>]
```

### What it restores

- Selected shell configs to `~/`
- Termux configs
- SSH configuration and public keys (legacy archives may also contain private keys)
- The selected `.config` directories present in the archive
- `$PREFIX/etc/apt/sources.list` when present
- Embedded package selections (via `dpkg --set-selections` + `apt-get dselect-upgrade`)
- The tool catalog is retained as metadata only; Karnel does not incorrectly reinstall every tool in the source catalog

Requires and verifies the SHA256 checksum before extraction. Restore rejects
archives containing traversal paths, links, devices, or other unsafe entries.
Configuration is first merged into staging so unrelated existing files remain
in place, then committed with local backups. A copy, move, or package-restore
failure rolls configuration back instead of reporting a partial success.
Package-manager operations themselves are not transactionally reversible by
Karnel if `apt-get` changes package state before returning an error.

### Options

| Argument | Description |
|----------|-------------|
| `<file>` | Path to a specific backup file |
| `--cloud` | Restore from the rclone remote named `karnel`; a remote can replace both archive and checksum, so `KARNEL_ALLOW_UNAUTHENTICATED_CLOUD_RESTORE=1` is required to trust it |
| `--list`, `-l` | List available full backups and snapshots |
| `--help`, `-h` | Show help |

```bash
karnel restore
karnel restore /path/to/backup.tar.gz
karnel restore --cloud
karnel restore --list
```

---

## cleanup — Clean caches and temp files

```bash
karnel cleanup
```

Cleans:
- npm cache (`npm cache clean --force`)
- pip cache (`pip cache purge`)
- Karnel install logs (`install_*.log`)
- Python `__pycache__` directories
- pkg cache (`pkg clean -y`)
- Karnel banner and tip caches

---

## version — Print version

```bash
karnel version
```

Prints the installed Karnel version string (`$KARNEL_VERSION`).

---

## --version — Print version (flag form)

```bash
karnel --version
```

Equivalent to `karnel version`.

---

## help — Print top-level help

```bash
karnel help
```

Prints the main help screen with all commands and module targets.

---

## Module targets reference

The main tool modules work with `install`, `uninstall`, `reinstall`, `update`,
`list`, `show`, and `open`:

`ai` `auto` `db` `deploy` `dev` `editor` `games` `lang` `network` `npm`
`osint` `security` `shell` `ui` `utils`

`voice` works with `install`, `uninstall`, `reinstall`, `update`, `list`, and
`open`; it has no per-tool README for `show`.

`plugin` works with `install`, `uninstall`, `reinstall`, `update`, `list`, and
`open`, but does not expose tool documentation through `show`.

---

## Module documentation pages

Per-module documentation pages:

### ai
Documentation page: [ai module]({{ '/karnel/ai/' | relative_url }}).

### auto
Documentation page: [auto module]({{ '/karnel/auto/' | relative_url }}).

### db
Documentation page: [db module]({{ '/karnel/db/' | relative_url }}).

### deploy
Documentation page: [deploy module]({{ '/karnel/deploy/' | relative_url }}).

### dev
Documentation page: [dev module]({{ '/karnel/dev/' | relative_url }}).

### editor
Documentation page: [editor module]({{ '/karnel/editor/' | relative_url }}).

### games
Documentation page: [games module]({{ '/karnel/games/' | relative_url }}).

### lang
Documentation page: [lang module]({{ '/karnel/lang/' | relative_url }}).

### network
Documentation page: [network module]({{ '/karnel/network/' | relative_url }}).

### npm
Documentation page: [npm module]({{ '/karnel/npm/' | relative_url }}).

### osint
Documentation page: [osint module]({{ '/karnel/osint/' | relative_url }}).

### plugin
Documentation page: [plugin module]({{ '/karnel/plugin/' | relative_url }}).

### security
Documentation page: [security module]({{ '/karnel/security/' | relative_url }}).

### shell
Documentation page: [shell module]({{ '/karnel/shell/' | relative_url }}).

### ui
Documentation page: [ui module]({{ '/karnel/ui/' | relative_url }}).

### utils
Documentation page: [utils module]({{ '/karnel/utils/' | relative_url }}), including the [Herdr](https://herdr.dev) terminal AI assistant (`karnel install utils --herdr`).

### voice
Documentation page: [voice module]({{ '/karnel/voice/' | relative_url }}).
