---
title: Documentation Changelog
permalink: /CHANGELOG/
layout: base
---

# Documentation Changelog

## 4.18.0

- **Three-tier compatibility layer:** a foreign glibc binary is no longer handled by one fixed trick. `compat_adapt` wraps, probes and climbs to the cheapest tier that actually starts the tool — the glibc loader alone (free, installs nothing), the glibc userland (`$PREFIX/glibc/bin`, 383 glibc tools, prepended to `PATH` together with the glibc exec shim so child processes resolve the same way), or proot over a synthetic `/lib`, `/usr` and `/etc` assembled from the sysroot already on the device. That last tier replaces `proot-distro install ubuntu` for binaries that merely hardcode an absolute path, and it downloads nothing. A tier that cannot be reached is refused before the wrapper is written, so `proot -r ''` can never ship, and every step unwraps back to `<path>.karnel-real`.
- **Shebang repair that survives symlinks:** `compat_fix_shebang` edits the target of a link rather than the link itself. `sed -i` unlinks its argument, so repairing `$PREFIX/bin/npm` used to replace that symlink with a detached copy of `npm-cli.js` whose relative `require('../lib/cli.js')` then resolved from `$PREFIX/bin` — one broken `npm` traded for another. The same bug was live in `karnel doctor`, whose `_fix_npm_shebangs` ran `sed -i` over every entry in `$PREFIX/bin`.
- **`npm` and the CLIs on top of it were dead on arrival:** Android has no `/usr`, so `#!/usr/bin/env node` exits 126 with `bad interpreter` even though node is installed, and none of the three `termux-exec` preloads intercepts the kernel's shebang resolution. `npm`, `npx`, `kc`, `kcode`, `keel`, `snyk`, `httptmuxd`, `gdbus-codegen`, `glib-genmarshal` and `glib-mkenums` all now resolve to their Termux interpreter; `$PREFIX/bin` reports 0 unresolvable shebangs.
- **Doctor:** the check asks whether the interpreter path exists instead of grepping for the literal `#!/usr/bin/env`, so a stale absolute path is caught and a resolvable `env` line is left alone; the fix delegates to the compatibility layer; a new *Android Compatibility Layer* section reports the glibc sysroot, how many tools are riding a wrapper, whether proot is reachable for the FHS tier, and any shebang that still does not resolve.
- **Tests:** `tests/android-compat.sh` covers classification, wrapping, re-tiering without disturbing the parked original, escalation, falling back when no tier helps, building the FHS root exactly once, refusing tier 4 without a root, shebang repair through a symlink, and agreement with `readelf` (17 cases).

## 4.17.45

- **npm on a real Termux host:** every npm call goes through `karnel_npm()`, which runs npm through `node` when its `#!/usr/bin/env node` shebang cannot be executed (Termux ships no `/usr`, so the kernel answered `bad interpreter`) and retries with `--force` only on `EBADPLATFORM`. The remaining bare `npm install/uninstall/update/view/ls` calls in the installers were converted; guests inside proot keep plain npm.
- **Installers that could never succeed:** wpscan and wafw00f read their recorded backend with a redirection-only command (`< file`) that prints nothing, so update and uninstall always failed; KeelCode validated the base package digest instead of the `linux-arm64` release it actually downloads; Cline, Command Code, Copilot Termux and Walkie repaired the shebang on the failure branch, leaving the installed binary unrunnable.
- **Stub detection:** `karnel_is_stub_binary()` replaces a word-list heuristic that reported real CLIs (`supercode`, `python-config`) as offline placeholders right after a successful install.
- **Test harness:** `run_test` runs the body under `set -e` so intermediate failures surface. This exposed a Turbopack contract that always failed on the x86_64 CI runner, a Kilo Code install aborted by a `tar` stub and an Odysseus uninstall that had to assert its refusal explicitly.
- **Output noise:** the version spinner probes `/dev/tty` for real instead of trusting `-c`, which passed without a controlling terminal and leaked `No such device or address` into every `karnel update`.

## 4.17.44

- **CLI correctness:** `karnel search` builds its catalog from tool READMEs in one pass instead of per-directory subshells; `karnel stats` counts modules that actually carry install markers and prints `not installed` instead of empty probes; `karnel open` gained routes for `doctor`, `brain`, `pg`, `init`, `env`, `backup`, `show`, `cleanup`, `supabase`, `linux`, `plugin`, `voice`, `security`, `osint`, `termux`, `termux-api` and `terms`.
- **Confirmation safety:** `--auto` now takes the safe answer on destructive prompts instead of answering `y`, and the agent declines to run code unless `-y`/`AGENT_YES` says so explicitly; doctor's dangerous fixes require `-t 0` and a non-auto run.
- **Installer method selection:** menus only list methods that can succeed — AMP Code, Codebuff, MiMo Code and Antigravity CLI no longer offer a proot entry that always failed, and Antigravity's proot install/update refuse before provisioning or mutating a container.
- **Installer fixes:** Freebuff repairs the npm shebang after a successful install instead of inside the failure branch; Claude Code and OpenCode no longer call a host-only shebang helper inside the Ubuntu container; the doctor markdownlint entry no longer passes a nonexistent `--no-missiglob` flag.
- **Ownership and stats:** central ownership covers 96 of 166 tools (was 61), modules write install markers on success, and security installers keep their per-package ownership intact.
- **Packaging:** `pack:check` normalizes modes from the git index on a real filesystem (shared storage masks every mode to 0660), asserts the CLI entry point ships executable, and `npm run release` publishes the validated tarball.
- **Links and data safety:** Zork downloads over HTTP with pinned SHA-256 digests because the host's TLS does not validate; dead `karnelroute.online` references were dropped and GitHub Pages links now name the Vercel production site as canonical.
- **Banner portability:** `banner.sh` keys its colour, figlet and tip tables as associative arrays so bash and zsh draw the same picture (zsh was losing the left border and shifting the gradient), resolves `KARNEL_VERSION` from `package.json` instead of always showing `v4.x`, draws the text logo as valid UTF-8 at the exact terminal width, caches per width for the `clear()` override, bounds the tip picker and restores the caller's traps.
- **List coverage:** every group exposes the same `Install Flag`/`Status` columns, `karnel list plugins` is accepted, the TUI counts installers at runtime instead of advertising a stale `AI Tools (43)`, and dialog menus/checklists show the whole list (they used to render half and a third of it, which hid lower entries such as Walkie).
- **Installer exit codes:** KeelCode and Supercode CLI now capture npm's exit status instead of a `rc` that was always zero, and repair the shebang only after a successful install.
- **Regression tests:** `tests/list-coverage.sh` proves all 17 targets list all 166 installers, `tests/banner.sh` renders in bash and zsh at the exact width as valid UTF-8, and the site catalog is checked against the CLI registries.
- **Housekeeping:** removed 11 unreferenced `.proot` wrapper templates, `gga/termux.patch`, `cline/helper/cline_helper.c` and `assets/banner/banner.txt`; restored 16 files deleted from the site worktree; `lint:shell` no longer depends on how the suite was invoked.

