# Os mesmos passos em outras stacks

Leia só a seção da stack do projeto. O `scripts/prova.sh` já sabe qual rodar.

## Laravel

- Criar: `php artisan make:migration add_cpf_to_clientes_table --table=clientes`
- O que já rodou: `php artisan migrate:status`
- Prova: `php artisan migrate`, `php artisan migrate:rollback --step=1`, `php artisan migrate`
- Com Sail: `./vendor/bin/sail artisan ...` no lugar de `php artisan ...`

## Rails

- Criar: `bin/rails generate migration AddCpfToClientes cpf:string`
- O que já rodou: `bin/rails db:migrate:status`
- Prova: `bin/rails db:migrate`, `bin/rails db:rollback STEP=1`, `bin/rails db:migrate`
- Índice em tabela grande no PostgreSQL: `algorithm: :concurrently` e `disable_ddl_transaction!` na migration, porque `CREATE INDEX CONCURRENTLY` não roda dentro de transação.

## Prisma

- Criar sem aplicar, para revisar o SQL: `npx prisma migrate dev --create-only --name add_cpf`
- Aplicar em desenvolvimento: `npx prisma migrate dev`
- O que já rodou: `npx prisma migrate status`
- Não existe rollback automático. A prova do `prova.sh` é `npx prisma migrate deploy` (aplica as pendentes, sem perguntar nada e sem criar migration) e `npx prisma migrate status` em dia. Por isso crie a migration antes, com `--create-only`. Para desfazer, escreva uma migration nova.
- `migrate dev` é interativo: sem terminal (a ferramenta Bash do Claude Code não tem), ele falha quando precisa perguntar um nome ou um reset, e cria migration nova se o schema mudou.
- Produção também roda `npx prisma migrate deploy`, nunca `migrate dev` nem `migrate reset`.

## Django

- Criar: `python manage.py makemigrations <app>`
- O que já rodou: `python manage.py showmigrations <app>`
- Prova: `python manage.py migrate` e `python manage.py makemigrations --check --dry-run` (sai com erro se faltou migration).
- Desfazer até uma migration anterior: `python manage.py migrate <app> <migration_anterior>`

## Alembic (SQLAlchemy)

- Criar: `alembic revision -m "add cpf em clientes"` (ou `--autogenerate`, e revise o arquivo)
- O que já rodou: `alembic current` e `alembic history`
- Prova: `alembic upgrade head`, `alembic downgrade -1`, `alembic upgrade head`
