# Zork

Jogos clássicos de aventura em texto — Zork I, II e III

**Pacote:** zork  
**Autor:** israel marques  
**Repositório:** https://github.com/karnel-termuxOFC/karnel-termux  
**Oficial:** http://www.infocom-if.org  
**Tipo:** Utilitário (frotz)  
**Licença:** MIT

## Descrição

Zork é uma série de jogos de aventura em texto originalmente desenvolvidos pela Infocom. Este instalador baixa Zork I, II e III e os empacota com o interpretador Z-machine `frotz`. Jogue ficção interativa diretamente no seu terminal.

## Dependências

- frotz (interpretador Z-machine, instalado via pkg)
- unzip

## Instalar

```bash
karnel install utils --zork
```

## Desinstalar

```bash
karnel uninstall utils --zork
```

## Atualizar

```bash
karnel update utils --zork
```

## Notas

- Comando: `zork [1|2|3]` (padrão: Zork I)
- Dados do jogo em `~/.local/share/karnel-data/zork/`
- Requer conexão com internet para download inicial
