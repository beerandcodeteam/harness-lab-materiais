# Aula 2.1 · Hooks: o que o modelo não decide

Módulo 2 · Trava. Material de apoio em PDF: [material-de-apoio-aula-2.1.pdf](material-de-apoio-aula-2.1.pdf).

Pedir não é obrigar: o que está no CLAUDE.md é pedido, o que está num hook acontece. Esta pasta
tem os hooks da aula para você ver o ciclo de vida da sua própria sessão e sentir o contrato do
hook (entra um JSON, sai um código) no seu terminal.

## O que é instalado

| Arquivo no seu projeto | Evento | O que faz |
| --- | --- | --- |
| `.claude/hooks/espiao.sh` | todos (via `--settings`) | Anota cada evento em `.claude/logs/eventos.log`. Nunca imprime no stdout |
| `.claude/settings.espiao.json` | | Liga o espião em 8 eventos. Só vale quando você abre com `claude --settings .claude/settings.espiao.json` |
| `.claude/hooks/contexto-inicio.sh` | `SessionStart` | Põe no contexto a branch, os últimos commits e a próxima tarefa do `tarefas.md` |
| `.claude/hooks/avisa.sh` | `Notification` (`permission_prompt\|idle_prompt`) | Notificação do sistema, bipe e notificação do terminal via `terminalSequence`. Webhook opcional em `AVISO_WEBHOOK` |
| `.claude/settings.json` | | Liga o `contexto-inicio.sh` e o `avisa.sh`. Se você já tem um, os hooks são somados ao seu |
| `.claude/logs/.gitignore` | | Deixa os logs fora do git |

## Instalar

Precisa de `jq` (`sudo apt install jq` no Ubuntu e WSL, `brew install jq` no macOS).

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 2.1
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

## Conferir

Fora do Claude Code, mande o JSON que ele mandaria:

```bash
A=~/harness-lab-materiais/modulo-2-trava
E=$A/aula-2.1-hooks-o-que-o-modelo-nao-decide/modelos/entradas
.claude/hooks/espiao.sh < $E/pretooluse-bash.json; echo "exit $?"
.claude/hooks/contexto-inicio.sh; echo "exit $?"
cat .claude/logs/eventos.log
```

Depois abra a sessão com o espião ligado e, num segundo terminal, `tail -f .claude/logs/eventos.log`:

```bash
claude --settings .claude/settings.espiao.json
```

Dentro do Claude Code, `/hooks` mostra o que está ligado e de onde veio, e este pedido prova que o
`SessionStart` chegou ao modelo:

> Sem ler arquivos: qual é a branch e a próxima tarefa?

## Para ler e adaptar (não são instalados)

- `modelos/libera-pergunta-bloqueia.sh`: as três respostas de um `PreToolUse` (exit 0, `ask`,
  `deny` com motivo) num esqueleto curto. A versão completa é a da aula 2.3.
- `modelos/entradas/`: o JSON real que cada evento manda no stdin, para testar qualquer hook com `<`.

## Teste deste repositório

`teste/verificar.sh` roda na sandbox do `testes/validar.py` (HOME falso) depois dos comandos do
PDF. O `teste/projeto/` é um projeto falso com `tarefas.md` e um `settings.json` que já tinha uma
permissão, para provar que o instalador soma em vez de sobrescrever. Os hooks também foram
testados numa sessão `claude -p` real (Claude Code 2.1.316): o espião anotou do `SessionStart` ao
`SessionEnd`, e o modelo respondeu a branch e a próxima tarefa só com o texto do `contexto-inicio.sh`.
O `terminalSequence` do `avisa.sh` só é emitido em sessão interativa.
