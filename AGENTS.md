# Karnel

**Author:** israel marques

Karnel is a Termux environment manager. The project is at `~/karnel/` with code under `karnel/`.

- CLI command: `karnel` (in PATH)
- Main entry: `karnel/bin/karnel`
- Module orchestrators: `karnel/modules/` (ai.sh, auto.sh, db.sh, deploy.sh, dev.sh, editor.sh, lang.sh, npm.sh, osint.sh, shell.sh, ui.sh, voice.sh)
- Tool installers: `karnel/tools/` (ai/*, auto/*, db/*, deploy/*, dev/*, editor/*, lang/*, npm/*, osint/*, shell/*, ui/*, voice/*)
- CLI commands: `karnel/cli/commands/` (install.sh, uninstall.sh, update.sh, reinstall.sh, list.sh, show.sh, open.sh, doctor.sh, brain.sh, env.sh, init.sh, pg.sh, robin.sh, voice.sh, ia.sh, agent.sh)
- CLI commands: AI subcommands include `karnel ia sessions`, `karnel ia routes`, `karnel ia install`
- Local AI assistant: `karnel agent ask|run|config|status` (utils: `karnel/utils/agent_*.sh`)
- AI listing: `karnel list ai` (not `karnel ia list`)
- omniRoute: `karnel install ai --omni-route`; installs omni-route wrapper (npm: karnelroute, https://www.npmjs.com/package/karnelroute)
- Utils: `karnel/utils/` (banner.sh, bootstrap.sh, colors.sh, env.sh, log.sh)

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tools** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them. `codegraph_node` returns one symbol's source + callers, or reads a whole file with line numbers. If the tools are listed but deferred, load them by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` and `codegraph node <symbol-or-file>` print the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
