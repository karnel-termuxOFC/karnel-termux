# Codebuff

A 100% free coding agent, right from your terminal

**Package:** codebuff
**Author:** israel marques
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux
**Official:** https://codebuff.com
**Releases:** https://github.com/CodebuffAI/codebuff
**Type:** AI coding agent (Binary + glibc bootstrapper)
**License:** MIT

## Description

Codebuff is the free coding agent: a free CLI coding agent and Codebuff Web, the free way to build full-stack apps. No subscription, no setup, no lock-in. Karnel Termux offers two installation methods: native with glibc support for best performance, or via proot-distro Ubuntu container for maximum compatibility.

## Dependencies

- **Native mode:** glibc-repo, glibc, clang, git, curl, tar
- **Proot mode:** proot-distro, curl, ca-certificates, tar

## Install

```bash
karnel install ai --codebuff
```

You will be prompted to choose:

1. **Native (recommended)** — Compiles a glibc bootstrapper and downloads the latest Codebuff binary from GitHub releases
2. **Proot-distro (alternative)** — Runs Codebuff inside an Ubuntu proot-distro container

## Uninstall

```bash
karnel uninstall ai --codebuff
```

## Update

```bash
karnel update ai --codebuff
```

## Notes

- **Native mode** requires `glibc-repo`, `glibc`, `clang`, and other dependencies (installed automatically)
- The native binary is stored in `~/.local/share/karnel-data/codebuff/`
- A small C bootstrapper (`codebuff_helper.c`) handles ELF loading via the glibc dynamic linker
- **Proot mode** uses `proot-distro ubuntu` and downloads the binary directly inside the container
- Version is fetched automatically from GitHub releases (`CodebuffAI/codebuff-community`)
- Data directory: `~/.local/share/karnel-data/codebuff/`
