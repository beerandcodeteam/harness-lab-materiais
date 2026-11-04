<?php

use App\Http\Controllers\CadastroController;
use App\Http\Controllers\PedidoController;
use Illuminate\Support\Facades\Route;

Route::view('/cadastro', 'cadastro');
Route::post('/register', [CadastroController::class, 'store']);
Route::get('/pedidos', [PedidoController::class, 'index']);
