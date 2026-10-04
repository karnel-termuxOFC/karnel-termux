# OpenSSH

SSH server and client for secure remote access

**Package:** openssh  
**Author:** israel  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux
**Official:** https://www.openssh.com  
**Type:** Development tool (pkg)  
**License:** BSD

## Description

OpenSSH provides both SSH client (`ssh`) and server (`sshd`) for encrypted remote connections, file transfers, and port forwarding. On Termux, it enables connecting to remote servers and running an SSH server locally.

## Dependencies

- Installed via pkg

## Install

```bash
karnel install dev --openssh
```

## Uninstall

```bash
karnel uninstall dev --openssh
```

## Update

```bash
karnel update dev --openssh
```

## Notes

- SSH client: `ssh`
- SSH server: `sshd` (start with `sshd -D`)
- Config: `$PREFIX/etc/ssh/`
- Default port: 8022 (non-privileged, avoids conflicts)
