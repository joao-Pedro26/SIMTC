# Brainstorm — Assinatura do participante no formulário de inscrição

> 05/11/2026 · Substitui a ideia original de pegar a assinatura no app mobile, que já foi revertida no commit `3b4a98f`, na migration `20260920120000_remove_participant_signature_from_assessment`.

## 1. Objetivo

No formulário público de inscrição (`/register/[qrToken]`, aberto pelo QR Code no celular), o participante pode **assinar com o dedo na tela**. A assinatura fica salva e passa a aparecer no **certificado**, no espaço que hoje só tem a linha e o nome do aluno.

- **Opcional, mas recomendada.** A inscrição funciona sem assinatura. Nesse caso o certificado sai como hoje, só com a linha e o nome.
- **Fica ligada à pessoa (CPF), não à inscrição.** Quem assinou num treinamento reaproveita a mesma assinatura nos próximos.
- **Prévia sempre visível.** Se o CPF já tem assinatura salva, ela aparece no formulário. Quando a pessoa desenha uma nova, a nova também aparece em prévia antes do envio, mesmo que ela nunca tenha assinado antes.
- **Sem "assinar depois" no MVP.** Quem não assinar na inscrição fica sem assinatura. Não há link por e-mail nem upload pelo admin.

## 2. Ponto de partida (o que existe hoje no código)

| Peça | Estado atual |
|---|---|
| `public-register-flow.tsx` | Telas `confirm → form → success`. Envia **JSON** com nome, CPF, e-mail, categoria e validade da CNH. |
| `POST /public/register/:qrToken` | `registerPublic()` faz a deduplicação por CPF (`findOrUpdateParticipantForSession`, que **sobrescreve** os dados) e cria o `TrainingParticipant`. Limite de 10 requisições por hora. |
| `Participant` (Prisma) | Não tem nenhum campo de assinatura. |
| `certificate.html` | A coluna do aluno tem só `.sig-line` e `participant.name`. A do consultor já usa `.sig-img` (58px de altura) com signed URL. |
| `certificates.service.ts` | Já resolve a signed URL do bucket privado `signatures` do consultor (`getSignedUrl(..., 300)`). Esse padrão serve de modelo. |
| `participant-cleanup.util.ts` | Apaga o `Participant` órfão dentro de uma transação, mas **não mexe no Storage**. |
| Backend | Tem multer (via `@nestjs/platform-express`) e **não tem `sharp`**. O body JSON está no padrão do Express, com **limite de 100 KB**. |

## 3. Modelo de dados

```prisma
model Participant {
  // ...campos atuais
  signaturePath      String?   // path no bucket privado `participant-signatures`
  signatureUpdatedAt DateTime? // mostrado na prévia: "Assinatura salva em 12/10/2026"
}
```

- **Bucket novo e privado:** `participant-signatures`, separado do `signatures` dos consultores. Uma assinatura é dado pessoal sensível e não pode ficar pública.
- **Path:** `{participantId}/{Date.now()}.png`. Segue o padrão de cache-bust já usado em logos e na assinatura do consultor: o arquivo novo é enviado, o banco é atualizado e só então o anterior é apagado.
- Guardar **só o path** no banco, nunca a URL. Toda leitura passa por signed URL de curta duração.
- Migration criada com `prisma migrate dev --create-only` e aplicada com `migrate deploy`. **Nunca usar `migrate reset`** (ver o histórico de drift de migrations).

## 4. Prévia da assinatura existente — o ponto delicado

### O risco
O formulário é **público**: qualquer pessoa com o QR Code consegue abri-lo. Se só digitar um CPF já mostrasse a assinatura salva, alguém poderia ver a assinatura de outra pessoa sabendo apenas o CPF dela, que é um dado fácil de achar. Para assinatura isso é grave (risco de falsificação, LGPD). O mesmo vale para **trocar** a assinatura de outra pessoa.

