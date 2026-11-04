"""test_cadastro.py · aula 4.3 · um teste por critério do FEATURE-ALVO.md (pytest)

Pendente = @pytest.mark.skip com o motivo e o corpo escrito.
O loop só apaga a linha do marcador.
"""
import pytest

from cadastro import cadastrar


@pytest.fixture
def usuarios():
    return [{"nome": "Ana Souza", "email": "ana@exemplo.com"}]


def test_ac01_recusa_email_que_ja_existe(usuarios):
    r = cadastrar(usuarios, "Ana de novo", "ana@exemplo.com")

    assert r["ok"] is False
    assert len(usuarios) == 1


@pytest.mark.skip(reason="AC-02 · pendente")
def test_ac02_recusa_o_mesmo_email_com_outra_caixa(usuarios):
    r = cadastrar(usuarios, "Ana de novo", "Ana@Exemplo.com")

    assert r["ok"] is False
    assert len([u for u in usuarios if u["email"].lower() == "ana@exemplo.com"]) == 1


@pytest.mark.skip(reason="AC-03 · pendente")
def test_ac03_mostra_a_mensagem_no_campo_de_email(usuarios):
    r = cadastrar(usuarios, "Ana de novo", "ana@exemplo.com")

    assert r == {"ok": False, "erros": {"email": "Este e-mail já está cadastrado"}}


def test_ac04_cadastra_email_novo_como_antes(usuarios):
    r = cadastrar(usuarios, "Bruno Lima", "bruno@exemplo.com")

    assert r["ok"] is True
    assert "bruno@exemplo.com" in [u["email"] for u in usuarios]
