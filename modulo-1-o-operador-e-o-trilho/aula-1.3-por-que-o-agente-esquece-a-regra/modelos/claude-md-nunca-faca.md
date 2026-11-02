# Trecho de CLAUDE.md: a regra dura da demo da aula 1.3

Para ler e adaptar, não é instalado. É a regra que o Claude recitou na demo, escrita do
jeito que a documentação pede: concreta, verificável, curta e no topo do arquivo.

Leia o aviso antes de copiar: **isto é um pedido, não uma trava.** O CLAUDE.md entra no
contexto como texto. A documentação oficial diz que o Claude o trata "as context, not
enforced configuration" e manda usar um hook `PreToolUse` para bloquear uma ação "regardless
of what Claude decides" (página Memory). A cancela de verdade para este comando é a aula 2.3.

Por que ainda vale ter a regra escrita: ela explica o porquê e o caminho certo. Quando o
hook da 2.3 barrar o comando, o modelo já sabe o que fazer em vez de procurar um atalho.

---

```markdown
## Nunca faça

- NUNCA rode `php artisan migrate:fresh`. Ele apaga todas as tabelas e os dados do banco.
  O mesmo vale para `migrate:reset`, `migrate:refresh`, `migrate:rollback`, `db:wipe`,
  `db:seed` em banco que já tem dados e qualquer SQL destrutivo (`DROP`, `TRUNCATE`,
  `DELETE` sem `WHERE`). Proibido em qualquer ambiente, com ou sem `--seed`, sem o meu OK
  explícito na conversa.
- Não use atalho de mesmo efeito: apagar o arquivo do SQLite, trocar `DB_DATABASE` no
  `.env` ou rodar o comando por dentro de um script.
- O único comando de migration liberado é `php artisan migrate`: só para frente, só no
  ambiente local.
- Se algo parecer exigir banco limpo (migration quebrada, teste falhando, "banco
  inconsistente"), PARE e me pergunte. Mostre o erro e a migration envolvida.
```

---

## Equivalentes em outras stacks

Troque os comandos da primeira linha pelos da sua stack. A estrutura é a mesma.

| Stack | Derruba e recria o banco | Liberado |
| --- | --- | --- |
| Laravel | `php artisan migrate:fresh`, `migrate:reset`, `migrate:refresh`, `db:wipe` | `php artisan migrate` |
| Node + Prisma | `npx prisma migrate reset`, `npx prisma db push --force-reset` | `npx prisma migrate dev` (local; se ele propuser reset, recuse) |
| Rails | `rails db:reset`, `rails db:drop`, `rails db:schema:load` | `rails db:migrate` |
| Django | `python manage.py flush`, `migrate <app> zero` | `python manage.py migrate` |

## Como conferir que ele sabe a regra (o teste da aula)

```bash
grep -n "migrate:fresh" CLAUDE.md
```

E, numa sessão nova: `Qual a regra sobre usar migrate:fresh neste projeto?`

Ele recitar a regra prova só que ela está no contexto. Não prova que ele vai cumprir no
meio de uma tarefa longa, com migration quebrando: no primeiro turno a regra costuma vencer.
