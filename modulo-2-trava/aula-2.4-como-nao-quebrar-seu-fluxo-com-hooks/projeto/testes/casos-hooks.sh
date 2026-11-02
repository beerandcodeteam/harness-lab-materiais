# casos-hooks.sh · Harness Lab · aula 2.4 · os casos que o testa-hooks.sh roda
# Este arquivo é seu: troque os comandos pelos do seu projeto.
#
# Formato:  caso "HOOK [args]" "descrição curta" JSON ESPERADO
#   HOOK      nome do script em .claude/hooks (hook que não existe é pulado, não reprova).
#             .py roda com python3, .js com node; .sh roda direto, como no settings
#   JSON      bash_json 'comando'          PreToolUse de Bash
#             arq_json Read|Edit|Write caminho   PreToolUse de ferramenta de arquivo
#             arq_json Edit caminho PostToolUse  o mesmo JSON, no PostToolUse
#             stop_json true|false         Stop, com o stop_hook_active
#   ESPERADO  bloqueia | pergunta | libera
#
# Regra de ouro: para cada regra, um caso que tem que barrar E um que tem que passar.
# O segundo é o que pega o "barrou demais".
# O guard-jev.py da aula 2.3 não tem casos aqui: ele chama a API do Jev a cada comando.

echo "guard-destructive.py (aula 2.3)"
caso guard-destructive.py "migrate:fresh"              "$(bash_json 'php artisan migrate:fresh --seed')"        bloqueia
caso guard-destructive.py "migrate:fresh via sail"     "$(bash_json './vendor/bin/sail artisan migrate:fresh')" bloqueia
caso guard-destructive.py "db:wipe"                    "$(bash_json 'php artisan db:wipe')"                     bloqueia
caso guard-destructive.py "migrate --force"            "$(bash_json 'php artisan migrate --force')"             bloqueia
caso guard-destructive.py "push --force"               "$(bash_json 'git push origin main --force')"            bloqueia
caso guard-destructive.py "reset --hard"               "$(bash_json 'git reset --hard HEAD~1')"                 bloqueia
caso guard-destructive.py "prisma migrate reset"       "$(bash_json 'npx prisma migrate reset')"                bloqueia
caso guard-destructive.py "rails db:reset"             "$(bash_json 'bin/rails db:reset')"                      bloqueia
caso guard-destructive.py "compose down -v"            "$(bash_json 'docker compose down -v')"                  bloqueia
# os que têm que passar
caso guard-destructive.py "migrate normal"             "$(bash_json 'php artisan migrate')"                     libera
caso guard-destructive.py "migrate:status"             "$(bash_json 'php artisan migrate:status')"              libera
caso guard-destructive.py "prisma migrate status"      "$(bash_json 'npx prisma migrate status')"               libera
caso guard-destructive.py "rails db:migrate"           "$(bash_json 'bin/rails db:migrate')"                    libera
caso guard-destructive.py "push sem force"             "$(bash_json 'git push')"                                libera
caso guard-destructive.py "grep que só cita migrate"   "$(bash_json 'grep -rn migrate docs/')"                  libera

