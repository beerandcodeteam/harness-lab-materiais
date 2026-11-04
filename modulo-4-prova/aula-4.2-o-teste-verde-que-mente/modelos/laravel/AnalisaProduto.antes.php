<?php

// Reconstrução didática do caso da aula 4.2 (não é o código do projeto original).
// Copie para app/Ai/Agents/AnalisaProduto.php para ver o SchemaEstritoTest vermelho.
// O erro: ->nullable() sem ->required(). Para o builder, o campo fica fora do
// "required"; para a OpenAI em modo strict, o schema inteiro é inválido (HTTP 400).

namespace App\Ai\Agents;

use Illuminate\Contracts\JsonSchema\JsonSchema;
use Laravel\Ai\Attributes\Strict;
use Laravel\Ai\Contracts\Agent;
use Laravel\Ai\Contracts\HasStructuredOutput;
use Laravel\Ai\Promptable;
use Stringable;

#[Strict]
class AnalisaProduto implements Agent, HasStructuredOutput
{
    use Promptable;

    public function instructions(): Stringable|string
    {
        return 'Analise o produto pedido e diga se vale a pena comprar.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'product' => $schema->object(fn (JsonSchema $s) => [
                'name' => $s->string()->nullable(),
                'category' => $s->string()->nullable(),
                'estimated_price_range' => $s->string()->nullable(),
            ])->required(),
            'summary' => $schema->string()->required(),
            'similar_products' => $schema->array()
                ->max(5)
                ->items($schema->object(fn (JsonSchema $s) => [
                    'name' => $s->string()->required(),
                    'reason' => $s->string()->nullable(),
                ]))
                ->required(),
            'recommendation' => $schema->object(fn (JsonSchema $s) => [
                'decision' => $s->string()
                    ->enum(['buy', 'wait_for_offer', 'do_not_buy'])
                    ->nullable(),
                'reason' => $s->string()->required(),
            ])->nullable(),
        ];
    }
}
