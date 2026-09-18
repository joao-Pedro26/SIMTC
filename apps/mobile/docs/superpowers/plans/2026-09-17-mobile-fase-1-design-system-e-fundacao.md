# App Mobile SIMTC — Fase 1: Design System + Fundação MVVM — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o scaffold placeholder pela fundação real do app: identidade Android definitiva, configuração de ambiente, Design System com os tokens de produção, cliente HTTP com refresh automático, autenticação de verdade contra a API, serviço de conectividade global e o esquema Drift completo — com a tela de Login redesenhada logando no ambiente real a partir do aparelho físico.

**Architecture:** Camadas na estrutura já existente do scaffold: `lib/ui/core/` guarda o Design System (tokens, tema e componentes "burros"), `lib/ui/<feature>/` guarda tela + ViewModel, `lib/data/repositories/` e `lib/data/services/` guardam Repository, cliente HTTP, banco local e serviços transversais. Toda tela fala só com seu `ChangeNotifier`; todo `ChangeNotifier` fala só com Repositories; todo Repository devolve `Result<T>`. `ApiClient` (dio) concentra base URL, `Authorization` e o refresh em `401`; `TokenStorage` isola o `flutter_secure_storage`; `ConnectivityService` nasce único no `MultiProvider` do app. O esquema Drift completo já entra nesta fase (as tabelas ficam vazias até as fases que as usam), para que nenhuma fase seguinte precise migrar banco.

**Tech Stack:** Flutter 3.41.6 / Dart 3.11.4 · provider 6.1.5 · go_router 14.8.1 · dio 5.11.1 · drift 2.31.0 + drift_flutter 0.2.8 · flutter_secure_storage 9.2.4 · google_fonts 6.3.3 · connectivity_plus 6.1.5 · mocktail (novo, testes)

**Spec:** `brainstorm-implementacao-mobile.md` → "Fase 1"; UI a partir de `prompt-claude-design-mobile.md` (sistema de design, seções `<sistema_de_design>` e `<catalogo_de_telas>` 1.1/1.2) e do export do Claude Design "SIMTC Mobile.dc.html"; contexto de arquitetura em `brainstorm-app-mobile.md` (seções 4 e 6). Achados de contrato e do scaffold em `apps/mobile/docs/fase-0-auditoria.md` — leitura obrigatória antes de executar.

## Decisões tomadas com o usuário (17/09/2026)

1. **Identidade do app:** `applicationId`/`namespace` passam a ser `br.com.simtc.app` e o rótulo vira "SIMTC" — trocados agora porque, depois do primeiro APK distribuído, a troca instalaria um segundo app em vez de atualizar.
2. **URL da API:** dev usa `http://localhost:3001/api` (via `adb reverse`) e produção usa `https://api.simtc.com.br/api` — confirmado respondendo em 17/09/2026 (`POST /api/auth/check-email` → 201; sem o prefixo `/api` → 404).
3. **Consultor inativo:** o app mostra a mesma mensagem genérica de credencial inválida, porque o backend responde `401 "Credenciais inválidas"` nos dois casos. A mensagem específica fica como pendência e **não** entra nesta fase.
4. **Referência visual:** o export do Claude Design ("SIMTC Mobile.dc.html") é a referência pixel-a-pixel; os valores escritos em `prompt-claude-design-mobile.md` prevalecem quando houver divergência de token (cor/espaçamento), por serem os valores reais de produção.

## Global Constraints

**Repositório e processo**
- Branch de trabalho: `feat/mobile-app` (a mesma da Fase 0). Sem git worktree — os documentos-fonte não são versionados.
- Commits em português, numa linha, `tipo(escopo): mensagem`, sem ponto final e **sem `Co-Authored-By`** nem rodapé; um commit por task concluída e verificada.
- `git add` sempre com caminhos explícitos, nunca `git add -A`/`git add .`.
- Não avançar com teste novo falhando, `flutter analyze` com erro ou build quebrado. Baseline do backend permanece em 12 falhas pré-existentes (não mexer).
- Ambiguidade de regra de negócio → parar e perguntar ao usuário.
- Artefatos SDD em `.superpowers/sdd/2026-09-17-mobile-fase-1-design-system-e-fundacao/`.

**Mobile (valem para todas as fases)**
- Flutter 3.41.6 / Dart 3.11.4. App **só Android** (celular e tablet), APK sideload. Validação manual em **aparelho físico** (USB ou Wi-Fi, nunca emulador) — procedimento em `apps/mobile/simtc/README.md`.
- MVVM + Repository: um `ChangeNotifier` por tela/fluxo via `provider`; tela nunca chama `Dio`/Drift direto; Repository por domínio devolvendo o `Result<T>` de `lib/utils/result.dart` (reaproveitado, não recriado).
- `ConnectivityService` único, criado no `MultiProvider` do app, nunca dentro de uma tela.
- Composição "quebra-cabeça" obrigatória: cada tela decompõe a UI em métodos privados `Widget _buildX()` combinados num `build()` enxuto.
- Design System: primária `#1D9AA4` (hover `#167F8A`, escuro `#0A6E80`, suave `#EEF9FA`); CTA `#F5A520` (hover `#E09510`, suave `#FEF8EE`); mauve `#9B80A8` (suave `#F5F0F8`); charcoal `#1E2A34`/`#2A3A46`; neutros `#F8FAFC`, `#FFFFFF`, `#E2E8F0`, `#0F172A`, `#475569`, `#94A3B8`. Severidade (paleta separada): B `#DCFCE7`/`#16A34A`, PM `#FEF9C3`/`#CA8A04`, M `#FEE2E2`/`#DC2626`, rótulos literais "B", "PM", "M". Status de participante: PENDENTE cinza, EM_AVALIACAO amarelo, APROVADO verde, NECESSITA_REAVALIACAO vermelho/laranja escuro — nunca o laranja de marca. Status e severidade nunca só por cor. Espaçamento em constantes nomeadas, tipografia Inter com `MediaQuery.textScaler`, um único `ThemeData` Material 3, nenhum `Color(0xFF…)` fora do DS.
- Alvos de toque mínimos de 48dp; contraste alto por padrão; skeleton no lugar de spinner em listas; estados de erro e vazio explícitos.
- Offline-first no fluxo de avaliação (fases 4 e 5); ações admin exigem conexão (fase 6).
- Contratos reais apenas — nenhum campo ou endpoint não confirmado no código do backend.
- Arquivos gerados (`*.g.dart`) são versionados junto com a fonte.

## Estado herdado da Fase 0 (ponto de partida)

- Branch `feat/mobile-app` com 10 commits; `apps/mobile/simtc` versionado como base só Android; `flutter analyze` limpo e 1 smoke test.
- Backend com `PracticalAssessment.participantSignatureUrl` (migration aplicada), os dois endpoints de assinatura (bucket `signatures`, prefixo `participants/`) e `assessmentId` na resposta do sync.
- Aparelho de teste validado: motorola edge 50 fusion (Android 16), USB e Wi-Fi, com `adb reverse tcp:3001` alcançando o backend local.
- **Atenção do `fase-0-auditoria.md` que esta fase precisa resolver:** `INTERNET` ausente no manifest principal; `applicationId` de exemplo; `google_fonts` baixando fonte em runtime; banco Drift placeholder `simtc_app_db` já instalado no aparelho de teste (trocar o nome do banco, não confiar em desinstalar); `dio` mandando `application/octet-stream` por padrão em multipart; `/auth/me` sem `consultantId` (ler do JWT).

## Referência visual (export do Claude Design)

O canvas completo está versionado em `apps/mobile/docs/design/SIMTC-Mobile.dc.html` (3765 linhas, 42 quadros). Blocos:

| Linhas | Bloco | Quadros |
|---|---|---|
| 460–695 | Variante ADMIN | 1.11 Adicionar participante, 1.12 Dados do treinamento, 1.13 Consultores da sessão |
| 696–1416 | **Celular compact** | 1.1 Abertura (702), 1.2 Entrar (719), 1.3 Minhas sessões (767), 1.4 Detalhe consultor (855) e variante ADMIN (944), Checklist (1043), 1.6 Conferir e finalizar (1118), 1.7 Assinatura (1169), 1.8 Resultado (1217), 1.9 Sincronizar (1297), 1.10 Perfil (1365) |
| 1417–3383 | Tablet | as mesmas telas em 1280×800 e 800×1280, mais dois quadros "Spec para dev" (3323 e 3354) |
| 3384–3765 | Fundações e sistema de design | Justificativa de design: contexto de uso, mapeamento M3, escala tipográfica e decisões |

**Autoridade: as telas, fielmente.** Por decisão do usuário (17/09/2026), o bloco "Fundações e sistema de design" é **desconsiderado por completo** — ele registra um raciocínio que não foi seguido ao desenhar as telas (navbar charcoal, `EM_AVALIACAO` em teal, rampa própria de severidade, escala tipográfica M3 "limpa"). A implementação copia as medidas e as cores dos quadros das telas. Para o que não estiver no canvas, vale `prompt-claude-design-mobile.md`.

Esta fase usa os quadros de 1.1 Abertura (linha 702) e 1.2 Entrar (linha 719), e tira das telas 1.3 (linha 767) e 1.4 (linha 855) as medidas dos componentes-base.

**Tokens confirmados no canvas** (histograma do bloco do celular): `#1D9AA4`, `#0A6E80`, `#F5A520`, `#0F172A`, `#475569`, `#334155`, `#94A3B8`, `#E2E8F0`, `#CBD5E1`, `#F8FAFC`, `#F1F5F9`, `#1E2A34`, `#FFFFFF`. Semânticos: verde `#DCFCE7`/`#86D9A4`/`#166534`/`#15803D`; âmbar `#FFF7EC`/`#F0DCB8`/`#8A4100`/`#C2670A`/`#3D2500`; vermelho `#FEE2E2`/`#B91C1C`; mauve `#F5F0F8`/`#CFBBD8`; teal suave `#E6F6F7`/`#D6EDF0`.

**Dois pontos em que o código não copia o canvas ao pé da letra** (nenhum deles muda cor, medida ou layout):

1. O canvas usa a família de ícones **Material Symbols Outlined**; o Flutter traz Material Icons. A fase usa `Icons.*` (variantes outlined) centralizados em `AppIcons`, para que adotar um pacote de Material Symbols depois seja mudança de um arquivo só.
2. O canvas mostra mockups de status bar (relógio 08:42, ícone de sinal) — são moldura do desenho, não UI do app.

**Observação de acessibilidade, registrada sem alterar o desenho:** na navbar, o item ativo usa `#38BEC8` sobre a pastilha `#F8FAFC`, o que dá 2,3:1 num rótulo de 10 px (WCAG AA pede 4,5:1). A implementação segue o canvas; se o contraste incomodar no uso real dentro do veículo, a troca por `#0A6E80` é de uma linha em `pill_nav_bar.dart`. Fica como pendência para a revisão de acessibilidade da Fase 8.

## Mapa de Arquivos

### Novos

| Arquivo | Responsabilidade |
|---|---|
| `lib/config/app_config.dart` | `apiBaseUrl` e nome do ambiente via `--dart-define` |
| `lib/ui/core/theme/app_colors.dart` | Tokens de marca, neutros e semânticos |
| `lib/ui/core/theme/app_spacing.dart` | Escala de espaçamento e raios nomeados |
| `lib/ui/core/theme/app_typography.dart` | Escala tipográfica (Inter + JetBrains Mono) |
| `lib/ui/core/theme/app_icons.dart` | Ícones do app num ponto só |
| `lib/ui/core/theme/app_theme.dart` | `ThemeData` Material 3 mapeando os tokens |
| `lib/ui/core/widgets/app_text_field.dart` | Campo de texto do DS (rótulo, ícone, erro, senha) |
| `lib/ui/core/widgets/app_buttons.dart` | `AppPrimaryButton` e `AppSecondaryButton` |
| `lib/ui/core/widgets/app_checkbox.dart` | Checkbox quadrado do DS com rótulo |
| `lib/ui/core/widgets/inline_notice.dart` | Aviso em bloco (ícone + texto) usado no login e em estados vazios |
| `lib/ui/core/widgets/status_chip.dart` | Chip de status (participante e sessão), sempre ícone + texto |
| `lib/ui/core/widgets/severity_badge.dart` | Badge B/PM/M |
| `lib/ui/core/widgets/filter_chip_bar.dart` | Barra de filtros em pastilha com contador |
| `lib/ui/core/widgets/session_card.dart` | Linha de sessão (empresa, curso, meta, chip, progresso) |
| `lib/ui/core/widgets/pill_nav_bar.dart` | Navbar flutuante arredondada com badge |
| `lib/ui/core/widgets/skeleton.dart` | `SkeletonBox` e `SkeletonListItem` |
| `lib/ui/core/widgets/connectivity_banner.dart` | Faixa de "sem conexão" |
| `lib/ui/debug/ds_gallery_screen.dart` | Galeria dos componentes (só em debug) |
| `lib/data/services/api/api_client.dart` | Dio com base URL, `Authorization` e refresh em 401 |
| `lib/data/services/api/api_exception.dart` | Erro de API normalizado (status, mensagem do backend) |
| `lib/data/services/local/token_storage.dart` | Tokens no `flutter_secure_storage` + preferência "manter conectado" |
| `lib/data/services/local/tables.dart` | Tabelas Drift |
| `lib/data/services/connectivity_service.dart` | Estado online/offline global |
| `lib/data/models/auth_user.dart` | Usuário autenticado (`/auth/me` + `consultantId` do JWT) |
| `lib/data/repositories/auth_repository.dart` (reescrito) | Login, refresh, me, logout, esqueci a senha |
| `lib/ui/auth/login_screen.dart` (reescrito) | Tela 1.2 |
| `lib/ui/auth/login_viewmodel.dart` (reescrito) | Estado do login |
| `lib/ui/splash/splash_screen.dart` | Tela 1.1 |
| `lib/ui/splash/splash_viewmodel.dart` | Decide a rota inicial |
| `lib/ui/home/home_placeholder_screen.dart` | Tela provisória pós-login (substituída na Fase 2) |
| `lib/app_providers.dart` | `MultiProvider` único do app |
| `assets/fonts/*.ttf` | Inter 400/500/600/700 e JetBrains Mono 400/600 (offline) |
| `test/**` | Testes de tokens, componentes, Drift, ApiClient, AuthRepository e LoginViewModel |

### Modificados

| Arquivo | O que muda |
|---|---|
| `android/app/build.gradle.kts` | `namespace`/`applicationId` → `br.com.simtc.app` |
| `android/app/src/main/AndroidManifest.xml` | Permissão `INTERNET`, `android:label="SIMTC"` |
| `android/app/src/debug/AndroidManifest.xml` | `usesCleartextTraffic` para o backend local |
| `android/app/src/main/kotlin/br/com/simtc/app/MainActivity.kt` | Pacote novo (arquivo movido) |
| `pubspec.yaml` | Fontes declaradas, `mocktail` em dev_dependencies |
| `lib/main.dart` | Inicialização (banco, serviços, `allowRuntimeFetching = false`) |
| `lib/app.dart` | `MaterialApp.router` com o tema do DS e os providers |
| `lib/router.dart` | Rotas splash/login/home + redirect por autenticação |
| `lib/data/services/local/app_database.dart` | Esquema completo (7 tabelas), banco `simtc.sqlite` |
| `apps/mobile/simtc/README.md` | Como rodar apontando para dev e para produção |

### Deletados (na Task 10, quando nada mais os referencia)

`lib/utils/app_colors.dart`, `lib/utils/api_constants.dart`, `lib/data/services/api/api_service.dart`, `lib/data/repositories/evaluation_repository.dart`, `lib/data/models/evaluation_model.dart`, `lib/data/models/user_model.dart`, `lib/ui/core/widgets/custom_button.dart`, `lib/ui/core/widgets/custom_text_field.dart`, `lib/ui/dashboard/**`, `lib/ui/evaluation/**`.

## Ordem de execução

| Task | Entrega | Depende de |
|---|---|---|
| 1 | Identidade Android (`br.com.simtc.app`) + permissão de internet | — |
| 2 | `AppConfig` por `--dart-define` | — |
| 3 | Tokens + tipografia offline + tema | 2 |
| 4 | Componentes de formulário (campo, botões, checkbox, aviso) | 3 |
| 5 | Componentes de listagem e navegação + galeria em debug | 4 |
| 6 | Esquema Drift completo | — |
| 7 | `ApiClient` + `TokenStorage` | 2 |
| 8 | `AuthRepository` + modelo de usuário | 7 |
| 9 | `ConnectivityService` + providers + rotas | 8 |
| 10 | Splash + Login reais e remoção do placeholder | 5, 9 |

