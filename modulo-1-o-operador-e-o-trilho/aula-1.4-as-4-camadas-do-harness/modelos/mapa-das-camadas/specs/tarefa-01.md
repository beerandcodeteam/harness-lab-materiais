## Tarefa 01 · listar produtos ativos

### Critérios de aceite

1. GET /api/produtos retorna só os ativos
2. Sem login → 401
3. Resposta no formato { data, meta }

Cada critério vira um teste em tests/Feature/ProdutosTest.php.
