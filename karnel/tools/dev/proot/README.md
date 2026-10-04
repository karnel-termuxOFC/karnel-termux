# Proot

Chroot alternative for user-space sandboxing

**Package:** proot  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://proot-me.github.io  
**Type:** System tool (pkg)  
**License:** GPL-2.0

## Description

PRoot is a user-space implementation of chroot, mount --bind, and binfmt_misc. It allows users to run arbitrary programs in a sandboxed environment without root privileges, essential for running Linux distributions in Termux.

## Dependencies

- Installed via pkg

## Install

```bash
karnel install dev --proot
```

## Uninstall

```bash
karnel uninstall dev --proot
```

## Update

```bash
karnel update dev --proot
```

## Notes

- Command: `proot`
- Used by proot-distro for running Linux distributions
- Required by some AI tool installation methods

