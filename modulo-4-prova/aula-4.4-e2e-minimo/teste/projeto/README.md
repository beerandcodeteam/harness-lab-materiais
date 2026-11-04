# Projeto falso · sandbox da aula 4.4

Não é um app. É a forma de um projeto Laravel com Pest, Sail e o Pest browser, no estado em que
fica depois dos comandos de stack (`composer require pestphp/pest-plugin-browser --dev`,
`npm install playwright@latest`) e do pedido do ambiente (`tests/Browser` no `phpunit.xml` e no
`tests/Pest.php`). Esses passos não rodam na sandbox: dependem do projeto real e do Claude.

A sandbox do `validar.py` copia esta pasta para `~/projeto`, roda os comandos do PDF (clone,
`instalar.sh 4.4`, a cópia do smoke e o `confere-e2e.py`) e depois o `teste/verificar.sh`.