## 4.17.43

- Added `stats` to the bash and zsh completion catalogs.

## 4.17.42

- **Audit fixes:** `$module` vs `$target` in `reinstall` for full security/deploy reinstalls; games routed through the module layer for consistent headers and error handling; security module gained separator/box/log feedback; `ia.sh` hardcoded paths now respect `KARNEL_DATA`; the default `LOG_FILE` moved off `install_ai.log`; `upgrade` captures the cleanup exit code.

## 4.17.41

- Version references bumped to `4.17.41`.

## 4.17.40

- **Deduplication:** extracted `pkg-tool.sh` (14 security tools) and a `module-lifecycle.sh` factory (4 modules), converting deploy, games, network, utils and 14 pkg-only security installers to them — roughly 700 lines of duplicated boilerplate removed.

## 4.17.39

- **Plugins:** `karnel plugin enable|disable <name>` and `karnel plugin config <name> [key] [value]`; metadata tracks enabled state (default `true`) and a config object; disabled plugins are skipped by command collection and tagged in listings.

## 4.17.38

- **Installer consistency:** 129 `reinstall_*` functions now check the uninstall return code; 13 AI tools gained the Termux shebang repair they were missing.

## 4.17.37

- **Installer bugs:** nine utils tools logged to `install_dev.log` instead of `install_utils.log`; 14 security pkg uninstallers silently ignored failures; the opencode uninstall `sed` pattern mangled unrelated `.bashrc` lines.

## 4.17.36

- **Managed lifecycle:** netlify, vercel, masscan and metasploit installers preserve managed files, and `utils/env.sh` hardened the environment they run in.

## 4.17.35

- **Ownership hardening:** `update.sh` and the amass, burpsuite, ffuf, gobuster and subfinder installers refuse to touch installs Karnel does not own.

## 4.17.34

- **Auto mode:** added non-interactive `--auto` (`read_confirm` gained an auto answer, `agent_actions` participates) with matching completion entries and tests.

## 4.17.33

- **Supply chain:** hardened release downloads across installers.

## 4.17.32

- **Supply chain:** GitHub release asset digests are verified before install.

## 4.17.31

- **Docs:** README synchronized with the current AI catalog.

## 4.17.30

- **10Router:** repaired Termux shebangs on already-installed 10Router CLIs.

## 4.17.29

- **10Router:** added the 10Router AI server CLI to the AI catalog, registry and completions.

## 4.17.28

- **QR Code:** resolved launcher symlinks.

## 4.17.27

- **QR Code:** isolated dependency tests.

## 4.17.26

- **QR Code:** stabilized release validation.

## 4.17.25

- **QR Code:** covered installer dependencies in tests.

## 4.17.24

- **QR Code:** made QR code installation Termux-safe.

## 4.17.23

- **Tool installation:** repaired the Termux tool installation runtime across doctor, AI installers and the npm module.

## 4.17.22

- **Data safety and correctness (8):** restore rejects ambiguous multiple archives; Brain preserves same-day title collisions, uses file paths for AI context, initializes/pushes `main`, detects missing `origin`, and supports editors with arguments; PostgreSQL backup filenames are path-safe; AI-session persistence escapes JSON correctly.
- **Agent safety (3):** positional prompts retain all words, zero-valued execution/context limits are rejected, and PLAN mode rejects shell syntax plus destructive `find`/in-place operations that bypassed its read-only contract.
- **Installer reliability (1):** Bun proot installation/update no longer reject safe archives before extraction.
- **Regression coverage:** added critical CLI contracts and strengthened Brain reciprocal-relation coverage; the isolated full suite passes.
- Version references bumped to `4.17.22`.

## 4.17.21

- **Official-site routing:** `karnel open`, npm package metadata, and the GitHub/npm README now point to the Vercel production site, `https://karneltermux.vercel.app`, rather than the secondary GitHub Pages mirror.
- **Open targets:** `karnel open supabase` now opens `/karnel/supabase` and `karnel open cleanup` now opens `/karnel/cleanup`; the old destinations were generic deploy documentation and nonexistent `/cli`, respectively.
- **Docs clarity:** labeled GitHub Pages as a secondary documentation mirror.
- Version references bumped to `4.17.21`.

## 4.17.20

