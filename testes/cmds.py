"""Extrai os blocos de comando (.cmd) de um material, na ordem do documento."""
from html.parser import HTMLParser


class _P(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.blocos, self.pilha, self.atual, self.no_pre = [], [], None, False

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == "div":
            eh = "cmd" in (a.get("class") or "").split()
            self.pilha.append(eh)
            if eh:
                self.atual = {"tipo": a.get("data-tipo", ""), "onde": a.get("data-onde", ""),
                              "fonte": a.get("data-fonte", ""), "teste": a.get("data-teste", ""),
                              "texto": ""}
        elif tag == "pre" and self.atual is not None:
            self.no_pre = True

    def handle_endtag(self, tag):
        if tag == "pre":
            self.no_pre = False
        elif tag == "div" and self.pilha:
            if self.pilha.pop() and self.atual is not None:
                linhas = self.atual.pop("texto").split("\n")
                while linhas and not linhas[-1].strip():
                    linhas.pop()
                while linhas and not linhas[0].strip():
                    linhas.pop(0)
                self.atual["linhas"] = linhas
                self.blocos.append(self.atual)
                self.atual = None

    def handle_data(self, d):
        if self.no_pre and self.atual is not None:
            self.atual["texto"] += d


def blocos(html_texto):
    p = _P()
    p.feed(html_texto)
    return p.blocos
