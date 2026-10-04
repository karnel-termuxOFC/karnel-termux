# omniRoute (karnelroute wrapper)

**AI Gateway CLI** — 236+ AI providers via a single endpoint.

**Package:** omni-route (npm: karnelroute)  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**npm:** https://www.npmjs.com/package/karnelroute  
**Type:** AI Gateway (npm package with smart wrapper)  
**License:** MIT

## Description

omniRoute is the Karnel Termux wrapper for the official `karnelroute` npm package — an AI Gateway that provides 236+ AI providers via a single endpoint, with auto-fallback to free providers and smart routing with compression (15-95% token savings).

## Installation

```bash
karnel install ai --omni-route
```

## Usage

```bash
omni-route                         # Start AI gateway on localhost:20128
omni-route serve --daemon           # Start as background daemon
omni-route serve --daemon --no-open # Daemon without browser
omni-route stop                     # Stop the server
omni-route --help                   # Show all commands
omni-route --version                # Show version
```

> Note: `karnelroute` also works as an alias.

## Dashboard

Access the web dashboard at:
- **URL:** http://localhost:20128
- **Setup:** Configure providers at `/dashboard`
- **API Base:** `http://localhost:20128/v1`

## Architecture

The wrapper uses a **2-tier installation** strategy:

1. **Local install** (`~/.karnel/packages/karnelroute/`) — Fast, no download on subsequent runs
2. **npm install** (first run) — Downloads and caches locally with `--ignore-scripts`

### Termux / Android Native Fixes (root cause of "Internal Server Error" 500)

KarnelRoute bundles `better-sqlite3` (and `sqlite-vec`) as **prebuilt `linux-x64` glibc**
native addons. On Termux/Android the runtime is **aarch64 + Bionic libc** and
`process.platform` reports `android`, so those addons fail to load
(`dlopen: cannot locate symbol …`). With no working database, every HTTP request
returns `500` and the logs show an `out of memory` DB-probe death spiral.

The installer fixes this **definitively** (no workarounds) by rebuilding the
native addons from source for the running Node/ABI:

1. **Rebuild native modules** — `better-sqlite3` and `sqlite-vec` are recompiled
   with Termux's `clang` against the local Node headers. `node-gyp` mis-detects
   Termux as Android and demands `android_ndk_path`; the installer supplies a
   dummy value so the Android gyp config resolves while Termux's clang compiles.
2. **Instrumentation resilience** — Next.js `registerInstrumentation()` used to
   *re-throw* any error from KarnelRoute's (non-critical) instrumentation hook and
   crash the whole server. The installer patches Next's
   `instrumentation-globals.external.js` so a hook error is logged and the server
   keeps running (the real application database is unaffected).

Both fixes are re-applied automatically on every `install` / `update`, so a fresh
or updated install keeps working on Termux/Android.

### Resetting a corrupted database

If `~/.karnelroute/storage.sqlite` becomes corrupt, KarnelRoute cannot auto-recover
and renames it to `storage.sqlite.probe-failed-*`. Remove those files and let the
server recreate a fresh database:

```bash
rm -f ~/.karnelroute/storage.sqlite{,-wal,-shm} ~/.karnelroute/storage.sqlite.probe-failed-*
omni-route serve --daemon
```

## Commands

| Command | Description |
|---------|-------------|
| `omni-route` | AI Gateway (alias: karnelroute) |
| `omni-route serve` | Start the server |
| `omni-route serve --daemon` | Run in background |
| `omni-route stop` | Stop the daemon |

## Notes

- Installed via npm package: `karnelroute` (official)
- Data directory: `~/.karnelroute/` (auto-generated config)
- Default port: 20128
- Dashboard requires `INITIAL_PASSWORD` (auto-generated on first run)
- For external access, configure `JWT_SECRET` and `API_KEY_SECRET` in `.env`

## Links

- npm: https://www.npmjs.com/package/karnelroute

## Related

- `karnel ia routes` — List installed AI CLI tools
- `karnel ia sessions` — View active AI sessions
- `karnel install ai --omni-route` — Install
