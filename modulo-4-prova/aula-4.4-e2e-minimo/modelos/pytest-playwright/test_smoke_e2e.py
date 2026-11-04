"""test_smoke_e2e.py · aula 4.4 · o comando da Prova consegue abrir um navegador? (pytest-playwright)

Onde pôr: tests/e2e/test_smoke_e2e.py
Fica ATIVO, sem marcador. O E2E da feature nasce pendente, e teste pendente não abre
o navegador: sem este smoke, a Prova fica verde mesmo sem Chromium no ambiente.

Precisa do app de pé durante o pytest, e o pytest-playwright não sobe servidor: o
conftest.py ao lado sobe o app e define o base_url (no Django, o live_server do
pytest-django). Com o app fora do ar, o erro é "net::ERR_CONNECTION_REFUSED".
Rode pelo comando da Prova (pytest), na mesma máquina ou container.
"""
from playwright.sync_api import Page


def test_a_home_abre_sem_erro_de_javascript(page: Page):
    # Só erro de JavaScript. O console também registra "Failed to load resource" de
    # qualquer 4xx, que não é defeito da página.
    erros = []
    page.on("pageerror", lambda erro: erros.append(str(erro)))

    resposta = page.goto("/")

    assert resposta is not None and resposta.ok
    assert erros == []