### Proposta: liberar com CPF + e-mail
A prévia só aparece quando **o CPF e o e-mail digitados batem com os que estão salvos**. O e-mail já é obrigatório no formulário, então o participante não ganha nenhum passo extra.

**Endpoint novo:**
```
POST /public/register/:qrToken/signature-preview
body: { cpf, email }
→ { status: 'none' }                                    // CPF sem assinatura (ou CPF não cadastrado)
→ { status: 'found', previewUrl, updatedAt }           // CPF + e-mail conferem
→ { status: 'locked' }                                  // existe assinatura, mas o e-mail não confere
```
- `qrToken` precisa ser de uma sessão ativa, com a mesma regra do `registerPublic`.
- `previewUrl` é uma signed URL de **120 segundos**. Basta para o `<img>` carregar e não serve para compartilhar.
- Throttle próprio e mais apertado, algo como **20 por hora por IP**, para impedir que alguém fique testando CPF e e-mail em sequência.
- Comparar o e-mail em minúsculas e sem espaços nas pontas.
- **Não devolver nenhum outro dado** (nome, CNH). O formulário web continua sem preencher nada automaticamente pelo CPF, e isso é de propósito.
- **Por que existe o `locked`:** a pessoa existe, mas o e-mail é outro, seja porque mudou ou porque digitou errado. A tela mostra uma mensagem neutra: *"Este CPF já tem uma assinatura salva, que será usada no seu certificado."* Não aparece prévia, não dá para assinar de novo e não há pedido para entrar em contato. Se for o dono de verdade, o certificado sai com a assinatura dele, que é o objetivo. Se for outra pessoa, ela não vê a assinatura e não consegue trocá-la. Revelar que o CPF tem assinatura é aceitável: é bem menos do que o formulário já revela hoje quando avisa "CPF já inscrito neste treinamento".

### Quando chamar
No front, com debounce de cerca de 600 ms, assim que o **CPF for válido** (o `validateCpf` já existe) **e o e-mail tiver formato válido**. Chama de novo se qualquer um dos dois mudar. Enquanto espera, o card mostra um skeleton.

### Regra para trocar a assinatura
É o mesmo raciocínio da prévia: **só dá para substituir uma assinatura existente se CPF e e-mail conferirem**. No estado `locked` o front nem oferece a opção de assinar. Mesmo assim, o backend confere de novo: se chegar um `replace` sem o e-mail conferir (por exemplo, numa chamada feita direto na API), ele **mantém a antiga e descarta a nova**. Se o dono real tiver trocado de e-mail, o certificado continua saindo com a assinatura antiga, o que é aceitável.

> Observação: hoje `findOrUpdateParticipantForSession` já deixa qualquer pessoa com o CPF sobrescrever nome, e-mail e CNH de outra. É um risco que já existia e não é escopo desta feature, mas fica registrado. A assinatura **não** deve seguir esse comportamento permissivo.

## 5. UX no formulário (celular)

### Card "Assinatura" no fim do formulário, antes do botão Enviar
Etiqueta **"Recomendado"** (laranja `--orange-soft`) e uma linha de explicação: *"Sua assinatura aparecerá no seu certificado."*

O card tem quatro estados:

| Estado | O que aparece | Ações |
|---|---|---|
| **A. Vazio** (CPF sem assinatura, ou ainda sem CPF/e-mail) | Área tracejada: "✍️ Toque para assinar" | Abrir o modal |
| **B. Assinatura salva** (`found`) | Prévia sobre fundo branco + "Assinatura salva em 12/10/2026" | **Usar esta** (padrão, já vem marcado) · **Assinar novamente** |
| **C. Nova assinatura** | Prévia da nova + selo "Nova" | **Refazer** (abre o modal de novo) · **Remover**. Se havia assinatura salva, Remover volta ao estado B; se não, volta ao A. |
| **D. Já salva, sem prévia** (`locked`) | Ícone de caneta + *"Este CPF já tem uma assinatura salva, que será usada no seu certificado."* | Nenhuma. Não há prévia nem botão para assinar de novo. O lembrete de envio sem assinatura também não aparece. |

