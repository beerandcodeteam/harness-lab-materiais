<?php

// SmokeOpenAiTest.php · aula 4.2 · uma chamada real, fora do juiz.
//
// Chama a OpenAI de verdade, com a chave do seu .env, e confere o contrato
// que importa: o pedido foi aceito (nada de 400) e voltaram todas as chaves.
// De quebra, grava a resposta crua em tests/Fixtures/openai/gravada/: é a
// forma real que o DubleNaBordaHttpTest.php serve à suíte padrão.
//
// Só a gravada é sobrescrita. O pior caso (texto longo, null) fica escrito à
// mão no DubleNaBordaHttpTest.php, porque uma chamada real não garante que ele
// venha. Antes de commitar, olhe o git diff de tests/Fixtures: chave nova ou
// sumida na resposta do provedor aparece ali.
//
// Grupo integration: tire o grupo do comando do juiz no phpunit.xml
// (<groups><exclude><group>integration</group></exclude></groups>) e rode
// à parte, antes do PR ou depois de atualizar o SDK:
//   php artisan test --group=integration
// Sem OPENAI_API_KEY o teste é pulado, não quebra.
//
// Onde pôr: tests/Feature/Ai/SmokeOpenAiTest.php
// O que trocar: o agente, o pedido e as chaves esperadas.

use App\Ai\Agents\AnalisaProduto;

it('a OpenAI aceita o pedido e devolve todas as chaves', function () {
    $resposta = AnalisaProduto::make()->prompt('Vale a pena comprar um fone Bluetooth de R$ 200?');

    expect($resposta->structured)
        ->toHaveKeys(['product', 'summary', 'similar_products', 'recommendation']);

    $destino = base_path('tests/Fixtures/openai/gravada/analisa-produto.json');
    @mkdir(dirname($destino), 0755, true);
    file_put_contents($destino, json_encode($resposta->raw->json(),
        JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES).PHP_EOL);
})
    ->group('integration')
    ->skip(fn () => blank(config('ai.providers.openai.key')), 'sem OPENAI_API_KEY: smoke real pulado');
