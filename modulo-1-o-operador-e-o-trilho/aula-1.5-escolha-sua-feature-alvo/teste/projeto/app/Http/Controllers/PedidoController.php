<?php

namespace App\Http\Controllers;

use App\Models\Pedido;

class PedidoController extends Controller
{
    public function index()
    {
        // TODO: exportar os pedidos do mês em CSV (o financeiro pede toda semana)
        return view('pedidos.index', ['pedidos' => Pedido::latest()->paginate(20)]);
    }
}