A prévia é **sempre exibida no formulário**. No estado C ela é gerada no próprio aparelho (`dataURL`), sem chamar o servidor.

### Modal de captura
- **Tela cheia** no celular e dialog centralizado no desktop. Desktop com mouse funciona igual.
- Canvas grande, ocupando a largura toda, com a linha de base desenhada e o texto "Assine acima da linha".
- Dica de orientação: *"Gire o celular para ter mais espaço"*. Fica só como sugestão, porque travar a orientação via `screen.orientation.lock` só funciona em fullscreen no Chrome Android e não funciona no Safari.
- Botões: **Limpar** · **Cancelar** · **Confirmar**. O Confirmar fica desabilitado enquanto o canvas está vazio ou só tem um ponto: exigir um mínimo de cerca de 2 traços ou 15 pontos.
- Texto de consentimento acima do Confirmar: *"Ao confirmar, você autoriza o uso desta assinatura exclusivamente na emissão dos seus certificados da SIM Treinamentos."* Confirmar já é o aceite e não precisa de checkbox, para não pesar a tela.
- Cuidados de toque, sobretudo no **iOS Safari**, que vai ser usado mesmo com o app sendo só Android, porque o formulário é web: `touch-action: none` no canvas, travar o scroll do body enquanto o modal está aberto e evitar o pull-to-refresh e o bounce.
- **Redimensionamento e rotação:** o canvas perde o desenho. Guardar os traços (`toData()`), redimensionar considerando o `devicePixelRatio` e redesenhar com `fromData()`.

### Lembrete ao enviar sem assinatura
Se o estado for **A** no envio, mostrar **uma vez** um diálogo curto: *"Seu certificado sairá sem a sua assinatura. Deseja assinar agora?"*, com os botões **[Assinar agora]** e **[Enviar sem assinatura]**. Isso deixa a assinatura recomendada sem torná-la obrigatória. Não aparece nos estados B, C e D.

### Tela de sucesso
Acrescentar uma linha conforme o caso:
- "✓ Assinatura salva para o certificado."
- "Você se inscreveu sem assinatura."
- "Inscrição feita, mas a assinatura não pôde ser salva." Isso cobre falha no upload, ver a seção 6.

## 6. Captura → arquivo → backend

### Biblioteca
**`signature_pad`** (szimek, sem dependências), envolvida num hook próprio (`useSignaturePad`). Não usar o `react-signature-canvas`: é uma camada a mais, com manutenção irregular. Configuração: traço preto `#111`, `minWidth 0.8`, `maxWidth 2.6` (a espessura varia com a velocidade e o resultado parece caneta).

### Exportação no cliente
1. **Recortar** o espaço transparente em volta: varrer o `getImageData` atrás da caixa que contém o desenho e deixar uns 8px de margem. Sem isso, a assinatura fica minúscula no certificado, porque o `.sig-img` tem altura fixa de 58px.
2. **Reduzir** para no máximo **600×200**, mantendo a proporção.
3. Exportar **PNG transparente** (`canvas.toBlob('image/png')`). O arquivo final fica em torno de 5 a 30 KB.

### Transporte: multipart no próprio endpoint de inscrição
O `POST /public/register/:qrToken` passa a aceitar **`multipart/form-data`**, com os campos de texto atuais e um arquivo opcional `signature`, além do campo `signatureAction: 'keep' | 'replace' | 'none'`.

Por que não base64 dentro do JSON:
- o limite padrão de 100 KB do body JSON fica perto demais;
- base64 aumenta o tamanho em cerca de 33%;
- multer já existe no projeto.

Por que não um segundo request só para a assinatura:
- uma rota pública separada de upload precisaria de algum token para amarrar a assinatura à inscrição;
- com uma requisição só, inscrição e assinatura chegam juntas.

**Ponto de atenção do multipart:** os campos chegam como string. Conferir se o `ValidationPipe` com `transform` continua validando o DTO direito, sobretudo o `participationType`.

