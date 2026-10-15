# PocketStage Mídia · Contexto mestre

Cole este arquivo no início de uma conversa nova (ou nas instruções de um Projeto) para retomar o trabalho.
A especificação completa está no documento "PocketStage Mídia — Especificação" (Claude Docs). Em caso de conflito, a especificação vale.
Atualizado em 2026-10-15 (Flutter, multiplataforma).

<instrucoes_de_trabalho>
- Dono do projeto: Mello. Ator, comediante, produtor de eventos e técnico de áudio. Opera o app em cena, no escuro.
- Português do Brasil, direto e curto. Sem enrolação.
- Faça exatamente o que for pedido. "Quero criar/fazer X" é a ideia, não o pedido de construir: confirme e espere.
- Não mude as regras de reprodução nem reverta decisões sem pedido. Se algo fora do pedido parecer necessário, proponha numa frase e pergunte.
- Uma etapa por vez, com o "ok" do Mello antes da seguinte. Ao fim de cada etapa: o que mudou, como testar no aparelho, o que ficou pendente (até 4 linhas).
- Nunca mencione de onde veio a ideia do app nem cite outros apps como referência, em nenhum texto, código ou documento.
</instrucoes_de_trabalho>

## 1. O que é

App **multiplataforma** (Android, iPhone, iPad, Windows, macOS) que vira mesa de trilhas, vídeos, imagens e textos para teatro e stand-up. O aparelho é a mesa; o telão recebe só o palco, por HDMI ou como segundo monitor.
**Decisão (2026-10-15): o app é feito em Flutter.** O código Android em Kotlin e o protótipo web são só referência de comportamento; o Kotlin não será mais compilado.
Obrigatório em todas as plataformas: a tela nunca apaga nem bloqueia com o app aberto (sem opção de desligar) e o som continua em segundo plano (app minimizado, outro app por cima, tela do sistema bloqueada).
Limites: no iPhone/iPad o app não escolhe a saída de áudio (abre o seletor do iOS) e copia a mídia para dentro do app; no computador o telão é uma janela em tela cheia no segundo monitor.
É o futuro módulo premium "Tela de Cabine Técnica" do **PocketStage** (stage manager de bolso do Mello, Flutter + Firebase, ainda só protótipo web), na Fase 3 dele. Até lá, apps separados que trocam shows no mesmo formato.

## 2. Regras de reprodução (não mudar sem pedido)

1. 4 colunas fixas; 4 a 32 botões. Coluna = índice % 4.
2. Uma mídia por coluna; a nova corta a anterior (com fade, se ligado). Colunas diferentes tocam juntas.
3. Tocar de novo o botão que toca: para / recomeça / ignora (Ajuste geral; padrão: para).
4. Telão: uma imagem ou vídeo por vez, de qualquer coluna. Texto é camada por cima; texto novo substitui texto.
5. Fim natural libera a coluna e apaga o telão, exceto vídeo "fixo no último quadro".
6. Imagem fica até ser tocada de novo, substituída, apagada ou sair pelo tempo de tela.
7. Trilha com imagem ligada: a imagem entra junto; ao acabar a trilha fica (padrão) ou sai, escolhido num pop-up ao ligar.
8. ▶ da linha: para tudo e toca a linha. Tocar de novo para tudo. GO = próxima linha; também linha anterior.
9. Pausar congela tudo (incl. pré-esperas e tempos). Parar tudo usa o fade do Parar tudo. Bloquear desativa a grade; desbloquear = segurar.
10. Painel do telão: o título "Telão" é o botão Mostrar/Ocultar telão. Ocultar recolhe o painel para a direita (grade ocupa tudo); mostrar expande. O botão nunca muda de lugar. Aberto, o painel fica fixo ao rolar a grade.

## 3. Mídia (cue) — campos do show.json

Tipos: AUDIO, VIDEO, IMAGE, TEXT. `id` fixo (trocar arquivo mantém; remover e readicionar gera outro).
Básico: name, volume (linear; UI em dB −∞ a +6), loop, fadeIn, fadeOut, fit (CONTAIN/COVER), hold, text/textPos/textSize, visualId/visualStays, linkId/role (entrada, saida, fundo, livre).
Avançado: startSec, endSec, fadeInSec, fadeOutSec, fadeCurve (null = padrão), pan, repeat, duckDb, muted, preWaitSec, autoStopSec, followId/followMode/followSec, stopCols/stopAllOnGo, lockAfter, transition (null = padrão)/transSec, color, note, hotkey.

## 4. Ajustes gerais (JSON nas preferências; mesmos nomes no web)

