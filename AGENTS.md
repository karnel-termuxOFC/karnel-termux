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

## Ambiente de desenvolvimento

- Dispositivo: Termux aarch64 (Android), node v24.18.0, npm 12.2.0, shellcheck 0.11.0, GNU findutils (tem `-printf`). **Não existe `/usr/bin/env`** — todo shebang de script do repo usa o caminho absoluto `#!/data/data/com.termux/files/usr/bin/bash`.
- `$PREFIX` = `/data/data/com.termux/files/usr`; `$PREFIX/glibc` = sysroot glibc aarch64 2.44 (383 bins); `proot` **não** está instalado (tier 4 inalcançável neste aparelho).
- Scratch/shim: `/data/data/com.termux/files/usr/tmp/opencode/`; prefixe `PATH` com `/data/data/com.termux/files/usr/tmp/opencode/bin` antes de chamar shellcheck/npm/karnel.
- A armazenagem compartilhada (`/storage/emulated/0/...`) mascara todos os modos como `0660` — o `pack:check` normaliza a partir do índice do git por isso.

## Comandos de verificação

- `bash tests/check-shellcheck.sh` → `shellcheck --severity=error -x -P SCRIPTDIR` sobre **todos** os scripts do repo (≈329). **Demora de 10 a 40 minutos neste aparelho** (um único processo). Erro/warning (SC2016, SC2030, SC2086, SC2115) **não** falham.
- `bash tests/run-isolated.sh` = `npm test` = toda a suíte (43 arquivos). Um `npm run ci` completo mede ≈650 s.
- `bash tests/android-compat.sh` → 28 casos, ≈9 s.
- `bash tests/ai-installer-hardening.sh` → 12 casos, ≈3 s.
- `npm run pack:check` → valida o tarball (528 arquivos) e o entry point executável.
- Nenhum teste deve ser adicionado fora de `tests/run.sh` — `tests/android-compat.sh` ficou de fora do CI por muito tempo por causa disso. Confira com: `for f in tests/*.sh; do grep -q "tests/$(basename $f)" tests/run.sh || echo "faltando: $f"; done`

## Compat layer (`karnel/utils/compat.sh`)

- Tiers: `COMPAT_TIER_LOADER=2` (ld.so do sysroot), `COMPAT_TIER_USERLAND=3` (`$PREFIX/glibc/bin` no PATH), `COMPAT_TIER_PROOT=4` (root FHS sintético). `compat_adapt` = wrap + probe + sobe de tier até o mais barato que funciona.
- **Todo wrapper começa com `unset LD_PRELOAD`** — `login(1)` exporta o shim bionic e o ld.so do glibc morre com `invalid ELF header`. Tier 3 exporta só `PATH`, nunca preload.
- `compat_wrap` não pode recusar `.karnel-real` órfão: bytes idênticos são descartados, diferentes viram `.karnel-real.stale` (o runtime do freebuff se re-extrai no lugar).
- `compat_fix_shebangs` só é seguro em `$PREFIX/bin` — rodar com `.` na raiz do repo reescreve 322 shebangs para o caminho do aparelho (já aconteceu; revertido com `git checkout -- .` + restaurar os 2 arquivos alterados de propósito).
- **Snapshot-diff, não sweep**: `compat_path_snapshot`/`compat_adapt_since` registram `path|size|mtime` das partes graváveis do PATH. Um sweep com `readelf` mede 51 s (588 ELF); o diff do snapshot leva 60 ms. `readelf -l | awk` sobre 588 ELF mediu **875 s** — jamais use.
- `_compat_adapt_path` é o workhorse; `compat_adapt_installed` é só `command -v` + `_compat_adapt_path`.
- O dispatcher (`_karnel_dispatch` em `karnel/cli/karnel.sh`) envolve `install | update | upgrade | reinstall | restore | plugin | supabase | deploy | voice | robin | pg | open | init` com snapshot antes e `compat_adapt_since` depois; o exit code do comando é preservado (`cmd_rc`).

## Padrões de instalação de ferramentas

