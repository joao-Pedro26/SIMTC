# SIMTC Mobile (Flutter)

App Android (celular e tablet) do fluxo de avaliação prática da SIM Treinamentos.
Planos de implementação: `apps/mobile/docs/superpowers/plans/`. Auditoria da base: `apps/mobile/docs/fase-0-auditoria.md`.

## Requisitos

- Flutter 3.41.x (Dart 3.11). Conferir com `flutter --version`.
- Android SDK com `adb` no PATH. Conferir com `adb version`.
- Aparelho Android físico com as **Opções do desenvolvedor** ativadas: em Configurações → Sobre o telefone, tocar 7 vezes em **Número da versão** (em alguns aparelhos, **Número de compilação**).

Os testes de cada fase são feitos em aparelho físico, não em emulador.

## Comandos do dia a dia

```bash
cd apps/mobile/simtc
flutter pub get
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # depois de mudar tabelas Drift ou modelos JSON
```

## Ambientes

A URL da API é resolvida em tempo de compilação por `--dart-define`:

| Ambiente | Comando | URL |
|---|---|---|
| Desenvolvimento (padrão) | `flutter run -d <ID>` | `http://localhost:3001/api` (backend do PC, via `adb reverse`) |
| Produção | `flutter build apk --release --dart-define=API_BASE_URL=https://api.simtc.com.br/api --dart-define=APP_ENV=prod` | `https://api.simtc.com.br/api` |

Sem `--dart-define`, o app sempre aponta para o backend local — nenhuma build de desenvolvimento fala com produção por engano.

## Rodar no aparelho via USB

1. No aparelho, em Opções do desenvolvedor, ativar **Depuração USB**.
2. Conectar o cabo e aceitar, no aparelho, o pedido "Permitir depuração USB?".
3. Rodar `adb devices -l`: o aparelho deve aparecer com o estado `device`. Se aparecer `unauthorized`, desbloqueie a tela e aceite o pedido.
4. Rodar `flutter devices` e copiar o id do aparelho (a linha **sem** "emulator").
5. Rodar `flutter run -d <ID_DO_APARELHO>`.

## Rodar no aparelho via Wi-Fi

O PC e o aparelho precisam estar na mesma rede Wi-Fi. Há dois caminhos.

### Caminho A — partindo do cabo (mais simples)

Com o aparelho já conectado por USB e autorizado:

```bash
IP=$(adb -s <ID_DO_APARELHO> shell ip -f inet addr show wlan0 | sed -nE 's/.*inet ([0-9.]+).*/\1/p' | head -1)
adb -s <ID_DO_APARELHO> tcpip 5555      # reinicia o adbd do aparelho em modo TCP
adb connect $IP:5555
```

Depois é só desconectar o cabo: a conexão sem fio continua. O aparelho passa a aparecer no `flutter devices` como `<IP>:5555` (junto com o id USB, enquanto o cabo estiver ligado), e se roda com `flutter run -d <IP>:5555`.

O modo TCP vale até o aparelho reiniciar ou trocar de rede; para voltar ao USB, `adb usb`.

### Caminho B — sem cabo, pareando pelo aparelho (Android 11+)

1. No aparelho, em Opções do desenvolvedor, ativar **Depuração por Wi-Fi**.
2. Nessa tela, tocar em **Parear dispositivo com código de pareamento** e, no PC, rodar:
   `adb pair <IP>:<PORTA_DE_PAREAMENTO> <CÓDIGO>`
3. Ainda na tela "Depuração por Wi-Fi", anotar o **endereço IP e porta** (é uma porta diferente da do pareamento) e, no PC, rodar:
   `adb connect <IP>:<PORTA>`
4. Rodar `flutter run -d <IP>:<PORTA>`.

O pareamento (passo 2) é feito uma vez por PC; nas próximas vezes basta o passo 3, e a porta muda sempre que a depuração por Wi-Fi é desligada e ligada de novo.

Só os aparelhos pareados por este caminho B aparecem em `flutter devices --device-connection wireless`; os do caminho A aparecem na listagem normal do `flutter devices`.

## Acessar o backend local a partir do aparelho

Em desenvolvimento, o app fala com o backend que roda no PC (`npm run start:dev` em `apps/backend`, porta 3001). Em vez de usar o IP do PC, que exige liberar o firewall do Windows, redirecione a porta pelo `adb`:

```bash
adb -s <ID_DO_APARELHO> reverse tcp:3001 tcp:3001
adb -s <ID_DO_APARELHO> reverse --list    # deve listar tcp:3001 tcp:3001
```

Com isso, `http://localhost:3001/api` **no aparelho** chega ao backend do PC. Para um teste rápido, abra `http://localhost:3001/docs` no Chrome do aparelho: deve aparecer o Swagger da API.

- O redirecionamento some quando o aparelho desconecta do `adb`. Rode o `reverse` de novo depois de reconectar.
- O redirecionamento é por conexão, não por aparelho: ao passar do cabo para o Wi-Fi, refaça o `reverse` usando o id novo (`<IP>:5555`). Funciona igual nos dois casos.
- **Testes offline (Fases 4 e 5):** via USB, o modo avião não derruba o `adb`, então com o `reverse` ativo o app continua alcançando `localhost:3001`. Para simular falta de rede de verdade, ative o modo avião, confira que o Wi-Fi também desligou e remova o redirecionamento com `adb -s <ID_DO_APARELHO> reverse --remove tcp:3001`. Para "voltar a ficar online", recrie o redirecionamento e desligue o modo avião.
