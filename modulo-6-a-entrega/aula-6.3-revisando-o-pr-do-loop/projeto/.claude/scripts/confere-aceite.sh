#!/usr/bin/env bash
# confere-aceite.sh · aula 6.3 · os testes de aceite saíram do loop como entraram?
#
# Uso: .claude/scripts/confere-aceite.sh [<base>] [--hook <caminho do guarda-aceite.py>]
#   <base>  commit de antes do loop. Padrão: o pai do primeiro commit feat(phase-N)
#           ou wip(phase-N) do branch (o mesmo que o revisa-loop.sh usa).
#
# Para cada arquivo listado no .claude/aceite.txt da base, compara a versão da
# base com a de HEAD. A única diferença aceita é tirar marcadores de pendente
# (Pest ->todo(), Vitest e Jest .skip, linha @pytest.mark.skip), um, alguns ou
# todos. A regex é a do hook da 4.2: este script importa MARCADORES e normaliza
# do .claude/hooks/guarda-aceite.py, para haver uma regex só.
#
# Pega o que o hook não pega: edição feita por Bash ("Rules match tool calls,
# not intent"), commit feito à mão, marcador acrescentado, arquivo apagado.
#
# Exit: 0 só marcadores saíram (ou nada mudou) · 1 achou diferença · 2 erro de uso
# Requer git e python3. Só lê.
set -euo pipefail

BASE=""
HOOK=""
while [ $# -gt 0 ]; do
  case "$1" in
    --hook) HOOK="${2:?--hook pede um caminho}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    -*) echo "opção desconhecida: $1" >&2; exit 2 ;;
    *) BASE="$1"; shift ;;
  esac
done

RAIZ=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "confere-aceite: rode dentro do repositório" >&2; exit 2; }
cd "$RAIZ"
HOOK="${HOOK:-$RAIZ/.claude/hooks/guarda-aceite.py}"
[ -f "$HOOK" ] || { echo "confere-aceite: não achei $HOOK (o hook da 4.2). Passe --hook <caminho>." >&2; exit 2; }

if [ -z "$BASE" ]; then
  intervalo=HEAD
  for principal in main master; do  # commits de fase antigos da main não contam
    if git rev-parse -q --verify "$principal" >/dev/null && [ "$(git rev-parse "$principal")" != "$(git rev-parse HEAD)" ]; then
      intervalo="$(git merge-base "$principal" HEAD)..HEAD"; break
    fi
  done
  primeiro=$(git log --reverse --format='%H %s' "$intervalo" | awk '$2 ~ /^(feat|wip)\(phase-[0-9]+\)/ {print $1; exit}')
  [ -n "$primeiro" ] || { echo "confere-aceite: nenhum commit feat(phase-N) no branch; passe a base (ex.: main)." >&2; exit 2; }
  BASE=$(git rev-parse "$primeiro^")
fi
git rev-parse --verify -q "$BASE^{commit}" >/dev/null || { echo "confere-aceite: base inválida: $BASE" >&2; exit 2; }

# -B: importar o hook não pode deixar __pycache__ em .claude/hooks/ (o git add -A do loop levaria)
exec python3 -I -B - "$HOOK" "$BASE" <<'PY'
import fnmatch, importlib.util, re, subprocess, sys

hook, base = sys.argv[1], sys.argv[2]
spec = importlib.util.spec_from_file_location("guarda_aceite", hook)
guarda = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guarda)          # só define funções; o main() do hook não roda
MARCADORES, normaliza = guarda.MARCADORES, guarda.normaliza


def falha(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def git(*args, ok=False):
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    if r.returncode != 0 and not ok:
        falha(f"confere-aceite: git {' '.join(args)} falhou: {r.stderr.strip()}")
    return r


def conteudo(ref, caminho):
    r = git("show", f"{ref}:{caminho}", ok=True)
    return r.stdout if r.returncode == 0 else None


def so_tirou_marcadores(antes, depois):
    """depois == antes com zero ou mais marcadores removidos (qualquer subconjunto)."""
    b = normaliza(antes)
    achados = []
    for rx, troca in MARCADORES:
        for m in rx.finditer(b):
            achados.append((m.start(), m.end(), m.group(0), m.expand(troca)))
    achados.sort()
    partes, pos = [], 0
    for ini, fim, com, sem in achados:
        if ini < pos:
            continue
        partes.append(re.escape(b[pos:ini]))
        partes.append(f"(?:{re.escape(com)}|{re.escape(sem)})")
        pos = fim
    partes.append(re.escape(b[pos:]))
    return re.fullmatch("".join(partes), normaliza(depois)) is not None


def marcadores(texto):
    return sum(len(rx.findall(texto)) for rx, _ in MARCADORES)


lista_base = conteudo(base, ".claude/aceite.txt")
lista_head = conteudo("HEAD", ".claude/aceite.txt")
if lista_base is None:
    falha(f"confere-aceite: a base {base[:7]} não tem .claude/aceite.txt. Os testes de aceite entram antes do loop (aulas 4.2 a 4.4).")

padroes = [l.strip() for l in lista_base.splitlines() if l.strip() and not l.strip().startswith("#")]
arq_base = git("ls-tree", "-r", "--name-only", base).stdout.splitlines()
arq_head = git("ls-tree", "-r", "--name-only", "HEAD").stdout.splitlines()

problemas = 0
print(f"Base {base[:7]} -> HEAD. Testes de aceite de .claude/aceite.txt ({len(padroes)} linha(s)):")
if lista_head != lista_base:
    problemas += 1
    print("  MUDOU    .claude/aceite.txt: a lista de protegidos mudou depois da base. Confira quem tirou o quê.")

for padrao in padroes:
    na_base = [a for a in arq_base if fnmatch.fnmatch(a, padrao)]
    no_head = [a for a in arq_head if fnmatch.fnmatch(a, padrao)]
    if not na_base and not no_head:
        problemas += 1
        print(f"  SUMIU    {padrao}: nenhum arquivo casa, nem na base nem em HEAD")
        continue
    for arq in sorted(set(na_base) | set(no_head)):
        antes, depois = conteudo(base, arq), conteudo("HEAD", arq)
        if antes is None:
            problemas += 1
            print(f"  NOVO     {arq}: não existia na base. Teste de aceite nasce antes do loop; leia inteiro.")
        elif depois is None:
            problemas += 1
            print(f"  APAGADO  {arq}")
        elif normaliza(antes) == normaliza(depois):
            print(f"  igual    {arq} ({marcadores(antes)} pendente(s))")
        elif so_tirou_marcadores(antes, depois):
            print(f"  ok       {arq}: só marcador saiu ({marcadores(antes)} -> {marcadores(depois)} pendente(s))")
        else:
            problemas += 1
            print(f"  MUDOU    {arq}: mudou além do marcador. git diff {base[:7]} HEAD -- {arq}")

if problemas:
    print(f"{problemas} problema(s). O hook barra o Claude, não o Bash nem você: decida cada um antes do merge.")
    sys.exit(1)
print("Só marcadores saíram. Os testes de aceite são os mesmos que você aprovou.")
PY
