# PocketStage Mídia

Mesa de trilhas, vídeos, imagens e textos para teatro e stand-up, com telão por HDMI ou segundo monitor.
Flutter · Android, iPhone, iPad, Windows e macOS.

## Build

Todo push na `main` roda o GitHub Actions (aba **Actions**):
análise e testes, e depois APK do Android, app do Windows, app do macOS e app do iOS sem assinatura.
Os arquivos ficam em **Artifacts**, no fim de cada execução.

As pastas de plataforma (`android/`, `ios/`, `windows/`, `macos/`) são geradas no build por `tool/setup_platforms.sh`,
que também aplica o ID `br.com.pocketstage.midia`. As configs do Firebase ficam em `android/app/` e `ios/Runner/`.

## Fontes

Archivo e Chivo Mono, licença SIL OFL 1.1 (`assets/fonts/OFL.txt`).
