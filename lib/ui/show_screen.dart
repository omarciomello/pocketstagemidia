import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../media/android_player.dart';
import '../diagnostico.dart';
import '../state.dart';
import '../theme.dart';
import 'cronometro_box.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'shows_screen.dart';
import 'stage_view.dart';
import 'transfer.dart';
import 'widgets.dart';

/// A mesa: grade de botões, relógios das colunas e o painel do telão.
class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key, required this.app});
  final AppState app;

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  AppState get app => widget.app;
  Timer? _tick;
  StreamSubscription<String>? _toasts;
  StreamSubscription<String>? _saidas;
  final FocusNode _foco = FocusNode(debugLabel: 'mesa');
  String? _dicaDoShow;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final st = app.engine.state();
      if (mounted && (st.columns.any((c) => c != null) || st.waitingMs.isNotEmpty || st.fadingIdx.isNotEmpty)) {
        setState(() {});
      }
    });
    _toasts = app.toasts.listen((m) {
      if (mounted) aviso(context, m);
    });
    _saidas = app.novaSaida.listen((nome) {
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      m.hideCurrentSnackBar();
      m.showSnackBar(SnackBar(
        content: Text('Nova saída de som: $nome. O som continua em ${SomAndroid.instancia.nomeDe(app.settings.audioDeviceType)}.'),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Escolher', textColor: Cores.ciano, onPressed: _escolherSaida),
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _dicaAviao());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _toasts?.cancel();
    _saidas?.cancel();
    _foco.dispose();
    super.dispose();
  }

  void _dicaAviao() {
    final s = app.active;
    if (s == null || !mounted || _dicaDoShow == s.id) return;
    _dicaDoShow = s.id;
    if (app.settings.tipAirplane) {
      aviso(context, 'Dica: ligue o modo avião para nenhuma ligação ou notificação tocar durante o show.');
    }
  }

  // ---------- ações ----------

  Future<void> _pararTudo() async {
    if (app.settings.confirmStopAll &&
        !await confirmar(context, 'Parar tudo?', 'Todas as mídias param e o telão apaga.', ok: 'Parar tudo', perigo: true)) {
      return;
    }
    app.dispatch(const StopAll());
  }

  void _pausar() => app.dispatch(app.engine.paused ? const Resume() : const Pause());

  KeyEventResult _tecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (app.engine.locked || ModalRoute.of(context)?.isCurrent != true) return KeyEventResult.ignored;
    final name = keyNameOf(e);
    if (name == null) return KeyEventResult.ignored;
    final a = resolveKey(name, app.settings, app.active);
    switch (a) {
      case null:
        return KeyEventResult.ignored;
      case GlobalKeyAction(:final key):
        switch (key) {
          case ShortcutAction.go:
            app.engine.stepRow(1);
          case ShortcutAction.prev:
            app.engine.stepRow(-1);
          case ShortcutAction.stopAll:
            _pararTudo();
          case ShortcutAction.pause:
            _pausar();
          case ShortcutAction.blackout:
            app.dispatch(const Blackout());
        }
      case CueKeyAction(:final cueId):
        app.dispatch(Go(cueId));
    }
    return KeyEventResult.handled;
  }

  Future<void> _sair() async {
    if (!app.settings.confirmExit ||
        await confirmar(context, 'Sair do app?', 'O que estiver tocando para e o telão apaga.', ok: 'Sair', perigo: true)) {
      app.engine.hardStop();
      await SystemNavigator.pop();
    }
  }

  void _menu() {
    final s = app.active;
    final travadas = app.engine.state().usedCueIds.length;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        Widget item(String t, IconData i, VoidCallback f, {Color cor = Cores.texto}) => ListTile(
              leading: Icon(i, color: cor),
              title: Text(t, style: TextStyle(color: cor, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(c);
                f();
              },
            );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              item('Shows salvos', Icons.list_alt, () => _abrir(ShowsScreen(app: app))),
              if (s != null) item('Editar este show', Icons.edit_outlined, () => _abrir(EditorScreen(app: app, show: s))),
              if (s != null) item('Exportar show', Icons.ios_share, () => exportarShow(context, app, s)),
              if (s != null)
                item('Exportar show completo', Icons.inventory_2_outlined, () => exportarShow(context, app, s, completo: true)),
              item('Importar show', Icons.file_open_outlined, () => importarShow(context, app)),
              if (travadas > 0)
                item('Liberar deixas travadas ($travadas)', Icons.lock_open, () {
                  app.dispatch(const ReleaseLocks());
                  aviso(context, 'Deixas liberadas.');
                }),
              if (app.telao != null && Platform.isAndroid) item('Telão: diagnóstico', Icons.cast, _diagnostico),
              item('Ajustes', Icons.tune, () => _abrir(SettingsScreen(app: app))),
              if (Diagnostico.caminho != null)
                item('Arquivo de diagnóstico', Icons.bug_report_outlined, () {
                  final c = Diagnostico.caminho!;
                  Clipboard.setData(ClipboardData(text: c));
                  aviso(context, 'Caminho copiado: $c');
                }),
              item('Sobre', Icons.info_outline, _sobre),
            ]),
          ),
        );
      },
    );
  }

  void _abrir(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  void _escolherSaida() => escolherSaidaSom(context, app);

  Future<void> _diagnostico() async {
    final t = app.telao!;
    final txt = await t.diagnostico();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Telão: diagnóstico', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SingleChildScrollView(child: SelectableText(txt, style: mono(size: 12, color: Cores.texto, weight: FontWeight.w500))),
        actions: [
          Btn('Copiar', onTap: () {
            Clipboard.setData(ClipboardData(text: txt));
            aviso(context, 'Diagnóstico copiado.');
          }),
          Btn('Reconectar', onTap: () {
            Navigator.pop(c);
            t.reconectar();
          }),
          Btn('Fechar', tipo: BtnTipo.primario, onTap: () => Navigator.pop(c)),
        ],
      ),
    );
  }

  void _sobre() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('PocketStage Mídia', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Mesa de trilhas, vídeos, imagens e textos para teatro e stand-up. Quatro colunas: cada uma toca uma mídia '
          'por vez e corta a anterior; colunas diferentes tocam juntas. Imagens e vídeos vão para o telão, um por vez, '
          'e o texto fica por cima.',
          style: TextStyle(color: Cores.textoFraco, height: 1.45),
        ),
        actions: [Btn('Fechar', onTap: () => Navigator.pop(c))],
      ),
    );
  }

  // ---------- desenho ----------

  @override
  Widget build(BuildContext context) {
    final s = app.active;
    final st = app.engine.state();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sair();
      },
      child: Focus(
        focusNode: _foco,
        autofocus: true,
        onKeyEvent: _tecla,
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              _barra(s, st),
              Expanded(
                child: s == null
                    ? Center(child: Btn('Abrir um show', tipo: BtnTipo.primario, onTap: () => _abrir(ShowsScreen(app: app))))
                    : LayoutBuilder(builder: (context, box) => _corpo(s, st, box.maxWidth)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _barra(Show? s, EngineState st) {
    final tocando = st.columns.any((c) => c != null) || st.fadingIdx.isNotEmpty || st.waitingMs.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Cores.linha))),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: tocando ? Cores.verde : Cores.textoApagado),
        ),
        const SizedBox(width: 10),
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'Pocket', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          TextSpan(text: 'Stage', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Cores.ciano)),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(border: Border.all(color: Cores.lilas), borderRadius: BorderRadius.circular(4)),
          child: const Text('MÍDIA', style: TextStyle(color: Cores.lilas, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(s?.name ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoFraco, fontSize: 13)),
        ),
        if (Platform.isAndroid)
          ListenableBuilder(
            listenable: SomAndroid.instancia,
            builder: (_, __) {
              final som = SomAndroid.instancia;
              final ok = som.escolhidaPresente;
              return GestureDetector(
                onTap: _escolherSaida,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: ok ? Cores.ciano : Cores.laranja),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.volume_up, size: 14, color: ok ? Cores.ciano : Cores.laranja),
                    const SizedBox(width: 4),
                    Text(ok ? som.nomeDe(som.escolhida).split(' (').first.toUpperCase() : 'TELEFONE*',
                        style: mono(size: 11, color: ok ? Cores.ciano : Cores.laranja, weight: FontWeight.w700)),
                  ]),
                ),
              );
            },
          ),
        if (app.telao?.disponivel == true)
          ListenableBuilder(
            listenable: app.telao!,
            builder: (_, __) {
              final n = app.telao!.conectado;
              final abrindo = n == null && app.telao!.abrindo;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: n != null || abrindo ? Cores.lilas : Cores.linha),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(n != null ? 'TELÃO $n' : (abrindo ? 'ABRINDO TELÃO…' : 'SEM TELÃO'),
                    style: mono(size: 11, color: n != null || abrindo ? Cores.lilas : Cores.textoFraco, weight: FontWeight.w700)),
              );
            },
          ),
        if (s != null && st.locked)
          HoldButton(
            label: 'Segure para desbloquear',
            segundos: app.settings.holdSec,
            onDone: () => app.dispatch(const Unlock()),
          )
        else if (s != null) ...[
          Btn('Bloquear', compacto: true, onTap: () => app.dispatch(const Lock())),
          const SizedBox(width: 6),
          Btn(st.paused ? 'Retomar' : 'Pausar', compacto: true, tipo: st.paused ? BtnTipo.ligado : BtnTipo.normal, onTap: _pausar),
          const SizedBox(width: 6),
          Btn('Parar tudo', compacto: true, tipo: BtnTipo.perigo, onTap: _pararTudo),
          const SizedBox(width: 6),
        ],
        if (!(s != null && st.locked)) Btn('', icon: Icons.more_vert, compacto: true, onTap: _menu),
      ]),
    );
  }

  Widget _corpo(Show s, EngineState st, double largura) {
    final aberto = app.tvOpen;
    final painel = math.min(340.0, math.max(220.0, largura * .32));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _mesa(s, st)),
        const SizedBox(width: 12),
        // O painel do telão fica fora da rolagem: não se move ao rolar a grade.
        SizedBox(
          width: aberto ? painel : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _botaoTelao(aberto),
            if (aberto) ...[
              const SizedBox(height: 10),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 12), child: _monitor(s, st))),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _botaoTelao(bool aberto) {
    return Tooltip(
      message: aberto ? 'Ocultar telão' : 'Mostrar telão',
      child: Material(
        color: Cores.painel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: aberto ? const Color(0x66E0A6F0) : Cores.linha),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => app.tvOpen = !aberto,
          child: SizedBox(
            height: 36,
            width: 96,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(aberto ? Icons.chevron_right : Icons.chevron_left, size: 18, color: aberto ? Cores.lilas : Cores.textoFraco),
              const SizedBox(width: 2),
              Text('Telão',
                  style: TextStyle(
                    color: aberto ? Cores.lilas : Cores.textoFraco,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _monitor(Show s, EngineState st) {
    String? nome(String? id) => id == null ? null : s.cueById(id)?.name;
    final tela = nome(st.screenCueId);
    final texto = nome(st.textCueId);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: Border.all(color: app.stage.lit ? Cores.lilas : Cores.linha)),
          child: StageView(stage: app.stage),
        ),
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(style: const TextStyle(color: Cores.textoFraco, fontSize: 13, height: 1.5), children: [
          const TextSpan(text: 'No telão: '),
          TextSpan(text: tela ?? 'nada', style: TextStyle(color: tela == null ? Cores.textoFraco : Cores.texto, fontWeight: FontWeight.w700)),
          if (texto != null) ...[
            const TextSpan(text: '\nTexto: '),
            TextSpan(text: texto, style: const TextStyle(color: Cores.texto, fontWeight: FontWeight.w700)),
          ],
          if (st.currentRow != null) TextSpan(text: '\nLinha ${st.currentRow! + 1}'),
        ]),
      ),
      const SizedBox(height: 8),
      Btn('Apagar telão',
          onTap: (st.screenCueId != null || st.textCueId != null) && !st.locked ? () => app.dispatch(const Blackout()) : null),
      const SizedBox(height: 8),
      if (app.telao?.janela != null)
        ListenableBuilder(
          listenable: app.telao!,
          builder: (_, __) {
            final t = app.telao!;
            if (!t.ativo && t.abrindo) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Cores.cianoFundo,
                  border: Border.all(color: Cores.ciano),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Cores.ciano)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('Abrindo telão… aguarde',
                        style: TextStyle(color: Cores.ciano, fontWeight: FontWeight.w700)),
                  ),
                ]),
              );
            }
            return Btn(
              t.ativo ? 'Fechar telão' : 'Abrir telão no 2º monitor',
              tipo: t.ativo ? BtnTipo.ligado : BtnTipo.normal,
              onTap: () => t.ativo ? t.janela!.fechar() : t.janela!.abrir(),
            );
          },
        )
      else
        Btn('Telão em tela cheia',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TelaoCheio(stage: app.stage)))),
      const SizedBox(height: 14),
      CronometroBox(app: app),
    ]);
  }

  Widget _mesa(Show s, EngineState st) {
    final aj = app.settings;
    final linhaGo = aj.showRowGo;
    final alturas = {'P': 64.0, 'M': 84.0, 'G': 104.0};
    final h = alturas[aj.btnSize] ?? 84.0;
    final porIndice = <int, ColumnState>{
      for (final c in st.columns)
        if (c != null) c.index: c,
    };
    final agora = DateTime.now().millisecondsSinceEpoch;
    final pisca = (agora ~/ 400).isEven;

    Widget relogioCol(int col) {
      final c = st.columns[col];
      if (c == null) {
        return Text('00:00', textAlign: TextAlign.center, style: mono(size: 19, color: Cores.textoFraco));
      }
      final r = _tempo(s, c, aj);
      final aviso = r.aviso && !st.paused;
      final cor = aviso ? (pisca ? Cores.laranja : Cores.laranja.withValues(alpha: .35)) : Cores.ciano;
      final icone = switch (c.kind) {
        MediaKind.image => Icons.image_outlined,
        MediaKind.text => Icons.notes,
        _ => null,
      };
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icone != null) ...[Icon(icone, size: 17, color: cor), const SizedBox(width: 6)],
        Flexible(child: Text(r.texto, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: mono(size: 19, color: cor))),
        if (c.loop && c.kind != MediaKind.image && c.kind != MediaKind.text) ...[
          const SizedBox(width: 4),
          Icon(Icons.repeat, size: 16, color: cor),
        ],
      ]);
    }

    return Column(children: [
      Row(children: [
        if (linhaGo) const SizedBox(width: 52),
        for (var c = 0; c < cols; c++) Expanded(child: relogioCol(c)),
      ]),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(children: [
            for (var r = 0; r < s.rows; r++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  height: h,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (linhaGo) ...[
                      _RowGo(
                        atual: st.currentRow == r,
                        onTap: st.locked ? null : () => app.dispatch(PlayRow(r)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    for (var c = 0; c < cols; c++) ...[
                      if (c > 0) const SizedBox(width: 10),
                      Expanded(child: _celula(s, st, r * cols + c, porIndice[r * cols + c])),
                    ],
                  ]),
                ),
              ),
            if (st.locked)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('BLOQUEADO · OS BOTÕES NÃO RESPONDEM',
                    style: TextStyle(color: Cores.ciano, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 12)),
              ),
          ]),
        ),
      ),
    ]);
  }

  ({String texto, bool aviso, double progresso}) _tempo(Show s, ColumnState c, Settings aj) {
    final cue = s.cueById(c.cueId);
    final ini = ((cue?.startSec ?? 0) * 1000).round();
    final decorrido = aj.clockMode == 'decorrido';
    int? resta;
    String txt;
    double prog;
    if (c.kind == MediaKind.image || c.kind == MediaKind.text) {
      if (c.durMs > 0) resta = c.durMs - c.posMs;
      txt = resta != null && !decorrido ? '−${relogio(resta)}' : relogio(c.posMs);
      prog = c.durMs > 0 ? c.posMs / c.durMs : 1;
    } else {
      final dur = c.durMs - ini;
      final pos = c.posMs - ini;
      if (!c.loop && dur > 0) resta = dur - pos;
      txt = resta != null && !decorrido ? '−${relogio(resta)}' : relogio(pos);
      prog = dur > 0 ? pos / dur : 0;
    }
    final w = (aj.endWarnSec * 1000).round();
    return (texto: txt, aviso: w > 0 && resta != null && resta <= w, progresso: prog.clamp(0.0, 1.0));
  }

  Widget _celula(Show s, EngineState st, int i, ColumnState? vivo) {
    final cue = s.cells[i];
    if (cue == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0x05FFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Cores.linha),
        ),
        alignment: Alignment.center,
        child: const Text('Sem mídia', style: TextStyle(color: Cores.textoApagado)),
      );
    }
    final aj = app.settings;
    final t = vivo == null ? null : _tempo(s, vivo, aj);
    final espera = st.waitingMs[i];
    final saindo = vivo == null && st.fadingIdx.contains(i);
    final travada = cue.lockAfter && st.usedCueIds.contains(cue.id);
    final falta = app.faltando(s).contains(cue.id);
    final noTelao = vivo?.onScreen ?? false;
    final artista = s.lineupName(cue.linkId);
    final cor = corDe(cue.color);
    final tam = {'P': 14.0, 'M': 16.0, 'G': 19.0}[aj.btnSize] ?? 16.0;
    final aviso = t != null && t.aviso && !st.paused;

    Color borda = Cores.linha;
    if (vivo != null) borda = aviso ? Cores.laranja : Cores.ciano;
    if (saindo) borda = const Color(0x736FD3DF);
    if (espera != null) borda = Cores.lilas;

    return Opacity(
      opacity: travada ? .5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: st.locked ? null : (_) => app.dispatch(Go(cue.id)),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: vivo != null ? Cores.cianoEscuro : Cores.painel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borda, width: vivo != null || espera != null ? 1.5 : 1),
            boxShadow: vivo != null ? const [BoxShadow(color: Color(0x266FD3DF), blurRadius: 18, offset: Offset(0, 4))] : null,
          ),
          child: Stack(children: [
            if (vivo != null)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: t!.progresso,
                  child: const ColoredBox(color: Cores.cianoFundo),
                ),
              ),
            if (cor != null) Positioned(left: 0, right: 0, top: 0, height: 4, child: ColoredBox(color: cor)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              // Em botão baixo o conteúdo é cortado em vez de estourar.
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxHeight: double.infinity,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (falta)
                  const Text('ARQUIVO FALTANDO',
                      style: TextStyle(color: Cores.vermelho, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2))
                else if (travada)
                  const Text('TRAVADA', style: TextStyle(color: Cores.vermelho, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2))
                else if (cue.kind != MediaKind.audio)
                  Text(cue.kind.label,
                      style: TextStyle(
                        color: noTelao ? Cores.lilas : Cores.textoFraco,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      )),
                Text(
                  cue.name,
                  maxLines: artista != null || cue.note.isNotEmpty ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tam,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: vivo != null ? Cores.ciano : (saindo ? Cores.textoFraco : Cores.texto),
                  ),
                ),
                if (artista != null)
                  Text(artista, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Cores.textoFraco, fontSize: 11)),
                if (cue.note.isNotEmpty)
                  Text(cue.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Cores.textoFraco, fontSize: 11, fontStyle: FontStyle.italic)),
                  ]),
                ),
              ),
            ),
            if (cue.hotkey.isNotEmpty)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(border: Border.all(color: Cores.linha), borderRadius: BorderRadius.circular(3)),
                  child: Text(keyLabel(cue.hotkey), style: mono(size: 10, color: Cores.textoFraco, weight: FontWeight.w500)),
                ),
              ),
            if (espera != null)
              Positioned(
                bottom: 5,
                right: 7,
                child: Text('espera ${(espera / 1000).ceil()}s', style: mono(size: 11, color: Cores.lilas, weight: FontWeight.w500)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _RowGo extends StatelessWidget {
  const _RowGo({required this.atual, required this.onTap});
  final bool atual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTap == null ? null : (_) => onTap!(),
      child: Container(
        width: 44,
        decoration: BoxDecoration(
          color: atual ? Cores.ciano : Cores.painel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: atual ? Cores.ciano : Cores.linha),
          boxShadow: atual ? const [BoxShadow(color: Color(0x4D6FD3DF), blurRadius: 18, offset: Offset(0, 4))] : null,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.play_arrow_rounded, size: 24, color: atual ? Cores.tinta : Cores.textoFraco),
      ),
    );
  }
}
