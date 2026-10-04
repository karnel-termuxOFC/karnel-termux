# PostgreSQL

Advanced open-source relational database

**Package:** postgresql  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Official:** https://www.postgresql.org  
**Type:** Database (pkg)  
**License:** PostgreSQL License

## Description

PostgreSQL is a powerful, open-source object-relational database system with over 30 years of active development. It has a strong reputation for reliability, feature robustness, and performance. Karnel Termux includes a dedicated manager (`karnel pg`) for starting, stopping, and managing PostgreSQL instances.

## Dependencies

- Installed via pkg
- Data directory managed by `karnel pg`

## Install

```bash
karnel install db --postgresql
```

## Uninstall

```bash
karnel uninstall db --postgresql
```

## Update

```bash
karnel update db --postgresql
```

## Notes

- Managed via `karnel pg` commands (start, stop, restart, status, init, create, drop, list, shell)
- Logs: `~/.cache/karnel/postgresql.log`
- Automatic data directory detection
- Support for existing installations

