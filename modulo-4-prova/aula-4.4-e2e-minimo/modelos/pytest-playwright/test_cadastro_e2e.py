"""test_cadastro_e2e.py · aula 4.4 · o AC-03 do FEATURE-ALVO.md, clicando como o usuário (pytest-playwright)

Onde pôr: tests/e2e/test_cadastro_e2e.py
Instalar: pip install pytest-playwright && playwright install chromium
Rodar:    pytest (o comando da Prova)

O servidor precisa estar de pé durante o teste: o conftest.py ao lado sobe o app e
define o base_url (Django: o live_server do pytest-django).
Pendente: @pytest.mark.skip com o corpo escrito, até a fase que implementa a mensagem.
Rótulos ("E-mail", "Criar conta") são exemplo: troque pelos da sua tela.
"""
import pytest
from playwright.sync_api import Page, expect


def cadastra(page: Page, nome: str, email: str) -> None:
    page.goto("/register")
    page.get_by_label("Nome").fill(nome)
    page.get_by_label("E-mail").fill(email)
    page.get_by_label("Senha").fill("senha-forte-123")
    page.get_by_role("button", name="Criar conta").click()


@pytest.mark.skip(reason="AC-03 · pendente")
def test_ac03_mostra_a_mensagem_abaixo_do_campo(page: Page):
    # Erro de JavaScript na página. Não use console error inteiro: o navegador registra
    # "Failed to load resource ... 422" quando o app responde 422 à validação.
    erros = []
    page.on("pageerror", lambda erro: erros.append(str(erro)))

    cadastra(page, "Ana Souza", "ana@exemplo.com")
    cadastra(page, "Ana de novo", "Ana@Exemplo.com")

    expect(page.get_by_text("Este e-mail já está cadastrado")).to_be_visible()
    assert erros == []
