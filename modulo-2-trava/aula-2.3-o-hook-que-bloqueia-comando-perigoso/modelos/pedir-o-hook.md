# Pedir o hook ao Claude Code · aula 2.3

Na aula, os dois hooks foram escritos pelo próprio Claude Code, a partir de um pedido curto.
Aqui estão os pedidos da aula, uma versão com os critérios que mudam o resultado e a lista
para revisar o que ele escrever para você.

## Os pedidos da aula

1. O guard de regras (virou o `guard-destructive.py`):

> Quero que crie um hook que bloqueie comandos destrutivos, como, por exemplo, migrate fresh,
> tentar acessar produção, remoção indevida de coisas que não estão no git ainda, esse tipo de coisa.

2. O guard com o Jev (virou o `guard-jev.py`), com a chave já no `env` do `~/.claude/settings.json`:

> Que tal testarmos a construção de um hook utilizando o Jev, o modelo de decisão da TypeSafe?
> Já temos no env do Claude a API key para isso. Faça o Jev classificar se o comando em si é
> potencialmente destrutivo.

## O pedido com os critérios que mudam o resultado

> Crie um hook PreToolUse com matcher Bash em .claude/hooks/, ligado no .claude/settings.json
> do projeto. Ele lê o JSON do stdin, pega tool_input.command e responde com
> hookSpecificOutput.permissionDecision "deny" e um permissionDecisionReason escrito para o
> modelo (o que fazer no lugar). Bloqueie: [os comandos que apagam o banco na minha stack],
> acesso a produção (ssh, scp, rsync remoto, deploy), git que descarta trabalho
> (reset --hard, clean -f, checkout --, push --force) e rm de arquivo que o git não consegue
> devolver. Quebre o comando em pedaços (; && || | $( ) bash -c) antes de checar.
> Falhe fechado: erro no script vira deny, e ponha "onFailure": "block" no settings.
> Libere o inofensivo: migrate, testes, git status, rm de node_modules ou vendor.
> Depois, me mostre um teste com JSON falso no stdin para cada regra, um que barra e um que passa.

## Revisar o hook que ele escrever

- [ ] O matcher é `Bash`? Ele só vê o terminal. Read, Edit e Write precisam de outro hook ou de `permissions.deny`.
- [ ] O deny sai em JSON com exit 0? (exit 2 também bloqueia; aí o motivo vai no stderr, sem o "ask")
- [ ] O motivo diz ao modelo o que fazer no lugar, e pede para não contornar?
- [ ] O script quebrado nega, em vez de liberar? E o settings tem `"onFailure": "block"`?
- [ ] O comando é quebrado em pedaços? `git status && rm -rf x` precisa ser barrado.
- [ ] Tem caso de teste para o que deve passar? Regra que barra o inofensivo vira regra desligada.
- [ ] Nada de segredo no `.claude/settings.json` do projeto (ele vai para o git).
