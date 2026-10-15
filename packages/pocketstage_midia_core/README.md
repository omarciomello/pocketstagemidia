# pocketstage_midia_core

Núcleo do PocketStage Mídia, em Dart puro (sem Flutter):

- `model.dart` — mídia (Cue), show (show.json compatível com o PocketStage) e Ajustes gerais.
- `engine.dart` — regras de reprodução: 4 colunas, uma mídia por coluna, telão com uma imagem ou vídeo e texto por cima, ▶ da linha e GO, pré-espera, seguir, ducking, travas, Pausar, Parar tudo, Apagar telão, bloqueio.
- `protocol.dart` — comandos JSON, estado e log.
- `archive.dart` — exportar e importar `.psshow`.
- `keys.dart` — atalhos de teclado e pedal.
- `backend.dart` — o que cada plataforma implementa (players e telão).
- `scheduler.dart` — relógio real e relógio manual para testes.

Testes: `dart test`.
