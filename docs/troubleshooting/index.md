---
title: Troubleshooting
permalink: /troubleshooting/
layout: base
---

# Troubleshooting

Common issues when installing, updating, or publishing Karnel Termux.

## karnel update karnel

`karnel update karnel` resolves the latest GitHub release tag (strictly
`v<major>.<minor>.<patch>`), downloads the `karnel-termux-install.sh` and
`karnel-termux-install.sh.sha256` assets pinned to that tag, verifies the
SHA-256 checksum, and only then runs the installer. If verification fails or the
tag has no assets, the updater falls back to the local Git checkout and then to
npm/pnpm installs.

| Message | Cause / fix |
|---------|-------------|
| `GitHub returned an invalid release tag` | GitHub API responded without a clean SemVer tag. Retry, or check network access to `api.github.com`. |
| `Checksum verification failed for the curl installer` | The downloaded installer does not match the signed checksum (corruption or tampering). Retry; if it persists, update via `karnel update karnel` falling back to git, or `npm install -g karnel-termux@latest`. |
| `All update methods failed` | Every fallback failed. Check network, the Git checkout state, and npm connectivity. |
| Update stays on the same version | Old releases (`v4.13.3`, `v4.13.4`) do not ship installer assets, so the curl path falls back to git. A release that includes the installer assets enables the verified curl path. |

The updater prints its progress to the terminal only; it does not write log
files. For module installs, `karnel install dev` logs to
`$KARNEL_CACHE/install_dev.log` and `karnel install npm` logs to
`$KARNEL_CACHE/install_npm.log`.

## npm publishing

`npm publish` returning `403`/`404` means the `NPM_TOKEN` used by the
Release workflow cannot publish `karnel-termux`.

Create an npm **granular access token** with:

- **Packages & scopes**: Read + Publish access for `karnel-termux`
- **Permissions**: Automation (Bypass 2FA)

Save it as the `NPM_TOKEN` Actions secret in the
`israelmarques1024-dotcom/karnel-termux` repository. Never paste a token into
issues, chat, shell history, or screenshots. If a token is ever exposed,
revoke it immediately at https://www.npmjs.com/settings/<user>/tokens.

## GitHub Releases

Releases are created from the `v*.*.*` tag before npm publishing, so a failing
npm publish does not block the release. The workflow needs `contents: write`
permission (already declared). If `gh release create` fails, confirm the tag
exists and the token used by GitHub Actions has write access.

## Documentation mirror (GitHub Pages)

The documentation source is the `docs/` directory, and the published site is
the Vercel production site, `https://karneltermux.vercel.app`. The `Publish Docs`
workflow (`.github/workflows/docs.yml`) runs `actions/jekyll-build-pages` on
every push to `main` that changes `docs/**`, uploads the result as a Pages
artifact and deploys it to the `github-pages` environment; that mirror,
`https://israelmarques1024-dotcom.github.io/karnel-termux/`, is served only
while GitHub Pages is enabled for the repository.

If a build fails, open the Actions run for the failing job and read the Jekyll
output: the usual causes are invalid `_config.yml` YAML, an SCSS compile error
in `assets/css/style.scss`, or a malformed `{% raw %}{{ }}{% endraw %}` Liquid tag. After a
successful deploy, the published site is visible under the repository's
**Settings → Pages**.

## Reporting a bug

Include:

```bash
karnel --version
karnel doctor termux --quick
command -v node npm gh vercel
```

Plus the relevant logs:

- `$KARNEL_CACHE/install_dev.log`
- `$KARNEL_CACHE/install_npm.log`

**Never** include GitHub, npm, Vercel, Puter, or other authentication tokens,
cookies, or `.env` values in the report.
