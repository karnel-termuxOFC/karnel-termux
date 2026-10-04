# OpenCode

Open-source agent that helps you write code in your terminal

**Package:** opencode  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://github.com/anomalyco/opencode  
**Type:** AI coding agent (Binary + glibc bootstrapper)  
**License:** MIT

## Description

OpenCode is an AI-powered coding agent developed by anomalyco that operates directly in your terminal. It provides intelligent code completion, refactoring suggestions, and natural language code generation. Karnel Termux offers two installation methods: native with glibc support for best performance, or via proot-distro Ubuntu container for maximum compatibility.

## Dependencies

- **Native mode:** glibc-repo, glibc, clang, git, ripgrep, python, jq, nodejs-lts, curl, tar
- **Proot mode:** proot-distro, ca-certificates, nodejs, npm

## Install

```bash
karnel install ai --opencode
```

You will be prompted to choose:

1. **Native (recommended)** — Compiles a glibc bootstrapper and downloads the OpenCode release configured by Karnel
2. **Proot-distro (alternative)** — Runs the pinned `opencode-ai@1.18.15` npm package inside an Ubuntu container

## Uninstall

```bash
karnel uninstall ai --opencode
```

## Update

```bash
karnel update ai --opencode
```

## Notes

- **Native mode** requires `glibc-repo`, `glibc`, `clang`, and other dependencies (installed automatically)
- The native binary is stored in `~/.local/share/karnel-data/opencode/`
- A small C bootstrapper (`opencode_helper.c`) handles ELF loading via the glibc dynamic linker
- **Proot mode** uses `proot-distro ubuntu` and installs the pinned `opencode-ai@1.18.15` npm package
- Data directory: `~/.local/share/karnel-data/opencode/`
