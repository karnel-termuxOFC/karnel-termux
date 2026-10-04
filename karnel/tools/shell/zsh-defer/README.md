# Zsh-defer

Deferred plugin loading for faster ZSH startup

**Package:** zsh-defer  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://github.com/romkatv/zsh-defer  
**Type:** ZSH plugin (git clone)  
**License:** MIT

## Description

Zsh-defer defers the loading of ZSH plugins to after the first prompt, significantly improving shell startup time. Non-essential plugins are loaded in the background while the shell remains responsive.

## Dependencies

- ZSH, git, zoxide

## Install

```bash
karnel install shell --zsh-defer
```

## Uninstall

```bash
karnel uninstall shell --zsh-defer
```

## Update

```bash
karnel update shell --zsh-defer
```

## Notes

- Installed in `~/.zsh-plugins/`
- Delays plugin loading until after first prompt
- Improves perceived ZSH startup time

