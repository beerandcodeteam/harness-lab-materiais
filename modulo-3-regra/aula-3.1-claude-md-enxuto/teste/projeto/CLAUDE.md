# CLAUDE.md

Este arquivo dá orientação ao Claude Code ao trabalhar com o código deste repositório.

## Visão geral

Loja é uma aplicação Laravel 12 com Livewire 3 e Pest. O Laravel usa MVC.
Models ficam em app/Models e controllers em app/Http/Controllers.
As views ficam em resources/views.

## Estrutura de pastas

```
app/
├── Actions/
├── Http/
│   └── Controllers/
├── Models/
└── Providers/
database/
├── factories/
└── migrations/
resources/
└── views/
```

## Comandos

- Tudo via Sail: ./vendor/bin/sail artisan ...
- Um teste: ./vendor/bin/sail artisan test --filter=Nome
- Lint do que mudou: ./vendor/bin/sail bin pint --dirty

## Estilo

- Use 4 espaços de indentação.
- Use aspas simples nas strings.
- Siga a PSR-12.

## Regras gerais

- Escreva código limpo e siga as boas práticas.
- Escreva testes para tudo.
- IMPORTANTE!!! SEMPRE rode os testes antes de terminar!!!
- NUNCA rode migrate:fresh.
- Regra de negócio em app/Actions, uma classe por caso de uso.
- Dinheiro em centavos (int).

## Erros cometidos

- Cuidado com datas, já deu problema.
- Dia 12/09 o agente quebrou o relatório de vendas porque converteu o horário
  no model, aí eu tive que corrigir na mão e depois revisar tudo.

## Criar um módulo novo

1. Crie a pasta em modules/.
2. Crie o service provider.
3. Registre o provider em bootstrap/providers.php.
4. Crie a migration.
5. Crie o model.
6. Crie a factory.
7. Crie a Action.
8. Crie o componente Livewire.
9. Crie o teste Pest.
10. Rode o pint.

## Nesta sprint

- Não mexa no checkout.