- **PostgreSQL and Supabase (3):**
  - `pg stop` now returns failure when `pg_ctl stop` fails; `pg restart` now stops immediately on either stop or start failure instead of printing a false success.
  - `pg schedule` now returns failure if `crontab` rejects the generated entry instead of returning success after temporary-file cleanup.
  - `supabase remote-status` now preserves a failed Supabase CLI status instead of logging a warning and exiting 0.
- **Search (1):** `karnel search` now treats user input as literal text in tool and brain searches. Regex metacharacters such as `[` no longer cause grep errors, and option-like input cannot change grep behavior.
- **Project initializer (7):**
  - `karnel init` now requires explicit confirmation before templates that may overwrite existing files.
  - Next landing pages no longer import a Button component that the initializer never creates.
  - React's generated Button now has its `clsx` and `tailwind-merge` runtime dependencies installed.
  - Express templates no longer import ungenerated entities/routes, and production PostgreSQL TLS now verifies certificates.
  - Go templates derive imports from the actual `go.mod` module name rather than hard-coding `project`.
  - Rust Dockerfiles derive the release binary from `Cargo.toml` instead of assuming `project`.
- **Regression coverage:** added PostgreSQL/Supabase contracts (5) and init/search contracts (10); the isolated full suite passes.
- Version references bumped to `4.17.20`.

## 4.17.19

- **Release gate:** `tests/bun-installer.sh` did not mock the integrity helpers required by the hardened Bun native installer (`github_release_asset_sha256`, `verify_sha256`, `safe_extract_zip`). The test exited 1 before printing its result, causing `tests/run-isolated.sh`, CI, npm publishing, and GitHub release creation to fail from 4.17.14 through 4.17.18 despite the preceding suites passing. The test now supplies contract-faithful stubs; the full isolated suite exits 0.
- Version references bumped to `4.17.19`.

## 4.17.18

- **Core fixes (2):**
  - `karnel/cli/commands/ia.sh`: `karnel ia sessions --all` was a silent no-op — the flag was bound and never used, and agent names were always displayed anyway. Removed from the help text; the parser still accepts `--all` for back-compat.
  - `karnel/cli/commands/open.sh`: `karnel open` help did not list the `robin` target even though the dispatcher handled it (`osint / robin`).
- **npm/GitHub readme audit + site fixes (10):**
  - `README.md`: documentation links were repo-relative (`docs/doctor/index.md`, `docs/index.md`, …), which 404 on npmjs.com — the README is also the npm package readme. All seven links now use absolute GitHub URLs.
  - `README.md`: "Supported Agents (15)" → 14 (the count included `text`, which the same docs describe as "no agent"), and the `!` alias row was missing from the table; added.
  - `docs/ARCHITECTURE/index.md`: the commands tree said "27 .sh files" — the directory has 28.
  - `docs/ARCHITECTURE/index.md`: the "Tool Installer Pattern" documented `_tool_dependencies()`/`_tool_install()`/`_tool_postinstall()`, which exist nowhere in the repo; replaced with the real `install_<tool>`/`uninstall_<tool>`/`update_<tool>`/`reinstall_<tool>` contract and the 0/2 exit-code semantics.
  - `docs/karnel/dev/index.md`: listed `proot-distro` as a dev tool; the module installs `proot` (a different package).
  - `docs/_layouts/default.html`: Google Fonts was only `rel="preload"` — no stylesheet link existed anywhere, so Open Sans never loaded; replaced with a normal stylesheet link.
  - `docs/_layouts/base.html`: the "Live Site" nav item linked to the site itself; now points to the GitHub repository.
  - `docs/assets/css/style.scss`: the dark palette was set unconditionally on `:root`, making every light-mode fallback in the stylesheet unreachable; added a `prefers-color-scheme: light` override so OS theme is respected.
  - `docs/CHANGELOG.md`: the permanent "## Unreleased - 2026-07-16" heading (for long-shipped features) retitled honestly as historical.
  - `docs/cli/index.md`: removed the `karnel ia sessions --all` example (flag removed).
  - Version references bumped to `4.17.18`.

## 4.17.17

- **Core fixes (8, incl. one broken tool and a 4.17.16 regression):**
  - `karnel/tools/utils/treex/treex.py`: **the entire tool was broken** — an `IndentationError` (a lost `while True:`/`try:`/`os.scandir` block in `explorer_mode`) made every invocation crash. Reconstructed the block; all bundled Python tools now compile.
  - `karnel/tools/utils/applaunch/applaunch.py`: launched a nonexistent `Settings.py` after every action, printing a Python "can't open file" error on every run; removed.
  - `karnel/tools/utils/applaunch/applaunch.py`: replaced `os.system` f-string interpolation and `shell=True` (3× `am start`, `mkdir -p`, `aapt dump badging`) with argv-list `subprocess.run` / `os.makedirs` — removes shell-injection surface from package-manager-derived values.
  - `karnel/cli/commands/doctor/code_exec.sh`: **reverted the 4.17.16 fix-command guard** — it refused the legitimate multi-statement `Go:gofmt` fix (and would refuse `Java:javac`/`bandit` checks), silently disabling Go auto-fix. Check/fix commands come exclusively from the in-repo `LANG_TOOLS` registry, so the guard was a functional regression, not security. A comment now documents this so it is not re-added.
  - `karnel/cli/commands/brain.sh`: `_brain_update_related` appended the raw `$slug` in its `sed` branch while the escaped `$escaped` value was computed but unused — a slug containing `/` or `&` corrupted memory files. Now uses `$escaped` on both branches.
  - `karnel/cli/commands/list.sh`: `karnel list utils` showed 12 tools while docs (and the module) promise 13 — the Herdr row was missing from `_list_utils`.
  - `karnel/tools/utils/splash/splash.py`: `update_delay` rewrote *any* line containing "sleep" inside the loading-screen block, including the embedded `python3 -c "... sed /sleep 12;..."` cleanup line, corrupting the `bash.bashrc` self-cleanup; now only `sleep`-prefixed lines are rewritten.
  - `karnel/tools/utils/splash/splash.py`: delay prompt crashed with an unhandled `ValueError` on non-numeric input; input is now validated (non-negative integer).