fadeIn 2, fadeOut 3, fadeCurve linear, stopAllFade 0.35, masterDb 0, retrigger parar, pausePreWait true (Pausar congela as pré-esperas; desligado, cancela), audioDeviceType 0 (Android), transition fade, visFade 1, textPos embaixo, textSize M, btnSize M, clockMode restante, endWarnSec 5, showRowGo true, confirmStopAll false, holdSec 1.2, lockOnOpen false, confirmExit true, tipAirplane true (tela sempre ligada é obrigatória, sem ajuste), keys {go: PageDown, prev: PageUp, stopAll, pause, blackout}.
Uma tecla = uma ação. Atalho geral vence atalho de mídia. Restaurar padrões disponível.

## 5. Integração com o PocketStage

- show.json: `{format:"pocketstage.show", version:1, id, name, date?, start?, eventType?, lineup[], media:{count, cells[32]}, updatedAt}`. lineup e campos desconhecidos passam sem mudança. Formato antigo convertido sozinho.
- .psshow = ZIP (show.json, log.json, media/<cueId>.<ext>). Importar cria show novo; versão > 1 recusada com "Este show foi criado numa versão mais nova do PocketStage. Atualize o app."
- Comandos: go, stop, play_row, stop_all, blackout, pause, resume, lock, unlock, release_locks, load_show, set_settings.
- Log: `{t, source:"midia", type, ref, linkId, text}`; tipos cue_go, cue_stop, cue_end, stop_all, blackout, pause, resume, lock, unlock.
- Deep link: pocketstage-midia://show/{id} e .../go/{cueId} (só desbloqueado).

## 6. Técnica

Alvo (Flutter): núcleo Dart puro `pocketstage_midia_core` (modelos, show.json, .psshow, comandos, estado, log, regras) + telas Flutter + plugins: media_kit (áudio/vídeo, um player por disparo; pan e ganho > 0 dB via filtros mpv a validar), plugin próprio de telão (Presentation no Android, tela externa no iOS/iPadOS, janela em tela cheia no segundo monitor), wakelock_plus, audio_service + audio_session, file_picker, path_provider, archive, share_plus, app_links. Telas falam com o motor só por comandos.
Build: GitHub Actions (Android, Windows, macOS; iOS em máquina macOS). O Flutter não roda no ambiente do Claude.
Repositório: github.com/omarciomello/pocketstagemidia (main). ID do app: br.com.pocketstage.midia (Android, iOS, macOS). Firebase: projeto pocketstagemidia (configs em android/app e ios/Runner; ainda sem uso).
Núcleo: packages/pocketstage_midia_core (Engine + MediaBackend + Scheduler; ManualScheduler nos testes).
Referência: código Kotlin (:app, :engine) e protótipo web (artifact "PocketStage Mídia").
Decisão: Pausar congela as pré-esperas por padrão; o operador escolhe nos Ajustes (pausePreWait).
Decisão provisória: no celular/tablet a mídia escolhida é copiada para dentro do app; no computador fica onde está.
Nomes do núcleo: FadeCurve e ShortcutAction (Curve e GlobalKey colidem com o Flutter).
CI: erros viram anotações do GitHub (tool/ci_run.sh); capturas das telas no ramo ci-capturas (test/capturas_test.dart).

## 7. Visual

Tema escuro único. Fundo #090A0F; painéis #12141C/#1E212D/#272B38; texto #E2E4E9/#8B8F9E/#4A4E5E; ciano #6FD3DF = deixa ativa; lilás #E0A6F0 = telão; laranja #FFB648 = aviso de fim; vermelho #FF6B6B = destrutivo; verde #3DDC84 = tocando. Fontes Archivo e Chivo Mono (OFL, embutidas). Bolinha cinza em repouso; nada se mexe no hover.

## 8. Estado e próxima fase

Feito: protótipo web completo; código Kotlin de referência (nunca compilado). Flutter: (1) repositório e build no GitHub Actions com Android, Windows, macOS e iOS sem assinatura ✔; (2) núcleo em Dart com testes das regras ✔; (3) telas em Flutter: mesa com painel do telão ocultável e fixo, lista de shows, editor do show e da mídia, Ajustes, exportar/importar e show de exemplo, com som e vídeo pelo media_kit e tela sempre ligada ✔ (falta testar em aparelho).
Próxima fase, nesta ordem: (4) telão, tela sempre ligada e segundo plano em cada plataforma; (5) teste em palco em vários aparelhos (mín. um Android, um iPhone ou iPad e um computador, com tabela de aparelhos testados); (6) decisões pendentes; (7) funções de operador: verificar show, mover/copiar mídia, duplicar show, desfazer, tela de log; (8) Fase 3 com o PocketStage.
Riscos: telão nativo em cada sistema; pan/ganho no media_kit; iOS exige Mac e conta Apple Developer; arquivos no iOS precisam ser copiados.
