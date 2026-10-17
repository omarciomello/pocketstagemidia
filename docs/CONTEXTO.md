# PocketStage Mídia · Contexto mestre

Cole este arquivo no início de uma conversa nova (ou nas instruções de um Projeto) para retomar o trabalho.
A especificação completa está no documento "PocketStage Mídia — Especificação" (Claude Docs). Em caso de conflito, a especificação vale.
Atualizado em 2026-10-16 (fase de base concluída: Android e computador).

<instrucoes_de_trabalho>
- Dono do projeto: Mello. Ator, comediante, produtor de eventos e técnico de áudio. Opera o app em cena, no escuro.
- Português do Brasil, direto e curto. Sem enrolação.
- Faça exatamente o que for pedido. "Quero criar/fazer X" é a ideia, não o pedido de construir: confirme e espere.
- Não mude as regras de reprodução nem reverta decisões sem pedido. Se algo fora do pedido parecer necessário, proponha numa frase e pergunte.
- Uma etapa por vez, com o "ok" do Mello antes da seguinte. Ao fim de cada etapa: o que mudou, como testar no aparelho, o que ficou pendente (até 4 linhas).
- Nunca mencione de onde veio a ideia do app nem cite outros apps como referência, em nenhum texto, código ou documento.
</instrucoes_de_trabalho>

## 1. O que é

App para **Android e computador (Windows e macOS)** que vira mesa de trilhas, vídeos, imagens e textos para teatro e stand-up. O aparelho é a mesa; o telão recebe só o palco, por HDMI ou como segundo monitor.
**Decisões:** o app é feito em Flutter (2026-10-15); a web saiu da fila e o foco é app e computador; iPhone e iPad ficam para depois (2026-10-16). O código Kotlin e o protótipo web são só referência de comportamento.
Obrigatório em todas as plataformas: a tela nunca apaga nem bloqueia com o app aberto (sem opção de desligar) e o som continua em segundo plano (app minimizado, outro app por cima, tela do sistema bloqueada).
Limites: no iPhone/iPad o app não escolhe a saída de áudio (abre o seletor do iOS) e copia a mídia para dentro do app; no computador o telão é uma janela em tela cheia no segundo monitor.
É o futuro módulo premium "Tela de Cabine Técnica" do **PocketStage** (stage manager de bolso do Mello, Flutter + Firebase, ainda só protótipo web), na Fase 3 dele. Até lá, apps separados que trocam shows no mesmo formato.

## 2. Regras de reprodução (não mudar sem pedido)

1. 4 colunas fixas; 4 a 32 botões (de 4 em 4), mais 48 e 64. Coluna = índice % 4.
2. Uma mídia por coluna; a nova corta a anterior (com fade, se ligado). Colunas diferentes tocam juntas.
3. Tocar de novo o botão que toca: para / recomeça / ignora (Ajuste geral; padrão: para).
4. Telão: uma imagem ou vídeo por vez, de qualquer coluna. Texto é camada por cima; texto novo substitui texto.
5. Fim natural libera a coluna e apaga o telão, exceto vídeo "fixo no último quadro".
6. Imagem fica até ser tocada de novo, substituída, apagada ou sair pelo tempo de tela.
7. Trilha com imagem ligada: a imagem entra junto; ao acabar a trilha fica (padrão) ou sai, escolhido num pop-up ao ligar.
8. ▶ da linha: para tudo e toca a linha. Tocar de novo para tudo. GO = próxima linha; também linha anterior. Cada ▶ mostra o número da linha; teclas 1–9 tocam as linhas 1–9 e 0 toca a linha 10.
9. Pausar congela tudo (incl. pré-esperas e tempos). Parar tudo usa o fade do Parar tudo. Bloquear desativa a grade; desbloquear = segurar.
10. Painel do telão: o título "Telão" é o botão Mostrar/Ocultar telão. Ocultar recolhe o painel para a direita (grade ocupa tudo); mostrar expande. O botão nunca muda de lugar. Aberto, o painel fica fixo ao rolar a grade.

## 3. Mídia (cue) — campos do show.json

Tipos: AUDIO, VIDEO, IMAGE, TEXT. `id` fixo (trocar arquivo mantém; remover e readicionar gera outro).
Básico: name, volume (linear; UI em dB −∞ a +6), loop, fadeIn, fadeOut, fit (CONTAIN/COVER), hold, text/textPos/textSize, visualId/visualStays, linkId/role (entrada, saida, fundo, livre).
Avançado: startSec, endSec, fadeInSec, fadeOutSec, fadeCurve (null = padrão), pan, repeat, duckDb, muted, preWaitSec, autoStopSec, followId/followMode/followSec, stopCols/stopAllOnGo, lockAfter, transition (null = padrão)/transSec, color, note, hotkey.

## 4. Ajustes gerais (JSON nas preferências; mesmos nomes no web)

