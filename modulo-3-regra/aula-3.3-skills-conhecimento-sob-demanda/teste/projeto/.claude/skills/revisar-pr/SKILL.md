---
name: revisar-pr
description: Revisa o pull request aberto contra o padrão deste projeto (testes, migrations, nomes) e lista os problemas por arquivo. Use quando pedirem revisão de PR, review ou checagem antes do merge.
---
# Revisar PR

1. `git diff origin/main...HEAD --stat` para ver o tamanho.
2. Para cada arquivo, confira teste, nome e migration.
3. Termine com a lista: arquivo, linha, problema.
