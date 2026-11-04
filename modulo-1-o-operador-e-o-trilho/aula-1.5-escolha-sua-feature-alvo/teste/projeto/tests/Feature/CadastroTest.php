<?php

use App\Models\User;

it('cria o usuário com e-mail novo', function () {
    $this->post('/register', [
        'name' => 'Ana',
        'email' => 'ana@exemplo.com',
        'password' => 'segredo123',
        'password_confirmation' => 'segredo123',
    ])->assertRedirect('/painel');

    expect(User::where('email', 'ana@exemplo.com')->count())->toBe(1);
});
