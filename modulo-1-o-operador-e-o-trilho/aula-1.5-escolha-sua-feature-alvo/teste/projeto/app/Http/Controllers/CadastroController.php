<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;

class CadastroController extends Controller
{
    public function store(Request $request)
    {
        // FIXME: Ana@Exemplo.com passa como e-mail novo se já existe ana@exemplo.com
        $dados = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'unique:users,email'],
            'password' => ['required', 'confirmed', 'min:8'],
        ]);

        $user = User::create($dados);
        auth()->login($user);

        return redirect('/painel');
    }
}
