# PocketStage Mídia

Mesa de trilhas, vídeos, imagens e textos para teatro e stand-up, com telão por HDMI ou segundo monitor.
Flutter · Android, Windows e macOS (iPhone e iPad depois).

## Estrutura

- `packages/pocketstage_midia_core/` — núcleo em Dart puro: show.json, .psshow, regras de reprodução, comandos e log, com testes.
  O som e o telão de cada plataforma entram pela interface `MediaBackend`.
- `lib/` — telas em Flutter (mesa, shows, editor, ajustes, registro do show, cronômetro, telão).
- `tool/setup_platforms.sh` — gera as pastas de plataforma e aplica os ajustes nativos (telão no Android e no computador, ajuste do media_kit_video para duas janelas).
- `docs/CONTEXTO.md` — contexto mestre para retomar o trabalho.

## Build

Todo push na `main` roda o GitHub Actions (aba **Actions**):
análise e testes, e depois APK do Android, app do Windows, app do macOS e app do iOS sem assinatura.
Os arquivos ficam em **Artifacts**, no fim de cada execução, e na release **teste** (aba Releases).
Capturas das telas: ramo `ci-capturas`; teste da mesa com o telão no Windows: ramo `ci-capturas-win`.
Assinatura do APK: segredos `PSM_KEYSTORE_B64` e `PSM_KEY_PASSWORD` (o keystore nunca vai para o repositório).

As pastas de plataforma (`android/`, `ios/`, `windows/`, `macos/`) são geradas no build por `tool/setup_platforms.sh`,
que também aplica o ID `br.com.pocketstage.midia`. As configs do Firebase ficam em `android/app/` e `ios/Runner/`.

## Fontes

Archivo e Chivo Mono, licença SIL OFL 1.1 (`assets/fonts/OFL.txt`).