- **Docs / site fixes (10):**
  - `docs/cli/index.md`: removed five duplicated rows at the end of the `list` module table (network/utils/osint/voice/security appeared twice).
  - `docs/index.md`: the Supabase anchor was "fixed" in the wrong direction — kramdown generates `supabase--remote-project-helpers` (double dash) from `## supabase — Remote-project helpers`; restored the double-dash link and corrected the 4.17.16 changelog note.
  - `docs/troubleshooting/index.md`: corrected the claim that `karnel update karnel` logs to `install_dev.log`/`install_npm.log` — the updater prints to the terminal only; those files belong to the dev/npm module installers.
  - `README.md`: the Site badge displayed a nonexistent domain (`karneltermux.github.io`); now shows the real `israelmarques1024-dotcom.github.io/karnel-termux`.
  - `README.md`: removed the false CI claim that the docs site validates "catalog contracts, TypeScript, formatting, tests, and production build" (no TypeScript exists in the repo; `docs.yml` only runs `jekyll-build-pages`).
  - `README.md`: the "Project Structure" tree omitted `osint/`, `voice/`, and `plugins/` under `karnel/tools/`; added.
  - `README.md`: fixed the broken intro sentence (the "install and manage:" colon was followed by the credits instead of the feature list).
  - `docs/karnel/security/index.md`: "30+ tools" → "30 tools" (the module has exactly 30).
  - `docs/assets/css/style.scss`: removed the dead `.karnel-note` admonition CSS (referenced nowhere, same class of orphaned selector as the removed `.karnel-nav`).
  - Version references bumped to `4.17.17`.

## 4.17.16

- **Core hardening (10 critical bug fixes):**
  - `karnel/tools/lang/bun/install.sh`: the proot install/update paths now reject Bun archives containing path-traversal or absolute-path members before `unzip -o` runs (defense-in-depth alongside the SHA-256 check).
  - `karnel/tools/utils/passman/passman.py`: **fixed a critical defect** — the module referenced `os.*` without importing `os`, which broke the entire password manager. Added `import os`.
  - `karnel/tools/utils/passman/passman.py`: the encrypted vault is now written with `0600` permissions (was world-readable), and `import_vault` now backs up the existing vault to `<vault>.bak` before overwriting (prevents silent data loss).
  - `karnel/cli/commands/backup.sh` and `restore.sh`: temporary directories now use a safe `mktemp` template under `TMPDIR`/`KARNEL_CACHE` instead of a bare `mktemp -d` (avoids an insecure `/tmp` fallback).
  - `karnel/cli/commands/doctor/code_exec.sh`: `_exec_apply_fix` now validates the fix command with `_exec_fix_cmd_is_safe`, rejecting shell operators, stray braces, and destructive leading commands such as `rm`/`sudo`/`mv` — closing a command-injection path via a malicious project doctor config.
  - `karnel/cli/commands/env.sh`: when a variable name looks like a secret (`SECRET`/`TOKEN`/`KEY`/`PASSWORD`/…), the shell rc file is tightened to `0600` so other local users cannot read stored secrets.
- **Docs / site fixes:**
  - Removed the duplicate logo on the documentation homepage (it was rendered both in the header and in the page body).
  - Fixed two `karnel voice` help URLs that pointed at a custom redirector (`karneltermux.vercel.app/termux/api`); they now point to the official `https://github.com/termux/termux-api`.
  - `README.md`: "45 other AI agents" → "45 AI agents" (Herdr is a utility, not one of the 45).
  - `docs/cli/index.md`: the `list` table was missing `network`, `osint`, `voice`, `security`, `utils`, and `plugin`; all six rows were added.
  - `docs/cli/index.md`: added the `osint --robin` install flag to the per-module flags table.
  - `docs/index.md`: removed a broken `./ARCHITECTURE/` link (that page does not exist) and corrected the Supabase anchor direction (`#supabase--remote-project-helpers`, double dash as generated by kramdown from `## supabase — Remote-project helpers`).
  - Bumped version references to `4.17.16` (README badge, install snippet, `package.json`).

## 4.17.15

- **Core hardening (10+ bug fixes):**
  - `karnel/utils/tools.sh`: `_register_safe_reinstall_handlers` now rejects any tool/module name containing shell metacharacters before `eval`-ing the generated reinstall handler (prevents code injection via a crafted tool directory name).
  - `karnel/tools/ai/droid/install.sh`: dropped the predictable `/tmp/droid-install` / `/tmp/droid-update` paths inside the proot container in favor of `mktemp -d`.
  - `karnel/tools/ai/kimchi-code/install.sh`: replaced predictable `/tmp/kimchi-install` with `mktemp -d` and added an archive-member path-traversal check before extraction.
  - `karnel/tools/ai/oh-my-pi/install.sh`: replaced predictable `/tmp/omp-install` / `/tmp/omp-update` with `mktemp -d`.
  - `karnel/tools/ai/crush/install.sh`: `mktemp -d` now uses a safe template (no bare `/tmp` fallback).
  - `karnel/cli/commands/{init,voice,brain,ia}.sh`: bare `mktemp` calls now use a safe `$KARNEL_CACHE`/`$TMPDIR` template instead of falling back to `/tmp`.
