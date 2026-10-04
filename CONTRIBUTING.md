# Contribuindo com o Karnel Termux

## Código de Conduta

Seja respeitoso e construtivo. Projetos open source dependem de colaboração.

## Como Contribuir

### Reportar Bugs

Abra uma [issue](https://github.com/israelmarques1024-dotcom/karnel-termux/issues) com:

- Versão do Karnel (`karnel --version`)
- Passos para reproduzir
- Comportamento esperado vs real
- Logs de erro (`~/.cache/karnel/logs/` por padrão, ou `$XDG_CACHE_HOME/karnel/logs/`)

### Sugerir Features

Abra uma issue com o prefixo `[feature]` descrevendo:

- O problema que resolve
- Como funcionaria
- Exemplos de uso

### Adicionar um Tool Installer

Cada ferramenta instalável segue esta estrutura:

```
karnel/tools/<module>/<tool-name>/
├── install.sh        # Script de instalação (obrigatório)
├── uninstall.sh      # Script de desinstalação (opcional)
└── README.md         # Documentação (opcional, mas recomendado)
```

O `install.sh` deve seguir o contrato de lifecycle:

1. Retornar `0` somente quando a operação foi executada com sucesso
2. Retornar `2` quando a ferramenta já estiver instalada, sem criar ownership Karnel
3. Retornar um valor diferente de `0` e `2` em qualquer falha
4. Preservar instalações e dados que não tenham marcador de ownership Karnel
5. Usar `log_success`, `log_info`, `log_warn` e `log_error` para feedback

Ferramentas registradas devem ser incluídas no `all.sh` do módulo. Instaladores
baseados em `pkg`, npm ou outro registry central precisam detectar o binário ou
pacote existente antes de instalar. Veja `karnel/tools/security/template.sh` e
os testes em `tests/lifecycle-orchestration.sh`.

### Adicionar um Módulo

Módulos orquestradores ficam em `karnel/modules/<module>.sh`.

Eles importam `karnel/utils/*` e chamam os installers de `karnel/tools/<module>/`.

Use `_batch_tool_action` ou `_run_tool_lifecycle_action` para preservar o
contrato `0/2/falha`, a execução completa do lote e as regras de ownership. Não
chame handlers específicos diretamente em novos fluxos de lifecycle.

### Criar um Plugin (para usuários)

```bash
karnel plugin create meu-plugin
cd "${XDG_DATA_HOME:-$HOME/.local/share}/karnel-data/plugins/meu-plugin"
# Edite karnel-plugin.json e adicione comandos em commands/
```

Estrutura:

```
meu-plugin/
├── karnel-plugin.json   # Manifesto obrigatório
├── LICENSE              # Licença obrigatória
└── commands/            # Somente comandos declarados no manifesto
    └── meu-comando.sh
```

Exemplo de `karnel-plugin.json`:

```json
{
  "schemaVersion": 1,
  "name": "meu-plugin",
  "version": "1.0.0",
  "description": "Faz algo incrível",
  "commands": ["meu-comando"],
  "minKarnelVersion": "4.11.6",
  "license": "MIT",
  "checksum": "sha256:<hash-do-payload-do-plugin>",
  "capabilities": []
}
```

Os nomes seguem `^[a-z][a-z0-9-]{0,62}$`; a versão e
`minKarnelVersion` seguem SemVer. `commands/meu-comando.sh` precisa declarar
`meu-comando_main()` com a chave de abertura na mesma linha. Campos
desconhecidos, arquivos de comando extras, qualquer symlink no payload e
colisões de comando são rejeitados.

Plugins são Bash executado com as permissões do usuário. `capabilities` é apenas
uma declaração informativa; não existe sandbox. Para instalar repositório que
não está no registry é obrigatório `karnel plugin install owner/repo --unsafe`
e confirmação interativa.

## Plugin Registry — Publicar seu Plugin

Quer que seu plugin apareça em `karnel plugin search`?

1. Crie um repositório GitHub com seu plugin
2. Adicione o arquivo `karnel-plugin.json` na raiz (ou use um subdiretório e
   declare-o em `path` na entrada do registry)
3. Abra um PR adicionando seu repositório ao registry em:

   `https://github.com/israelmarques1024-dotcom/karnel-plugins`

Formato da entrada:

```json
{
  "name": "meu-plugin",
  "repo": "seu-user/meu-plugin",
  "ref": "main",
  "version": "1.0.0",
  "description": "Descrição curta",
  "commands": ["meu-comando"],
  "minKarnelVersion": "4.11.6",
  "license": "MIT",
  "checksum": "sha256:<hash-do-payload-do-plugin>",
  "capabilities": []
}
```

O registry valida schema, unicidade, SemVer, repositório acessível, licença,
manifesto, comandos e checksum. Consulte o README e a política de revisão do
[`karnel-plugins`](https://github.com/israelmarques1024-dotcom/karnel-plugins)
antes de abrir o PR.

## Pull Requests

1. Fork o repositório
2. Crie um branch descritivo: `feat/meu-recurso` ou `fix/meu-bug`
3. Faça commits pequenos e descritivos
4. Teste suas mudanças
5. Abra o PR para `main`

### Checklist do PR

- [ ] Rodei `bash tests/run.sh` e os testes direcionados da mudança
- [ ] Rodei `bash tests/check-shellcheck.sh`
- [ ] Segue a estrutura de diretórios existente
- [ ] Usa os helpers `log_*` e respeita o contrato de status `0/2/falha`
- [ ] Não quebra funcionalidades existentes
- [ ] Atualizei o README se necessário

## Estrutura do Projeto

```
karnel-termux/
├── karnel/bin/karnel           # Entrypoint
├── karnel/cli/commands/        # Comandos do CLI
├── karnel/modules/             # Orquestradores de módulo
├── karnel/tools/               # Instaladores de ferramentas
├── karnel/utils/               # Utilitários compartilhados
├── tests/                      # Testes shell
├── install.sh                  # Instalador de release
├── package.json                # Publicação npm
└── scripts/                    # Scripts auxiliares
```

## Ambiente de Desenvolvimento

```bash
git clone https://github.com/israelmarques1024-dotcom/karnel-termux.git
cd karnel-termux
chmod +x karnel/bin/karnel
export PATH="$PWD/karnel/bin:$PATH"
karnel doctor
bash tests/run.sh
bash tests/check-shellcheck.sh
```

## Dúvidas

Abra uma issue ou pergunte no [site oficial](https://karneltermux.vercel.app).
