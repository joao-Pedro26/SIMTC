# Referência visual do app mobile

`SIMTC-Mobile.dc.html` é o export do projeto "Paleta e componentes do app móvel"
do Claude Design (`claude.ai/design/p/e2d444d2-44d5-4519-a4d1-fb3e7bb8e588`),
importado em 17/09/2026. É a referência de layout das telas; quando um token de
cor ou espaçamento divergir, vale o que está escrito em
`prompt-claude-design-mobile.md` (são os valores reais de produção).

## Como o arquivo está organizado

| Linhas | Bloco | Conteúdo |
|---|---|---|
| 13–248 | Variante ADMIN | 1.11 Adicionar participante, 1.12 Dados do treinamento, 1.13 Consultores da sessão |
| 249–969 | Celular (compact) | 1.1 Abertura, 1.2 Entrar, 1.3 Minhas sessões, 1.4 Detalhe (consultor e ADMIN), Checklist, 1.6 Conferir e finalizar, 1.7 Assinatura, 1.8 Resultado, 1.9 Sincronizar, 1.10 Perfil |
| 970–2878 | Tablet | as mesmas telas em 1280×800 e 800×1280, mais o quadro "Spec para dev" |

Cada quadro é um `div.dv-opt` com o rótulo da tela; as telas são HTML com estilo
inline, então dá para ler medidas, cores e pesos de fonte direto do markup.

## Limitação conhecida: o arquivo está truncado

A ferramenta de importação lê no máximo 256 KiB, e o export é maior que isso.
O arquivo termina no meio do último quadro do bloco de tablet — **"Spec para
dev · linha de checklist e chip de severidade"** —, que é justamente a
especificação da linha de infração usada na Fase 4.

Tudo o que vem antes está completo, inclusive o bloco do celular inteiro.

Para substituir pela versão completa: baixe o arquivo pelo próprio Claude Design
e salve por cima deste, mantendo o nome. Vale fazer isso antes de planejar a
Fase 4 (checklist) e a Fase 7 (tablet).
