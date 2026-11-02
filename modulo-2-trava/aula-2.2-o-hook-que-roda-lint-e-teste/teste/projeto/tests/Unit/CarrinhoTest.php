<?php

// Teste falso da sandbox: o stub vendor/bin/pest roda este arquivo com o php.
require __DIR__.'/../../app/Services/Carrinho.php';

$valor = (new App\Services\Carrinho)->desconto(100);

if ($valor !== 10.0) {
    echo "Failed asserting that {$valor} is identical to 10.0.\n";
    exit(1);
}

echo "ok\n";
