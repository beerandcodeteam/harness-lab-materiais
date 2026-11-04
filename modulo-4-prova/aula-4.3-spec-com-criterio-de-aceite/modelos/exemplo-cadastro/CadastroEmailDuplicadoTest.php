<?php

// CadastroEmailDuplicadoTest.php · aula 4.3 · um teste por critério do FEATURE-ALVO.md
//
// Onde pôr: tests/Feature/CadastroEmailDuplicadoTest.php
// Ativo: o comportamento já existe e o teste fica verde hoje (AC-01, AC-04).
// Pendente: o comportamento é novo; o corpo está escrito e o ->todo() segura o
// teste até a fase que implementa o critério (AC-02, AC-03). O loop só tira o marcador.
//
// POST /register com name, email, password e password_confirmation: é o formato dos
// starter kits do Laravel (Fortify). Se o seu cadastro usa outra rota ou outro campo, troque aqui.

use App\Models\User;
use Illuminate\Support\Facades\DB;

beforeEach(function () {
    User::factory()->create(['email' => 'ana@exemplo.com']);
});

function dadosDoCadastro(string $email): array
{
    return [
        'name' => 'Ana Souza',
        'email' => $email,
        'password' => 'senha-forte-123',
        'password_confirmation' => 'senha-forte-123',
    ];
}

it('AC-01 · recusa e-mail que já existe e não cria usuário', function () {
    $this->post('/register', dadosDoCadastro('ana@exemplo.com'))
        ->assertSessionHasErrors('email');

    expect(User::count())->toBe(1);
    $this->assertGuest();
});

it('AC-02 · recusa o mesmo e-mail com outra caixa', function () {
    $this->post('/register', dadosDoCadastro('Ana@Exemplo.com'))
        ->assertSessionHasErrors('email');

    expect(DB::table('users')->whereRaw('LOWER(email) = ?', ['ana@exemplo.com'])->count())->toBe(1);
    $this->assertGuest();
})->todo();

it('AC-03 · mostra "Este e-mail já está cadastrado" no campo de e-mail', function () {
    $this->post('/register', dadosDoCadastro('ana@exemplo.com'))
        ->assertSessionHasErrors(['email' => 'Este e-mail já está cadastrado']);
})->todo();

it('AC-04 · cadastra e-mail novo e entra logado, como antes', function () {
    $this->post('/register', dadosDoCadastro('bruno@exemplo.com'))
        ->assertSessionHasNoErrors();

    expect(User::where('email', 'bruno@exemplo.com')->count())->toBe(1);
    $this->assertAuthenticated();
});
