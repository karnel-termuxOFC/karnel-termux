# Gentleman Guardian Angel

Provider-agnostic AI code review on every commit

**Package:** gga  
**Author:** Gentleman-Programming  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://github.com/Gentleman-Programming/gentleman-guardian-angel  
**Type:** AI code review CLI (Pure Bash)  
**License:** MIT

## Description

GGA (Gentleman Guardian Angel) is a provider-agnostic AI code review tool that runs on every commit. It validates staged files against your `AGENTS.md` rules using any LLM provider (Claude, Gemini, Codex, OpenCode, Ollama, LM Studio, GitHub Models). Pure Bash, zero dependencies, works as a standard pre-commit git hook.

Karnel stages the official source with a Termux-compatible Bash path and installs the command and libraries into Karnel-managed locations.

## Dependencies

- git, curl
- bash 5.0+

## Install

```bash
karnel install ai --gga
```

## Uninstall

```bash
karnel uninstall ai --gga
```

## Update

```bash
karnel update ai --gga
```

## Notes

- Pinned official source stored in `$KARNEL_DATA/gga-termux/`
- Runtime libraries stored in `$KARNEL_DATA/gga-runtime/`
- Binary installed to `$PREFIX/bin/gga`
- Karnel verifies ownership before replacing or removing source, runtime, or command files
- `karnel update ai --gga` reapplies the immutable source revision shipped by the current Karnel release
- The source repository is required only during install/update and can be safely removed afterward