- **Full site overhaul (10+ fixes):**
  - Removed the YouTube `capi.deb` channel references from the README.
  - Fixed the README install snippet (stale `4.17.11` → `4.17.15`) and the `45+` AI-agents count (→ `45`).
  - Fixed a dead `/termux/api` link (now points to the official termux-api repo).
  - `docs/cli/index.md`: corrected the misleading "resolves the `/cli/#<module>` anchors" note, renamed the duplicate `Modules` heading to `Module documentation pages`, and fixed the `network` module description (no longer misattributes OSINT).
  - `docs/index.md`: module names are now clickable links to their per-module pages.
  - All 17 module pages gained a `CLI reference` cross-link in their footer.
  - Removed dead `.karnel-nav` CSS and added the branding logo site-wide via the `default.html` page header.
  - Verified the existing GitHub Pages deploy already honors `docs/_config.yml` (baseurl/theme load correctly) — no deploy change needed.

## 4.17.14

- **Core security audit — fixed 12 critical bugs:**
  - `agent_llm.sh`: config save now uses `%q` instead of `%s`, closing a command-injection/RCE vector when `source`ing saved agent config.
  - `agent_actions.sh`: PLAN (read-only) mode now enforces a strict allowlist (`_agent_cmd_is_readonly`) so non-inspection commands (ruby, php, lua, etc.) can no longer bypass the guard.
  - `zork/zork.sh`: rewritten with a self-contained safe extractor that rejects `..`/absolute paths and symlink escapes before moving files into `ZORK_DIR`.
  - `zork/install.sh` / `bun/install.sh`: removed unsafe `unzip -o` / tar fallbacks; extraction now uses the hardened `safe_extract_zip` / `safe_extract_tar` helpers.
  - `supabase`, `kiro`, `cline`, `kilocode-cli`, `keelcode` installers: replaced the local `safe_extract_tar` (which fell back to an unsafe `tar -xzf` on missing integrity helpers) with a self-contained, safe implementation that has no unsafe fallback.
  - `restore.sh` / `pg.sh`: database restore no longer silences `tar` / `pg_restore` errors with `2>/dev/null`; failures are surfaced to the user.
  - `shell.sh`: `OH_MY_ZSH_REF` is now escaped before being substituted into `sed` patterns, preventing delimiter injection.
- **Site overhaul:**
  - Fixed single-brace Liquid (`{{ }}`) on all 17 per-module pages (34 broken links resolved).
  - `karnel open` gained a `robin` target (opens the OSINT module page) and a `herdr` target row in the CLI reference.
  - Added a `## Modules` anchor section to the CLI reference so `/cli/#<module>` links resolve.
  - Moved favicon + SEO meta into `<head>` via a `docs/_layouts/default.html` override of the cayman theme (previously dead `<body>`-level meta); set `logo:` for rich-link previews.

## 4.17.13

- Fixed the shell completion catalog (`scripts/completion.bash` / `completion.zsh`) to include the `herdr` utils tool, satisfying the `completion-catalog` CI gate.

## 4.17.12

- Generated real per-module documentation pages under `/karnel/<module>/` (all 17 modules: ai, auto, db, deploy, dev, editor, games, lang, network, npm, osint, plugin, security, shell, ui, utils, voice).
- `karnel open <module>` now opens the in-site page (`/karnel/<module>/`) instead of the GitHub source; added a dedicated `herdr` open target that opens the utils page.
- Featured **Herdr** prominently in the README and on the site landing page, with a `karnel install utils --herdr` callout.
- Added `karnel/tools/utils/herdr/README.md` so `karnel show utils --herdr` renders proper documentation.
- Site/CLI audit: fixed the stale "12 scripts" utils summary in the CLI reference (now lists all 13 tools including Herdr).

## 4.17.11

- Added the **Herdr** CLI to the `utils` module (`karnel install utils --herdr`), with checksum-verified download, atomic install, and Karnel ownership markers.
- Critical runtime fixes:
  - `cursor-cli`, `hermes-agent` and the `doctor` psutil patch now extract archives with the guarded `safe_extract_tar` (path-traversal/symlink protection).
  - `pg schedule` now exports `PATH`/`PREFIX` in the cron job and logs failures instead of discarding output.
  - `pg restore` uses `--single-transaction` and surfaces errors instead of silently retrying.
  - `doctor --fix` no longer auto-applies destructive fixes (install-class, cache wipes, mass symlink deletion) without explicit confirmation; non-interactive sessions skip them (fail-closed).
  - `doctor code --fix` now snapshots each rewritten file to `<file>.karnel-bak` before applying in-place formatters.
  - `_fix_broken_symlinks` only removes broken symlinks that point into Karnel-managed paths.
  - `karnel upgrade` no longer triggers a concurrent update check.
  - `shell.sh` temp directory falls back to `KARNEL_CACHE` instead of `/tmp`.
- Website/documentation overhaul: `karnel open` now resolves to real GitHub source URLs (no more 404s), canonical site URL unified to GitHub Pages, utility-tool count corrected to 13 (Herdr added), cloud-backup docs corrected to rclone, added `karnel upgrade` to the command table, and added favicon/SEO meta + Troubleshooting nav.

## 4.17.10

