<?php

use App\Models\Produto;
use App\Models\User;

use function Pest\Laravel\actingAs;
use function Pest\Laravel\getJson;

// Critério 1
it('lista só produtos ativos', function () {
    Produto::factory()->ativo()->create();
    Produto::factory()->inativo()->create();

    actingAs(User::factory()->create())
        ->getJson('/api/produtos')
        ->assertOk()
        ->assertJsonCount(1, 'data');
});

// Critério 2
it('exige login', fn () => getJson('/api/produtos')->assertUnauthorized());

// Critério 3
it('responde no formato data e meta', function () {
    actingAs(User::factory()->create())
        ->getJson('/api/produtos')
        ->assertJsonStructure(['data', 'meta']);
});
