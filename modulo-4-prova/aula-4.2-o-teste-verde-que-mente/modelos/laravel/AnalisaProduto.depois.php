<?php

// Reconstrução didática do caso da aula 4.2, já corrigida.
// Copie para app/Ai/Agents/AnalisaProduto.php para ver o SchemaEstritoTest verde.
// A correção: todo campo leva ->required(). Nullable continua nullable: o modelo
// pode devolver null, mas a chave precisa estar no "required".

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
                'name' => $s->string()->nullable()->required(),
                'category' => $s->string()->nullable()->required(),
                'estimated_price_range' => $s->string()->nullable()->required(),
            ])->required(),
            'summary' => $schema->string()->required(),
            'similar_products' => $schema->array()
                ->max(5)
                ->items($schema->object(fn (JsonSchema $s) => [
                    'name' => $s->string()->required(),
                    'reason' => $s->string()->nullable()->required(),
                ]))
                ->required(),
            'recommendation' => $schema->object(fn (JsonSchema $s) => [
                'decision' => $s->string()
                    ->enum(['buy', 'wait_for_offer', 'do_not_buy'])
                    ->nullable()
                    ->required(),
                'reason' => $s->string()->required(),
            ])->nullable()->required(),
        ];
    }
}
