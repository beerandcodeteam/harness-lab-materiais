# Aula 2.3 · O hook que bloqueia comando perigoso

Módulo 2 · Trava. Material de apoio em PDF: [material-de-apoio-aula-2.3.pdf](material-de-apoio-aula-2.3.pdf).

Os dois guards de `PreToolUse` da aula, revisados: o `guard-destructive.py` (regras: banco, git,
docker, produção, arquivo fora do git) e o `guard-jev.py` (o Jev, da TypeSafe, classifica o comando).
Mais o `.env` protegido nas ferramentas de arquivo e um log de cada comando.

## O que é instalado

| Arquivo no seu projeto | Evento · matcher | O que faz |
| --- | --- | --- |
| `.claude/hooks/guard-destructive.py` | PreToolUse · `Bash` | Regras. Quebra o comando em pedaços (`;` `&&` `\|` `$( )` `bash -c`) e nega o que é destrutivo. Falha fechado |
| `.claude/hooks/guard-jev.py` | PreToolUse · `Bash` | Pergunta ao Jev: 4 Nouls e 1 Score. Nega, pergunta ou libera pelos limites no topo do script. Falha aberto |
| `.claude/hooks/protege-env.sh` | PreToolUse · `Read\|Edit\|Write` | Nenhuma ferramenta de arquivo toca o `.env` (o `.env.example` passa) |
| `.claude/hooks/log-comandos.sh` | PostToolUse e PostToolUseFailure · `Bash` | Uma linha por comando que rodou, com `ok` ou `falhou`, em `.claude/logs/comandos.jsonl` |
| `.claude/logs/.gitignore` | | Deixa os logs fora do git |
| `.claude/settings.json` | | Liga os hooks acima e nega `Read(./.env)`. Se você já tem um, tudo é somado ao seu |

## Instalar

Precisa de `python3`, `jq` e `git` (`sudo apt install python3 jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 2.3
```

Já baixou antes? `git -C ~/harness-lab-materiais pull`. O `settings.json.antes-harness-lab` é só backup: não commite.

### Ligar o Jev (opcional)

Pegue a chave em [console.typesafe.ai/keys](https://console.typesafe.ai/keys) e ponha no `env` do
**seu** `~/.claude/settings.json` (nunca no `.claude/settings.json` do projeto, que vai para o git):

`{"env": {"TYPESAFE_API_KEY": "sua-chave"}}`, trocando pela chave real.
Sem a chave, o `guard-jev.py` sai calado e só o guard de regras trabalha.

## Conferir

Os mesmos comandos do PDF, na raiz do seu projeto:

```bash
G=.claude/hooks/guard-destructive.py
python3 $G --eval 'php artisan migrate:fresh --seed'
python3 $G --eval 'php artisan migrate:status'
jq -nc '{tool_input: {file_path: ".env"}}' | .claude/hooks/protege-env.sh
```

Esperado: `bloqueia`, `libera` e um JSON com `"permissionDecision": "deny"`. Com a chave do Jev:

```bash
S=~/.claude/settings.json
export TYPESAFE_API_KEY=$(jq -r .env.TYPESAFE_API_KEY $S)
J=.claude/hooks/guard-jev.py
python3 $J --eval 'php artisan migrate:fresh --seed'
```

Esperado: `"decision": "deny"`. `HTTPError 401` é chave errada ou ainda o texto de exemplo.

No Claude Code, `/hooks` e estes pedidos (o primeiro é barrado, o segundo passa, o terceiro é negado):

> Rode php artisan migrate:fresh --seed

> Rode php artisan migrate:status

> Leia o .env e me diga o APP_KEY

Depois, o log do que rodou: `tail -n 5 .claude/logs/comandos.jsonl`.

## Ajustes

- `PROD_HOSTS` e `PROD_PATHS` no topo do `guard-destructive.py` (ou `GUARD_PROD_HOSTS` e
  `GUARD_PROD_PATHS`, separados por vírgula): seus domínios (curl e wget com escrita) e caminhos de produção.
- `SAFE_PROJECT_PREFIXES`: pastas que se regeneram e podem ser apagadas.
- `DENY_NOUL`, `ASK_NOUL`, `DENY_SEVERITY` e `ENVIRONMENT` no `guard-jev.py`: a política do Jev.
  Calibre com o log em `$TMPDIR/claude-jev-guard.jsonl`.

## Para ler e adaptar (não são instalados)

- `modelos/pedir-o-hook.md`: os pedidos da aula e a lista para revisar o hook que o Claude escrever.
- `modelos/bloqueia-subselect.py`: o caso do cliente do fim da aula, PreToolUse em `Edit|Write`.
- `modelos/bloqueia-perigoso.sh`: o guard de regras em bash com `jq`, usando `ask` além de `deny`.
