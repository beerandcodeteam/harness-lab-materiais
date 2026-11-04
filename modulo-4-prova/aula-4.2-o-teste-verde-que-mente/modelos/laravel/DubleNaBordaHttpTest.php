<?php

// DubleNaBordaHttpTest.php · aula 4.2 · o dublê na borda HTTP, com a forma real.
//
// O Http::fake() troca só a rede. O resto é o caminho de produção: o laravel/ai
// monta o pedido, manda pelo cliente HTTP do Laravel e lê uma resposta com a
// forma que a OpenAI devolve. O dublê da interface escrito à mão e o
// AnalisaProduto::fake() do SDK pulam esse caminho inteiro.
//
// Duas respostas, de origens diferentes:
// - a gravada, em tests/Fixtures/openai/gravada/analisa-produto.json: o
//   SmokeOpenAiTest.php grava ali a resposta crua de uma chamada real. Ela dá
//   a forma e as chaves que o provedor manda de verdade. A do repositório é
//   reconstrução: rode o smoke uma vez com chave e ele troca pela real.
// - a de borda: a mesma gravada, com o pior caso injetado à mão neste arquivo
//   (respostaDeBorda): texto maior que a coluna e null nos campos nullable.
//   Uma chamada real não garante o pior caso; você o escreve sobre a forma real.
//   O smoke nunca mexe nela, então rodar o smoke não muda o que este teste prova.
//
// Não confere o "required" do schema: isso é o SchemaEstritoTest.php. Os dois
// juntos cobrem o que saiu (o pedido) e o que voltou (a resposta).
//
// Onde pôr: tests/Feature/Ai/DubleNaBordaHttpTest.php
// O que trocar: as linhas marcadas com "troque".

use App\Ai\Agents\AnalisaProduto;
use Illuminate\Http\Client\Request;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;

beforeEach(function () {
    config(['ai.providers.openai.key' => 'chave-falsa-de-teste']);
    Http::preventStrayRequests();
});

/**
 * O corpo HTTP que o SmokeOpenAiTest.php gravou de uma chamada real.
 *
 * @return array<string, mixed>
 */
function respostaGravada(): array
{
    $arquivo = base_path('tests/Fixtures/openai/gravada/analisa-produto.json');

    return json_decode(file_get_contents($arquivo), true, flags: JSON_THROW_ON_ERROR);
}

/**
 * A gravada com o pior caso escrito à mão dentro do JSON que o modelo devolveu.
 *
 * @return array<string, mixed>
 */
function respostaDeBorda(): array
{
    $corpo = respostaGravada();
    $ultima = array_key_last($corpo['output']); // o laravel/ai lê o texto da última saída
    $saida = json_decode($corpo['output'][$ultima]['content'][0]['text'], true, flags: JSON_THROW_ON_ERROR);

    // troque pelos campos do seu agente: um texto maior que a coluna onde ele
    // vai parar e null em cada campo ->nullable() que o app usa
    $saida['product']['estimated_price_range'] = str_repeat('R$ 1.299 a R$ 1.799 na loja oficial; ', 4);
    $saida['product']['category'] = null;
    $saida['recommendation']['decision'] = null;
    $saida['similar_products'][0] = ['name' => 'Fone ABC Max', 'reason' => null];

    $corpo['output'][$ultima]['content'][0]['text'] = json_encode($saida, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);

    return $corpo;
}

it('monta o pedido pelo SDK e lê a resposta gravada', function () {
    Http::fake(['api.openai.com/*' => Http::response(respostaGravada())]);

    // troque pela chamada do seu app que usa o agente
    $resposta = AnalisaProduto::make()->prompt('Vale a pena comprar o fone XYZ Pro 2?');

    Http::assertSent(fn (Request $pedido) => $pedido['text']['format']['type'] === 'json_schema');

    // a forma real: as chaves que o provedor manda de verdade
    expect($resposta->structured)
        ->toHaveKeys(['product', 'summary', 'similar_products', 'recommendation']);
});

it('aguenta a borda: texto maior que a coluna e null nos campos nullable', function () {
    Http::fake(['api.openai.com/*' => Http::response(respostaDeBorda())]);

    // troque pela chamada do seu app que usa o agente e grava o resultado
    $resposta = AnalisaProduto::make()->prompt('Vale a pena comprar o fone XYZ Pro 2?');

    // troque pelo que o seu app faz com a resposta: gravar no banco é onde a
    // coluna curta estoura com o texto longo, e o lookup quebra com o null
    expect(mb_strlen($resposta['product']['estimated_price_range']))->toBeGreaterThan(100)
        ->and($resposta['product']['category'])->toBeNull()
        ->and($resposta['recommendation']['decision'])->toBeNull();
});

it('deixa o erro real da OpenAI chegar ao app', function () {
    Http::fake(['api.openai.com/*' => Http::response([
        'error' => ['message' => "Invalid schema for response_format 'schema_definition'"],
    ], 400)]);

    // troque pelo comportamento do seu app diante do 400: mensagem amigável,
    // análise marcada como falha, nada de tela 500
    expect(fn () => AnalisaProduto::make()->prompt('Vale a pena comprar o fone XYZ Pro 2?'))
        ->toThrow(RequestException::class);
});
