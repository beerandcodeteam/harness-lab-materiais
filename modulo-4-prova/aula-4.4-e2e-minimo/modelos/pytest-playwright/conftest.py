"""conftest.py · aula 4.4 · o próprio pytest sobe o app, como o webServer do Playwright Test (Node)

Onde pôr: tests/e2e/conftest.py, na pasta do smoke e do E2E (só os testes dela sobem o app).
O pytest-playwright não sobe servidor. Sem esta fixture, o comando da Prova (pytest) roda
com o app fora do ar e o smoke cai em "net::ERR_CONNECTION_REFUSED"; ou passa contra o app
que ficou aberto em outro terminal, com o código velho.

FastAPI, Flask e outros: troque COMANDO e PORTA pelos do seu app. A fixture sobe o app,
espera a porta abrir, entrega a URL ao page.goto("/") e derruba o app no fim da sessão.
Teste pendente (@pytest.mark.skip) não pede a fixture: não sobe nada.

Django: apague o resto deste arquivo e use o live_server do pytest-django
(pip install pytest-django), que roda o app numa thread do próprio pytest. Aí o mock
do teste chega ao app, porque é o mesmo processo.

    import os
    import pytest

    # Só no teste. O Playwright síncrono roda um event loop, e sem isto o Django
    # recusa o banco: "SynchronousOnlyOperation: You cannot call this from an async context"
    os.environ.setdefault("DJANGO_ALLOW_ASYNC_UNSAFE", "true")

    @pytest.fixture(scope="session")
    def base_url(live_server):
        return live_server.url

O escopo tem que ser "session": o pytest-playwright pede o base_url numa fixture de sessão.
Sem ele, o pytest para com "ScopeMismatch".
"""
import os
import socket
import subprocess
import sys
import time

import pytest

PORTA = 8001  # só do teste: diferente da porta do app que você deixa aberto
COMANDO = [sys.executable, "-m", "uvicorn", "app.main:app", "--port", str(PORTA)]
# Flask: [sys.executable, "-m", "flask", "--app", "app", "run", "--port", str(PORTA)]

# O app roda em outro processo: mock dentro do teste não chega lá. O serviço de fora vira
# fake pela configuração do app, aqui (ex.: a URL do provedor apontando para um dublê).
AMBIENTE = {}


def porta_aberta(porta):
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", porta)) == 0


@pytest.fixture(scope="session")
def base_url():
    if porta_aberta(PORTA):
        raise RuntimeError(f"a porta {PORTA} já está em uso: feche o app antigo ou troque a PORTA")
    app = subprocess.Popen(COMANDO, env={**os.environ, **AMBIENTE})
    try:
        limite = time.monotonic() + 30
        while not porta_aberta(PORTA):
            if app.poll() is not None:
                raise RuntimeError(f"o app saiu antes de abrir a porta {PORTA} (exit {app.returncode})")
            if time.monotonic() > limite:
                raise RuntimeError(f"o app não abriu a porta {PORTA} em 30 s")
            time.sleep(0.2)
        yield f"http://127.0.0.1:{PORTA}"
    finally:
        app.terminate()
        try:
            app.wait(timeout=10)
        except subprocess.TimeoutExpired:
            app.kill()
