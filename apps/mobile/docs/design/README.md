# Referência visual do app mobile

`SIMTC-Mobile.dc.html` é o canvas do projeto "Paleta e componentes do app móvel"
do Claude Design (`claude.ai/design/p/e2d444d2-44d5-4519-a4d1-fb3e7bb8e588`),
extraído em 17/09/2026 do export completo. São 3765 linhas e 42 quadros.

## Como o arquivo está organizado

| Linhas | Bloco | Conteúdo |
|---|---|---|
| 460–695 | Variante ADMIN | 1.11 Adicionar participante, 1.12 Dados do treinamento, 1.13 Consultores da sessão |
| 696–1416 | Celular (compact) | 1.1 Abertura (702), 1.2 Entrar (719), 1.3 Minhas sessões (767), 1.4 Detalhe consultor (855) e ADMIN (944), Checklist (1043), 1.6 Conferir e finalizar (1118), 1.7 Assinatura (1169), 1.8 Resultado (1217), 1.9 Sincronizar (1297), 1.10 Perfil (1365) |
| 1417–3383 | Tablet | as mesmas telas em 1280×800 e 800×1280, mais dois quadros "Spec para dev" (3323 e 3354) |
| 3384–3765 | Fundações e sistema de design | Contexto de uso, mapeamento para Material 3, escala tipográfica, paleta semântica e as decisões do designer |

Cada quadro é um `div.dv-opt` com o rótulo da tela; as telas são HTML com estilo
inline, então dá para ler medidas, cores e pesos de fonte direto do markup.
Alguns quadros usam dados de um `<script type="text/x-dc">` no fim do arquivo
(listas `statusChips`, `severity`, `typeScale`, `brand`, `CV`).

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
bloco por cima deste arquivo.