As tasks 1, 2, 6 e 7 não dependem do visual e podem ser executadas assim que o plano for aprovado.

---

## Task 1: Identidade do app Android e acesso à rede

**Files:**
- Modify: `apps/mobile/simtc/android/app/build.gradle.kts`
- Move: `apps/mobile/simtc/android/app/src/main/kotlin/com/example/simtc/MainActivity.kt` → `apps/mobile/simtc/android/app/src/main/kotlin/br/com/simtc/app/MainActivity.kt`
- Modify: `apps/mobile/simtc/android/app/src/main/AndroidManifest.xml`
- Modify: `apps/mobile/simtc/android/app/src/debug/AndroidManifest.xml`

**Interfaces:**
- Produces: pacote `br.com.simtc.app` (decisão do usuário de 17/09/2026) e permissão `android.permission.INTERNET` no manifest principal — sem ela, o APK release não acessa a API. O manifest de debug libera cleartext para o backend local em `http://localhost:3001` via `adb reverse`.

- [ ] **Step 1: Trocar `namespace` e `applicationId`**

Em `android/app/build.gradle.kts`, substituir:

```kotlin
    namespace = "com.example.simtc"
```

por:

```kotlin
    namespace = "br.com.simtc.app"
```

e substituir:

```kotlin
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.simtc"
```

por:

```kotlin
        applicationId = "br.com.simtc.app"
```

- [ ] **Step 2: Mover a `MainActivity` para o pacote novo**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc/android/app/src/main/kotlin"
mkdir -p br/com/simtc/app
git mv com/example/simtc/MainActivity.kt br/com/simtc/app/MainActivity.kt 2>/dev/null || mv com/example/simtc/MainActivity.kt br/com/simtc/app/MainActivity.kt
rm -rf com
ls -R br
```

Expected: `br/com/simtc/app/MainActivity.kt` existe e a pasta `com/` sumiu.

Em seguida, trocar a primeira linha do arquivo:

```kotlin
package com.example.simtc
```

por:

```kotlin
package br.com.simtc.app
```

- [ ] **Step 3: Permissão de internet e rótulo no manifest principal**

Em `android/app/src/main/AndroidManifest.xml`, substituir:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="simtc"
```

por:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Necessária no manifest principal: o APK release (sideload) não herda a
         permissão declarada nos manifests de debug/profile. -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
        android:label="SIMTC"
```

- [ ] **Step 4: Cleartext só em debug**

Substituir todo o conteúdo de `android/app/src/debug/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- A INTERNET permission é exigida pelo próprio tooling do Flutter em debug
         (hot reload, VM service). O release usa a declarada no manifest principal. -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Em desenvolvimento o app fala com o backend do PC em http://localhost:3001
         (via `adb reverse tcp:3001`). Android 9+ bloqueia cleartext por padrão;
         esta permissão vale só para builds de debug. -->
    <application android:usesCleartextTraffic="true" />
</manifest>
```

- [ ] **Step 5: Build e instalação no aparelho**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter build apk --debug
```

Expected: `No issues found!` e `✓ Built build\app\outputs\flutter-apk\app-debug.apk` (dê 600000 ms de timeout ao build).

Com o aparelho conectado (ver `README.md`), instalar e conferir o pacote e a permissão:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm list packages | grep simtc
adb shell dumpsys package br.com.simtc.app | grep -i "android.permission.INTERNET"
```

Expected: `package:br.com.simtc.app` aparece na lista e o `dumpsys` mostra `android.permission.INTERNET: granted=true`. O pacote antigo `com.example.simtc` continua instalado — remova-o com `adb uninstall com.example.simtc`, porque a partir daqui ele é outro app.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/android
git commit -m "chore(mobile): define o pacote br.com.simtc.app e libera acesso à rede"
```

---

## Task 2: Configuração de ambiente (`AppConfig`)

**Files:**
- Create: `apps/mobile/simtc/lib/config/app_config.dart`
- Create: `apps/mobile/simtc/test/config/app_config_test.dart`
- Modify: `apps/mobile/simtc/README.md`

**Interfaces:**
- Produces: `AppConfig.apiBaseUrl` (String, sem barra no fim) e `AppConfig.environment` — consumidos pelo `ApiClient` (Task 7). Padrão de desenvolvimento: `http://localhost:3001/api`. Produção (confirmada respondendo em 17/09/2026): `https://api.simtc.com.br/api`.

- [ ] **Step 1: Criar `lib/config/app_config.dart`**

```dart
/// Configuração de ambiente, resolvida em tempo de compilação.
///
/// Desenvolvimento (padrão): o app fala com o backend rodando no PC, alcançado
/// pelo aparelho via `adb reverse tcp:3001` (ver README).
///
/// Produção:
/// ```
/// flutter build apk --release \
///   --dart-define=API_BASE_URL=https://api.simtc.com.br/api \
///   --dart-define=APP_ENV=prod
/// ```
abstract final class AppConfig {
  /// URL base da API, sempre sem barra no final.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api',
  );

  /// Nome do ambiente: `dev` ou `prod`.
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static bool get isProduction => environment == 'prod';
}
```

- [ ] **Step 2: Criar `test/config/app_config_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('sem --dart-define, aponta para o backend local com o prefixo /api', () {
      expect(AppConfig.apiBaseUrl, 'http://localhost:3001/api');
      expect(AppConfig.environment, 'dev');
      expect(AppConfig.isProduction, isFalse);
    });

    test('a URL base não termina em barra (o ApiClient concatena os paths)', () {
      expect(AppConfig.apiBaseUrl.endsWith('/'), isFalse);
    });
  });
}
```

- [ ] **Step 3: Rodar os testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter test test/config/app_config_test.dart
flutter analyze
```

Expected: `All tests passed!` e `No issues found!`.

- [ ] **Step 4: Documentar os ambientes no README**

Em `apps/mobile/simtc/README.md`, logo após a seção "Comandos do dia a dia", inserir:

```markdown
## Ambientes

A URL da API é resolvida em tempo de compilação por `--dart-define`:

| Ambiente | Comando | URL |
|---|---|---|
| Desenvolvimento (padrão) | `flutter run -d <ID>` | `http://localhost:3001/api` (backend do PC, via `adb reverse`) |
| Produção | `flutter build apk --release --dart-define=API_BASE_URL=https://api.simtc.com.br/api --dart-define=APP_ENV=prod` | `https://api.simtc.com.br/api` |

Sem `--dart-define`, o app sempre aponta para o backend local — nenhuma build de desenvolvimento fala com produção por engano.
```

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/config/app_config.dart apps/mobile/simtc/test/config/app_config_test.dart apps/mobile/simtc/README.md
git commit -m "feat(mobile): configura a URL da API por ambiente com dart-define"
```

---

## Task 3: Tokens, fontes offline e tema do Design System

**Files:**
- Create: `apps/mobile/simtc/assets/fonts/Inter.ttf`, `assets/fonts/JetBrainsMono.ttf`, `assets/fonts/OFL-Inter.txt`, `assets/fonts/OFL-JetBrainsMono.txt`
- Create: `apps/mobile/simtc/lib/ui/core/theme/app_colors.dart`, `app_spacing.dart`, `app_typography.dart`, `app_icons.dart`, `app_theme.dart`
- Create: `apps/mobile/simtc/test/ui/core/theme/app_theme_test.dart`
- Modify: `apps/mobile/simtc/pubspec.yaml`

**Interfaces:**
- Produces: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIcons` e `AppTheme.light` — usados por todos os componentes (Tasks 4 e 5) e telas (Task 10). Nenhum widget usa `Color(0xFF…)`, tamanho de fonte solto ou `Icons.*` fora de `AppIcons` a partir daqui.
- Decisão: as fontes são **embutidas** (variáveis, com eixo `wght`), então o app abre com a tipografia certa mesmo sem rede na primeira execução — e `google_fonts` sai do `pubspec.yaml`.

- [ ] **Step 1: Baixar as fontes variáveis e as licenças**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc/assets"
mkdir -p fonts
curl.exe -sL -o fonts/Inter.ttf "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf"
curl.exe -sL -o fonts/JetBrainsMono.ttf "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf"
curl.exe -sL -o fonts/OFL-Inter.txt "https://github.com/google/fonts/raw/main/ofl/inter/OFL.txt"
curl.exe -sL -o fonts/OFL-JetBrainsMono.txt "https://github.com/google/fonts/raw/main/ofl/jetbrainsmono/OFL.txt"
ls -la fonts
file fonts/Inter.ttf fonts/JetBrainsMono.ttf
```

Expected: `Inter.ttf` com ~876 KB, `JetBrainsMono.ttf` com ~187 KB, os dois reconhecidos como `TrueType Font data`, e os dois arquivos de licença com alguns KB (a OFL exige distribuir a licença junto). Se algum vier com poucos bytes ou como HTML, o download falhou — refaça antes de seguir.

- [ ] **Step 2: Declarar as fontes e remover `google_fonts` do `pubspec.yaml`**

Substituir:

```yaml
  # UI
  google_fonts: ^6.2.1
  flutter_svg: ^2.0.10+1
  cached_network_image: ^3.4.1
```

por:

```yaml
  # UI — a tipografia é embutida em assets/fonts (ver lib/ui/core/theme),
  # para o app abrir com a fonte certa mesmo sem rede
  flutter_svg: ^2.0.10+1
  cached_network_image: ^3.4.1
```

e substituir:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
```

por:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter.ttf
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono.ttf
```

São fontes variáveis: um arquivo por família cobre todos os pesos, aplicados por `fontVariations` (Step 5).

- [ ] **Step 3: Criar `lib/ui/core/theme/app_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// Tokens de cor do app. Nenhum widget deve declarar `Color(0xFF…)` direto.
///
/// Marca e neutros vêm de `prompt-claude-design-mobile.md` (valores reais de
/// produção, os mesmos do painel web). Os tons semânticos foram conferidos no
/// export do Claude Design (`apps/mobile/docs/design/SIMTC-Mobile.dc.html`).
abstract final class AppColors {
  // ─── Marca ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1D9AA4);
  static const Color primaryHover = Color(0xFF167F8A);
  static const Color primaryDark = Color(0xFF0A6E80);
  static const Color primarySoft = Color(0xFFEEF9FA);

  /// Fundo de chips e tiles de ação sobre superfície branca
  static const Color primarySurface = Color(0xFFE6F6F7);

  /// Acento de marca — usado no item ativo da navbar, como no canvas
  static const Color accent = Color(0xFF38BEC8);

  static const Color cta = Color(0xFFF5A520);
  static const Color ctaHover = Color(0xFFE09510);
  static const Color ctaSoft = Color(0xFFFEF8EE);

  static const Color mauve = Color(0xFF9B80A8);
  static const Color mauveSoft = Color(0xFFF5F0F8);
  static const Color mauveBorder = Color(0xFFCFBBD8);

  static const Color charcoal = Color(0xFF1E2A34);
  static const Color charcoal2 = Color(0xFF2A3A46);

  // ─── Neutros ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color text = Color(0xFF0F172A);
  static const Color text2 = Color(0xFF334155);
  static const Color text3 = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // ─── Severidade B/PM/M — mesma escala do painel web ───────────────────────
  static const Color severityGoodBg = Color(0xFFDCFCE7);
  static const Color severityGoodInk = Color(0xFF16A34A);
  static const Color severityMediumBg = Color(0xFFFEF9C3);
  static const Color severityMediumInk = Color(0xFFCA8A04);
  static const Color severityHighBg = Color(0xFFFEE2E2);
  static const Color severityHighInk = Color(0xFFDC2626);

  // ─── Status (fundo / borda / tinta) ───────────────────────────────────────
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color successBorder = Color(0xFF86D9A4);
  static const Color successInk = Color(0xFF166534);

  static const Color warningBg = Color(0xFFFFF7EC);
  static const Color warningBorder = Color(0xFFF0DCB8);
  static const Color warningInk = Color(0xFF8A4100);

  /// Tinta de alerta mais forte — badges de pendência sobre fundo claro
  static const Color warningInkStrong = Color(0xFFC2670A);

  static const Color dangerBg = Color(0xFFFEE2E2);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color dangerInk = Color(0xFFB91C1C);

  static const Color neutralBg = Color(0xFFF1F5F9);
  static const Color neutralBorder = Color(0xFFCBD5E1);
  static const Color neutralInk = Color(0xFF334155);

  /// Sombra da navbar flutuante
  static const Color navShadow = Color(0x4715172A);
}
```

- [ ] **Step 4: Criar `lib/ui/core/theme/app_spacing.dart`**

```dart
/// Escala de espaçamento do app. Telas e componentes não usam números soltos.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Alvo de toque mínimo no Android — o consultor usa o app com o veículo em movimento
  static const double touchTarget = 48;

  /// Altura dos controles de formulário (campo de texto, botão principal)
  static const double controlHeight = 56;
}

/// Raios de borda do app.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;

  /// Pastilha: chips, navbar flutuante e badges
  static const double pill = 999;
}
```

- [ ] **Step 5: Criar `lib/ui/core/theme/app_typography.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipográfica do app, sobre as fontes variáveis embutidas em
/// `assets/fonts` (Inter para texto, JetBrains Mono para números/contadores).
///
/// Como as fontes são variáveis, cada estilo define `fontWeight` (para o
/// Flutter escolher a métrica) e `fontVariations` com o eixo `wght` (para o
/// peso ser interpolado de verdade, em vez de simulado).
abstract final class AppTypography {
  static const String interFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required double height,
    Color color = AppColors.text,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: interFamily,
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    required double height,
    Color color = AppColors.text,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  /// Título de tela ("Minhas sessões")
  static TextStyle get screenTitle =>
      _inter(size: 22, weight: FontWeight.w700, height: 1.2, letterSpacing: -0.22);

  /// Título de barra superior em fluxo empilhado ("Detalhe da sessão")
  static TextStyle get appBarTitle =>
      _inter(size: 17, weight: FontWeight.w600, height: 1.25);

  /// Título de item de lista (nome da empresa, nome do participante)
  static TextStyle get cardTitle =>
      _inter(size: 16, weight: FontWeight.w600, height: 1.3);

  /// Texto padrão
  static TextStyle get body =>
      _inter(size: 13.5, weight: FontWeight.w400, height: 1.35, color: AppColors.text3);

  /// Texto de apoio em blocos de aviso
  static TextStyle get bodySmall =>
      _inter(size: 13, weight: FontWeight.w400, height: 1.45, color: AppColors.text2);

  /// Metadados de item (data, local, CPF)
  static TextStyle get meta =>
      _inter(size: 12.5, weight: FontWeight.w400, height: 1.3, color: AppColors.text3);

  /// Rótulo de campo de formulário
  static TextStyle get fieldLabel =>
      _inter(size: 12.5, weight: FontWeight.w600, height: 1.2, color: AppColors.text3);

  /// Texto digitado em campo
  static TextStyle get fieldValue =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.3);

  /// Rótulo de chip (status, severidade, filtro)
  static TextStyle get chipLabel =>
      _inter(size: 12, weight: FontWeight.w600, height: 1.2);

  /// Rótulo de opção ao lado de um controle (checkbox, rádio)
  static TextStyle get optionLabel =>
      _inter(size: 14, weight: FontWeight.w400, height: 1.2, color: AppColors.text2);

  /// Rótulo de item da navbar
  static TextStyle get navLabel =>
      _inter(size: 10, weight: FontWeight.w600, height: 1);

  /// Texto de botão principal
  static TextStyle get button =>
      _inter(size: 16, weight: FontWeight.w700, height: 1.2, color: AppColors.surface);

  /// Link discreto ("Esqueci a senha")
  static TextStyle get link =>
      _inter(size: 13.5, weight: FontWeight.w600, height: 1.2, color: AppColors.primary);

  /// Contadores e números (filtros, badges, percentuais)
  static TextStyle get counter =>
      _mono(size: 11, weight: FontWeight.w600, height: 1.2);

  /// Campo de senha mascarado
  static TextStyle get passwordDots =>
      _mono(size: 18, weight: FontWeight.w600, height: 1.3, letterSpacing: 2.5);
}
```

