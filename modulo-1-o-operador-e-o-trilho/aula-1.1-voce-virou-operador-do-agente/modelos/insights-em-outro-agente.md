# O espelho do /insights no Codex, no Cursor e em outros agentes

Na aula, o primeiro passo do diagnóstico é o `/insights`, que é nativo do Claude Code. O Codex e o
Cursor não têm um comando equivalente (conferido em 02/11/2026: Codex CLI 0.166 e a documentação
do Cursor). O caminho é pedir ao próprio agente que leia o seu histórico e escreva o relatório.

O resultado é um espelho, como o `/insights`: texto escrito pelo modelo, diferente a cada vez.
A métrica do curso continua sendo a skill `diagnostico-operador`, que lê o histórico do Claude Code.

## Codex CLI

O Codex grava cada sessão como um arquivo `.jsonl` em `~/.codex/sessions/AAAA/MM/DD/`
(ou em `$CODEX_HOME/sessions/`, se você mudou o `CODEX_HOME`). Abra o Codex na sua pasta pessoal
e cole o pedido abaixo:

```text
Leia os arquivos .jsonl de ~/.codex/sessions/ dos últimos 30 dias. Em cada um, considere só as
mensagens com role "user" que eu digitei: ignore as que começam com <environment_context>, as de
role developer e as saídas de ferramenta. Não altere nenhum arquivo. Escreva um relatório curto,
em português, com:
1. Em quais projetos (campo cwd do session_meta) eu mais trabalhei e com que tipo de tarefa.
2. As 5 situações que mais se repetiram em que eu precisei intervir: colar erro, mandar
   continuar, aprovar comando, repetir uma convenção do projeto.
3. Três mensagens minhas de exemplo para cada situação, com a data.
4. O que eu poderia deixar escrito ou automatizado para não precisar intervir de novo.
```

## Cursor

O Cursor não documenta um arquivo de histórico que você possa abrir, nem um relatório das suas
mensagens. O "Conversation Insights" é do painel de Enterprise e mostra o tipo de trabalho do time;
o "Usage Analytics" (Team e Enterprise) mostra uso, não o que você digitou. O que existe para você é
a busca nas conversas: `Ctrl+K` (ou `Cmd+K` no Mac) abre a paleta e procura em todos os chats.

1. Abra as conversas de trabalho dos últimos dias, uma por vez.
2. Copie as mensagens que você digitou para um arquivo `minhas-mensagens.md` no projeto.
3. No chat do Cursor, peça:

```text
Leia @minhas-mensagens.md. São as minhas mensagens para o agente nos últimos dias.
Agrupe cada uma em: pedido de trabalho novo, testei e avisei que quebrou, mandei continuar ou
cobrei status, aprovei ou escolhi uma opção, repeti algo que você já devia saber.
Mostre a contagem de cada grupo, três exemplos de cada e o que eu poderia deixar escrito ou
automatizado para não intervir de novo.
```

Apague o `minhas-mensagens.md` depois, ou coloque em `.git/info/exclude`: ele tem o seu histórico.

## Qualquer outro agente (Gemini CLI, Copilot, Windsurf, OpenCode...)

O caminho é o mesmo para qualquer provider. São dois passos:

1. Descubra onde o agente guarda o histórico. Pergunte a ele mesmo, numa sessão nova:

```text
Onde você grava o histórico das minhas conversas nesta máquina? Me diga a pasta e o formato
dos arquivos, e se eles têm o texto das mensagens que eu digitei. Não altere nada.
```

2. Se ele apontar arquivos legíveis, faça como no Codex: peça para ler as mensagens que você
   digitou nos últimos 30 dias e escrever o mesmo relatório (projetos, situações em que você
   interveio, exemplos, o que deixar escrito). Se não houver arquivo, ou se ele não souber,
   faça como no Cursor: junte as suas mensagens em `minhas-mensagens.md` e use o mesmo pedido de
   agrupamento.

Confira a resposta do passo 1 abrindo a pasta: o agente pode errar o caminho do próprio histórico.

## Fontes

- Claude Code, `/insights`: https://code.claude.com/docs/en/costs.md#analyze-your-usage-patterns
- Codex, comandos: https://developers.openai.com/codex/cli/slash-commands
- Cursor, busca nas conversas: https://cursor.com/docs/agent/overview
- Cursor, Usage Analytics e Conversation Insights: https://cursor.com/docs/account/teams/analytics
