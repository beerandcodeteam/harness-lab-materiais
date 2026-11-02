<?php

namespace App\Http\Controllers;

use App\Models\Pedido;

class PedidoController extends Controller
{
    public function show(Pedido $pedido)
    {
        return view('pedidos.show', ['pedido' => $pedido->load('itens')]);
    }
}
