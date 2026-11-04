<?php

// CadastroApiE2ETest.php · aula 4.4 · ponta a ponta de API: chama a rota e confere a resposta e o banco.
//
// Onde pôr: tests/Feature/CadastroApiE2ETest.php
// A rota /api/register e os campos são exemplo: troque pelos da sua API.
// Fica com ->todo() até a fase que implementa a regra. Se a sua API já recusa, tire o
// marcador uma vez: passou, o comportamento já existe e o teste fica ativo.
//
// Limite: como todo HTTP test do Laravel, a requisição é simulada por dentro do framework.
// Não sobe servidor nem passa por proxy, fila real ou API de fora.

use App\Models\User;

it('AC-02 · recusa e-mail que já existe com outra caixa e não cria usuário', function () {
    User::factory()->create(['email' => 'ana@exemplo.com']);

    $this->postJson('/api/register', [
        'name' => 'Ana Souza',
        'email' => 'ANA@exemplo.com',
        'password' => 'senha-forte-123',
        'password_confirmation' => 'senha-forte-123',
    ])
        ->assertStatus(422)
        ->assertJsonValidationErrors('email');

    expect(User::count())->toBe(1);
})->todo();
