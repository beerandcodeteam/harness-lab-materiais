<?php

namespace App\Services;

class Carrinho
{
    public function desconto(float $total): float
    {
        return $total * 0.10;
    }
}