- [ ] **Step 6: Criar `lib/ui/core/theme/app_icons.dart`**

```dart
import 'package:flutter/material.dart';

/// Ícones do app num ponto só.
///
/// O export do Claude Design usa Material Symbols Outlined; aqui usamos as
/// variantes equivalentes do Material Icons que já vêm com o Flutter. Trocar a
/// família depois (por exemplo, adotando um pacote de Material Symbols) é
/// mudança só deste arquivo.
abstract final class AppIcons {
  static const IconData email = Icons.mail_outlined;
  static const IconData password = Icons.lock_outlined;
  static const IconData showPassword = Icons.visibility_outlined;
  static const IconData hidePassword = Icons.visibility_off_outlined;
  static const IconData check = Icons.check;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData search = Icons.search;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData noSignal = Icons.wifi_off_outlined;
  static const IconData sync = Icons.cloud_sync_outlined;
  static const IconData syncDone = Icons.cloud_done_outlined;
  static const IconData sessions = Icons.event_note_outlined;
  static const IconData profile = Icons.person_outlined;
  static const IconData approved = Icons.check_circle_outlined;
  static const IconData pending = Icons.schedule_outlined;
  static const IconData inProgress = Icons.hourglass_top_outlined;
  static const IconData needsReview = Icons.error_outline;
  static const IconData theoryOnly = Icons.menu_book_outlined;
  static const IconData logout = Icons.logout;
}
```

- [ ] **Step 7: Criar `lib/ui/core/theme/app_theme.dart`**

```dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema Material 3 único do app, montado sobre os tokens do DS.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.surface,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.cta,
      onSecondary: AppColors.surface,
      tertiary: AppColors.mauve,
      onTertiary: AppColors.surface,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceMuted,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.dangerInk,
      onError: AppColors.surface,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.dangerInk,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: AppTypography.interFamily,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.appBarTitle,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppTypography.bodySmall.copyWith(color: AppColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: AppTypography.screenTitle,
        titleMedium: AppTypography.cardTitle,
        titleSmall: AppTypography.appBarTitle,
        bodyMedium: AppTypography.body,
        bodySmall: AppTypography.meta,
        labelLarge: AppTypography.button,
        labelMedium: AppTypography.fieldLabel,
        labelSmall: AppTypography.navLabel,
      ),
    );
  }
}
```

- [ ] **Step 8: Criar `test/ui/core/theme/app_theme_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/theme/app_typography.dart';

void main() {
  group('AppTheme', () {
    testWidgets('mapeia os tokens de marca para o ColorScheme', (tester) async {
      late ThemeData theme;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.surface);
      expect(theme.colorScheme.secondary, AppColors.cta);
      expect(theme.colorScheme.error, AppColors.dangerInk);
      expect(theme.useMaterial3, isTrue);
    });

    test('usa a tipografia embutida, não uma fonte do sistema', () {
      expect(AppTheme.light.textTheme.headlineSmall!.fontFamily, AppTypography.interFamily);
      expect(AppTypography.counter.fontFamily, AppTypography.monoFamily);
    });

    test('estilos variáveis carregam o eixo wght correspondente ao peso', () {
      final style = AppTypography.button;
      expect(style.fontWeight, FontWeight.w700);
      expect(
        style.fontVariations,
        contains(const FontVariation('wght', 700)),
      );
    });
  });
}
```

- [ ] **Step 9: Rodar os testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter pub get
flutter analyze
flutter test test/ui/core/theme/app_theme_test.dart
```

Expected: `No issues found!` e `All tests passed!`. O `flutter analyze` ainda pode acusar `google_fonts` se algum arquivo do placeholder o importar — nesta fase nenhum importa; se acusar, pare e reporte em vez de mexer no placeholder.

- [ ] **Step 10: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/assets/fonts apps/mobile/simtc/lib/ui/core/theme apps/mobile/simtc/test/ui/core/theme apps/mobile/simtc/pubspec.yaml apps/mobile/simtc/pubspec.lock
git commit -m "feat(mobile): adiciona tokens, tipografia embutida e tema do design system"
```

---

## Task 4: Componentes de formulário do DS

**Files:**
- Create: `apps/mobile/simtc/lib/ui/core/widgets/app_text_field.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/app_buttons.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/app_checkbox.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/inline_notice.dart`
- Create: `apps/mobile/simtc/test/ui/core/widgets/form_widgets_test.dart`

**Interfaces:**
- Consumes: `AppColors`, `AppSpacing`, `AppRadius`, `AppTypography`, `AppIcons` (Task 3).
- Produces, usados pela tela de Login (Task 10) e pelas telas das fases seguintes:
  - `AppTextField({required String label, required TextEditingController controller, IconData? icon, String? hintText, String? errorText, bool obscureText = false, VoidCallback? onToggleObscure, TextInputType? keyboardType, TextInputAction? textInputAction, bool enabled = true, List<String>? autofillHints, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, FocusNode? focusNode})`
  - `AppPrimaryButton({required String label, VoidCallback? onPressed, bool isLoading = false, IconData? icon})`
  - `AppSecondaryButton({required String label, VoidCallback? onPressed, IconData? icon})`
  - `AppCheckbox({required bool value, required ValueChanged<bool> onChanged, required String label})`
  - `InlineNotice({required IconData icon, required String message, NoticeTone tone = NoticeTone.neutral})` e `enum NoticeTone { neutral, warning, danger, success }`
- Medidas do canvas (quadro `2b`): campo com altura mínima 56, raio 8, borda 1,5 px (`borderStrong` em repouso, `primary` em foco), ícone 20 px, texto 16; botão principal com altura 56, raio 12; checkbox 22×22, raio 6; aviso com raio 8 e padding 12.

- [ ] **Step 1: Criar `lib/ui/core/widgets/app_text_field.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Campo de texto do Design System: rótulo acima, ícone à esquerda, borda que
/// reage a foco e erro, e ação opcional à direita (ex.: mostrar/ocultar senha).
///
/// Componente sem regra de negócio — recebe estado e devolve eventos.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.icon,
    this.hintText,
    this.errorText,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final String? hintText;
  final String? errorText;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final List<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  Color get _borderColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.borderStrong;
  }

  Color get _iconColor {
    if (widget.errorText != null) return AppColors.dangerInk;
    if (_isFocused) return AppColors.primary;
    return AppColors.text3;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(),
        const SizedBox(height: AppSpacing.sm - 1),
        _buildInput(),
        if (widget.errorText != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          _buildError(),
        ],
      ],
    );
  }

  Widget _buildLabel() {
    return Text(widget.label, style: AppTypography.fieldLabel);
  }

  Widget _buildInput() {
    return Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
      decoration: BoxDecoration(
        color: widget.enabled ? AppColors.surface : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: _borderColor, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: _iconColor),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(child: _buildTextField()),
          if (widget.onToggleObscure != null) _buildObscureToggle(),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.obscureText
          ? AppTypography.passwordDots
          : AppTypography.fieldValue,
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: widget.hintText,
        hintStyle: AppTypography.fieldValue.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildObscureToggle() {
    return Semantics(
      button: true,
      label: widget.obscureText ? 'Mostrar senha' : 'Ocultar senha',
      child: InkWell(
        onTap: widget.onToggleObscure,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // A área de toque é o tamanho do filho: um ícone de 22 com padding
        // pequeno daria ~38 dp, abaixo do mínimo de 48 dp exigido para uso com
        // o veículo em movimento.
        child: SizedBox(
          width: AppSpacing.touchTarget,
          height: AppSpacing.touchTarget,
          child: Center(
            child: Icon(
              widget.obscureText ? AppIcons.showPassword : AppIcons.hidePassword,
              size: 22,
              color: AppColors.text3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Text(
      widget.errorText!,
      style: AppTypography.meta.copyWith(color: AppColors.dangerInk),
    );
  }
}
```

Adicione `import '../theme/app_icons.dart';` junto aos outros imports — o alternador de senha usa `AppIcons`.

- [ ] **Step 2: Criar `lib/ui/core/widgets/app_buttons.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Botão principal do app: altura de 56, cantos de 12 e cor de marca.
///
/// Enquanto `isLoading`, o botão não responde ao toque mas mantém a cor cheia —
/// cinza de desabilitado só aparece quando não há ação disponível.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor:
              isLoading ? AppColors.primary : AppColors.borderStrong,
          disabledForegroundColor: AppColors.surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
        child: isLoading ? _buildSpinner() : _buildContent(),
      ),
    );
  }

  Widget _buildSpinner() {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.surface),
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            style: AppTypography.button,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Botão secundário: mesma caixa do principal, contorno na cor de marca.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.controlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          disabledForegroundColor: AppColors.textMuted,
          side: BorderSide(
            color: onPressed == null ? AppColors.border : AppColors.primary,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.button,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.button.copyWith(color: AppColors.primaryDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Criar `lib/ui/core/widgets/app_checkbox.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Checkbox quadrado do DS com rótulo ao lado. A área de toque cobre rótulo e
/// caixa, e respeita o alvo mínimo de 48 dp.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBox(),
              const SizedBox(width: AppSpacing.sm + 2),
              Flexible(
                child: Text(label, style: AppTypography.optionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBox() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(AppIcons.check, size: 17, color: AppColors.surface)
          : null,
    );
  }
}
```

- [ ] **Step 4: Criar `lib/ui/core/widgets/inline_notice.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tom de um aviso em bloco.
enum NoticeTone { neutral, warning, danger, success }

/// Aviso em bloco: ícone à esquerda e texto explicativo.
///
/// Usado para mensagens que precisam ficar visíveis na tela (sem conexão, ação
/// indisponível, resultado de uma operação), em vez de um toast que some.
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.icon,
    required this.message,
    this.tone = NoticeTone.neutral,
  });

  final IconData icon;
  final String message;
  final NoticeTone tone;

  Color get _background => switch (tone) {
        NoticeTone.neutral => AppColors.background,
        NoticeTone.warning => AppColors.warningBg,
        NoticeTone.danger => AppColors.dangerBg,
        NoticeTone.success => AppColors.successBg,
      };

  Color get _border => switch (tone) {
        NoticeTone.neutral => AppColors.border,
        NoticeTone.warning => AppColors.warningBorder,
        NoticeTone.danger => AppColors.dangerBorder,
        NoticeTone.success => AppColors.successBorder,
      };

  Color get _ink => switch (tone) {
        NoticeTone.neutral => AppColors.text2,
        NoticeTone.warning => AppColors.warningInk,
        NoticeTone.danger => AppColors.dangerInk,
        NoticeTone.success => AppColors.successInk,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _background,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _ink),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: _ink),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Criar `test/ui/core/widgets/form_widgets_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_colors.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/app_buttons.dart';
import 'package:simtc/ui/core/widgets/app_checkbox.dart';
import 'package:simtc/ui/core/widgets/app_text_field.dart';
import 'package:simtc/ui/core/widgets/inline_notice.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
    ),
  );
}

void main() {
  group('AppTextField', () {
    testWidgets('mostra rótulo, aceita digitação e exibe o erro', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _pump(
        tester,
        AppTextField(
          label: 'E-mail',
          controller: controller,
          icon: AppIcons.email,
          errorText: 'E-mail ou senha incorretos',
        ),
      );

      expect(find.text('E-mail'), findsOneWidget);
      expect(find.text('E-mail ou senha incorretos'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'carla@simtc.com.br');
      expect(controller.text, 'carla@simtc.com.br');
    });

    testWidgets('o alternador de senha aparece só quando há callback e dispara o evento',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var toggles = 0;

      await _pump(
        tester,
        AppTextField(
          label: 'Senha',
          controller: controller,
          icon: AppIcons.password,
          obscureText: true,
          onToggleObscure: () => toggles++,
        ),
      );

      expect(find.byIcon(AppIcons.showPassword), findsOneWidget);
      await tester.tap(find.byIcon(AppIcons.showPassword));
      expect(toggles, 1);
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('dispara a ação quando habilitado', (tester) async {
      var taps = 0;
      await _pump(tester, AppPrimaryButton(label: 'Entrar', onPressed: () => taps++));

      await tester.tap(find.text('Entrar'));
      expect(taps, 1);
    });

    testWidgets('em carregamento mostra o indicador, esconde o rótulo e não responde ao toque',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        AppPrimaryButton(label: 'Entrar', isLoading: true, onPressed: () => taps++),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);

      await tester.tap(find.byType(AppPrimaryButton));
      expect(taps, 0);
    });

    testWidgets('sem ação, fica desabilitado', (tester) async {
      await _pump(tester, const AppPrimaryButton(label: 'Entrar'));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });
  });

  group('AppCheckbox', () {
    testWidgets('o toque devolve o valor invertido', (tester) async {
      bool? received;
      await _pump(
        tester,
        AppCheckbox(
          value: false,
          label: 'Manter conectado',
          onChanged: (v) => received = v,
        ),
      );

      await tester.tap(find.text('Manter conectado'));
      expect(received, isTrue);
    });

    testWidgets('marcado, mostra o check', (tester) async {
      await _pump(
        tester,
        AppCheckbox(value: true, label: 'Manter conectado', onChanged: (_) {}),
      );

      expect(find.byIcon(AppIcons.check), findsOneWidget);
    });
  });

  group('InlineNotice', () {
    testWidgets('mostra ícone e mensagem, e colore conforme o tom', (tester) async {
      await _pump(
        tester,
        const InlineNotice(
          icon: AppIcons.noSignal,
          message: 'Sem conexão no momento.',
          tone: NoticeTone.warning,
        ),
      );

      expect(find.byIcon(AppIcons.noSignal), findsOneWidget);
      expect(find.text('Sem conexão no momento.'), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(InlineNotice), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.warningBg);
    });
  });
}
```

- [ ] **Step 6: Rodar análise e testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter test test/ui/core/widgets/form_widgets_test.dart
```

Expected: `No issues found!` e `All tests passed!` (8 testes). Saída limpa, sem avisos de overflow.

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/ui/core/widgets apps/mobile/simtc/test/ui/core/widgets
git commit -m "feat(mobile): adiciona campo, botões, checkbox e aviso do design system"
```

---

## Task 5: Componentes de listagem, navegação e carregamento + galeria em debug

**Files:**
- Create: `apps/mobile/simtc/lib/ui/core/widgets/status_chip.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/severity_badge.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/filter_chip_bar.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/session_card.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/pill_nav_bar.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/skeleton.dart`
- Create: `apps/mobile/simtc/lib/ui/core/widgets/connectivity_banner.dart`
- Create: `apps/mobile/simtc/lib/ui/debug/ds_gallery_screen.dart`
- Create: `apps/mobile/simtc/test/ui/core/widgets/display_widgets_test.dart`

**Interfaces:**
- Consumes: tokens da Task 3.
- Produces (todos sem regra de negócio — recebem rótulo, ícone e tom prontos; o mapeamento de `ParticipantStatus`/`NoteType` para esses parâmetros é feito pelas telas nas Fases 2 a 4):
  - `enum StatusTone { neutral, info, warning, success, danger, mauve }`
  - `StatusChip({required String label, required IconData icon, required StatusTone tone, bool dashedBorder = false})`
  - `enum Severity { b, pm, m }` e `SeverityBadge({required Severity severity})` — rótulos literais "B", "PM" e "M"
  - `FilterChipBar({required List<FilterChipData> items, required int selectedIndex, required ValueChanged<int> onSelect})` e `FilterChipData({required String label, int? count})`
  - `SessionCard({required String companyName, required String courseName, required String meta, required Widget statusChip, Color accentColor = AppColors.border, String? progressLabel, double? progressValue, VoidCallback? onTap})`
  - `PillNavBar({required int currentIndex, required ValueChanged<int> onSelect, required List<PillNavItem> items})` e `PillNavItem({required IconData icon, required String label, int badgeCount = 0})`
  - `SkeletonBox({double? width, double height, double radius})` e `SkeletonListItem()`
  - `ConnectivityBanner({required bool isOffline, String? message})`