- 14/16 módulos usam `_run_tool_lifecycle_action` → `_tool_compat_adapt`; o fallback de reinstall em `karnel/tools/ai/all.sh` adapta por conta própria agora.
- Instaladores que poem payload glibc em **diretório de dados** (fora do PATH): freebuff (`~/.config/manicode`), bun (`$KARNEL_DATA/bun/bun.real`), turbopack (`$KARNEL_DATA/node-glibc`). Esses casos são do próprio instalador — o snapshot do PATH não os cobre.
- `railway`, `cursor-cli`, `kimchi-code`, `kilocode-cli`, `turbopack` instalam **wrappers shell** em `$PREFIX/bin` com payload em data dir; nunca ELF glibc cru no PATH.
- **Freebuff**: o launcher npm rebaixa o runtime a cada update e joga o ELF glibc cru por cima do wrapper — o entry do karnel (`$PREFIX/bin/freebuff`) agora faz `source compat.sh` + `compat_adapt` antes de `exec node launcher`. O `_verify_freebuff_entry` prova que o entry abre antes de reportar sucesso; sem isso o install reportava "already installed" para um comando morto.

## Auditoria de ferramentas instaladas

- Catálogo: 169 entradas (49 ai, 30 security, 22 dev, 13 utils, 11 npm, 10 shell, 8 lang, 6 games, 5 db, 4 ui, 4 deploy, 3 editor, 2 network, 1 osint, 1 auto).
- No aparelho: 21 instalados e abrindo, 0 quebrados, 147 ausentes (antes da correção do freebuff: 20 abrindo, 1 quebrado).
- `freebuff --version` → `0.2.26`; `bun --version` → `1.4.2`; `supabase --version` → `2.20.8`.

## Release flow

1. `bash tests/check-shellcheck.sh` (rc=0)
2. `npm test` (rc=0)
3. `npm run pack:check` (rc=0)
4. Bump: `package.json`, `package-lock.json` (topo + `packages[""]`), `README.md` (linha 11 badge + linha 81 `version=`). Adicione `## X.Y.Z` no topo de `docs/CHANGELOG.md`.
5. Commits separados: `fix: ...` para mudanças, `chore(release): X.Y.Z` para bump.
6. `git tag -a vX.Y.Z -m "X.Y.Z"`
7. Push: `git -c credential.helper= -c credential.username=x-access-token push "https://x-access-token:${PAT}@github.com/karnel-termuxOFC/karnel-termux.git" main --follow-tags`
8. `gh run list` → observe CI[main], CI[vX.Y.Z], Release, Publish Docs. `gh run view <id> --log-failed` para depurar.
9. `npm view karnel-termux version` → confirme que é a nova.
10. Site: 7 arquivos (`Layout.tsx`, `Home.tsx`, `KarnelDocs.tsx`, `KarnelPlugin.tsx`, `KarnelStats.tsx`, `Changelog.tsx`, `.github/workflows/ci.yml` com `ref: <sha> # vX.Y.Z`). Commits: `docs: sync site with karnel-termux vX.Y.Z`.

## Site (karnel-termux-site)

- Verificação: `npm install` em `$V` (cópia sem `.git`), depois `node node_modules/prettier/bin/prettier.cjs`, `node node_modules/typescript/lib/tsc.js --noEmit`, `node node_modules/vitest/vitest.mjs run`, `node node_modules/vite/bin/vite.js build`, `KARNEL_REPO_DIR=<repo> node scripts/generate-catalog.mjs --check`.
- `npx tsc` falha com "Unable to resolve @typescript/typescript-android-arm64" — use o caminho direto de `node_modules/typescript/lib/tsc.js`.
- Não use `/tmp` (permissão negada); use `/data/data/com.termux/files/usr/tmp/opencode/`.

## Credenciais (nunca commite; revogar depois)

- GitHub PAT: `<GITHUB_PAT>` → `export GH_TOKEN=...`
- npm token: `<NPM_TOKEN>`
- Sempre redigir na saída: `sed -e "s|${PAT}[^ ]*|***|g" -e "s|x-access-token:[^@]*@|***@|g"`

## Armadilhas conhecidas

- `setsid -f bash script` para rodar tarefas longas; escreva a saída **dentro** do script com `exec > arquivo 2>&1`, senão o `>/dev/null` da linha de comando descarta tudo.
- O shell da sessão do opencode é um processo glibc persistente (PID alto, 25% CPU, 860 MB RSS). `kill` de processos shellcheck/karnel travados por `pkill -f` com padrão que casa a linha de comando do próprio shellcheck (ele recebe todos os caminhos como argumentos).
- `sleep 10` funciona; `sleep 30+` pode travar >240 s sob carga (load médio 5-15).
- `npm install -g <tool>` recria o symlink em `$PREFIX/bin` a cada operação — sem o `_install_freebuff_entry` o comando volta a ser o shim npm morto.
- Teste conhecido flake: `tests/cli-lifecycle.sh` → `FAIL: curl update did not succeed` sob `npm run ci`; passa standalone.