- Round 10 security/correctness hardening (23 distinct fixes):
  - **Termux `/tmp` fallbacks eliminated** across host-side code
    (`update.sh`, `brain.sh`, `version.sh`, `log.sh`, `agent_actions.sh`,
    `doctor/code_langs.sh`, `supabase`, and the `security/*` tools amass,
    subfinder, ffuf, gobuster, burpsuite, zap) — now use `KARNEL_CACHE`.
  - **`karnel show <module>`** now rejects invalid module names
    (`/`, `..`, `~`), closing a path-traversal / information-disclosure bug.
  - **Agent PLAN (read-only) mode** hardened: blocks `sed`/`awk`/`perl`/
    `xargs`/`make`/`env`/`nohup`/`setsid`, `sed`/`perl -i`, editors,
    `git apply`/`worktree`/`read-tree`/`update-index`, and now also catches
    redirections without a preceding space (`echo x>file`).
  - **Plugin supply chain** fail-closed: installs now require a manifest
    checksum (was silently skipped), and registry installs pin to a committed
    SHA when provided.
  - **`karnel pg backup --schedule`** no longer swallows `crontab` failures
    and uses the escaped DB name to avoid duplicate cron jobs.
  - **Reinstall** now proceeds to install when the uninstall step reports
    "already uninstalled" (rc 2) instead of aborting.
  - **Archive extraction hardened**: `cline`, `goose`, `kiro` AI installers
    and `zork` now use the safe extractors; `zork` also drops literal `/tmp`.
  - Site fully overhauled (navigation, dark mode, GitHub Pages URLs, Liquid
    fixes, consistent front matter).

## 4.17.9

- Hardened installer and runtime security across the toolkit:
  - `droid` binary install now refuses when no published SHA-256 digest is
    available (fail-closed) instead of silently skipping verification.
  - `keelcode` and `supabase` now extract archives through the hardened
    `safe_extract_tar` (rejects symlink/absolute-path traversal) instead of
    raw `tar`.
  - Restored OpenCode installation: upstream publishes no checksum, so
    `github_download_and_extract` warns instead of refusing (other tools that
    publish checksums remain fail-closed).
  - `cursor-cli` now validates the downloaded bundle is a real gzip archive
    before extraction.
  - Agent PLAN (read-only) mode write-guard hardened: now blocks `sed -i` /
    `perl -i`, full-screen editors, and file descriptors like `2>file`.
  - Agent compaction no longer drops the freshly built summary during the
    trim safety-net.
  - `voice` uninstall no longer removes `termux-api` unless Karnel installed it.
  - `karnel show` no longer depends on `realpath` (portable fallback).
  - `karnel update` reports the accurate installed version instead of a
    misleading `latest`.
  - Reinstall no longer deletes the ownership marker before confirming the
    install, preventing a tool from being orphaned on install failure.

## 4.17.8

- Documentation site reconciled with the GitHub Pages deployment: the `Publish
  Docs` workflow (`.github/workflows/docs.yml`) builds Jekyll from `docs/` and
  deploys to GitHub Pages, so the live documentation URL is
  `https://israelmarques1024-dotcom.github.io/karnel-termux/`.
- `docs/CHANGELOG.md` is now a rendered page (added front matter + permalink)
  and all internal links to it use the clean `/CHANGELOG/` path.
- Tool counts verified against the actual `karnel/tools/*` and
  `karnel/tools/ai/*` directories: 45 AI tools, 3 editors, 8 languages,
  5 databases, 22 dev tools, 11 npm packages, 10 shell plugins, 4 UI
  components, 4 deploy CLIs, 6 games, 2 network tools, 12 utility tools,
  30 security tools, 1 automation tool.

## 4.17.7

- Documentation site overhauled: valid `_config.yml`, cayman-compatible custom
  stylesheet that imports the full theme, a workflow that builds Jekyll before
  deploying to GitHub Pages, and tool counts reconciled with the actual
  `karnel/tools/*` and `karnel/tools/ai/*` directories (45 AI tools, 3 editors,
  8 languages, 5 databases, 22 dev tools, 11 npm packages, 10 shell plugins,
  4 UI components, 4 deploy CLIs, 6 games, 2 network tools, 12 utility tools,
  30 security tools, 1 automation tool).

## 4.16.1 - 2026-08-22

- `karnel agent ask/run`: when the model endpoint is unreachable and Cactus is
  not installed, the agent now says so explicitly and offers to install Cactus
  on the spot (`karnel install ai --cactus`) instead of printing a generic
  "start your server" hint that referenced a binary the user did not have.
- Cactus glibc installer: fresh installs are now pinned to the tested
  `cactus-compute` version (2.0.1) — the previous unpinned spec silently pulled
  2.1.x with a ~1.5 GB torch/CUDA dependency chain; updates keep the
  `>=2,<3` range used by the proot path.
- Cactus glibc installer: pip output is now streamed live (and mirrored to the
  install log) instead of being hidden behind an indeterminate spinner, which
  made multi-minute downloads look frozen.
- Agent help/REPL screens and project READMEs were updated with contributor
  credits.

## 4.16.0 - 2026-08-20

- Rebranded fully to Karnel: removed legacy upstream branding across
  contributors, CLI `open` targets, completions, docs and agent utilities.
- `nvchad` editor tool now installs the official upstream `NvChad/starter`
  (pinned to a reviewed commit) instead of a third-party fork.
- Added the `karnel agent` subsystem (agent.sh, agent_actions.sh, agent_llm.sh,
  agent_markdown.sh) with voice, markdown and LLM helper utilities.
- Hardened AI installers: cursor-cli (atomic staging download + ownership
  markers), walkie, codegraph (correct Termux shebang), engram, gentle-ai,
  command-code, ctx7, openspec, freebuff, hermes-agent, mistral-vibe, openclaw
  and hugging-face (pinned dependency).
- Supply-chain tests now accept non-executable asset modes (644/660/664) so the
  suite passes on Android shared storage, and the package checker handles the
  npm >= 12 object-shaped pack report.
- AI registry count updated to 45 verified tools; all 26 isolated test suites
  pass.

## 4.15.2 - 2026-08-16