- Medidas do canvas (quadro `2c`, linhas 319-406): chip com raio pastilha, padding 5/11/5/9, ícone 14 e rótulo 12; card com borda superior e inferior de 1,5 px na cor do status e padding 15/20; barra de progresso de 6 px; navbar flutuante com 64 de altura, 16 de margem lateral, 12 do rodapé, raio pastilha, fundo `#F8FAFC` opaco e sombra `0 8 24 rgba(15,23,42,.28)`; item ativo com ícone e rótulo em `#38BEC8` sobre pastilha `rgba(56,190,200,.16)`, item inativo em `#94A3B8`; badge `#C2670A` com borda de 2 px na cor do fundo da navbar.

- [ ] **Step 1: Criar `lib/ui/core/widgets/status_chip.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tom semântico de um chip de status.
enum StatusTone { neutral, info, warning, success, danger, mauve }

/// Chip de status: sempre ícone + texto, nunca só cor (daltonismo e leitura
/// rápida com atenção dividida).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
    this.dashedBorder = false,
  });

  final String label;
  final IconData icon;
  final StatusTone tone;

  /// Usado para status que não pertencem a este consultor (ex.: participante em
  /// avaliação com outra pessoa): mesma cor, contorno mais fraco.
  final bool dashedBorder;

  Color get _background => switch (tone) {
        StatusTone.neutral => AppColors.neutralBg,
        StatusTone.info => AppColors.primarySurface,
        StatusTone.warning => AppColors.warningBg,
        StatusTone.success => AppColors.successBg,
        StatusTone.danger => AppColors.dangerBg,
        StatusTone.mauve => AppColors.mauveSoft,
      };

  Color get _border => switch (tone) {
        StatusTone.neutral => AppColors.neutralBorder,
        StatusTone.info => AppColors.primary,
        StatusTone.warning => AppColors.warningBorder,
        StatusTone.success => AppColors.successBorder,
        StatusTone.danger => AppColors.dangerBorder,
        StatusTone.mauve => AppColors.mauveBorder,
      };

  Color get _ink => switch (tone) {
        StatusTone.neutral => AppColors.neutralInk,
        StatusTone.info => AppColors.primaryDark,
        StatusTone.warning => AppColors.warningInk,
        StatusTone.success => AppColors.successInk,
        StatusTone.danger => AppColors.dangerInk,
        StatusTone.mauve => AppColors.mauve,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 11, 5),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: dashedBorder ? _border.withValues(alpha: 0.5) : _border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(label, style: AppTypography.chipLabel.copyWith(color: _ink)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Criar `lib/ui/core/widgets/severity_badge.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Severidade de uma infração. Os rótulos aparecem literalmente como "B", "PM"
/// e "M" — a mesma convenção do painel web, reconhecida por consultores e
/// admins. A explicação de cada nota vem do texto da própria nota, nunca de
/// expandir a sigla.
enum Severity { b, pm, m }

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({super.key, required this.severity});

  final Severity severity;

  String get _label => switch (severity) {
        Severity.b => 'B',
        Severity.pm => 'PM',
        Severity.m => 'M',
      };

  Color get _background => switch (severity) {
        Severity.b => AppColors.severityGoodBg,
        Severity.pm => AppColors.severityMediumBg,
        Severity.m => AppColors.severityHighBg,
      };

  Color get _ink => switch (severity) {
        Severity.b => AppColors.severityGoodInk,
        Severity.pm => AppColors.severityMediumInk,
        Severity.m => AppColors.severityHighInk,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        _label,
        textAlign: TextAlign.center,
        style: AppTypography.chipLabel.copyWith(color: _ink),
      ),
    );
  }
}
```

- [ ] **Step 3: Criar `lib/ui/core/widgets/filter_chip_bar.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Um filtro da barra: rótulo e, opcionalmente, um contador.
class FilterChipData {
  const FilterChipData({required this.label, this.count});

  final String label;
  final int? count;
}

