"""test_smoke_openai.py · aula 4.2 · uma chamada real, fora do juiz (pytest).

Chama o provedor de verdade, pela mesma função que o seu app usa, e confere o
contrato que importa: o pedido foi aceito e voltaram todas as chaves. De
quebra, grava em tests/fixtures/openai/gravada/ o que a sua função devolveu:
a forma real da resposta, para você escrever o dublê da suíte padrão. Não é o
corpo HTTP do provedor, e o pior caso (texto longo, null) não vem garantido
numa chamada real: escreva-o à mão no dublê, sobre essa forma.

Este repositório não traz o dublê em Python. O equivalente ao Http::fake() do
Laravel troca só a rede: respx para quem chama o provedor com httpx. O
openai-python 3.x usa HTTPX2, que o respx não intercepta (testado com openai
3.44.0 e respx 0.23.1); para qualquer versão do SDK, sirva o corpo gravado num
servidor local e aponte OPENAI_BASE_URL para ele. O corpo HTTP que o smoke do
Laravel grava (modelos/laravel/gravada/) tem a forma da Responses API.

Marcador integration: o pyproject tira o marcador do comando do juiz (ver
pyproject-integration.toml). Rode à parte, antes do PR ou depois de atualizar
o SDK:  pytest -m integration
Sem OPENAI_API_KEY o teste é pulado, não quebra.

Onde pôr: tests/test_smoke_openai.py
O que trocar: o import dentro do teste, o pedido e as chaves esperadas.
"""
import json
import os
from pathlib import Path

import pytest

pytestmark = pytest.mark.integration

GRAVADA = Path(__file__).parent / "fixtures" / "openai" / "gravada" / "analisa-produto.json"


@pytest.mark.skipif(not os.environ.get("OPENAI_API_KEY"), reason="sem OPENAI_API_KEY: smoke real pulado")
def test_provedor_aceita_o_pedido_e_devolve_todas_as_chaves():
    # O import fica aqui dentro: o pytest importa o arquivo mesmo com o marcador
    # fora, e um import que falha no topo derruba a coleta da suíte inteira.
    from app.analise import analisa_produto  # troque pelo seu módulo

    resposta = analisa_produto("Vale a pena comprar um fone Bluetooth de R$ 200?")

    assert {"product", "summary", "similar_products", "recommendation"} <= set(resposta)

    GRAVADA.parent.mkdir(parents=True, exist_ok=True)
    GRAVADA.write_text(json.dumps(resposta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