### Validação no backend (sem `sharp`)
- `FileInterceptor('signature', { limits: { fileSize: 300 * 1024 } })`.
- Conferir os **magic bytes** do PNG (`89 50 4E 47`) e não confiar no `mimetype` que o cliente declara.
- Ler largura e altura direto do chunk IHDR (bytes 16 a 23) e recusar acima de 2000×2000. Não precisa de lib para isso.
- `signatureAction='replace'` sem arquivo vira `400`.

### Ordem das operações em `registerPublic`
1. Validar a sessão e fazer a deduplicação por CPF (como hoje).
2. Se `replace`, e se a pessoa já tem assinatura, **conferir que o e-mail confere** (seção 4). Se não conferir, ignorar o arquivo e marcar `signatureIgnored: true` na resposta.
3. **Fazer o upload do arquivo novo** antes de mexer no banco.
4. Numa transação: criar o `TrainingParticipant` e atualizar `signaturePath` e `signatureUpdatedAt`.
5. Se a transação falhar, apagar o arquivo recém-enviado.
6. Depois do commit, apagar o arquivo antigo com `.catch(() => null)`, seguindo o padrão do consultor.
7. **Uma falha no upload da assinatura não derruba a inscrição.** Ela é concluída sem assinatura e a resposta volta com `signatureSaved: false`. Para quem está na fila do treinamento, perder a inscrição por causa da assinatura seria pior.

Resposta nova: `{ ...trainingParticipant, signatureSaved: boolean, signatureIgnored?: boolean }`.

## 7. Certificado

- Em `generateOne` (`certificates.service.ts`), resolver a signed URL do participante da mesma forma que a do consultor: `getSignedUrl('participant-signatures', path, 300)`. Se falhar, segue com `null`.
- Em `certificate.html`, na coluna do aluno:
  ```hbs
  <div class="sig">
    {{#if participant.signatureUrl}}
      <img class="sig-img" src="{{{participant.signatureUrl}}}" alt="Assinatura do participante">
    {{/if}}
    <div class="sig-line"></div>
    <p class="sig-name">{{participant.name}}</p>
  </div>
  ```
- **Alinhar as duas colunas.** Quando só um lado tem imagem, as linhas ficam em alturas diferentes. Opções: dar ao `.sig` uma altura mínima fixa (58px + linha), ou usar `align-items: flex-end` no `.signatures`. Testar as quatro combinações (com ou sem a assinatura de cada um).
- Atualizar também o `certificate-preview.html`.
- **Consequência que vamos aceitar:** os certificados são gerados sob demanda (`generateBatch`, `generateCertificateForParticipant`). Se a pessoa trocar a assinatura num treinamento novo e um certificado antigo for **regenerado**, ele sai com a assinatura nova. Como a assinatura é da pessoa, isso faz sentido e fica só registrado.
- A página 2 (conteúdo programático) e o relatório de avaliação **não mudam**: a assinatura que aparece neles é a do consultor.

## 8. Painel admin

**Fora do MVP de "assinar depois" (decisão já tomada), mas com duas coisas pequenas que valem a pena:**
- **Indicador na aba Participantes** (`participants-tab.tsx`): um ícone de caneta, cheio ou vazio, mostrando se a pessoa tem assinatura. Ajuda o admin a saber antes de gerar os certificados. Basta incluir `hasSignature: boolean` na listagem, sem expor o path.
- *(Opcional)* **Ver e remover a assinatura** pelo admin, para rabiscos ou para o caso `locked` de quem trocou de e-mail. Seria um `DELETE /participants/:id/signature` restrito a ADMIN. Remover não exige capturar nada novo, então não conflita com a decisão de "sem assinar depois".

O CLIENT (portal da empresa) e o app mobile **não veem** a assinatura. Não há motivo para mostrar.

## 9. Limpeza e LGPD