/// Barra horizontal de filtros em pastilha (Todos / Pendentes / Meus / ...).
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<FilterChipData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs + 2),
            _buildChip(items[i], i == selectedIndex, () => onSelect(i)),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(FilterChipData item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.surface : AppColors.text2;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.borderStrong,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: AppTypography.chipLabel.copyWith(color: ink, fontSize: 12.5),
            ),
            if (item.count != null) ...[
              const SizedBox(width: AppSpacing.xs + 1),
              Text(
                '${item.count}',
                style: AppTypography.counter.copyWith(
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Criar `lib/ui/core/widgets/session_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Linha de sessão da Home: empresa, curso, metadados, chip de status e, quando
/// houver, o progresso de avaliação. O traço superior e inferior usa a cor do
/// status, como no canvas.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.companyName,
    required this.courseName,
    required this.meta,
    required this.statusChip,
    this.accentColor = AppColors.border,
    this.progressLabel,
    this.progressValue,
    this.onTap,
  });

  final String companyName;
  final String courseName;
  final String meta;
  final Widget statusChip;
  final Color accentColor;
  final String? progressLabel;

  /// Progresso de 0 a 1; quando nulo, a barra não aparece.
  final double? progressValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg - 1,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.symmetric(
            horizontal: BorderSide(color: accentColor, width: 1.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.md),
            _buildStatusRow(),
            if (progressValue != null) ...[
              const SizedBox(height: AppSpacing.md),
              _buildProgressBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(companyName, style: AppTypography.cardTitle),
              const SizedBox(height: AppSpacing.xs + 1),
              Text(courseName, style: AppTypography.body),
              const SizedBox(height: AppSpacing.xs + 1),
              Text(meta, style: AppTypography.meta),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        const Icon(AppIcons.chevronRight, size: 24, color: AppColors.text3),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        statusChip,
        if (progressLabel != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              progressLabel!,
              style: AppTypography.meta.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: progressValue,
        minHeight: 6,
        backgroundColor: AppColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }
}
```

- [ ] **Step 5: Criar `lib/ui/core/widgets/pill_nav_bar.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Item da navbar flutuante.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;

  /// Quantidade pendente exibida em cima do ícone; 0 esconde o badge.
  final int badgeCount;
}

/// Navbar em pastilha flutuante (Sessões / Sincronizar / Perfil).
///
/// Fundo opaco, não translúcido: o app é usado dentro do veículo, com luz
/// variável, onde contraste previsível vale mais que o efeito de vidro.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<PillNavItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.all(AppSpacing.sm - 2),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.navShadow,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _buildItem(items[i], i == currentIndex, () => onSelect(i))),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(PillNavItem item, bool isSelected, VoidCallback onTap) {
    final ink = isSelected ? AppColors.accent : AppColors.textMuted;

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 22, color: ink),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.label, style: AppTypography.navLabel.copyWith(color: ink)),
                ],
              ),
              if (item.badgeCount > 0) _buildBadge(item.badgeCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Positioned(
      top: 4,
      child: Transform.translate(
        offset: const Offset(14, 0),
        child: Container(
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.warningInkStrong,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.background, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            '$count',
            style: AppTypography.navLabel.copyWith(
              color: AppColors.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Criar `lib/ui/core/widgets/skeleton.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Bloco cinza pulsante usado no lugar de spinner enquanto a lista carrega.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Item de lista em carregamento, no mesmo ritmo visual do `SessionCard`.
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg - 1,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 190, height: 16),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 240, height: 13),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: AppSpacing.md),
          SkeletonBox(width: 110, height: 24, radius: AppRadius.pill),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Criar `lib/ui/core/widgets/connectivity_banner.dart`**

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Faixa fina de "sem conexão", exibida abaixo do cabeçalho.
///
/// Fica oculta quando há conexão — o estado normal não ocupa espaço.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.isOffline,
    this.message,
  });

  final bool isOffline;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.warningBg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(AppIcons.offline, size: 16, color: AppColors.warningInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message ?? 'Sem conexão — o app continua funcionando com os dados baixados.',
              style: AppTypography.meta.copyWith(color: AppColors.warningInk),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 8: Criar `lib/ui/debug/ds_gallery_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_checkbox.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/connectivity_banner.dart';
import '../core/widgets/filter_chip_bar.dart';
import '../core/widgets/inline_notice.dart';
import '../core/widgets/pill_nav_bar.dart';
import '../core/widgets/session_card.dart';
import '../core/widgets/severity_badge.dart';
import '../core/widgets/skeleton.dart';
import '../core/widgets/status_chip.dart';

/// Galeria dos componentes do Design System, acessível só em build de debug
/// (rota `/ds`). Serve para conferir cor, espaçamento e toque no aparelho real,
/// sem depender de uma tela de produção estar pronta.
class DsGalleryScreen extends StatefulWidget {
  const DsGalleryScreen({super.key});

  @override
  State<DsGalleryScreen> createState() => _DsGalleryScreenState();
}

class _DsGalleryScreenState extends State<DsGalleryScreen> {
  final TextEditingController _textController =
      TextEditingController(text: 'carla.mendes@simtc.com.br');
  final TextEditingController _passwordController =
      TextEditingController(text: 'segredo123');
  bool _obscure = true;
  bool _checked = true;
  int _filterIndex = 0;
  int _navIndex = 0;

  @override
  void dispose() {
    _textController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              120,
            ),
            children: [
              _buildSection('Formulário', _buildFormSamples()),
              _buildSection('Status e severidade', _buildChipSamples()),
              _buildSection('Filtros', _buildFilterSample()),
              _buildSection('Sessão', _buildSessionSamples()),
              _buildSection('Carregamento', const SkeletonListItem()),
              _buildSection(
                'Conectividade',
                const ConnectivityBanner(isOffline: true),
              ),
            ],
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildNavBar()),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }

  Widget _buildFormSamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'E-mail',
          controller: _textController,
          icon: AppIcons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Senha',
          controller: _passwordController,
          icon: AppIcons.password,
          obscureText: _obscure,
          onToggleObscure: () => setState(() => _obscure = !_obscure),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: 'Campo com erro',
          controller: _textController,
          icon: AppIcons.email,
          errorText: 'E-mail ou senha incorretos',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCheckbox(
          value: _checked,
          label: 'Manter conectado',
          onChanged: (v) => setState(() => _checked = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(label: 'Entrar', onPressed: () {}),
        const SizedBox(height: AppSpacing.md),
        const AppPrimaryButton(label: 'Entrando', isLoading: true),
        const SizedBox(height: AppSpacing.md),
        const AppPrimaryButton(label: 'Sem ação'),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(label: 'Cancelar', onPressed: () {}),
        const SizedBox(height: AppSpacing.lg),
        const InlineNotice(
          icon: AppIcons.noSignal,
          message: 'Sem sinal: as ações administrativas ficam indisponíveis.',
          tone: NoticeTone.warning,
        ),
      ],
    );
  }

  Widget _buildChipSamples() {
    return const Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        StatusChip(label: 'Pendente', icon: AppIcons.pending, tone: StatusTone.neutral),
        StatusChip(label: 'Em avaliação', icon: AppIcons.inProgress, tone: StatusTone.warning),
        StatusChip(label: 'Aprovado', icon: AppIcons.approved, tone: StatusTone.success),
        StatusChip(label: 'Reavaliar', icon: AppIcons.needsReview, tone: StatusTone.danger),
        StatusChip(label: 'Somente teórica', icon: AppIcons.theoryOnly, tone: StatusTone.mauve),
        StatusChip(label: 'Em andamento', icon: AppIcons.sessions, tone: StatusTone.info),
        SeverityBadge(severity: Severity.b),
        SeverityBadge(severity: Severity.pm),
        SeverityBadge(severity: Severity.m),
      ],
    );
  }

  Widget _buildFilterSample() {
    return FilterChipBar(
      selectedIndex: _filterIndex,
      onSelect: (i) => setState(() => _filterIndex = i),
      items: const [
        FilterChipData(label: 'Hoje', count: 2),
        FilterChipData(label: 'Semana', count: 5),
        FilterChipData(label: 'Concluídas', count: 12),
      ],
    );
  }

  Widget _buildSessionSamples() {
    return Column(
      children: [
        SessionCard(
          companyName: 'Bracell Celulose',
          courseName: 'Direção Preventiva — Leve',
          meta: 'Hoje · 08:00 · Lençóis Paulista/SP',
          accentColor: AppColors.warningBorder,
          statusChip: const StatusChip(
            label: 'Em andamento',
            icon: AppIcons.inProgress,
            tone: StatusTone.warning,
          ),
          progressLabel: '4 de 12 avaliados',
          progressValue: 4 / 12,
          onTap: () {},
        ),
        SessionCard(
          companyName: 'Mineração Serra Azul',
          courseName: 'Direção Preventiva — Pesado',
          meta: '15 set · 13:30 · Itabira/MG',
          statusChip: const StatusChip(
            label: 'Planejado',
            icon: AppIcons.sessions,
            tone: StatusTone.info,
          ),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildNavBar() {
    return PillNavBar(
      currentIndex: _navIndex,
      onSelect: (i) => setState(() => _navIndex = i),
      items: const [
        PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
        PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: 3),
        PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
      ],
    );
  }
}
```

- [ ] **Step 9: Criar `test/ui/core/widgets/display_widgets_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/ui/core/theme/app_icons.dart';
import 'package:simtc/ui/core/theme/app_theme.dart';
import 'package:simtc/ui/core/widgets/filter_chip_bar.dart';
import 'package:simtc/ui/core/widgets/pill_nav_bar.dart';
import 'package:simtc/ui/core/widgets/session_card.dart';
import 'package:simtc/ui/core/widgets/severity_badge.dart';
import 'package:simtc/ui/core/widgets/skeleton.dart';
import 'package:simtc/ui/core/widgets/status_chip.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('StatusChip mostra ícone e texto juntos, nunca só cor', (tester) async {
    await _pump(
      tester,
      const StatusChip(
        label: 'Aprovado',
        icon: AppIcons.approved,
        tone: StatusTone.success,
      ),
    );

    expect(find.text('Aprovado'), findsOneWidget);
    expect(find.byIcon(AppIcons.approved), findsOneWidget);
  });

  testWidgets('SeverityBadge usa os rótulos literais B, PM e M', (tester) async {
    await _pump(
      tester,
      const Row(
        children: [
          SeverityBadge(severity: Severity.b),
          SeverityBadge(severity: Severity.pm),
          SeverityBadge(severity: Severity.m),
        ],
      ),
    );

    expect(find.text('B'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.textContaining('Melhorar'), findsNothing);
  });

  testWidgets('FilterChipBar devolve o índice tocado', (tester) async {
    int? selected;
    await _pump(
      tester,
      FilterChipBar(
        selectedIndex: 0,
        onSelect: (i) => selected = i,
        items: const [
          FilterChipData(label: 'Todos', count: 8),
          FilterChipData(label: 'Pendentes', count: 3),
        ],
      ),
    );

    await tester.tap(find.text('Pendentes'));
    expect(selected, 1);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('SessionCard mostra os dados, responde ao toque e esconde a barra sem progresso',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      SessionCard(
        companyName: 'Bracell',
        courseName: 'Direção Preventiva',
        meta: 'Hoje · Itabira/MG',
        statusChip: const StatusChip(
          label: 'Planejado',
          icon: AppIcons.sessions,
          tone: StatusTone.info,
        ),
        onTap: () => taps++,
      ),
    );

    expect(find.text('Bracell'), findsOneWidget);
    expect(find.text('Direção Preventiva'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.tap(find.text('Bracell'));
    expect(taps, 1);
  });

  testWidgets('PillNavBar marca o item ativo, mostra o badge e devolve o toque',
      (tester) async {
    int? selected;
    await _pump(
      tester,
      PillNavBar(
        currentIndex: 0,
        onSelect: (i) => selected = i,
        items: const [
          PillNavItem(icon: AppIcons.sessions, label: 'Sessões'),
          PillNavItem(icon: AppIcons.sync, label: 'Sincronizar', badgeCount: 3),
          PillNavItem(icon: AppIcons.profile, label: 'Perfil'),
        ],
      ),
    );

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Perfil'));
    expect(selected, 2);
  });

  testWidgets('SkeletonListItem anima sem quebrar o layout', (tester) async {
    await _pump(tester, const SkeletonListItem());
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byType(SkeletonBox), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 10: Rodar análise e testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter test test/ui/core/widgets
```

Expected: `No issues found!` e `All tests passed!` (14 testes somando com os da Task 4). Nenhum aviso de `RenderFlex overflowed` na saída.

- [ ] **Step 11: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/ui/core/widgets apps/mobile/simtc/lib/ui/debug apps/mobile/simtc/test/ui/core/widgets
git commit -m "feat(mobile): adiciona chips, card de sessão, navbar, skeleton e galeria do DS"
```

---

## Task 6: Esquema Drift completo

**Files:**
- Create: `apps/mobile/simtc/lib/data/services/local/tables.dart`
- Rewrite: `apps/mobile/simtc/lib/data/services/local/app_database.dart`
- Regenerate: `apps/mobile/simtc/lib/data/services/local/app_database.g.dart`
- Create: `apps/mobile/simtc/test/data/services/local/app_database_test.dart`

**Interfaces:**
- Produces: `AppDatabase` (aceita um `QueryExecutor` opcional, para testes com banco em memória) com as sete tabelas usadas pelas fases seguintes — `Sessions` (Fase 2), `Participants` (Fase 3), `AssessmentCategories`/`Infractions`/`InfractionNotes` (Fase 3), `LocalAssessments`/`LocalAssessmentItems` (Fases 4 e 5) — e `enum LocalSyncStatus { draft, pendingSync, synced, error }`.
- O banco passa a se chamar `simtc` (arquivo `simtc.sqlite`). O placeholder usava `simtc_app_db` com `schemaVersion` 1; manter o nome antigo faria o Drift abrir o arquivo já instalado nos aparelhos de teste sem criar as tabelas novas (ver `fase-0-auditoria.md`, seção 1.3).
- Nesta fase as tabelas nascem vazias: nenhuma tela grava nelas ainda. O esquema entra inteiro agora para que nenhuma fase seguinte precise migrar banco.

- [ ] **Step 1: Criar `lib/data/services/local/tables.dart`**

```dart
import 'package:drift/drift.dart';

/// Situação de sincronização de uma avaliação feita no aparelho.
enum LocalSyncStatus {
  /// Em preenchimento; ainda não finalizada pelo consultor.
  draft,

  /// Finalizada e aguardando envio.
  pendingSync,

  /// Aceita pelo backend.
  synced,

  /// O envio falhou; fica na fila para nova tentativa.
  error,
}

/// Cache das sessões de `GET /training-sessions`.
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get companyName => text()();
  TextColumn get companyLogoUrl => text().nullable()();
  TextColumn get courseName => text()();
  TextColumn get city => text()();
  TextColumn get state => text()();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();

  /// Quando esta linha veio da API — mostra ao usuário a idade do cache.
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cache dos participantes de uma sessão (`TrainingParticipant`).
class Participants extends Table {
  /// Id do `TrainingParticipant` (não o do `Participant`).
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get name => text()();
  TextColumn get cpf => text()();
  TextColumn get email => text().nullable()();
  TextColumn get participationType => text()();
  TextColumn get status => text()();
  TextColumn get assignedConsultantId => text().nullable()();
  TextColumn get assignedConsultantName => text().nullable()();

  /// Score da avaliação já sincronizada, quando houver.
  RealColumn get score => real().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: categorias de avaliação (`GET /assessment-categories`).
class AssessmentCategories extends Table {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: infrações de cada categoria.
class Infractions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text().references(AssessmentCategories, #id)();
  TextColumn get description => text()();
  IntColumn get order => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Catálogo: notas de cada infração (B, PM, M) com o peso usado no score.
class InfractionNotes extends Table {
  TextColumn get id => text()();
  TextColumn get infractionId => text().references(Infractions, #id)();

  /// `B`, `PM` ou `M`, como vem do backend.
  TextColumn get noteType => text()();
  TextColumn get comment => text().nullable()();

  /// `deduction` do backend — o cálculo do score usa este valor, não constantes.
  IntColumn get deduction => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Avaliação preenchida no aparelho (rascunho, fila de envio e histórico).
class LocalAssessments extends Table {
  /// Id local (uuid), gerado no aparelho — o id do backend só existe após o sync.
  TextColumn get id => text()();

  /// `TrainingParticipant.id`; um participante tem no máximo uma avaliação.
  TextColumn get trainingParticipantId => text()();
  TextColumn get sessionId => text()();

  /// Id devolvido por `POST /practical-assessments/sync`, usado para enviar a assinatura.
  TextColumn get remoteAssessmentId => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get syncStatus => textEnum<LocalSyncStatus>()();

  /// Caminho do arquivo de assinatura no próprio aparelho.
  TextColumn get signaturePath => text().nullable()();

  /// A assinatura já foi aceita pelo backend?
  BoolColumn get signatureUploaded => boolean().withDefault(const Constant(false))();

  /// Mensagem do último erro de envio, mostrada na tela de Sincronização.
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {trainingParticipantId},
      ];
}

/// Nota marcada em uma infração dentro de uma avaliação local.
class LocalAssessmentItems extends Table {
  TextColumn get id => text()();
  TextColumn get localAssessmentId => text().references(LocalAssessments, #id)();
  TextColumn get infractionId => text()();

  /// `InfractionNote.id` escolhido — é o que o sync envia.
  TextColumn get infractionNoteId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  /// Uma nota por infração em cada avaliação: remarcar substitui a anterior.
  @override
  List<Set<Column>> get uniqueKeys => [
        {localAssessmentId, infractionId},
      ];
}
```

- [ ] **Step 2: Substituir o conteúdo de `lib/data/services/local/app_database.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart' show LocalSyncStatus;

part 'app_database.g.dart';

/// Banco local do app.
///
/// O arquivo se chama `simtc.sqlite` — nome diferente do usado pelo scaffold
/// placeholder (`simtc_app_db`), para que aparelhos com a versão antiga
/// instalada não abram um banco sem as tabelas novas.
@DriftDatabase(
  tables: [
    Sessions,
    Participants,
    AssessmentCategories,
    Infractions,
    InfractionNotes,
    LocalAssessments,
    LocalAssessmentItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // O esquema usa chaves estrangeiras (participante → sessão, infração →
          // categoria); no SQLite elas só são aplicadas com este pragma ligado.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'simtc');
}
```

- [ ] **Step 3: Gerar o código do Drift**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
dart run build_runner build --delete-conflicting-outputs
```

Expected: termina com `Succeeded after ...` e sem erros; `lib/data/services/local/app_database.g.dart` passa a conter as sete tabelas (`$SessionsTable`, `$ParticipantsTable`, …). Dê 600000 ms de timeout. Se aparecer erro de `EvaluationTable` órfã, confirme que o `app_database.dart` foi substituído por completo.

- [ ] **Step 4: Criar `test/data/services/local/app_database_test.dart`**

```dart
// Sem `package:drift/drift.dart` aqui: ele exporta uma função `isNull()`
// obsoleta que colide com o matcher `isNull` do flutter_test. O que este teste
// usa (`NativeDatabase`, `SqliteException`) vem de `drift/native.dart`.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/local/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertSession(String id) {
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            companyName: 'Bracell Celulose',
            courseName: 'Direção Preventiva',
            city: 'Lençóis Paulista',
            state: 'SP',
            status: 'EM_ANDAMENTO',
            cachedAt: DateTime(2026, 9, 17, 8),
          ),
        );
  }

  test('grava e lê uma sessão do cache', () async {
    await insertSession('sess-1');

    final rows = await db.select(db.sessions).get();
    expect(rows, hasLength(1));
    expect(rows.single.companyName, 'Bracell Celulose');
    expect(rows.single.date, isNull);
  });

  test('participante exige uma sessão existente (chave estrangeira ativa)', () async {
    expect(
      () => db.into(db.participants).insert(
            ParticipantsCompanion.insert(
              id: 'tp-1',
              sessionId: 'sessao-inexistente',
              name: 'João Pedro',
              cpf: '12345678909',
              participationType: 'TEORICA_E_PRATICA',
              status: 'PENDENTE',
              cachedAt: DateTime(2026, 9, 17, 8),
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('avaliação local guarda o status de sincronização como enum', () async {
    await db.into(db.localAssessments).insert(
          LocalAssessmentsCompanion.insert(
            id: 'local-1',
            trainingParticipantId: 'tp-1',
            sessionId: 'sess-1',
            date: DateTime(2026, 9, 17),
            startTime: DateTime(2026, 9, 17, 9, 30),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 17, 9, 30),
            updatedAt: DateTime(2026, 9, 17, 9, 30),
          ),
        );

    final row = await db.select(db.localAssessments).getSingle();
    expect(row.syncStatus, LocalSyncStatus.draft);
    expect(row.signatureUploaded, isFalse);
    expect(row.attemptCount, 0);
  });

  test('um participante não pode ter duas avaliações locais', () async {
    Future<void> insert(String id) {
      return db.into(db.localAssessments).insert(
            LocalAssessmentsCompanion.insert(
              id: id,
              trainingParticipantId: 'tp-1',
              sessionId: 'sess-1',
              date: DateTime(2026, 9, 17),
              startTime: DateTime(2026, 9, 17, 9, 30),
              syncStatus: LocalSyncStatus.draft,
              createdAt: DateTime(2026, 9, 17, 9, 30),
              updatedAt: DateTime(2026, 9, 17, 9, 30),
            ),
          );
    }

    await insert('local-1');
    expect(() => insert('local-2'), throwsA(isA<SqliteException>()));
  });

  test('uma infração só pode ter uma nota marcada por avaliação', () async {
    await db.into(db.localAssessments).insert(
          LocalAssessmentsCompanion.insert(
            id: 'local-1',
            trainingParticipantId: 'tp-1',
            sessionId: 'sess-1',
            date: DateTime(2026, 9, 17),
            startTime: DateTime(2026, 9, 17, 9, 30),
            syncStatus: LocalSyncStatus.draft,
            createdAt: DateTime(2026, 9, 17, 9, 30),
            updatedAt: DateTime(2026, 9, 17, 9, 30),
          ),
        );

    Future<void> mark(String id, String noteId) {
      return db.into(db.localAssessmentItems).insert(
            LocalAssessmentItemsCompanion.insert(
              id: id,
              localAssessmentId: 'local-1',
              infractionId: 'inf-1',
              infractionNoteId: noteId,
              updatedAt: DateTime(2026, 9, 17, 9, 35),
            ),
          );
    }

    await mark('item-1', 'note-b');
    expect(() => mark('item-2', 'note-m'), throwsA(isA<SqliteException>()));
  });
}
```

- [ ] **Step 5: Rodar os testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter test test/data/services/local/app_database_test.dart
```

Expected: `No issues found!` e `All tests passed!` (5 testes). O sqlite nativo do host já foi verificado nesta máquina — se der erro de biblioteca, pare e reporte em vez de trocar o teste.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/data/services/local apps/mobile/simtc/test/data/services/local
git commit -m "feat(mobile): cria o esquema Drift completo do app"
```

---

## Task 7: `ApiClient` com refresh automático e `TokenStorage`

**Files:**
- Create: `apps/mobile/simtc/lib/data/services/api/api_exception.dart`
- Create: `apps/mobile/simtc/lib/data/services/api/api_client.dart`
- Create: `apps/mobile/simtc/lib/data/services/local/token_storage.dart`
- Create: `apps/mobile/simtc/test/data/services/api/api_client_test.dart`
- Modify: `apps/mobile/simtc/pubspec.yaml` (adiciona `mocktail` em `dev_dependencies`)

**Interfaces:**
- Consumes: `AppConfig.apiBaseUrl` (Task 2).
- Produces:
  - `ApiException({required int? statusCode, required String message, bool isNetworkError})`, com `ApiException.fromDio(DioException)` traduzindo o corpo de erro do NestJS (`{ message, error, statusCode }`, onde `message` pode ser uma lista de mensagens de validação) e erros de rede para "Sem conexão com o servidor".
  - `ApiClient({required String baseUrl, Dio? dio, required Future<String?> Function() readAccessToken, required Future<String?> Function() readRefreshToken, required Future<void> Function(String accessToken, String refreshToken) onTokensRenewed, required Future<void> Function() onSessionExpired})` com `get`, `post`, `patch`, `delete` e `upload` devolvendo `Response<T>` do dio, e lançando `ApiException`.
  - `TokenStorage` com `readAccess()`, `readRefresh()`, `persist({accessToken, refreshToken})`, `clear()`, `readKeepSignedIn()`, `setKeepSignedIn(bool)`.
- Comportamento do refresh: em `401` que não seja da própria rota `/auth/refresh`, o cliente chama `POST /auth/refresh` com o refresh token, salva o par novo por `onTokensRenewed` e repete a requisição original **uma vez**. Sem refresh token, ou se o refresh falhar, chama `onSessionExpired` e propaga o erro. Refreshes simultâneos compartilham a mesma chamada.
- O `ApiClient` não conhece `AuthRepository` (recebe funções), então não há dependência circular entre eles.

- [ ] **Step 1: Adicionar `mocktail` ao `pubspec.yaml`**

Substituir:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

por:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  mocktail: ^1.0.4
```

- [ ] **Step 2: Criar `lib/data/services/api/api_exception.dart`**

```dart
import 'package:dio/dio.dart';

/// Erro de API já traduzido para algo exibível ao usuário.
///
/// O backend responde `{ "message": ..., "error": ..., "statusCode": ... }`,
/// onde `message` é um texto ou, nos erros de validação do NestJS, uma lista.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetworkError;

  static const String _networkMessage =
      'Sem conexão com o servidor. Verifique a internet e tente de novo.';
  static const String _unexpectedMessage =
      'Não foi possível completar a operação. Tente de novo.';

  factory ApiException.fromDio(DioException error) {
    final isNetwork = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.unknown => error.response == null,
      _ => false,
    };

    if (isNetwork) {
      return const ApiException(message: _networkMessage, isNetworkError: true);
    }

    final response = error.response;
    return ApiException(
      statusCode: response?.statusCode,
      message: _messageFrom(response?.data) ?? _unexpectedMessage,
    );
  }

  static String? _messageFrom(Object? data) {
    if (data is! Map) return null;
    final message = data['message'];
    if (message is String && message.isNotEmpty) return message;
    if (message is List && message.isNotEmpty) {
      return message.map((item) => '$item').join('\n');
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
```

- [ ] **Step 3: Criar `lib/data/services/api/api_client.dart`**

```dart
import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Cliente HTTP do app.
///
/// Concentra três coisas que não devem ficar espalhadas pelos repositories: a
/// URL base do ambiente, o cabeçalho `Authorization` e a renovação do token
/// quando o backend responde 401.
///
/// Não conhece o `AuthRepository`: recebe funções para ler e gravar os tokens,
/// o que evita dependência circular entre os dois.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.readAccessToken,
    required this.readRefreshToken,
    required this.onTokensRenewed,
    required this.onSessionExpired,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      // O tratamento de erro é nosso; o dio não deve lançar antes da hora.
      validateStatus: (status) => status != null && status < 400,
    );
    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  final Dio _dio;
  final Future<String?> Function() readAccessToken;
  final Future<String?> Function() readRefreshToken;
  final Future<void> Function(String accessToken, String refreshToken) onTokensRenewed;
  final Future<void> Function() onSessionExpired;

  static const String refreshPath = '/auth/refresh';

  /// Refresh em andamento — chamadas paralelas esperam o mesmo resultado.
  Future<String?>? _pendingRefresh;

  Dio get dio => _dio;

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path != refreshPath) {
      final token = await readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final response = error.response;
    final isExpiredToken = response?.statusCode == 401 &&
        error.requestOptions.path != refreshPath &&
        error.requestOptions.extra['retriedAfterRefresh'] != true;

    if (!isExpiredToken) {
      handler.next(error);
      return;
    }

    final newToken = await _refreshToken();
    if (newToken == null) {
      handler.next(error);
      return;
    }

    try {
      final options = error.requestOptions;
      options.headers['Authorization'] = 'Bearer $newToken';
      options.extra['retriedAfterRefresh'] = true;
      final retried = await _dio.fetch<dynamic>(options);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Renova o par de tokens. Devolve o access token novo, ou null se a sessão
  /// acabou (aí o app precisa mandar o usuário para o login).
  Future<String?> _refreshToken() {
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await onSessionExpired();
      return null;
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refreshToken': refreshToken},
      );
      final data = response.data ?? const {};
      final accessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (accessToken == null || newRefreshToken == null) {
        await onSessionExpired();
        return null;
      }

      await onTokensRenewed(accessToken, newRefreshToken);
      return accessToken;
    } on DioException {
      await onSessionExpired();
      return null;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _run(() => _dio.get<T>(path, queryParameters: queryParameters));
  }

  Future<Response<T>> post<T>(String path, {Object? data}) {
    return _run(() => _dio.post<T>(path, data: data));
  }

  Future<Response<T>> patch<T>(String path, {Object? data}) {
    return _run(() => _dio.patch<T>(path, data: data));
  }

  Future<Response<T>> delete<T>(String path) {
    return _run(() => _dio.delete<T>(path));
  }

  /// Envio de arquivo (usado pela assinatura do participante, na Fase 5).
  ///
  /// O `contentType` da parte precisa ser informado: sem ele o dio manda
  /// `application/octet-stream` e o backend recusa com 400.
  Future<Response<T>> upload<T>(String path, FormData formData) {
    return _run(
      () => _dio.patch<T>(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      ),
    );
  }

  Future<Response<T>> _run<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
```

- [ ] **Step 4: Criar `lib/data/services/local/token_storage.dart`**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda os tokens de autenticação no armazenamento seguro do Android.
///
/// A preferência "manter conectado" decide se o par de tokens é gravado: sem
/// ela, a sessão vale só enquanto o app estiver aberto.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'auth.accessToken';
  static const String _refreshKey = 'auth.refreshToken';
  static const String _keepSignedInKey = 'auth.keepSignedIn';

  Future<String?> readAccess() => _storage.read(key: _accessKey);

  Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  /// Padrão: manter conectado (app de campo, usado várias vezes por dia).
  Future<bool> readKeepSignedIn() async {
    final value = await _storage.read(key: _keepSignedInKey);
    return value != 'false';
  }

  Future<void> setKeepSignedIn(bool value) {
    return _storage.write(key: _keepSignedInKey, value: '$value');
  }
}
```

- [ ] **Step 5: Criar `test/data/services/api/api_client_test.dart`**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';

/// Resposta programada para o adaptador falso.
class _Reply {
  const _Reply(this.statusCode, [this.body = const <String, dynamic>{}]);

  final int statusCode;
  final Map<String, dynamic> body;
}

/// Adaptador que responde sem rede: cada requisição consome a próxima resposta
/// da fila e fica registrada para inspeção no teste.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.replies);

  final List<_Reply> replies;
  final List<RequestOptions> requests = [];
  DioExceptionType? throwNetworkError;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    if (throwNetworkError != null) {
      throw DioException(requestOptions: options, type: throwNetworkError!);
    }

    final reply = replies.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeAdapter adapter;
  late List<String> renewedTokens;
  late int sessionExpiredCalls;
  String? accessToken;
  String? refreshToken;

  ApiClient buildClient(List<_Reply> replies) {
    adapter = _FakeAdapter(replies);
    renewedTokens = [];
    sessionExpiredCalls = 0;
    final dio = Dio()..httpClientAdapter = adapter;

    return ApiClient(
      baseUrl: 'http://localhost:3001/api',
      dio: dio,
      readAccessToken: () async => accessToken,
      readRefreshToken: () async => refreshToken,
      onTokensRenewed: (access, refresh) async {
        accessToken = access;
        refreshToken = refresh;
        renewedTokens.add(access);
      },
      onSessionExpired: () async => sessionExpiredCalls++,
    );
  }

  setUp(() {
    accessToken = 'token-velho';
    refreshToken = 'refresh-1';
  });

  test('envia o access token no cabeçalho Authorization', () async {
    final client = buildClient([const _Reply(200, {'ok': true})]);

    await client.get<Map<String, dynamic>>('/training-sessions');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer token-velho');
  });

  test('em 401, renova o token e repete a requisição uma vez', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(200, {'accessToken': 'token-novo', 'refreshToken': 'refresh-2'}),
      const _Reply(200, {'data': []}),
    ]);

    final response = await client.get<Map<String, dynamic>>('/training-sessions');

    expect(response.statusCode, 200);
    expect(renewedTokens, ['token-novo']);
    expect(adapter.requests.map((r) => r.path).toList(),
        ['/training-sessions', '/auth/refresh', '/training-sessions']);
    expect(adapter.requests.last.headers['Authorization'], 'Bearer token-novo');
    expect(sessionExpiredCalls, 0);
  });

  test('sem refresh token, avisa que a sessão expirou e propaga o 401', () async {
    refreshToken = null;
    final client = buildClient([const _Reply(401, {'message': 'Unauthorized'})]);

    await expectLater(
      client.get<Map<String, dynamic>>('/auth/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(sessionExpiredCalls, 1);
  });

  test('se o refresh também falhar, não repete a requisição original', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(401, {'message': 'Refresh token inválido ou expirado'}),
    ]);

    await expectLater(
      client.get<Map<String, dynamic>>('/training-sessions'),
      throwsA(isA<ApiException>()),
    );
    expect(sessionExpiredCalls, 1);
    expect(adapter.requests, hasLength(2));
  });

  test('a rota de refresh não leva Authorization', () async {
    final client = buildClient([
      const _Reply(401, {'message': 'Unauthorized'}),
      const _Reply(200, {'accessToken': 'token-novo', 'refreshToken': 'refresh-2'}),
      const _Reply(200, {'data': []}),
    ]);

    await client.get<Map<String, dynamic>>('/training-sessions');

    final refreshRequest =
        adapter.requests.firstWhere((r) => r.path == ApiClient.refreshPath);
    expect(refreshRequest.headers.containsKey('Authorization'), isFalse);
  });

  test('traduz a mensagem de erro do backend', () async {
    final client = buildClient([
      const _Reply(409, {
        'message': 'Participantes aprovados não podem ser reavaliados',
        'error': 'Conflict',
        'statusCode': 409,
      }),
    ]);

    await expectLater(
      client.post<Map<String, dynamic>>('/practical-assessments/assign'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)
            .having((e) => e.message, 'message',
                'Participantes aprovados não podem ser reavaliados'),
      ),
    );
  });

  test('junta as mensagens de validação do NestJS', () async {
    final client = buildClient([
      const _Reply(400, {
        'message': ['email must be an email', 'password should not be empty'],
        'statusCode': 400,
      }),
    ]);

    await expectLater(
      client.post<Map<String, dynamic>>('/auth/login'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message',
          'email must be an email\npassword should not be empty')),
    );
  });

  test('erro de rede vira ApiException marcada como falta de conexão', () async {
    final client = buildClient([]);
    adapter.throwNetworkError = DioExceptionType.connectionError;

    await expectLater(
      client.get<Map<String, dynamic>>('/training-sessions'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isNetworkError, 'isNetworkError', isTrue)
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
  });
}
```

- [ ] **Step 6: Rodar os testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter pub get
flutter analyze
flutter test test/data/services/api/api_client_test.dart
```

Expected: `No issues found!` e `All tests passed!` (8 testes).

- [ ] **Step 7: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/data/services apps/mobile/simtc/test/data/services/api apps/mobile/simtc/pubspec.yaml apps/mobile/simtc/pubspec.lock
git commit -m "feat(mobile): cliente HTTP com refresh automático e guarda de tokens"
```

---

## Task 8: Sessão e `AuthRepository`

**Files:**
- Create: `apps/mobile/simtc/lib/data/models/auth_user.dart`
- Create: `apps/mobile/simtc/lib/data/services/auth_session.dart`
- Rewrite: `apps/mobile/simtc/lib/data/repositories/auth_repository.dart`
- Create: `apps/mobile/simtc/test/data/repositories/auth_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `ApiException`, `TokenStorage` (Task 7); `Result<T>` de `lib/utils/result.dart` (já existe no scaffold, não recriar).
- Produces:
  - `enum AppUserRole { admin, consultant }` e `AuthUser({required String id, required String name, required String email, required AppUserRole role, String? consultantId})`, com `isAdmin`.
  - `AuthSession`: guarda o par de tokens em memória, grava no `TokenStorage` só quando "manter conectado" está ligado, e expõe `onExpired` (stream) para o app voltar ao login. Entregue ao `ApiClient` como as quatro funções que ele pede — é isso que evita dependência circular entre cliente HTTP e repositório.
  - `AuthRepository extends ChangeNotifier` com `currentUser`, `isAuthenticated`, `login({email, password, keepSignedIn})`, `restoreSession()`, `requestPasswordReset(email)` e `logout()`, todos devolvendo `Result`.
- Contratos reais consumidos: `POST /auth/login` `{email, password}` → `{accessToken, refreshToken}`; `GET /auth/me` → `{id, name, email, role}`; `POST /auth/forgot-password` `{email}` → `204`; `POST /auth/logout` → `204`.
- `consultantId` não vem do `/auth/me`: é lido do payload do access token (o JWT carrega `consultantId`), conforme `fase-0-auditoria.md`. Perfis sem `role` `ADMIN` ou `CONSULTANT` (ex.: `CLIENT`, que usa o portal web) são recusados no app.

- [ ] **Step 1: Criar `lib/data/models/auth_user.dart`**

```dart
import 'dart:convert';

/// Perfis aceitos pelo app. `CLIENT` existe no backend, mas usa o portal web.
enum AppUserRole { admin, consultant }

/// Usuário autenticado no app.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.consultantId,
  });

  final String id;
  final String name;
  final String email;
  final AppUserRole role;

  /// Id do `Consultant` vinculado, lido do JWT. Sem ele o usuário não consegue
  /// avaliar (o backend recusa a atribuição de participantes).
  final String? consultantId;

  bool get isAdmin => role == AppUserRole.admin;

  /// Monta o usuário a partir de `GET /auth/me`. Devolve null quando o perfil
  /// não é aceito no app.
  static AuthUser? fromMeJson(
    Map<String, dynamic> json, {
    String? consultantId,
  }) {
    final role = parseRole(json['role'] as String?);
    if (role == null) return null;

    return AuthUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      consultantId: consultantId,
    );
  }

  static AppUserRole? parseRole(String? value) => switch (value) {
        'ADMIN' => AppUserRole.admin,
        'CONSULTANT' => AppUserRole.consultant,
        _ => null,
      };
}

/// Lê o payload de um JWT sem validar a assinatura — a validação é do backend;
/// aqui só precisamos de um campo que o `/auth/me` não devolve.
Map<String, dynamic>? decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } on FormatException {
    return null;
  }
}
```

- [ ] **Step 2: Criar `lib/data/services/auth_session.dart`**

```dart
import 'dart:async';

import 'local/token_storage.dart';

/// Par de tokens da sessão corrente.
///
/// Fica em memória durante o uso e só vai para o armazenamento seguro quando o
/// usuário escolhe "manter conectado" — sem isso, fechar o app encerra a sessão.
class AuthSession {
  AuthSession(this._storage);

  final TokenStorage _storage;
  final StreamController<void> _expiredController =
      StreamController<void>.broadcast();

  String? _accessToken;
  String? _refreshToken;
  bool _keepSignedIn = true;

  /// Emite quando a sessão acabou (refresh recusado ou logout do servidor).
  Stream<void> get onExpired => _expiredController.stream;

  bool get keepSignedIn => _keepSignedIn;

  Future<String?> readAccessToken() async => _accessToken;

  Future<String?> readRefreshToken() async => _refreshToken;

  /// Carrega o que estiver salvo do uso anterior. Devolve true se havia sessão.
  Future<bool> restoreFromStorage() async {
    _keepSignedIn = await _storage.readKeepSignedIn();
    if (!_keepSignedIn) {
      await _storage.clear();
      return false;
    }

    _accessToken = await _storage.readAccess();
    _refreshToken = await _storage.readRefresh();
    return _accessToken != null && _refreshToken != null;
  }

  Future<void> start({
    required String accessToken,
    required String refreshToken,
    required bool keepSignedIn,
  }) async {
    _keepSignedIn = keepSignedIn;
    await _storage.setKeepSignedIn(keepSignedIn);
    await updateTokens(accessToken, refreshToken);
  }

  /// Usado também pelo `ApiClient` quando o token é renovado.
  Future<void> updateTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (_keepSignedIn) {
      await _storage.persist(accessToken: accessToken, refreshToken: refreshToken);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.clear();
  }

  /// Chamado pelo `ApiClient` quando não dá mais para renovar o token.
  Future<void> expire() async {
    await clear();
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  void dispose() => _expiredController.close();
}
```

- [ ] **Step 3: Substituir o conteúdo de `lib/data/repositories/auth_repository.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../utils/result.dart';
import '../models/auth_user.dart';
import '../services/api/api_client.dart';
import '../services/api/api_exception.dart';
import '../services/auth_session.dart';

/// Autenticação do app — sem nenhum atalho de desenvolvimento: se a API recusa,
/// o login falha.
class AuthRepository extends ChangeNotifier {
  AuthRepository({required ApiClient apiClient, required AuthSession session})
      : _api = apiClient,
        _session = session;

  final ApiClient _api;
  final AuthSession _session;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static const String _invalidCredentials = 'E-mail ou senha incorretos.';
  static const String _roleNotAllowed =
      'Esta conta não tem acesso ao app. Use o portal web.';
  static const String _sessionEnded = 'Sua sessão expirou. Entre de novo.';

  /// Entra com e-mail e senha. A senha não é aparada: espaços podem fazer parte dela.
  Future<Result<AuthUser>> login({
    required String email,
    required String password,
    required bool keepSignedIn,
  }) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data ?? const <String, dynamic>{};
      final accessToken = data['accessToken'] as String?;
      final refreshToken = data['refreshToken'] as String?;
      if (accessToken == null || refreshToken == null) {
        return Failure(Exception('login sem tokens'), _invalidCredentials);
      }

      await _session.start(
        accessToken: accessToken,
        refreshToken: refreshToken,
        keepSignedIn: keepSignedIn,
      );

      final user = await _loadCurrentUser(accessToken);
      if (user == null) {
        await logout();
        return Failure(Exception('perfil não permitido'), _roleNotAllowed);
      }

      _currentUser = user;
      notifyListeners();
      return Success(user);
    } on ApiException catch (error) {
      await _session.clear();
      return Failure(
        error,
        error.statusCode == 401 ? _invalidCredentials : error.message,
      );
    }
  }

  /// Tenta retomar a sessão salva na abertura do app.
  Future<Result<AuthUser>> restoreSession() async {
    final hasTokens = await _session.restoreFromStorage();
    if (!hasTokens) {
      return Failure(Exception('sem sessão salva'), _sessionEnded);
    }

    try {
      final accessToken = await _session.readAccessToken();
      final user = await _loadCurrentUser(accessToken ?? '');
      if (user == null) {
        await logout();
        return Failure(Exception('perfil não permitido'), _roleNotAllowed);
      }

      _currentUser = user;
      notifyListeners();
      return Success(user);
    } on ApiException catch (error) {
      if (error.statusCode == 401) await _session.clear();
      return Failure(error, error.isNetworkError ? error.message : _sessionEnded);
    }
  }

  /// Pede o e-mail de redefinição de senha. O backend responde 204 mesmo quando
  /// o e-mail não existe, para não revelar quais contas estão cadastradas — a
  /// tela mostra a mesma mensagem nos dois casos.
  Future<Result<void>> requestPasswordReset(String email) async {
    try {
      await _api.post<void>('/auth/forgot-password', data: {'email': email.trim()});
      return const Success<void>(null);
    } on ApiException catch (error) {
      return Failure(error, error.message);
    }
  }

  Future<void> logout() async {
    try {
      await _api.post<void>('/auth/logout');
    } on ApiException {
      // Sem rede ou token já inválido: a sessão local é limpa de qualquer forma.
    }
    await _session.clear();
    _currentUser = null;
    notifyListeners();
  }

  /// Chamado quando o `ApiClient` desiste de renovar o token.
  void handleSessionExpired() {
    if (_currentUser == null) return;
    _currentUser = null;
    notifyListeners();
  }

  Future<AuthUser?> _loadCurrentUser(String accessToken) async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    final data = response.data ?? const <String, dynamic>{};
    final payload = decodeJwtPayload(accessToken);
    return AuthUser.fromMeJson(
      data,
      consultantId: payload?['consultantId'] as String?,
    );
  }
}
```

- [ ] **Step 4: Criar `test/data/repositories/auth_repository_test.dart`**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/data/services/api/api_client.dart';
import 'package:simtc/data/services/api/api_exception.dart';
import 'package:simtc/data/services/auth_session.dart';
import 'package:simtc/data/services/local/token_storage.dart';
import 'package:simtc/utils/result.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockTokenStorage extends Mock implements TokenStorage {}

/// JWT de teste: só o payload importa (a assinatura não é verificada no app).
String fakeJwt(Map<String, dynamic> payload) {
  String encode(Map<String, dynamic> part) =>
      base64Url.encode(utf8.encode(jsonEncode(part))).replaceAll('=', '');
  return '${encode({'alg': 'HS256'})}.${encode(payload)}.assinatura';
}

Response<Map<String, dynamic>> jsonResponse(
  String path,
  Map<String, dynamic> body, {
  int status = 200,
}) {
  return Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: path),
    statusCode: status,
    data: body,
  );
}