echo "bloqueia-perigoso.sh (a Trava das demos das aulas 2.3 e 2.4)"
caso bloqueia-perigoso.sh "migrate:fresh"              "$(bash_json 'php artisan migrate:fresh --seed')"        bloqueia
caso bloqueia-perigoso.sh "migrate:fresh via sail"     "$(bash_json './vendor/bin/sail artisan migrate:fresh')" bloqueia
caso bloqueia-perigoso.sh "db:wipe"                    "$(bash_json 'php artisan db:wipe')"                     bloqueia
caso bloqueia-perigoso.sh "migrate --force (produção)" "$(bash_json 'php artisan migrate --force')"             bloqueia
caso bloqueia-perigoso.sh "push --force"               "$(bash_json 'git push origin main --force')"            bloqueia
caso bloqueia-perigoso.sh "push -f"                    "$(bash_json 'git push -f')"                             bloqueia
caso bloqueia-perigoso.sh "cat .env"                   "$(bash_json 'cat .env')"                                bloqueia
caso bloqueia-perigoso.sh "grep com | no padrão"       "$(bash_json "grep -E '^(APP_ENV|DB_HOST)=' .env")"      bloqueia
caso bloqueia-perigoso.sh "source .env.production"     "$(bash_json 'source .env.production')"                  bloqueia
caso bloqueia-perigoso.sh "rm -rf /"                   "$(bash_json 'rm -rf /')"                                bloqueia
caso bloqueia-perigoso.sh "rm -rf build"               "$(bash_json 'rm -rf build')"                            pergunta
caso bloqueia-perigoso.sh "reset --hard"               "$(bash_json 'git reset --hard HEAD~1')"                 pergunta
# os que têm que passar
caso bloqueia-perigoso.sh "migrate normal"             "$(bash_json 'php artisan migrate')"                     libera
caso bloqueia-perigoso.sh "migrate:status"             "$(bash_json 'php artisan migrate:status')"              libera
caso bloqueia-perigoso.sh "push --force-with-lease"    "$(bash_json 'git push --force-with-lease')"             libera
caso bloqueia-perigoso.sh "cat .env.example"           "$(bash_json 'cat .env.example')"                        libera
caso bloqueia-perigoso.sh "grep que só cita migrate"   "$(bash_json 'grep -rn migrate docs/')"                  libera
caso bloqueia-perigoso.sh "rodar os testes"            "$(bash_json 'npm test')"                                libera
# Outra stack? Se a sua Trava cobre, acrescente o par (o guard-destructive.py já cobre):
# caso bloqueia-perigoso.sh "prisma reset"   "$(bash_json 'npx prisma migrate reset')"  bloqueia
# caso bloqueia-perigoso.sh "rails db:reset" "$(bash_json 'bin/rails db:reset')"        bloqueia
# caso bloqueia-perigoso.sh "prisma status"  "$(bash_json 'npx prisma migrate status')" libera

echo "protege-env.sh (aula 2.3)"
caso protege-env.sh "Read .env"                        "$(arq_json Read .env)"                                  bloqueia
caso protege-env.sh "Edit .env.production"             "$(arq_json Edit .env.production)"                       bloqueia
caso protege-env.sh "Read .env.example"                "$(arq_json Read .env.example)"                          libera
caso protege-env.sh "Edit app/Models/User.php"         "$(arq_json Edit app/Models/User.php)"                   libera

echo "quality-gate.sh (aula 2.2)"
# O que tem que barrar: um .py com erro de sintaxe, criado aqui e apagado logo depois.
# Python porque o hook confere a sintaxe com o python3 em qualquer stack. Troque por um
# arquivo da sua stack (um .php quebrado, com o php no PATH) se preferir.
if command -v python3 >/dev/null 2>&1; then
  qg_tmp="$raiz/testes/.caso-quality-gate"
  mkdir -p "$qg_tmp" && printf 'def quebrado(:\n    pass\n' >"$qg_tmp/quebrado.py"
  caso "quality-gate.sh post-edit" "python com erro de sintaxe" \
    "$(arq_json Edit testes/.caso-quality-gate/quebrado.py PostToolUse)"                        bloqueia
  rm -rf "$qg_tmp"
  rm -f "${TMPDIR:-/tmp}/claude-quality-gate/$sessao.txt"   # a anotação que o post-edit fez
fi
# os que têm que passar
caso "quality-gate.sh post-edit" "edição sem file_path"  "$(bash_json 'ls' PostToolUse)"                        libera
caso "quality-gate.sh post-edit" "edição de markdown"    "$(arq_json Edit README.md PostToolUse)"               libera
caso "quality-gate.sh stop" "Stop já continuando"        "$(stop_json true)"                                    libera
