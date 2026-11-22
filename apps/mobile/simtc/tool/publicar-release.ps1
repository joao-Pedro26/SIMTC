<#
.SYNOPSIS
  Gera o APK de release e os arquivos que sobem para o bucket `app-releases`.

.DESCRIPTION
  1. Le a versao do pubspec.yaml (X.Y.Z+N; o N e o versionCode e SEMPRE sobe).
  2. Roda `flutter build apk --release` (assinado com a keystore de release).
  3. Copia o APK para dist\simtc-<versao>-<codigo>.apk.
  4. Calcula o SHA-256 e o tamanho.
  5. Gera dist\latest.json.

  O upload e manual, pelo painel do Supabase (projeto de PRODUCAO, bucket
  `app-releases`): suba primeiro o APK e, so depois, o latest.json. Assim o
  manifesto nunca aponta para um arquivo que ainda nao existe.

.PARAMETER Notas
  O que mudou, uma frase por item. Aparece no aviso de atualizacao do app.

.PARAMETER MinSuportada
  versionCode minimo aceito. Quem estiver abaixo e obrigado a atualizar.
  Padrao 1 (ninguem e obrigado). Use so quando uma mudanca de API quebra
  versoes antigas.

.EXAMPLE
  .\tool\publicar-release.ps1 -Notas "Corrige o envio da fila","Melhora a busca"

.EXAMPLE
  .\tool\publicar-release.ps1 -Notas "Mudanca na API" -MinSuportada 3
#>
[CmdletBinding()]
param(
  [string[]]$Notas = @(),
  [int]$MinSuportada = 1,
  [string]$BaseUrl = 'https://gohdttoyatgapamigaep.supabase.co/storage/v1/object/public/app-releases',
  [string]$ApiUrl = 'https://api.simtc.com.br/api'
)

$ErrorActionPreference = 'Stop'

# tool\ fica dentro de apps\mobile\simtc, que e a raiz do projeto Flutter.
$appRoot = Split-Path -Parent $PSScriptRoot
Push-Location $appRoot
try {
  $pubspec = Get-Content -Raw -Path (Join-Path $appRoot 'pubspec.yaml')
  if ($pubspec -match '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    $versionName = $Matches[1]
    $versionCode = [int]$Matches[2]
  } else {
    throw "Nao achei 'version: X.Y.Z+N' no pubspec.yaml."
  }

  if ($MinSuportada -gt $versionCode) {
    throw "MinSuportada ($MinSuportada) nao pode ser maior que o versionCode desta versao ($versionCode)."
  }

  if (-not (Test-Path (Join-Path $appRoot 'android\key.properties'))) {
    throw 'Falta android\key.properties (keystore de release). Sem ele o APK sairia sem a assinatura certa.'
  }

  # A URL da API vai explicita: o padrao do app em lib\config\app_config.dart
  # pode estar apontando para o backend local, e um APK de release assim nao
  # consegue falar com a producao.
  Write-Host "Gerando o APK $versionName+$versionCode (API: $ApiUrl) ..." -ForegroundColor Cyan
  & flutter build apk --release "--dart-define=API_BASE_URL=$ApiUrl"
  if ($LASTEXITCODE -ne 0) { throw 'O flutter build falhou.' }

  $builtApk = Join-Path $appRoot 'build\app\outputs\flutter-apk\app-release.apk'
  if (-not (Test-Path $builtApk)) {
    throw "APK nao encontrado em $builtApk."
  }

  $dist = Join-Path $appRoot 'dist'
  New-Item -ItemType Directory -Force -Path $dist | Out-Null

  # Sem '+' no nome: evita ter de codificar a URL.
  $fileName = "simtc-$versionName-$versionCode.apk"
  $apkPath = Join-Path $dist $fileName
  Copy-Item -Path $builtApk -Destination $apkPath -Force

  $hash = (Get-FileHash -Algorithm SHA256 -Path $apkPath).Hash.ToLower()
  $size = (Get-Item $apkPath).Length

  $manifest = [ordered]@{
    versionName             = $versionName
    versionCode             = $versionCode
    minSupportedVersionCode = $MinSuportada
    apkUrl                  = "$BaseUrl/$fileName"
    sha256                  = $hash
    sizeBytes               = $size
    releaseNotes            = @($Notas)
    publishedAt             = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  }

  $jsonPath = Join-Path $dist 'latest.json'
  $json = $manifest | ConvertTo-Json -Depth 4
  [System.IO.File]::WriteAllText($jsonPath, $json, (New-Object System.Text.UTF8Encoding($false)))

  $sizeMb = [math]::Round($size / 1MB, 1)
  Write-Host ''
  Write-Host "Pronto: versao $versionName (versionCode $versionCode), $sizeMb MB" -ForegroundColor Green
  Write-Host "  APK:    $apkPath"
  Write-Host "  Manifesto: $jsonPath"
  Write-Host "  SHA-256: $hash"
  Write-Host ''
  Write-Host 'Agora, no painel do Supabase de PRODUCAO (Storage > app-releases):' -ForegroundColor Yellow
  Write-Host "  1. Suba o $fileName"
  Write-Host '  2. Depois suba o latest.json (substitui o anterior)'
  Write-Host '  3. Abra o app em um aparelho com a versao anterior e confira o aviso'
} finally {
  Pop-Location
}