void main() {
  late _MockApiClient api;
  late _MockTokenStorage storage;
  late AuthSession session;
  late AuthRepository repository;

  const accessToken = 'cabecalho.payload.assinatura';

  setUp(() {
    api = _MockApiClient();
    storage = _MockTokenStorage();
    session = AuthSession(storage);
    repository = AuthRepository(apiClient: api, session: session);

    when(() => storage.persist(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
    when(() => storage.setKeepSignedIn(any())).thenAnswer((_) async {});
    when(() => storage.readKeepSignedIn()).thenAnswer((_) async => true);
    when(() => storage.readAccess()).thenAnswer((_) async => null);
    when(() => storage.readRefresh()).thenAnswer((_) async => null);
  });

  tearDown(() => session.dispose());

  void stubLogin({required String token}) {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenAnswer((_) async => jsonResponse(
              '/auth/login',
              {'accessToken': token, 'refreshToken': 'refresh-1'},
            ));
  }

  void stubMe(Map<String, dynamic> body) {
    when(() => api.get<Map<String, dynamic>>('/auth/me'))
        .thenAnswer((_) async => jsonResponse('/auth/me', body));
  }

  test('login guarda a sessão e traz o consultantId do JWT', () async {
    final token = fakeJwt({'sub': 'user-1', 'consultantId': 'consultant-9'});
    stubLogin(token: token);
    stubMe({
      'id': 'user-1',
      'name': 'Carla Mendes',
      'email': 'carla@simtc.com.br',
      'role': 'CONSULTANT',
    });

    final result = await repository.login(
      email: ' carla@simtc.com.br ',
      password: 'segredo 123',
      keepSignedIn: true,
    );

    expect(result, isA<Success<AuthUser>>());
    final user = (result as Success<AuthUser>).data;
    expect(user.name, 'Carla Mendes');
    expect(user.role, AppUserRole.consultant);
    expect(user.consultantId, 'consultant-9');
    expect(repository.isAuthenticated, isTrue);

    final sent = verify(() => api.post<Map<String, dynamic>>('/auth/login',
        data: captureAny(named: 'data'))).captured.single as Map<String, dynamic>;
    expect(sent['email'], 'carla@simtc.com.br', reason: 'e-mail é aparado');
    expect(sent['password'], 'segredo 123', reason: 'a senha não pode ser aparada');

    verify(() => storage.persist(
          accessToken: token,
          refreshToken: 'refresh-1',
        )).called(1);
  });

  test('sem "manter conectado", os tokens não vão para o armazenamento', () async {
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Admin', 'email': 'a@b.com', 'role': 'ADMIN'});

    await repository.login(
      email: 'a@b.com',
      password: '123456',
      keepSignedIn: false,
    );

    verifyNever(() => storage.persist(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        ));
    expect(await session.readAccessToken(), isNotNull,
        reason: 'a sessão continua válida enquanto o app estiver aberto');
  });

  test('perfil CLIENT é recusado com mensagem própria', () async {
    stubLogin(token: fakeJwt({'sub': 'user-2'}));
    stubMe({'id': 'user-2', 'name': 'Cliente', 'email': 'c@b.com', 'role': 'CLIENT'});
    when(() => api.post<void>('/auth/logout'))
        .thenAnswer((_) async => Response<void>(requestOptions: RequestOptions(path: '/auth/logout')));

    final result = await repository.login(
      email: 'c@b.com',
      password: '123456',
      keepSignedIn: true,
    );

    expect(result, isA<Failure<AuthUser>>());
    expect((result as Failure<AuthUser>).message, contains('portal web'));
    expect(repository.isAuthenticated, isFalse);
  });

  test('401 no login vira mensagem de credencial incorreta', () async {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenThrow(const ApiException(message: 'Credenciais inválidas', statusCode: 401));

    final result = await repository.login(
      email: 'x@y.com',
      password: 'errada',
      keepSignedIn: true,
    );

    expect((result as Failure<AuthUser>).message, 'E-mail ou senha incorretos.');
  });

  test('falta de rede no login preserva a mensagem de conexão', () async {
    when(() => api.post<Map<String, dynamic>>('/auth/login', data: any(named: 'data')))
        .thenThrow(const ApiException(
      message: 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
      isNetworkError: true,
    ));

    final result = await repository.login(
      email: 'x@y.com',
      password: '123456',
      keepSignedIn: true,
    );

    expect((result as Failure<AuthUser>).message, contains('Sem conexão'));
  });

  test('restoreSession sem tokens salvos falha sem chamar a API', () async {
    final result = await repository.restoreSession();

    expect(result, isA<Failure<AuthUser>>());
    verifyNever(() => api.get<Map<String, dynamic>>('/auth/me'));
  });

  test('restoreSession com tokens salvos recupera o usuário', () async {
    when(() => storage.readAccess()).thenAnswer((_) async => accessToken);
    when(() => storage.readRefresh()).thenAnswer((_) async => 'refresh-1');
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});

    final result = await repository.restoreSession();

    expect(result, isA<Success<AuthUser>>());
    expect(repository.currentUser!.name, 'Carla');
  });

  test('logout limpa a sessão mesmo se a API falhar', () async {
    stubLogin(token: fakeJwt({'sub': 'user-1'}));
    stubMe({'id': 'user-1', 'name': 'Carla', 'email': 'c@s.com', 'role': 'CONSULTANT'});
    await repository.login(email: 'c@s.com', password: '123456', keepSignedIn: true);

    when(() => api.post<void>('/auth/logout'))
        .thenThrow(const ApiException(message: 'offline', isNetworkError: true));

    await repository.logout();

    expect(repository.isAuthenticated, isFalse);
    expect(await session.readAccessToken(), isNull);
    verify(() => storage.clear()).called(greaterThanOrEqualTo(1));
  });

  test('esqueci a senha chama o endpoint e trata a resposta vazia', () async {
    when(() => api.post<void>('/auth/forgot-password', data: any(named: 'data')))
        .thenAnswer((_) async =>
            Response<void>(requestOptions: RequestOptions(path: '/auth/forgot-password'), statusCode: 204));

    final result = await repository.requestPasswordReset(' carla@simtc.com.br ');

    expect(result, isA<Success<void>>());
    final sent = verify(() => api.post<void>('/auth/forgot-password',
        data: captureAny(named: 'data'))).captured.single as Map<String, dynamic>;
    expect(sent['email'], 'carla@simtc.com.br');
  });
}
```

- [ ] **Step 5: Rodar os testes**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter test test/data/repositories/auth_repository_test.dart
```