fadeIn 2, fadeOut 3, fadeCurve linear, stopAllFade 0.35, masterDb 0, retrigger parar, pausePreWait true (Pausar congela as pré-esperas; desligado, cancela), audioDeviceType 0 (Android), transition fade, visFade 1, textPos embaixo, textSize M, btnSize M, clockMode restante, endWarnSec 5, showRowGo true, confirmStopAll false, holdSec 1.2, lockOnOpen false, confirmExit true, tipAirplane true (tela sempre ligada é obrigatória, sem ajuste), keys {go: PageDown, prev: PageUp, stopAll, pause, blackout}.
Uma tecla = uma ação. Atalho geral vence atalho de mídia, que vence atalho de linha (1–9, 0). Restaurar padrões disponível.

## 5. Integração com o PocketStage

- show.json: `{format:"pocketstage.show", version:1, id, name, date?, start?, eventType?, lineup[], media:{count, cells[32] (até 64 quando o show passa de 32 botões)}, updatedAt}`. lineup e campos desconhecidos passam sem mudança. Formato antigo convertido sozinho.
- .psshow = ZIP (show.json, log.json, media/<cueId>.<ext>). Importar cria show novo; versão > 1 recusada com "Este show foi criado numa versão mais nova do PocketStage. Atualize o app."
- Comandos: go, stop, play_row, stop_all, blackout, pause, resume, lock, unlock, release_locks, load_show, set_settings.
- show.json também guarda local, showType e `run` (cronômetro no modelo do PocketStage; hoje a mesa usa só running/runStart/acc, contagem progressiva).
- Exportar show = só a estrutura ("(estrutura)" no nome); Exportar show completo = com mídias, avisa o tamanho.
- Log: `{t, source:"midia", type, ref, linkId, text}`; tipos cue_go, cue_stop, cue_end, stop_all, blackout, pause, resume, lock, unlock, timer ("Cronômetro · Play/Pause (MM:SS)/Stop (MM:SS)").
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

Fase de base concluída em 2026-10-16 (Mello: "atingimos o objetivo até aqui"). Versões de teste em Releases › teste.
Feito e testado pelo Mello no celular e no PC:
- Build no GitHub Actions (Android, Windows, macOS, iOS sem assinatura); núcleo Dart com testes; capturas no ramo ci-capturas; teste da mesa com telão no Windows no ramo ci-capturas-win.
- Mesa, Shows, Editor, Ajustes da mídia, Ajustes; salvamento automático; pergunta antes de fechar; Exportar show / completo; "ARQUIVO FALTANDO".
- Android: telão HDMI (Presentation + 2º motor `telaoMain`, canal psm/telao) e DeX (TelaoActivity); som/vídeo por ExoPlayer nativo (Som.kt, canal psm/player); saída de som escolhida (padrão telefone); serviço em primeiro plano.
- Computador: telão em 2ª janela (desktop_multi_window 0.3.1 + window_manager fork boyan01 6fae92d, posição nativa psm/janela); aviso "Abrindo telão… aguarde". Mesa travava com o telão aberto: o media_kit_video guarda instância global e subclassifica a janela; corrigido no setup_platforms.sh (SetPropW 'psm_mkv', build falha se não aplicar).
- Cronômetro simples abaixo do telão (Play, Pause, Stop; progressivo; sem fila); modelo `run` completo em cronometro.dart para depois.
- Registro do show (Menu): lista, exportar .txt, limpar.
- 48 e 64 botões; ▶ numerados; teclas 1–9/0 tocam linhas.
- Exemplo v3: sinais e entradas Rock/Pop/HipHop (MP3 do Mello), cartaz "Comédia Stand Up"; migração tira atalhos 1–3 dos sinais em exemplos antigos.
- Editor: segurar e arrastar move a mídia (ocupado = troca); menu do botão com Copiar e Recortar; Colar = cópia com mesmos ajustes, id novo, sem atalho (Show.moverCelula/copiarCelula/colarCue no núcleo). Duplicar show (lista e menu da mesa): "Nome (cópia)", mesmas mídias (no celular copiadas de novo), fila; run e log zerados.
- Teste em palco aprovado pelo Mello no telefone e no computador (2026-10-16).
Decisões respondidas (2026-10-16), comportamento atual mantido: editar o show em uso não para nada (salvamento automático); deixas travadas destravam ao reabrir; Ajustes e atalhos gerais não viajam no .psshow (são do aparelho); aviso de fim só visual; celular/tablet copiam a mídia, computador usa o original; o app lembra se o painel do telão estava aberto.
Próximos passos (a partir do 2 é proposta; o Mello decide):
1. Assinatura fixa do APK: Mello cria os segredos PSM_KEYSTORE_B64 e PSM_KEY_PASSWORD (em andamento).
2. Abrir .psshow pelo arquivo e deep link.
3. Cronômetro com fila (regressiva, fases, textos do PS) usando o `run` existente.
4. Verificar show e desfazer (em aberto; o Mello não pediu ainda).
5. iPhone e iPad (telão externo).
6. Fase 3 com o PocketStage (cronômetro linkado).
Riscos: ajuste do media_kit_video ao atualizar o media_kit; pan/ganho > 0 dB a validar; iOS exige Mac e conta Apple Developer.
