<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class Frete
{
    public function prazo(string $cep): int
    {
        // TODO: trocar a tabela fixa pela API dos Correios
        $resposta = Http::get('https://api.exemplo-correios.test/prazo', ['cep' => $cep]);

        return (int) $resposta->json('dias', 7);
    }
}
