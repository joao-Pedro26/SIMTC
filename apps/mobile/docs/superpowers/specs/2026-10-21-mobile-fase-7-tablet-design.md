# Fase 7 — Adaptação para tablet (desenho)

Conversa de 21/10/2026. Base: `brainstorm-implementacao-mobile.md` (Fase 7), canvas
`apps/mobile/docs/design/SIMTC-Mobile.dc.html` (bloco Tablet, linhas 1439–3453) e o
código atual de `apps/mobile/simtc/`.

## Intenção

O consultor usa o tablet **no carro, durante a avaliação**, com o aparelho girando
entre retrato e paisagem. A fase faz o mesmo app funcionar bem no tablet, sem mudar
nenhuma regra, dado ou chamada ao backend, e sem piorar o celular.

**O que reprova a fase (dito pelo usuário):** perder as marcações do checklist ao
girar o tablet.

## Decisões do usuário (21/10/2026)

1. **Validação em emulador de tablet**, porque o usuário não tem tablet físico. É a
   primeira exceção à regra "aparelho físico, nunca emulador" e vale **só para o
   tablet**: o roteiro de aceite inclui uma passada no celular Android físico para
   confirmar que nada piorou.
2. **Perfil (1.10) e o "Sair" ficam na Fase 8.** Os quadros `4k` e `4v` não entram.
   O item de roteiro herdado da Fase 2 ("sair e entrar com outro consultor") vai
   junto para a Fase 8.
3. **Dividir em 7A e 7B** (escopo abaixo), cada uma com plano, execução e validação próprios;
   a 7B só é planejada depois da validação da 7A.
4. **Todas as telas seguem o giro do aparelho no tablet**, inclusive o checklist
   (nada de travar na orientação em que a avaliação começou).

## Escolhas minhas (avisadas ao usuário, sem objeção até aqui)

- **Quem é tablet:** `shortestSide >= 600dp`. Abaixo disso é celular e fica
  **travado em retrato** (o roteiro geral já dizia isso; hoje o app não trava, nem
  no `AndroidManifest` nem por `SystemChrome`). No tablet, libera as quatro orientações.
  O formato é decidido pelo tamanho da **tela física**, não da janela: em tela
  dividida o tablet continua sendo tablet (não trava em retrato); o layout de cada
  tela é que segue a largura disponível da janela.
- **Perfil na barra lateral:** fica como hoje no celular (aviso "Disponível em
  breve") até a Fase 8.
- **Lado a lado:** largura `>= 840dp` (tablet em paisagem). Em retrato (800 de
  largura) uma tela por vez, com seta de voltar — é o que o quadro `4e`
  ("master-detail colapsado") desenha.
- **Sem `flutter_adaptive_scaffold`:** o pacote foi descontinuado pela equipe do
  Flutter (pub.dev marca como discontinued desde a 0.3.3+1). A adaptação é feita
  com `MediaQuery`/`LayoutBuilder` e widgets próprios, sem dependência nova.

## Requisito central: girar não perde nada

- As marcações do checklist já são gravadas no banco local a cada toque
  (`ChecklistViewModel.toggleNote` → repositório, lidas de volta por stream). O giro
  não pode recriar a ViewModel, refazer o `init()` ou apagar o que está em memória:
  categorias abertas/fechadas, texto digitado em formulários, posição da rolagem e
  envio em andamento.
- O lado a lado ↔ uma-tela-por-vez é a troca mais arriscada: ao girar com um
  detalhe aberto, o detalhe continua aberto (em retrato vira a tela cheia com
  voltar; em paisagem volta a ficar ao lado da lista), sem perder estado.
- **Testes obrigatórios:** girar várias vezes seguidas (paisagem ↔ retrato) no
  meio do checklist com marcações feitas e conferir que todas continuam, inclusive
  com uma gravação ainda em andamento (`Completer`) no momento do giro; o mesmo
  para o detalhe da sessão no lado a lado e para os formulários de admin (7B).

## 7A — estrutura e telas de consulta

- Detecção de tablet/celular, trava de retrato no celular, giro livre no tablet.
- `PillNavBar` ganha a variante lateral vertical **no mesmo componente** (não
  duplicar), usada no tablet conforme os quadros.
- Lado a lado **Minhas sessões + Detalhe da sessão** em paisagem (`4c` consultor,
  `4d` ADMIN) e uma tela por vez em retrato (`4e`). A rota `/sessions/:id`
  continua valendo (deep link e voltar do sistema funcionam nas duas posições).
- Versões largas de **1.1 Abertura** (`4a`/`4o`), **1.2 Entrar** (`4b`/`4p`) e
  **1.9 Sincronizar** (`4j`/`4u`).

## 7B — avaliação e janelas de admin

- Fluxo de avaliação **em tela cheia** também no tablet (nunca vira lado a lado):
  1.4.1 Iniciar avaliação (`6b`/`6c`), 1.5 Checklist (`4f`/`4q`), 1.6 Conferir e
  finalizar (`4g`/`4r`), 1.8 Resultado (`4i`/`4t`). Specs `4z` e `5a` valem para a
  linha de checklist e os chips.
- **Janelas de admin** como diálogo ancorado no tablet: 1.11 Adicionar participante
  (`4l`/`4w`), 1.12 Dados do treinamento (`4m`/`4x`), 1.13 Consultores da sessão
  (`4n`/`4y`). Mesmas ViewModels da Fase 6; muda só a apresentação. No celular
  continuam telas cheias.

## Fora da Fase 7

Perfil e "Sair" (Fase 8); as buscas (Fase 8); skeletons/estados de erro gerais e
revisão de acessibilidade (Fase 8); as quatro decisões visuais em aberto da 6A;
qualquer mudança de backend.

## Restrições que seguem valendo

- Canvas é a fonte de medidas, fielmente; toda divergência é levada ao usuário
  antes do plano (o bloco "Fundações" do canvas é desconsiderado).
- Cada plano tem "Validação prévia" numa cópia descartável (um commit por task,
  mutação por JSON, desenho com as fontes de verdade em 1280×800, 800×1280 e,
  para o celular, 412×915 e 360×640 com fonte ampliada).
- Execução por subagentes: implementadores em haiku; revisões com modelo mais
  forte conforme a complexidade (sonnet nas tasks de layout simples, opus nas que
  mexem no giro, no lado a lado e no roteamento).
- Commits em português, `tipo(escopo)`, uma linha.

## Deixado para quem planeja

- Como estruturar o lado a lado sobre o `go_router` (ShellRoute, rota com dois
  painéis ou widget de layout que lê a rota), desde que a rota do detalhe continue
  endereçável e o estado sobreviva ao giro.
- Onde mora a detecção de formato (helper, `InheritedWidget`, extensão de
  `BuildContext`).
- Como ancorar os diálogos de admin ao botão de origem.
- A configuração do emulador de tablet (AVD 1280×800, Android recente) e o passo a
  passo do roteiro de aceite.
