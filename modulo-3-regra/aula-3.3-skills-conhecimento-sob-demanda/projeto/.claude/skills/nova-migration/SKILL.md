---
name: nova-migration
description: Cria ou altera tabela e coluna neste projeto sem travar produção (coluna nova nullable, backfill em job, NOT NULL numa segunda migration, índice em migration separada) e prova com migrate, rollback e migrate de novo antes de dar por terminado.
when_to_use: Pedido de migration, coluna nova, adicionar ou remover campo, índice, renomear coluna, mudar tipo, alterar ou criar tabela. Exemplos de pedido, "adiciona a coluna cpf em clientes", "cria um índice em pedidos.status".
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/prova.sh *)
---
# Nova migration

Estes passos valem para a tarefa inteira, não só para a primeira migration.

1. Veja se a tabela é grande antes de escrever: `php artisan db:show --counts` mostra as linhas de cada tabela (pode demorar em banco grande); `php artisan db:table <tabela>` mostra colunas, índices e o tamanho. Com Sail, troque `php` por `./vendor/bin/sail`.
2. Tabela grande (mais de 1 milhão de linhas): a coluna nova entra nullable, o backfill roda num job em lotes e o NOT NULL vem numa segunda migration, num deploy seguinte. Por quê: um UPDATE de milhões de linhas dentro da migration segura a tabela e o deploy pelo tempo do UPDATE inteiro.
3. Índice em tabela grande vai numa migration só dele. Por quê: se ele demorar ou falhar, o rollback não leva a coluna junto.
4. Nunca edite uma migration que já rodou em produção: crie uma nova. `php artisan migrate:status` mostra o que já rodou neste banco. Na dúvida se já foi para produção, pergunte.
5. Uma mudança por migration, com um `down()` que desfaz exatamente o `up()`.
6. Prove antes de dizer que terminou: rode `${CLAUDE_SKILL_DIR}/scripts/prova.sh .` na raiz do projeto (não precisa ler o script). Ele roda migrate, rollback de um passo e migrate de novo no banco de desenvolvimento e imprime só o resumo. Saiu `prova: FALHOU`? Corrija e rode de novo. Não diga que terminou sem ver `prova: ok`. Criou duas migrations (a nullable e a do NOT NULL)? A prova desfaz só a última: confira a anterior com `migrate:rollback --step=2` e `migrate` de novo.

Só se o projeto não for Laravel (Prisma, Rails, Django, Alembic): os comandos equivalentes estão em [references/stacks.md](references/stacks.md). O `prova.sh` detecta a stack sozinho.
