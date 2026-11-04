<?php

// CadastroHttpE2ETest.php · aula 4.4 · plano B: o mesmo fluxo do AC-03, sem navegador.
//
// Onde pôr: tests/Feature/CadastroHttpE2ETest.php
// Use quando o Pest browser não roda no comando da Prova (por exemplo, dentro do Sail sem
// o navegador no container) ou quando a feature é só API.
//
// Limite: o HTTP test do Laravel não sobe servidor nem roda JavaScript. A requisição é
// simulada por dentro do framework. Ele vê o HTML que o servidor devolve; não vê o que
// o navegador faz com ele.

use App\Models\User;

it('AC-03 · cadastro recusado volta para a tela com "Este e-mail já está cadastrado"', function () {
    User::factory()->create(['email' => 'ana@exemplo.com']);

    $this->from('/register')
        ->followingRedirects()
        ->post('/register', [
            'name' => 'Ana Souza',
            'email' => 'Ana@Exemplo.com',
            'password' => 'senha-forte-123',
            'password_confirmation' => 'senha-forte-123',
        ])
        ->assertOk()
        ->assertSee('Este e-mail já está cadastrado');

    expect(User::count())->toBe(1);
    $this->assertGuest();
})->todo();