- Implemented the previously missing `karnel brain add "text"` subcommand.
  `karnel brain save` (interactive) told non-interactive users to use
  `karnel brain add` when a terminal was unavailable, but the subcommand did
  not exist and fell through to "Unknown subcommand". `add` now saves a memory
  non-interactively with optional `--title`, `--category` and `--tags`.
- Fixed memory slug lookup in `karnel brain show/relate/edit/delete`. The help
  documents `karnel brain show slug-name`, but stored memories use
  `YYYY-MM-DD_<slug>.md` filenames and lookups required the exact, full,
  date-prefixed basename. A shared `_brain_find_memory` helper now resolves the
  bare slug (falls back to `*_<slug>.md`) so the documented short form works.
- Removed a duplicated `glow` rendering block in `karnel brain show`.
- `karnel brain search` (and related memory search in `ask`/`save` suggestions and
  `delete` relation clean-up) now falls back to `grep -r` when `ripgrep` is not
  installed, instead of failing with "ripgrep not found". Environments without
  `rg` (fresh minimal containers, CI runners) can now search memories.

- Fixed the plugin registry pin: `PLUGIN_REGISTRY_COMMIT` now points to
  `f19d3cd` (registry commit that pins reviewed plugin sources to commits/
  tags instead of moving `main`), with the matching registry checksum
  `ea82bf2f...`. Plugin updates previously failed with a "Checksum mismatch"
  whenever a plugin repository advanced ahead of the stale registry snapshot.

## 4.15.0 - 2026-08-14

- Replaced the unavailable GGA fork with the official Gentleman Guardian
  Angel v2.10.1, pinned by commit, with Termux-safe staging, ownership
  verification, rollback, and non-destructive uninstall.
- Made backup/restore transactional: staged configs, ancestor symlink
  rejection, signal-safe rollback, concurrent backup isolation, validated
  snapshot names, and explicit package/configuration phase separation.
- Hardened lifecycle ownership so pre-existing installs are never adopted,
  arbitrary handler exit codes are treated as failures, and stale or empty
  locks are recovered safely.
- Pinned release/npm/installer together: the npm package carries a validated
  `RELEASE_COMMIT`, the release workflow is serialized per tag and refuses
  divergent partial publications, and the installer activates only a verified,
  clean checkout.
- Authenticated security and AI installers with fixed versions and official
  SHA-256 checksums, safe archive extraction, staging, and rollback; unverifiable
  upstream assets now fail closed instead of executing unauthenticated bytes.
- Fixed the npm postinstall to distinguish the npm bin symlink from a complete
  managed installation, and removed the deprecated `curl | bash` guidance.
- Updated ShellCheck/syntax/test gates to 294 scripts and added regression
  suites for backup, lifecycle, installer integrity, and AI installer hardening.

## 4.14.0 - 2026-08-14

- Added tested Cactus 2.0.1 support on ARM64 through Ubuntu Proot with an
  isolated compatible Python runtime.
- Added the official Hugging Face `hf` CLI in an isolated native Termux
  environment, using HTTP transport when the optional Xet Android wheel is
  unavailable.
- Made the AI registry authoritative for TUI selection, route discovery, and
  lifecycle dispatch, with contracts covering all 43 registered tools.
- Fixed AI reinstall and uninstall error propagation, unknown status handling,
  binary alias summaries, ownership checks, and stale tool counts.

## 4.13.11 - 2026-08-10

- Hardened installers to preserve user-managed commands and data, with atomic
  staging for downloaded payloads and native binaries.
- Added verified plugin registry snapshots, npm release pinning, and regression
  contracts for installers, ownership, and package postinstall behavior.
- Added Android-compatible Railway installation through Ubuntu Proot and
  verified Railway and Netlify CLI installation on Termux.
- Synchronized CLI, GitHub README, npm metadata, and site documentation.
- Corrected the portable npm postinstall fixture used by release validation.

## 4.13.10 - 2026-08-06

- Included root documentation in the npm package and synchronized help, TUI, and release assets.

## 4.13.9 - 2026-08-06

- Completed tool documentation coverage and corrected CLI references, commands, flags, links, and catalog counts.

## 4.13.8 - 2026-08-06

- Added KeelCode through the official `@keelcode-ai/keelcode` npm package.
- Added SuperFile built from pinned upstream source `v1.5.0`.

## 4.13.7 - 2026-08-04

### Plugin System

- Registry entries may now share a repository when each uses a distinct plugin
  path, enabling multiple reviewed plugins from the official registry source.
- Plugin removal acquires the lifecycle lock before recovery and deletion,
  preventing a concurrent update from restoring a removed plugin.
- Registry downloads refuse HTTPS-to-HTTP redirect downgrades.

## 4.13.6 - 2026-08-03

### Fixes

- Reject missing values for `karnel voice --lang` before argument parsing can
  consume another option.
- Harden plugin command validation by rejecting hidden, non-shell, symlinked,
  and undeclared command entries.
- Permit the documented root plugin path (`"path": "."`) in reviewed registry
  entries while retaining traversal protection.
- Clarified CLI help, deployment requirements, and site documentation so they
  match current behavior.

## 4.13.5 - 2026-08-01

### Release hardening

- `karnel update karnel` now resolves the latest GitHub release tag, downloads the
  tag-pinned `karnel-termux-install.sh` and `.sha256` assets, verifies the SHA-256
  checksum before running, and only then falls back to git/npm/pnpm. The Release
  workflow attaches both immutable installer assets to each tag.
- GitHub Releases are created before npm publishing, so a failing npm publish no
  longer blocks the release.
- The site catalog CI now verifies that the generated catalog has not drifted from
  a pinned CLI checkout (`generate-catalog.mjs --check`).

### Fixes

