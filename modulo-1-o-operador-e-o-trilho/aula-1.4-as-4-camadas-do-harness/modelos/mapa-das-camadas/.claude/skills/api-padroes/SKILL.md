---
name: api-padroes
description: Padrões de resposta e erro da API. Use ao criar ou mudar um endpoint.
---

<!-- Só o name e a description acima entram em toda chamada. O corpo entra quando ele usa a skill. -->

# Padrões da API

- Toda resposta: `{ data, meta }`.
- Erro de validação: 422 com `{ errors }`.
- Paginação: `?page` e `?per_page`, máximo 100.
