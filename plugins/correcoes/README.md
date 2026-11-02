# correcoes

Plugin do Harness Lab, aula 1.3 ("Por que o agente esquece a regra").

A skill `/correcoes:anotar` lê o que você digitou nas últimas sessões do Claude Code no
projeto atual (`~/.claude/history.jsonl`), mostra as mensagens com cara de correção e
anota as 5 mais recentes em `correcoes.md`, na raiz do projeto: o que você pediu, o que o
agente fez e como você corrigiu. Não classifica nada: isso é a aula 1.4 (plugin
`diagnostico-camadas`, que lê o mesmo arquivo).

```bash
claude plugin marketplace add beerandcodeteam/harness-lab-materiais
claude plugin install correcoes@harness-lab
```

Dentro do Claude Code: `/correcoes:anotar`, `/correcoes:anotar 10` (mais sessões) ou
`/correcoes:anotar --todas` (todas as mensagens, não só as filtradas).

O script `skills/anotar/scripts/mensagens.sh` também roda sozinho no terminal, na raiz do
projeto. Só lê. Precisa de `jq` 1.6 ou mais novo. O formato do `history.jsonl` é interno do
Claude Code (testado na 2.1.316) e pode mudar entre versões.
