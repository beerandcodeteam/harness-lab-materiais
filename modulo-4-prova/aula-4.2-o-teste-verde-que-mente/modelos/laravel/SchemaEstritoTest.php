<?php

// SchemaEstritoTest.php · aula 4.2 · contrato do schema que sai para a OpenAI, sem rede.
//
// Monta o schema pelo mesmo caminho que o laravel/ai usa antes de mandar a
// requisição (Gateway/OpenAi/Concerns/BuildsTextRequests::buildSchemaFormat:
// new ObjectSchema($agent->schema(...), strict: ...)->toSchema()) e falha se
// alguma chave de "properties" ficar fora do "required", em qualquer nível.
//
// Onde pôr: tests/Feature/Ai/SchemaEstritoTest.php
// O que trocar: a lista de agentes no dataset, pelos agentes com structured output do seu app.
// Rodar: vendor/bin/sail test --filter=SchemaEstrito   (ou php artisan test --filter=SchemaEstrito)

use App\Ai\Agents\AnalisaProduto;
use Illuminate\JsonSchema\JsonSchemaTypeFactory;
use Laravel\Ai\ObjectSchema;

/**
 * Caminhos (ex.: product.name) de cada chave de properties que não está no required.
 *
 * @param  array<string, mixed>  $no
 * @return list<string>
 */
function chavesForaDoRequired(array $no, string $caminho = ''): array
{
    $achados = [];

    foreach ($no['properties'] ?? [] as $chave => $filho) {
        $atual = $caminho === '' ? $chave : "{$caminho}.{$chave}";

        if (! in_array($chave, $no['required'] ?? [], true)) {
            $achados[] = $atual;
        }

        $achados = [...$achados, ...chavesForaDoRequired($filho, $atual)];
    }

    if (is_array($no['items'] ?? null)) {
        $achados = [...$achados, ...chavesForaDoRequired($no['items'], $caminho === '' ? '[]' : "{$caminho}[]")];
    }

    foreach ($no['anyOf'] ?? [] as $ramo) {
        $achados = [...$achados, ...chavesForaDoRequired($ramo, $caminho)];
    }

    return $achados;
}

it('manda todo campo do schema no required, em todo nível', function (string $agente) {
    $campos = app($agente)->schema(new JsonSchemaTypeFactory);

    $schema = (new ObjectSchema($campos, strict: true))->toSchema();

    expect(chavesForaDoRequired($schema))->toBe([]);
})->with([
    AnalisaProduto::class,
]);
