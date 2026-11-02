# Aula 3.4 · Subagente: quando usar

Módulo 3 · Regra. Material de apoio em PDF: [material-de-apoio-aula-3.4.pdf](material-de-apoio-aula-3.4.pdf).

O valor do subagente é a janela de contexto limpa, não a persona. Esta pasta tem os dois subagentes
que se pagam no dia a dia (o que roda os testes e o revisor que não edita) e o caminho para o
`/ai-context` do BC Harness, a orquestração de três subagentes que a aula rodou.

## O que é instalado

| Arquivo no seu projeto | O que faz |
| --- | --- |
| `.claude/agents/test-runner.md` | Roda os testes (Haiku), devolve até 15 linhas: comando, quantos passaram, cada falha com `arquivo:linha` e uma hipótese. Não tem Edit nem Write |
| `.claude/agents/revisor.md` | Revisa o diff que vem no pedido. Só `Read, Grep, Glob`: não edita e não roda comando |
| `.claude/hooks/bash-so-permitido.sh` | Hook `PreToolUse` para o frontmatter de um subagente: deixa o Bash rodar só os comandos listados. Não faz nada sozinho; as variantes em `modelos/` usam |

O test-runner descobre o comando pelo projeto (Sail, `artisan`, `package.json`, pytest, rspec,
`go test`). Para fixar o do seu projeto, troque a lista no arquivo por uma linha só.

## Instalar

```bash
cd ~
git clone https://github.com/beerandcodeteam/harness-lab-materiais
cd /caminho/do/seu/projeto
~/harness-lab-materiais/instalar.sh 3.4
claude plugin validate .claude/agents
```

Já baixou antes? Atualize com `git -C ~/harness-lab-materiais pull`.

Se a pasta `.claude/agents/` não existia quando você abriu a sessão, feche e abra o Claude Code de
novo: o Claude Code só vigia as pastas de agentes que existiam no início da sessão.

## Usar

```text
@agent-test-runner rode a suíte inteira
@agent-revisor revise o diff da branch. Mande o git diff no pedido
```

O `@agent-<nome>` garante que aquele subagente roda. Pedido em texto ("use o test-runner") deixa a
decisão com o Claude.

## O /ai-context da aula (plugin BC Harness)

```bash
claude plugin marketplace add beerandcodeteam/beer-and-code-harness
claude plugin install bc-harness@beer-and-code
```

Depois, na raiz do projeto, dentro do Claude Code: `/bc-harness:ai-context` (ou com `--adopt` se
você já tem um CLAUDE.md ou AGENTS.md escrito à mão ou pelo Laravel Boost). Ele escreve `AGENTS.md`,
um `CLAUDE.md` que só aponta para o `AGENTS.md` e 8 arquivos em `docs/agents/`. Não faz commit:
revise com `git diff`. O plugin traz também `/bc-harness:init`, `/bc-harness:plan` e um hook de
Bash (`sail-guard`) que, em projeto com Sail, bloqueia `php`, `artisan` e `composer` no host e devolve
o comando com `./vendor/bin/sail`.

## Para ler e adaptar (não são instalados)

- `modelos/revisor-com-git.md`: o revisor com Bash, travado num hook que só deixa `git diff`,
  `git log`, `git show`, `git status` e `grep`. Ele busca o diff sozinho.
- `modelos/test-runner-travado.md`: o test-runner com o comando fixo do Sail e o Bash travado nele.
- `modelos/pedido-para-subagente.md`: as quatro partes de um bom pedido, ruim e bom lado a lado.

Para usar uma variante, copie por cima do arquivo instalado:

```bash
A=~/harness-lab-materiais/modulo-3-regra/aula-3.4-subagente-quando-usar
cp "$A/modelos/revisor-com-git.md" .claude/agents/revisor.md
```

O `cp` troca o seu `revisor.md` atual: se ele é seu, guarde uma cópia antes.

Hook no frontmatter de subagente de projeto só roda depois que você aceita o diálogo de confiança
da pasta (workspace trust). Sessão `claude -p` não conta como confiada. Em subagente que vem de
plugin, o campo `hooks` é ignorado.

## Testar o hook sem abrir o Claude Code

```bash
H=.claude/hooks/bash-so-permitido.sh
j='{"tool_input":{"command":"git diff; rm -rf ."}}'
echo "$j" | $H "git diff" || echo "exit $?"
```

O esperado é a mensagem de bloqueio e `exit 2`. Troque o comando por `git diff --stat`: sai `0`.