Expected: `No issues found!` e `All tests passed!` (9 testes). Se o `mocktail` reclamar de argumento não registrado, use `registerFallbackValue` no `setUpAll` — não troque a asserção.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/data/models/auth_user.dart apps/mobile/simtc/lib/data/services/auth_session.dart apps/mobile/simtc/lib/data/repositories/auth_repository.dart apps/mobile/simtc/test/data/repositories
git commit -m "feat(mobile): autenticação real contra a API com sessão e refresh"
```

---

## Task 9: Conectividade, providers e rotas

**Files:**
- Create: `apps/mobile/simtc/lib/data/services/connectivity_service.dart`
- Create: `apps/mobile/simtc/lib/app_providers.dart`
- Rewrite: `apps/mobile/simtc/lib/router.dart`
- Create: `apps/mobile/simtc/test/data/services/connectivity_service_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (Task 6), `ApiClient`/`TokenStorage` (Task 7), `AuthSession`/`AuthRepository` (Task 8), `AppConfig` (Task 2).
- Produces:
  - `ConnectivityService extends ChangeNotifier` com `isOnline`, `onReconnected` (stream que emite só na transição offline→online) e `initialize()`/`dispose()`. É criado **uma vez** no `MultiProvider` do app; nenhuma tela o instancia. A partir da Fase 5 é ele que dispara a fila de sincronização.
  - `AppDependencies.create({required AppDatabase database})`, que instancia tudo na ordem certa e expõe `providers` (para o `MultiProvider`), as instâncias (`authRepository`, `apiClient`, …) e `dispose()`.
  - `createRouter(AuthRepository auth)` → `GoRouter` com `/splash`, `/login`, `/home` e, só em debug, `/ds` (galeria do DS). O redirecionamento manda para `/login` quem não está autenticado e tira de `/login` quem já está.
- `connectivity_plus` informa se existe rede, não se o servidor responde: uma chamada ainda pode falhar com o aparelho "online". Por isso o estado de erro das telas nunca depende só deste serviço.

- [ ] **Step 1: Criar `lib/data/services/connectivity_service.dart`**

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Estado de conectividade do aparelho, compartilhado por todo o app.
///
/// Criado uma única vez no `MultiProvider` (nunca dentro de uma tela), porque a
/// volta da conexão precisa ser percebida em qualquer lugar do app — é o gatilho
/// da sincronização automática a partir da Fase 5.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<void> _reconnectedController =
      StreamController<void>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Emite quando o aparelho volta a ter rede (só na transição offline→online).
  Stream<void> get onReconnected => _reconnectedController.stream;

  Future<void> initialize() async {
    _apply(await _connectivity.checkConnectivity(), notify: false);
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results, {bool notify = true}) {
    final isOnline = results.any((result) => result != ConnectivityResult.none);
    if (isOnline == _isOnline) return;

    final wasOffline = !_isOnline;
    _isOnline = isOnline;
    if (notify) notifyListeners();
    if (isOnline && wasOffline && !_reconnectedController.isClosed) {
      _reconnectedController.add(null);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _reconnectedController.close();
    super.dispose();
  }
}
```

- [ ] **Step 2: Criar `lib/app_providers.dart`**

```dart
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'config/app_config.dart';
import 'data/repositories/auth_repository.dart';
import 'data/services/api/api_client.dart';
import 'data/services/auth_session.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/local/app_database.dart';
import 'data/services/local/token_storage.dart';

/// Dependências vivas do app, criadas uma única vez na abertura.
///
/// O `ApiClient` recebe do `AuthSession` as funções de leitura e gravação de
/// token; o `AuthRepository` recebe os dois. Assim o cliente HTTP não conhece o
/// repositório e não há ciclo entre eles.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.tokenStorage,
    required this.session,
    required this.apiClient,
    required this.authRepository,
    required this.connectivityService,
  });

  factory AppDependencies.create({required AppDatabase database}) {
    final tokenStorage = TokenStorage();
    final session = AuthSession(tokenStorage);
    late final AuthRepository authRepository;

    final apiClient = ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      readAccessToken: session.readAccessToken,
      readRefreshToken: session.readRefreshToken,
      onTokensRenewed: session.updateTokens,
      onSessionExpired: () async {
        await session.expire();
        authRepository.handleSessionExpired();
      },
    );

    authRepository = AuthRepository(apiClient: apiClient, session: session);

    return AppDependencies._(
      database: database,
      tokenStorage: tokenStorage,
      session: session,
      apiClient: apiClient,
      authRepository: authRepository,
      connectivityService: ConnectivityService()..initialize(),
    );
  }

  final AppDatabase database;
  final TokenStorage tokenStorage;
  final AuthSession session;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final ConnectivityService connectivityService;

  /// Providers na ordem de dependência, para o `MultiProvider` do app.
  ///
  /// Todos entram por `.value` porque quem cria é esta classe — e é ela quem
  /// libera os recursos em `dispose()`.
  List<SingleChildWidget> get providers => [
        Provider<AppDatabase>.value(value: database),
        Provider<TokenStorage>.value(value: tokenStorage),
        Provider<AuthSession>.value(value: session),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<ConnectivityService>.value(
          value: connectivityService,
        ),
      ];

  void dispose() {
    connectivityService.dispose();
    authRepository.dispose();
    session.dispose();
  }
}
```

- [ ] **Step 3: Substituir o conteúdo de `lib/router.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'ui/auth/login_screen.dart';
import 'ui/debug/ds_gallery_screen.dart';
import 'ui/home/home_placeholder_screen.dart';
import 'ui/splash/splash_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String designSystem = '/ds';
}

/// Rotas do app. O redirecionamento observa o `AuthRepository`: entrar ou sair
/// da sessão troca a tela sem nenhuma navegação manual espalhada pelo código.
GoRouter createRouter(AuthRepository auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.designSystem,
          builder: (context, state) => const DsGalleryScreen(),
        ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;

      // A splash decide sozinha para onde ir depois de tentar retomar a sessão.
      if (location == AppRoutes.splash) return null;
      if (kDebugMode && location == AppRoutes.designSystem) return null;

      final isAuthenticated = auth.isAuthenticated;
      if (!isAuthenticated && location != AppRoutes.login) return AppRoutes.login;
      if (isAuthenticated && location == AppRoutes.login) return AppRoutes.home;
      return null;
    },
  );
}
```

- [ ] **Step 4: Criar `test/data/services/connectivity_service_test.dart`**

```dart
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/services/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late ConnectivityService service;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => changes.stream);
    service = ConnectivityService(connectivity: connectivity);
  });

  tearDown(() async {
    service.dispose();
    await changes.close();
  });

  test('começa com o estado real do aparelho', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);

    await service.initialize();

    expect(service.isOnline, isFalse);
    expect(service.isOffline, isTrue);
  });

  test('avisa os ouvintes quando a conexão cai', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);
    await service.initialize();

    var notifications = 0;
    service.addListener(() => notifications++);

    changes.add([ConnectivityResult.none]);
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isFalse);
    expect(notifications, 1);
  });

  test('emite onReconnected só na volta da conexão', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);
    await service.initialize();

    final reconnections = <void>[];
    service.onReconnected.listen(reconnections.add);

    changes.add([ConnectivityResult.mobile]);
    await Future<void>.delayed(Duration.zero);
    changes.add([ConnectivityResult.wifi]); // continua online: não emite de novo
    await Future<void>.delayed(Duration.zero);

    expect(reconnections, hasLength(1));
    expect(service.isOnline, isTrue);
  });
}
```

- [ ] **Step 5: Rodar os testes**

Neste ponto o `router.dart` referencia telas que só existem na Task 10, então o projeto ainda não compila inteiro. Rode só o teste desta task:

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter test test/data/services/connectivity_service_test.dart
```

Expected: `All tests passed!` (3 testes). `flutter analyze` vai apontar os imports não resolvidos de `router.dart` — isso é esperado e se resolve na Task 10; não crie telas vazias só para silenciar.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib/data/services/connectivity_service.dart apps/mobile/simtc/lib/app_providers.dart apps/mobile/simtc/lib/router.dart apps/mobile/simtc/test/data/services/connectivity_service_test.dart
git commit -m "feat(mobile): serviço de conectividade, providers do app e rotas com guarda"
```

---

## Task 10: Abertura, Login e remoção do placeholder

**Files:**
- Create: `apps/mobile/simtc/lib/ui/splash/splash_screen.dart`, `lib/ui/splash/splash_viewmodel.dart`
- Rewrite: `apps/mobile/simtc/lib/ui/auth/login_screen.dart`, `lib/ui/auth/login_viewmodel.dart`
- Create: `apps/mobile/simtc/lib/ui/home/home_placeholder_screen.dart`
- Rewrite: `apps/mobile/simtc/lib/main.dart`, `lib/app.dart`, `test/widget_test.dart`
- Create: `apps/mobile/simtc/test/ui/auth/login_viewmodel_test.dart`
- Delete: `lib/utils/app_colors.dart`, `lib/utils/api_constants.dart`, `lib/data/services/api/api_service.dart`, `lib/data/repositories/evaluation_repository.dart`, `lib/data/models/evaluation_model.dart`, `lib/data/models/user_model.dart`, `lib/ui/core/widgets/custom_button.dart`, `lib/ui/core/widgets/custom_text_field.dart`, `lib/ui/dashboard/` (2 arquivos), `lib/ui/evaluation/` (2 arquivos)

**Interfaces:**
- Consumes: componentes do DS (Tasks 4 e 5), `AuthRepository` (Task 8), providers e rotas (Task 9).
- Produces: telas 1.1 e 1.2 do canvas, ligadas à API real, e o app sem nenhum resto do scaffold placeholder.
- Layout do login (canvas, quadro `2b`): logo com 150 de altura centralizada, bloco de campos com 18 de espaçamento, campo de e-mail com ícone `mail`, campo de senha com ícone `lock` e alternador, linha com "Manter conectado" à esquerda e "Esqueci a senha" à direita, botão "Entrar" de 56 de altura, e um aviso ao pé quando está offline. Padding da tela: 48 no topo, 24 nas laterais.

- [ ] **Step 1: Criar `lib/ui/auth/login_viewmodel.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../../utils/result.dart';

