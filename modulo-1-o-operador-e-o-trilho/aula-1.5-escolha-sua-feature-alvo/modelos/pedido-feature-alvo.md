# Pedido · encontrar a feature-alvo com o Claude Code (aula 1.5)

Na aula (6:22): "Abra o seu assistente de código e estruture. Pega esses slides daqui para
trás, joga no Claude e fala assim: eu quero encontrar uma feature-alvo a partir dessa peneira
aqui. Me ajuda a encontrar." Este é esse pedido, com o conteúdo dos slides (as cinco peneiras)
já dentro, para quem não instalou o plugin `feature-alvo` (com o plugin, é só `/feature-alvo`).

## Como usar

1. Na raiz do seu projeto, rode `~/harness-lab-materiais/instalar.sh 1.5`. Ele põe o modelo
   do `FEATURE-ALVO.md` na raiz, com os títulos que o Módulo 4 usa.
2. Abra o `claude` e aperte Shift+Tab até a barra mostrar `plan mode on`. No modo de plano
   ele lê e roda comando para explorar, mas não edita arquivo.
3. Cole o pedido abaixo. Responda o que ele perguntar (backlog e valor real são seus).
4. Escolha a candidata. Quando o plano trouxer o arquivo preenchido, aprove: aí ele grava.
5. Confira que nenhum espaço do modelo sobrou fora de crases. Precisa dar 0:

   ```bash
   sed 's/`[^`]*`//g' FEATURE-ALVO.md | grep -cE "<[^>]+>"
   ```

## O pedido

```text
Quero escolher a feature-alvo do Harness Lab neste repositório: a feature
que um loop vai entregar sozinho no fim do curso. Me ajude a encontrar.

1. Leia o repositório sem alterar nada: git log --oneline -20, as branches
   e os marcadores que deixei para depois no código (FIXME, HACK e afins).
   Me pergunte o que está no backlog do time.
2. Monte 3 candidatas reais, cada uma com a evidência (commit,
   arquivo:linha ou o que eu contei).
3. Passe cada uma nas cinco peneiras, nesta ordem, e diga em qual cai:
   pequena (cabe em 2 a 4 fases); verificável (dá para escrever critério
   "Quando ..., então ..." que um teste confere); isolada (quantos arquivos
   falam da área, com git grep -il); valor real (pergunte para mim); sem
   terceiro instável (a prova não depende de API externa, sandbox de
   pagamento ou serviço de outro time). Se cair, proponha a fatia que passa.
4. Eu escolho. Depois rascunhe de 3 a 5 critérios "Quando ..., então ..."
   com resultado que dá para conferir e preencha o FEATURE-ALVO.md da raiz,
   com os títulos que já estão nele. Não mexa em mais nada.
```

## O que conferir na resposta

- Cada candidata tem evidência. Candidata sem commit, sem `arquivo:linha` e sem você ter
  contado é invenção: peça para trocar.
- A peneira "valor real" voltou como pergunta para você, não como resposta dele.
- A sugestão que ele mais gostou também passou pelas cinco. Quem escolhe é você.
- Os critérios dizem o que dá para ver: estado no banco, contagem, mensagem exata, status.
  Palavra vaga (rápido, melhor, amigável, adequado) ainda não é critério.
