# Referência visual do app mobile

`SIMTC-Mobile.dc.html` é o canvas do projeto "Paleta e componentes do app móvel"
do Claude Design (`claude.ai/design/p/e2d444d2-44d5-4519-a4d1-fb3e7bb8e588`),
extraído em 01/10/2026 do export completo. São 3836 linhas e 45 quadros.

## Como o arquivo está organizado

| Linhas | Bloco | Conteúdo |
|---|---|---|
| 459–694 | Variante ADMIN | 1.11 Adicionar participante (464), 1.12 Dados do treinamento (543), 1.13 Consultores da sessão (618) |
| 695–1438 | Celular (compact) | 1.1 Abertura (701), 1.2 Entrar (718), 1.3 Minhas sessões (766), 1.4 Detalhe consultor (862) e ADMIN (951), 1.4.1 Iniciar avaliação (1050), Checklist (1110), 1.6 Conferir e finalizar (1185), 1.8 Resultado (1239), 1.9 Sincronizar (1319), 1.10 Perfil (1387) |
| 1439–3453 | Tablet | as mesmas telas em 1280×800 e 800×1280 (1.4.1 Iniciar avaliação em 1934 e 1995), mais dois quadros "Spec para dev" (3393 e 3424) |
| 3454–3836 | Fundações e sistema de design | Contexto de uso, mapeamento para Material 3, escala tipográfica, paleta semântica e as decisões do designer |

Cada quadro é um `div.dv-opt` com o rótulo da tela; as telas são HTML com estilo
inline, então dá para ler medidas, cores e pesos de fonte direto do markup.
Alguns quadros usam dados de um `<script type="text/x-dc">` no fim do arquivo
(listas `statusChips`, `severity`, `typeScale`, `brand`, `CV`, `sessionsToday`,
`sessionsWeek`).

## O que mudou no export de 01/10/2026

Em relação ao export de 24/09/2026, só entraram quadros novos (nenhum quadro existente mudou; os ids das imagens mudam a cada export):

- **6a — 1.4.1 Iniciar avaliação · antes do checklist** (celular, linha 1050): o estado "não iniciada" do checklist, com o bloco "A avaliação ainda não começou.", a lista "O que será avaliado" (código, nome, itens e pontos de cada categoria) e o botão "Iniciar avaliação" no rodapé.
- **6b e 6c** — a mesma tela no tablet, paisagem (1934) e retrato (1995).
- Os textos de fluxo do celular e do tablet passaram a incluir o 6a e o 6b/6c.

## O que mudou no export de 24/09/2026

Em relação ao export de 17/09/2026:

- **1.7 Assinatura saiu** (celular e os dois quadros de tablet). É a decisão de 20/09/2026: a assinatura do participante passou para o formulário web de inscrição.
- **1.3 Minhas sessões:** cada card ganhou, à esquerda do nome, um quadro de 44×44 com o logo da empresa ou, sem logo, as iniciais (Inter 700 14, `#0A6E80`). O espaço entre esse quadro e o texto é de 12.
- **1.4 Detalhe da sessão** (consultor e ADMIN): o logo do cabeçalho perdeu a borda `#D6EDF0`.
- Mudanças nos quadros das fases seguintes: 1.6 Conferir e finalizar; os quadros de tablet 4e, 4r, 4t, 4j e 4y; a spec 5a; e o bloco de fundações.

## Qual parte manda

**As telas, fielmente.** Por decisão do autor do projeto (17/09/2026), o bloco
"Fundações e sistema de design" é **desconsiderado**: ele registra um raciocínio
que não foi seguido ao desenhar as telas. Não use aquele bloco como fonte de
token, medida ou regra. Divergências conhecidas entre ele e as telas:

- fundações descrevem a navbar como charcoal opaca; as telas usam pastilha clara `#F8FAFC` com o item ativo em `#38BEC8`;
- fundações colocam `EM_AVALIACAO` em teal e propõem uma rampa própria de severidade;
- fundações propõem uma escala tipográfica M3 "redonda" (24/20/16/14), enquanto as telas usam os tamanhos intermediários que estão no markup.

Para tokens que não estejam nas telas, vale `prompt-claude-design-mobile.md`
(valores reais de produção).

## De onde veio este arquivo

O export do Claude Design é um HTML "bundle" auto-extraível (~1,4 MB, com fontes
e imagens embutidas em base64). O que está versionado aqui é só o template do
canvas, extraído do bloco `<script type="__bundler/template">` do bundle — é o
mesmo HTML, sem os binários. Para atualizar: baixe o export novo e extraia esse
bloco por cima deste arquivo (o conteúdo do bloco é uma string JSON; decodifique
antes de gravar). Os ids das imagens (`<img src="…uuid…">`) mudam a cada export.