/// Estado da tela de login. Nenhuma chamada de rede acontece aqui — tudo passa
/// pelo `AuthRepository`.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  String _email = '';
  String _password = '';
  bool _keepSignedIn = true;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _infoMessage;

  String get email => _email;
  String get password => _password;
  bool get keepSignedIn => _keepSignedIn;
  bool get obscurePassword => _obscurePassword;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  bool get canSubmit =>
      !_isSubmitting && _email.trim().isNotEmpty && _password.isNotEmpty;

  void setEmail(String value) {
    _email = value;
    _clearMessages();
  }

  /// A senha não é aparada: espaços podem fazer parte dela.
  void setPassword(String value) {
    _password = value;
    _clearMessages();
  }

  void setKeepSignedIn(bool value) {
    _keepSignedIn = value;
    notifyListeners();
  }

  void toggleObscurePassword() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void _clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      _errorMessage = null;
      _infoMessage = null;
    }
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;

    _isSubmitting = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    final result = await _authRepository.login(
      email: _email,
      password: _password,
      keepSignedIn: _keepSignedIn,
    );

    _isSubmitting = false;
    switch (result) {
      case Success():
        notifyListeners();
        return true;
      case Failure(message: final message):
        _errorMessage = message ?? 'Não foi possível entrar. Tente de novo.';
        notifyListeners();
        return false;
    }
  }

  /// Pede o e-mail de redefinição. A resposta é sempre a mesma, exista a conta
  /// ou não — o backend responde 204 nos dois casos, de propósito.
  Future<void> requestPasswordReset() async {
    if (_email.trim().isEmpty) {
      _errorMessage = 'Informe o e-mail para receber o link de redefinição.';
      notifyListeners();
      return;
    }

    _isSubmitting = true;
    notifyListeners();

    final result = await _authRepository.requestPasswordReset(_email);

    _isSubmitting = false;
    switch (result) {
      case Success():
        _errorMessage = null;
        _infoMessage =
            'Se este e-mail estiver cadastrado, enviamos um link para redefinir a senha.';
      case Failure(message: final message):
        _infoMessage = null;
        _errorMessage = message ?? 'Não foi possível enviar o e-mail agora.';
    }
    notifyListeners();
  }
}
```

- [ ] **Step 2: Criar `lib/ui/auth/login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/services/connectivity_service.dart';
import '../../router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_icons.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';
import '../core/widgets/app_checkbox.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/inline_notice.dart';
import 'login_viewmodel.dart';

/// Tela 1.2 do canvas.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>(
      create: (context) => LoginViewModel(
        authRepository: context.read<AuthRepository>(),
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Consumer<LoginViewModel>(
            builder: (context, viewModel, _) => _buildBody(context, viewModel),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LoginViewModel viewModel) {
    final isOffline = context.watch<ConnectivityService>().isOffline;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.huge,
        AppSpacing.xxl,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLogo(),
          const SizedBox(height: AppSpacing.xxxl),
          _buildEmailField(viewModel),
          const SizedBox(height: AppSpacing.lg + 2),
          _buildPasswordField(viewModel),
          const SizedBox(height: AppSpacing.md),
          _buildOptionsRow(viewModel),
          if (viewModel.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineNotice(
              icon: AppIcons.needsReview,
              message: viewModel.errorMessage!,
              tone: NoticeTone.danger,
            ),
          ],
          if (viewModel.infoMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineNotice(
              icon: AppIcons.email,
              message: viewModel.infoMessage!,
              tone: NoticeTone.success,
            ),
          ],
          const SizedBox(height: AppSpacing.lg + 2),
          _buildSubmitButton(context, viewModel),
          if (isOffline) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildOfflineNotice(),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Image.asset(
        'assets/images/logo-simtc.png',
        height: 150,
        semanticLabel: 'SIM Treinamentos',
      ),
    );
  }

  Widget _buildEmailField(LoginViewModel viewModel) {
    return AppTextField(
      label: 'E-mail',
      controller: _emailController,
      icon: AppIcons.email,
      hintText: 'seu.email@simtc.com.br',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username, AutofillHints.email],
      enabled: !viewModel.isSubmitting,
      onSubmitted: (_) => _passwordFocus.requestFocus(),
      onChanged: viewModel.setEmail,
    );
  }

  Widget _buildPasswordField(LoginViewModel viewModel) {
    return AppTextField(
      label: 'Senha',
      controller: _passwordController,
      focusNode: _passwordFocus,
      icon: AppIcons.password,
      obscureText: viewModel.obscurePassword,
      onToggleObscure: viewModel.toggleObscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      enabled: !viewModel.isSubmitting,
      onSubmitted: (_) => _submit(context, viewModel),
      onChanged: viewModel.setPassword,
    );
  }

  Widget _buildOptionsRow(LoginViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: AppCheckbox(
            value: viewModel.keepSignedIn,
            label: 'Manter conectado',
            onChanged: viewModel.isSubmitting ? (_) {} : viewModel.setKeepSignedIn,
          ),
        ),
        TextButton(
          onPressed: viewModel.isSubmitting ? null : viewModel.requestPasswordReset,
          child: Text('Esqueci a senha', style: AppTypography.link),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, LoginViewModel viewModel) {
    return AppPrimaryButton(
      label: 'Entrar',
      isLoading: viewModel.isSubmitting,
      onPressed: viewModel.canSubmit ? () => _submit(context, viewModel) : null,
    );
  }

  Widget _buildOfflineNotice() {
    return const InlineNotice(
      icon: AppIcons.noSignal,
      message:
          'Sem conexão. O primeiro acesso neste aparelho precisa de internet para validar suas credenciais.',
    );
  }

  Future<void> _submit(BuildContext context, LoginViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    final entered = await viewModel.submit();
    if (entered && context.mounted) {
      context.go(AppRoutes.home);
    }
  }
}
```

O `onChanged` usado aqui já faz parte do `AppTextField` entregue na Task 4.

- [ ] **Step 3: Criar `lib/ui/splash/splash_viewmodel.dart` e `lib/ui/splash/splash_screen.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../data/repositories/auth_repository.dart';
import '../../utils/result.dart';

/// Decide, na abertura, se o app vai para a Home ou para o Login.
class SplashViewModel extends ChangeNotifier {
  SplashViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  /// Tenta retomar a sessão salva. Devolve true quando consegue.
  Future<bool> decideInitialRoute() async {
    final result = await _authRepository.restoreSession();
    return result is Success;
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../../router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'splash_viewmodel.dart';

/// Tela 1.1 do canvas: logo centralizada e uma barra fina de progresso,
/// enquanto o app tenta retomar a sessão salva. Sem texto de carregamento.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    final viewModel = SplashViewModel(
      authRepository: context.read<AuthRepository>(),
    );
    final isSignedIn = await viewModel.decideInitialRoute();
    if (!mounted) return;
    context.go(isSignedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo(),
            const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
            _buildProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo-simtc.png',
      height: 130,
      semanticLabel: 'SIM Treinamentos',
    );
  }

  Widget _buildProgress() {
    return SizedBox(
      width: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: const LinearProgressIndicator(
          minHeight: 4,
          backgroundColor: Color(0x24000000),
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Criar `lib/ui/home/home_placeholder_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/auth_repository.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_buttons.dart';

/// Tela provisória depois do login — substituída pela lista de sessões na Fase 2.
///
/// Existe para fechar o fluxo desta fase: entrar, ver quem está logado e sair.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('SIMTC')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Olá, ${user?.name ?? ''}', style: AppTypography.screenTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(user?.email ?? '', style: AppTypography.body),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user?.isAdmin == true ? 'Perfil: administrador' : 'Perfil: consultor',
              style: AppTypography.meta,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Consultor vinculado: ${user?.consultantId ?? '—'}',
                style: AppTypography.meta),
            const Spacer(),
            AppSecondaryButton(
              label: 'Sair',
              onPressed: () => context.read<AuthRepository>().logout(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Substituir `lib/main.dart` e `lib/app.dart`**

```dart
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/services/local/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SimtcApp(database: AppDatabase()));
}
```

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'app_providers.dart';
import 'data/services/local/app_database.dart';
import 'router.dart';
import 'ui/core/theme/app_theme.dart';

class SimtcApp extends StatefulWidget {
  const SimtcApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SimtcApp> createState() => _SimtcAppState();
}

class _SimtcAppState extends State<SimtcApp> {
  // Criados uma vez: recriar o GoRouter a cada build perderia a pilha de navegação.
  late final AppDependencies _dependencies =
      AppDependencies.create(database: widget.database);
  late final GoRouter _router = createRouter(_dependencies.authRepository);

  @override
  void dispose() {
    _dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _dependencies.providers,
      child: MaterialApp.router(
        title: 'SIMTC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
```

- [ ] **Step 6: Apagar o que sobrou do placeholder**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git rm -r --quiet \
  apps/mobile/simtc/lib/utils/app_colors.dart \
  apps/mobile/simtc/lib/utils/api_constants.dart \
  apps/mobile/simtc/lib/data/services/api/api_service.dart \
  apps/mobile/simtc/lib/data/repositories/evaluation_repository.dart \
  apps/mobile/simtc/lib/data/models/evaluation_model.dart \
  apps/mobile/simtc/lib/data/models/user_model.dart \
  apps/mobile/simtc/lib/ui/core/widgets/custom_button.dart \
  apps/mobile/simtc/lib/ui/core/widgets/custom_text_field.dart \
  apps/mobile/simtc/lib/ui/dashboard \
  apps/mobile/simtc/lib/ui/evaluation
grep -rn "app_colors\|api_constants\|ApiService\|EvaluationModel\|UserModel\|CustomButton\|CustomTextField" apps/mobile/simtc/lib apps/mobile/simtc/test || echo "ok: nenhuma referência ao placeholder"
```

Expected: `ok: nenhuma referência ao placeholder`.

- [ ] **Step 7: Substituir `test/widget_test.dart` e criar o teste do ViewModel**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simtc/app.dart';
import 'package:simtc/data/services/local/app_database.dart';
import 'package:simtc/ui/splash/splash_screen.dart';

void main() {
  testWidgets('o app abre na tela de abertura', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(SimtcApp(database: database));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:simtc/data/models/auth_user.dart';
import 'package:simtc/data/repositories/auth_repository.dart';
import 'package:simtc/ui/auth/login_viewmodel.dart';
import 'package:simtc/utils/result.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository auth;
  late LoginViewModel viewModel;

  const user = AuthUser(
    id: 'u1',
    name: 'Carla',
    email: 'carla@simtc.com.br',
    role: AppUserRole.consultant,
  );

  setUp(() {
    auth = _MockAuthRepository();
    viewModel = LoginViewModel(authRepository: auth);
  });

  test('só habilita o envio com e-mail e senha preenchidos', () {
    expect(viewModel.canSubmit, isFalse);

    viewModel.setEmail('carla@simtc.com.br');
    expect(viewModel.canSubmit, isFalse);

    viewModel.setPassword('123456');
    expect(viewModel.canSubmit, isTrue);
  });

  test('login bem-sucedido repassa a preferência de manter conectado', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async => const Success(user));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('123456')
      ..setKeepSignedIn(false);

    expect(await viewModel.submit(), isTrue);
    verify(() => auth.login(
          email: 'carla@simtc.com.br',
          password: '123456',
          keepSignedIn: false,
        )).called(1);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isSubmitting, isFalse);
  });

  test('falha mostra a mensagem do repositório e não navega', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async =>
            Failure<AuthUser>(Exception('401'), 'E-mail ou senha incorretos.'));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('errada');

    expect(await viewModel.submit(), isFalse);
    expect(viewModel.errorMessage, 'E-mail ou senha incorretos.');
  });

  test('digitar de novo limpa a mensagem de erro', () async {
    when(() => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
          keepSignedIn: any(named: 'keepSignedIn'),
        )).thenAnswer((_) async =>
            Failure<AuthUser>(Exception('401'), 'E-mail ou senha incorretos.'));

    viewModel
      ..setEmail('carla@simtc.com.br')
      ..setPassword('errada');
    await viewModel.submit();

    viewModel.setPassword('outra');
    expect(viewModel.errorMessage, isNull);
  });

  test('esqueci a senha sem e-mail avisa antes de chamar a API', () async {
    await viewModel.requestPasswordReset();

    expect(viewModel.errorMessage, contains('Informe o e-mail'));
    verifyNever(() => auth.requestPasswordReset(any()));
  });

  test('esqueci a senha mostra a mesma confirmação sempre', () async {
    when(() => auth.requestPasswordReset(any()))
        .thenAnswer((_) async => const Success(null));

    viewModel.setEmail('carla@simtc.com.br');
    await viewModel.requestPasswordReset();

    expect(viewModel.infoMessage, contains('enviamos um link'));
    expect(viewModel.errorMessage, isNull);
  });
}
```

- [ ] **Step 8: Rodar a suíte inteira**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter analyze
flutter test
```

Expected: `No issues found!` e `All tests passed!` — 52 testes somando todas as tasks da fase (2 de config, 3 de tema, 9 de formulário, 6 de listagem, 5 de banco, 8 de API, 9 de auth, 3 de conectividade, 6 de login e 1 de abertura). Antes desta task a suíte tem 26; as Tasks 7 a 10 somam as outras 26. Saída limpa, sem avisos de overflow ou de fonte ausente.

- [ ] **Step 9: Testar no aparelho físico**

Com o backend rodando (`npm run start:dev` em `apps/backend`) e o aparelho conectado:

```bash
adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC/apps/mobile/simtc"
flutter run -d <ID_DO_APARELHO>
```

Roteiro de verificação no aparelho:
1. O app abre na tela de abertura (logo + barra) e vai para o login — sem sessão salva.
2. Entrar com credencial errada mostra "E-mail ou senha incorretos." num aviso vermelho, sem travar a tela.
3. Entrar com um usuário `CONSULTANT` ou `ADMIN` real leva à tela provisória, que mostra nome, e-mail, perfil e o id do consultor vindo do JWT.
4. Fechar e reabrir o app: com "Manter conectado" marcado, a abertura leva direto para a tela provisória; desmarcado, volta para o login.
5. "Sair" volta para o login e, ao reabrir, o login continua aparecendo.
6. Desligar o Wi-Fi e os dados do aparelho: a tela de login mostra o aviso de falta de conexão, e tentar entrar mostra a mensagem "Sem conexão com o servidor…".
7. Em `http://localhost:3001/docs` no aparelho, confirmar que o backend continua alcançável (descarta problema de rede quando algo falhar).
8. Só em debug, abrir a galeria do DS: pare o app e rode `flutter run -d <ID> --route=/ds` — confira cores, toques de 48 dp e a navbar sobre o aparelho de verdade.

Anote no relatório o que apareceu em cada passo.

- [ ] **Step 10: Commit**

```bash
cd "C:/Users/joaop/Claude/Projects/App de Treinamento SIMTC"
git add apps/mobile/simtc/lib apps/mobile/simtc/test
git commit -m "feat(mobile): telas de abertura e login reais, sem o scaffold placeholder"
```

---

## Critério de "pronto para testar" da Fase 1 (spec)

- [ ] A tela de Login usa os componentes e tokens do DS e autentica de verdade contra `POST /auth/login` no ambiente de desenvolvimento.
- [ ] O token é guardado e a sessão é retomada na abertura (respeitando "manter conectado").
- [ ] O app navega para uma tela provisória depois do login, e "Sair" volta ao login.
- [ ] Nada do scaffold placeholder continua no projeto.
- [ ] Tudo isso rodando no aparelho físico.

Depois disso: revisão final da fase, registro no ledger e **parada** para sua validação antes do plano da Fase 2.
