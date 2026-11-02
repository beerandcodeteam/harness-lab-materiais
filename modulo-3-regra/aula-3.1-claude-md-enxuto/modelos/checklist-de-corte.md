# Checklist de corte · CLAUDE.md enxuto (aula 3.1)

Passe **cada linha** do seu CLAUDE.md por aqui, de cima para baixo. A primeira pergunta decide
quase tudo; as outras dizem para onde vai o que sai.

## 0. Antes de cortar

- [ ] `cp -n CLAUDE.md CLAUDE.old.md` (o Claude Code não carrega `CLAUDE.old.md`; nada se perde).
- [ ] Numa sessão nova, mande `oi` e rode `/context`. Anote a linha **Memory files**.
- [ ] `wc -l CLAUDE.md` e anote. A doc pede menos de 200 linhas por arquivo.
- [ ] `/memory`: tem CLAUDE.md em subpasta ou em `~/.claude/` que você esqueceu?

## 1. O filtro

> O agente descobriria isso lendo o código?

- **Sim**: a linha sai. Ele lê `composer.json`, `package.json`, `pyproject.toml`, `Gemfile` e a
  estrutura de pastas sozinho.
- **Não**: a linha fica, se for um destes seis:

| Fica | Exemplo |
| --- | --- |
| Comando exato | `./vendor/bin/sail artisan test --filter=Nome` · `pnpm vitest run caminho` |
| Decisão fora do padrão | Regra de negócio em `app/Actions`, não no controller |
| Armadilha do ambiente | Tudo roda no Docker/Sail; comando no host falha |
| Erro que já aconteceu (mais de uma vez) | Datas em UTC; converta só na view. (Converter no model dobrou o fuso.) |
| Fluxo do repositório | Branch a partir da `develop`; Conventional Commits |
| Onde procurar | Contrato da API em `docs/api.md` (ponteiro, não o conteúdo) |

## 2. O que sai, e para onde vai

| Se a linha é... | Exemplo | Destino |
| --- | --- | --- |
| Conselho genérico | "Escreva código limpo e siga boas práticas" | Corte. Se a prática é específica, escreva a prática |
| Aula do framework | "O Laravel usa MVC. Models em app/Models" | Corte |
| Mapa de pastas | Árvore com `├──` | Corte. Ele roda `ls` e `grep` |
| Estilo que o linter cobra | "4 espaços, aspas simples" | Hook de lint (aula 2.2) |
| Regra sem exceção | "NUNCA rode migrate:fresh" | Hook ou `permissions.deny` (Módulo 2) |
| IMPORTANTE em maiúscula | "IMPORTANTE!!! SEMPRE rode os testes" | Escreva normal. Se ainda falha: hook `Stop` |
| Procedimento longo | "Para criar módulo: 1) ... 30)" | Skill (aula 3.3) |
| Coisa de uma tarefa | "Nesta sprint, não mexa no checkout" | No pedido, ou na spec da feature |
| Preferência só sua | "Me responda em tópicos curtos" | `CLAUDE.local.md` (no `.gitignore`) |
| Vale só para uma parte do código | Regras de `modules/pagamentos/` | `.claude/rules/` com `paths:` (aula 3.2) |
| Nota para humanos | "Este bloco foi pedido pelo time X" | Comentário `<!-- ... -->`: não gasta contexto |

## 3. Erro cometido: como reescrever

- [ ] A regra primeiro, na forma positiva ("converta na view", não só "não converta no model").
- [ ] O jeito certo, com o código ou comando exato.
- [ ] O porquê curto, entre parênteses. É ele que faz o agente acertar o caso parecido.
- [ ] Uma linha (duas, no máximo). Sem data, sem "ontem", sem quem errou.
- [ ] Só entra se aconteceu mais de uma vez e **você** decidiu. Nada de arquivo de erros que o
      agente alimenta sozinho.

Antes:

```
- Cuidado com datas, já deu problema. Dia 12/09 o agente quebrou o relatório
  de vendas porque converteu o horário errado, aí eu tive que corrigir na mão.
```

Depois:

```
- Datas no banco em UTC; converta só na view com ->timezone(config('app.tz')).
  (Converter no model dobrou o fuso no relatório de vendas.)
```

## 4. Depois de cortar

- [ ] Numa sessão nova, `oi` e `/context` de novo. Compare a linha **Memory files**.
- [ ] Pergunta-teste: peça uma tarefa pequena que deveria acionar uma regra. Ele seguiu sem você lembrar?
- [ ] Depois de uma hora de sessão, repita a pergunta-teste.
- [ ] Liste o que virou "anote para hook" e "anote para skill". Isso alimenta o Módulo 2 e a aula 3.3.
- [ ] Commit do CLAUDE.md: ele é do time.
