# Claude Code

Anthropic's CLI tool with Claude AI

**Package:** claude-code  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://github.com/anthropics/claude-code  
**Type:** AI coding assistant (Binary + glibc bootstrapper)  
**License:** MIT

## Description

Claude Code is Anthropic's AI-powered coding assistant that runs directly in your terminal. It leverages Claude's advanced language models to help with code generation, debugging, refactoring, and answering technical questions. Karnel Termux provides two installation methods: native with glibc support for best performance, or via proot-distro Ubuntu container.

## Dependencies

- **Native mode:** glibc-repo, glibc, clang, curl, tar
- **Proot mode:** proot-distro, ca-certificates, nodejs, npm

## Install

```bash
karnel install ai --claude-code
```

## Uninstall

```bash
karnel uninstall ai --claude-code
```

## Update

```bash
karnel update ai --claude-code
```

## Notes

- Native installation (recommended): runs directly with glibc support via a C bootstrapper
- Proot-distro (alternative): runs the pinned `@anthropic-ai/claude-code@2.1.226` npm package inside an Ubuntu container
- The installer will prompt you to select which method to use
- Data directory: `~/.local/share/karnel-data/claude/`
