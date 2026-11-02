# O esqueleto enxuto em outras stacks (aula 3.1)

Os quatro blocos são os mesmos do `CLAUDE.md.exemplo` (Laravel): **Comandos, Decisões, Erros que
já aconteceram, Onde procurar**. Muda o conteúdo, não os blocos. Os exemplos abaixo são
ilustrativos: troque pelo que é verdade no seu projeto e apague o que não for.

## Node / Next.js

```markdown
# Painel · Next.js 15 + Prisma + Vitest

## Comandos
- Instalar: `pnpm install` (npm e yarn quebram o lockfile)
- Um teste: `pnpm vitest run caminho/do/arquivo.test.ts`
- Tipos: `pnpm tsc --noEmit`

## Decisões
- Acesso ao banco só em `src/server/`; componente de cliente não importa Prisma.
- Erros com os helpers de `src/lib/errors.ts`, nunca `throw` de string.

## Erros que já aconteceram
- Migration nova: `pnpm prisma migrate dev --name x`, não `db push`.
  (`db push` não gera arquivo e o deploy subiu sem a coluna.)

## Onde procurar
- Variáveis de ambiente: `.env.example`, antes de criar uma nova.
```

## Python / Django

```markdown
# Agenda · Django 5 + pytest + uv

## Comandos
- Tudo com uv: `uv run python manage.py ...`
- Um teste: `uv run pytest caminho/test_x.py -k nome`
- Lint do que mudou: `uv run ruff check --fix caminho`

## Decisões
- Regra de negócio em `services/`, view só orquestra.
- Datas com `django.utils.timezone.now()`, nunca `datetime.now()`.

## Erros que já aconteceram
- Teste que toca o banco leva `@pytest.mark.django_db`.
  (Sem a marca, o teste passou local e quebrou no CI com banco vazio.)

## Onde procurar
- Decisões de arquitetura: `docs/adr/`.
```

## Ruby / Rails

```markdown
# Loja · Rails 8 + RSpec

## Comandos
- Tudo no container: `docker compose exec web bin/rails ...`
- Um teste: `docker compose exec web bundle exec rspec spec/x_spec.rb:42`
- Lint do que mudou: `docker compose exec web bundle exec rubocop -a caminho`

## Decisões
- Regra de negócio em `app/services`, um objeto por caso de uso.
- Dinheiro com a gem money-rails, em centavos.

## Erros que já aconteceram
- Job novo: teste com `perform_enqueued_jobs`, não chamando `perform` direto.
  (Chamar direto escondeu um erro de serialização do argumento.)

## Onde procurar
- Contrato da API: `docs/openapi.yaml`.
```

## O que não entra em nenhuma delas

Estilo (é lint), "nunca rode X" (é hook ou deny), passo a passo longo (é skill), explicação de
como o framework funciona (ele já sabe) e mapa de pastas (ele roda `ls`).