- `participant-cleanup.util.ts`: hoje apaga os `Participant` órfãos **dentro da transação**. Ele precisa **devolver os `signaturePath`** dos apagados, para o chamador apagá-los do Storage **depois do commit**, porque o Storage não participa da transação. É o mesmo problema de arquivo órfão no Storage resolvido em 27/08.
- O hard delete de participante e de treinamento precisa passar por esse caminho.
- O bucket é privado e o acesso é sempre por signed URL curta. As únicas leituras são a prévia (120s, com CPF e e-mail) e a geração do PDF (300s, no servidor).

## 10. Fases de implementação

Cada fase termina com algo testável.

**Fase 1 — Backend: dados e upload**
- Migration em `Participant` (`signaturePath`, `signatureUpdatedAt`) e bucket privado `participant-signatures` no Supabase.
- `registerPublic` com multipart, `signatureAction`, validação PNG e IHDR, e a ordem de operações da seção 6.
- Shared types: `RegisterParticipantPublicDto` com `signatureAction` e a resposta com `signatureSaved` e `signatureIgnored`.
- Testes unitários: envio com assinatura nova, com `keep`, com `none`, com `replace` e e-mail diferente (ignorado), com falha de upload (inscrição mantida) e com arquivo que não é PNG (400).

**Fase 2 — Backend: prévia e limpeza**
- `POST /public/register/:qrToken/signature-preview` com conferência de CPF e e-mail, signed URL de 120s e throttle próprio.
- Cleanup devolvendo os paths e apagando do Storage depois do commit.
- Testes: `none`, `found`, `locked`, sessão encerrada e participante apagado sem deixar arquivo órfão.

**Fase 3 — Web: componente de assinatura**
- `useSignaturePad`, `SignatureModal` (tela cheia, Limpar/Cancelar/Confirmar, consentimento, rotação e redimensionamento) e a função de recorte e redução.
- Testar isolado numa rota de dev ou numa story, **num celular de verdade** (Chrome Android e Safari iOS).

**Fase 4 — Web: integração no formulário**
- Card com os estados A, B, C e D, consulta da prévia com debounce, troca do `fetch` JSON por `FormData`, diálogo de lembrete e linhas novas na tela de sucesso.

**Fase 5 — Certificado**
- Signed URL em `generateOne`, template com o `{{#if}}`, alinhamento das colunas e atualização do preview. Gerar PDFs de teste nas quatro combinações.

**Fase 6 — Admin (pequena)**
- Indicador `hasSignature` na aba Participantes e, se aprovado, o remover.

**Fase 7 — QA ponta a ponta**
- QR Code → inscrição com assinatura → gerar certificado → baixar o PDF.
- Mesmo CPF em outro treinamento → prévia carrega → "Usar esta" → certificado.
- CPF existente com e-mail diferente → `locked`.
- Inscrição sem assinatura, passando pelo lembrete → certificado só com a linha.

## 11. Pontos em aberto

1. ~~**Estado D (`locked`)**~~ **Decidido em 05/11/2026:** fica com a mensagem neutra (*"Este CPF já tem uma assinatura salva, que será usada no seu certificado."*), sem prévia, sem botão para assinar de novo e sem pedir que a pessoa entre em contato com a SIM. A assinatura salva continua valendo.
2. **O próprio participante pode apagar a assinatura salva** pelo formulário (botão "Remover assinatura salva" no estado B)? Do ponto de vista de LGPD seria o ideal. Custa pouco, porque usa a mesma conferência de CPF e e-mail.
3. **Remoção pelo admin (seção 8):** entra ou não?
4. **Marca d'água na prévia** ("PRÉVIA"), para dificultar ainda mais o uso indevido? Sem `sharp` no backend teria que ser só no front com CSS, o que não protege a imagem em si. A sugestão é **não fazer** e confiar em CPF + e-mail + 120s + throttle.
5. **Inscrições feitas pelo admin ou em lote** continuam sem assinatura no MVP. Se no futuro entrar "assinar depois", o caminho natural é reaproveitar o `SignatureModal` numa rota com token enviado por e-mail.
