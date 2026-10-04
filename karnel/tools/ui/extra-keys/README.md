# Extra Keys

Additional keyboard rows for Termux with navigation keys

**Package:** karnel-termux (extra-keys config)  
**Author:** israel marques  
**Repository:** https://github.com/karnel-termuxOFC/karnel-termux  
**Type:** Termux UI customization  
**License:** MIT

## Description

Adds two extra keyboard rows to the Termux terminal with useful keys for coding: ESC, TAB, CTRL, ALT, arrow keys, HOME, END, PGUP, PGDN. This transforms the default Termux keyboard into a more developer-friendly input experience.

## Dependencies

- Termux (base installation)

## Install

```bash
karnel install ui --extra-keys
```

## Uninstall

```bash
karnel uninstall ui --extra-keys
```

## Update

```bash
karnel update ui --extra-keys
```

## Notes

- Config file: `~/.termux/termux.properties`
- Adds two extra key rows with navigation keys
- Includes ESC, TAB, CTRL, ALT, arrows, HOME, END, PGUP, PGDN, `</>` and `-`
- Restart Termux to apply changes