- Repaired the Freebuff installer (release tag, asset name, download URL, binary
  rename) and verified install/update on Termux aarch64.
- `karnel list` detects Kiro, KiloCode, and Cursor via any of their binaries.
- Added troubleshooting documentation covering npm tokens, releases, Vercel, and
  update failures.
- Synchronized documentation with the 39-entry AI registry and the 4 deploy CLIs.

## 4.9.0 - 2026-07-20

### New modules

- Added `network` module with 2 tools: dark (Dark Web OSINT Tor crawler) and
  dedsec-network (multi-purpose network scanner/OSINT/pentest).
- Added `utils` module with 11 utility scripts: fconv, filecheck, websites,
  notes, treex, passman, applaunch, splash, httptmux, zork, and qrcode.

### Documentation

- Created READMEs for all 13 new tools under `karnel/tools/network/` and
  `karnel/tools/utils/`.
- Updated `open.sh` with `network` and `utils` targets for browser docs.
- Updated root README, docs index, CLI reference, and architecture docs with
  the new module counts and tool descriptions.
- Bumped version to 4.9.0.

## 4.8.0 - 2026-07-18

### Robin OSINT

- Added the `osint` module and `karnel robin` lifecycle command.
- Pinned Robin `v2.8` and validated its source commit before activation.
- Added a transactional source/venv installation path for Termux aarch64.
- Separated application code, provider configuration, and investigations.
- Added safe migration from the original single-directory layout.
- Added process identity validation, Streamlit readiness checks, Tor probes,
  versioned responsible-use acknowledgement, and explicit data purge.
- Added `karnel start robin`, global status integration, and
  `karnel doctor robin [--network]`.

### Quality and release

- Expanded catalog documentation from 24 to 32 development tools.
- Added complete Bash/Zsh syntax validation, Robin contract tests, ShellCheck
  error gating, npm package inspection, CI, and release automation.
- Corrected competing stderr redirections in three installers.

## 2026-07-16 — Doctor command surface (shipped before 4.8.0)

### Doctor command surface

- Added `karnel doctor code` alongside the existing Termux diagnostics.
- Kept exactly two operational Doctor subcommands: `termux` and `code`.
- Removed the stale `karnel doctor fix` entry from the main help. Termux fixes remain
  available through `karnel doctor termux --fix`.
- Synchronized the Doctor AI probe and documentation with the 39-entry registry,
  including Copilot-Termux.

### Code analysis engine

- Added project detection for 25 language and ecosystem labels.
- Added a registry with 76 check definitions and 68 distinct tool labels.
- Added quick, standard, and deep modes with 64, 74, and 76 definitions,
  respectively.
- Added text reports and clean JSON output.
- Added safe and unclassified auto-fix modes.
- Added bounded subproject discovery through four directory levels.

### Correctness fixes

- Declared persistent arrays with `declare -g`/`declare -gA` so they survive the
  function-scoped `import()` mechanism.
- Replaced space-delimited tool output with one registry record per line.
- Added a parser that preserves shell pipelines inside registry commands.
- Fixed file discovery that incorrectly expected NUL-delimited `find` output.
- Run language checks and fixes inside the matching manifest directory while
  keeping cross-language checks at the requested project root.
- Preserve command exit statuses, including silent failures and timeouts.
- Quote sample file paths with Bash `%q` before shell execution.
- Prevent `npx` checks from downloading packages by using `--no-install`.
- Resolve compound tool labels such as `npm audit`, `go test`, `cargo test`, and
  `docker compose` to their real executables.
- Run gofmt over discovered Go files instead of passing a directory, and send
  javac output to the temporary directory instead of `/dev/null`.
- Parse Python files through `ast` instead of `compileall`, preventing diagnostics
  from creating `__pycache__` artifacts in the analyzed project.
- Run cross-language checks once per project instead of once per detected language.
- Skip placeholder-based checks when no compatible sample file exists.
- Apply fixes only to findings, preserve the target directory, and report failed
  fix commands accurately.
- Match fixes by both tool and category so tools with multiple checks do not apply
  unrelated corrections.
- Emit standalone JSON with the analyzed directory, result count, category,
  severity, and details.
- Record the requested target directory in text reports instead of `$PWD`.

### Detection fixes

- Preserve the root directory through recursive scans so subprojects are registered.
- Scan `.github/workflows` and detect GitHub Actions YAML files.
- Merge YAML detection so GitHub Actions is no longer shadowed by Ansible rules.
- Recognize scoped Angular and NestJS packages.
- Associate framework names with their language for terminal display.
- Detect Python for all supported Python manifest variants.
- Normalize manifest records for JavaScript, Django, CMake, Maven, Gradle, and .NET.

### Termux diagnostics

- Made `--quick` stop after essential system and package checks instead of running
  the extended network and I/O probes.
- Added explicit timeouts to Termux information and battery probes so a missing or
  unresponsive Termux:API service cannot block the full diagnostic run.
- Generate the Markdown report after auto-fixes so the `Fixed` count is accurate.
- Use explicit `skipped` values for quick-mode sections in the report.
- Fixed Python cache cleanup so version-directory globs expand correctly.
- Quote packages returned by `pip check` before reinstalling them.

### Verification

- Expanded `tests/smoke.sh` from 10 to 14 checks.
- Added syntax coverage for nested Doctor modules.
- Added registry count and pipeline-parsing regression tests.
- Added GitHub Actions, Python manifest, TypeScript, and NestJS detection tests.
- Verified clean JSON with Python's standard JSON parser.
- Verified modified shell files with ShellCheck at style severity.

## Security note

Doctor executes third-party analysis tools in the selected project. Review tool
configuration and use version control before enabling fixes. `npx` checks do not
install missing packages automatically.
