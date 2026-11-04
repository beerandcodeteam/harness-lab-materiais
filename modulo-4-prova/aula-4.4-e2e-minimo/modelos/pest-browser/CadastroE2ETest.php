<?php

// CadastroE2ETest.php · aula 4.4 · o AC-03 do FEATURE-ALVO.md, clicando como o usuário.
//
// Onde pôr: tests/Browser/CadastroE2ETest.php
// Um fluxo só: abre o cadastro, preenche com um e-mail que já existe em outra
// caixa, envia e confere a mensagem e o console. Fica com ->todo() até a fase que
// implementa a mensagem; o loop só tira o marcador.
//
// Os rótulos ('Create account') são os do starter kit do Laravel em inglês.
// Troque pelos da sua tela.

use App\Models\User;

it('AC-03 · mostra "Este e-mail já está cadastrado" abaixo do campo, no navegador', function () {
    User::factory()->create(['email' => 'ana@exemplo.com']);

    visit('/register')
        ->type('name', 'Ana Souza')
        ->type('email', 'Ana@Exemplo.com')
        ->type('password', 'senha-forte-123')
        ->type('password_confirmation', 'senha-forte-123')
        ->press('Create account')
        ->assertSee('Este e-mail já está cadastrado')
        ->assertNoSmoke();

    expect(User::count())->toBe(1);
})->todo();
