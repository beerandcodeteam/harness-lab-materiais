---
paths:
  - "database/migrations/**"
---

# Migrations

- Migration que já foi para produção não muda: crie uma nova.
- Coluna nova em tabela grande: nullable primeiro, backfill em job, depois o NOT NULL.
  (Lock de 4 min na tabela de pedidos.)
