import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart' as core;

import '../media/android_player.dart';
import '../media/backend.dart';
import '../theme.dart';

class _Camada {
  _Camada(this.id, this.child, {this.opacity = 0});
  final int id;
  final Widget child;
  double opacity;
  int ms = 0;
  bool saindo = false;
}

/// Desenha o telão: imagem ou vídeo com texto por cima, com as transições do show.
/// Várias StageView podem mostrar o mesmo [StageController] (prévia e tela cheia).
class StageView extends StatefulWidget {
  const StageView({super.key, required this.stage, this.mostrarApagado = true});

  final StageController stage;
  final bool mostrarApagado;

  @override
  State<StageView> createState() => _StageViewState();
}

class _StageViewState extends State<StageView> {
  final List<_Camada> _vis = [];
  final List<_Camada> _txt = [];
  int _frame = -1;
  int _text = -1;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    widget.stage.addListener(_mudou);
    final f = widget.stage.frame;
    _frame = f.serial;
    if (f.visual != null) _vis.add(_Camada(f.serial, _visual(f.visual!), opacity: 1));
    final t = widget.stage.text;
    _text = t.serial;
    if (t.text != null) _txt.add(_Camada(t.serial, _texto(t.text!), opacity: 1));
  }

  @override
  void didUpdateWidget(StageView old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      old.stage.removeListener(_mudou);
      widget.stage.addListener(_mudou);
    }
  }

  @override
  void dispose() {
    widget.stage.removeListener(_mudou);
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _depois(int ms, VoidCallback fn) {
    _timers.add(Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(fn);
    }));
  }

  void _mudou() {
    final f = widget.stage.frame;
    if (f.serial != _frame) {
      _frame = f.serial;
      _trocaVisual(f);
    }
    final t = widget.stage.text;
    if (t.serial != _text) {
      _text = t.serial;
      _trocaTexto(t);
    }
  }

  void _trocaVisual(StageFrame f) {
    final ms = f.ms;
    final corte = f.transition == core.Transition.corte || ms <= 0;
    final preto = f.transition == core.Transition.preto;
    final saida = f.visual == null ? (corte ? 0 : ms) : (corte ? 0 : (preto ? ms ~/ 2 : ms));
    setState(() {
      for (final c in _vis.where((c) => !c.saindo)) {
        c.saindo = true;
        c.opacity = 0;
        c.ms = saida;
        _depois(saida + 80, () => _vis.remove(c));
      }
      final v = f.visual;
      if (v == null) return;
      final nova = _Camada(f.serial, _visual(v), opacity: corte ? 1 : 0);
      _vis.add(nova);
      if (!corte) {
        final atraso = preto ? ms ~/ 2 : 0;
        final dur = preto ? ms - ms ~/ 2 : ms;
        _depois(atraso + 16, () {
          nova.opacity = 1;
          nova.ms = dur;
        });
      }
    });
  }

  void _trocaTexto(StageTextFrame t) {
    setState(() {
      for (final c in _txt.where((c) => !c.saindo)) {
        c.saindo = true;
        c.opacity = 0;
        c.ms = t.outMs;
        _depois(t.outMs + 80, () => _txt.remove(c));
      }
      final txt = t.text;
      if (txt == null) return;
      final nova = _Camada(t.serial, _texto(txt), opacity: t.inMs <= 0 ? 1 : 0);
      _txt.add(nova);
      if (t.inMs > 0) {
        _depois(16, () {
          nova.opacity = 1;
          nova.ms = t.inMs;
        });
      }
    });
  }

  Widget _visual(core.StageVisual v) {
    final fit = v.cue.fit == core.Fit.cover ? BoxFit.cover : BoxFit.contain;
    final p = v.player;
    if (p is VideoTextura && !(p is PlayerAndroid && p.alvo == 'telao')) {
      return _TexturaVideo(p, fit);
    }
    if (v.cue.kind == core.MediaKind.video && !(p is MkPlayer && p.video != null)) {
      return ColoredBox(
        color: const Color(0xFF0B0C12),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('VÍDEO NO TELÃO',
                style: TextStyle(color: Cores.lilas, fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 11)),
            const SizedBox(height: 4),
            Text(v.cue.name, style: const TextStyle(color: Cores.texto, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    if (p is MkPlayer && p.video != null) {
      return Video(
        controller: p.video!,
        controls: NoVideoControls,
        fit: fit,
        fill: Colors.black,
        pauseUponEnteringBackgroundMode: false,
      );
    }
    final id = v.cue.id;
    return Image.file(
      File(core.PsShow.localPath(v.cue.uri)),
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        widget.stage.onImageError?.call(id);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _texto(core.StageText t) => _TextoTelao(t);

  @override
  Widget build(BuildContext context) {
    final aceso = _vis.isNotEmpty || _txt.isNotEmpty;
    return ClipRect(
      child: ColoredBox(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          if (!aceso && widget.mostrarApagado)
            const Center(
              child: Text('TELÃO APAGADO',
                  style: TextStyle(color: Color(0xFF262A36), fontWeight: FontWeight.w800, letterSpacing: 3, fontSize: 12)),
            ),
          for (final c in _vis)
            AnimatedOpacity(
              key: ValueKey('v${c.id}'),
              opacity: c.opacity,
              duration: Duration(milliseconds: c.ms),
              child: c.child,
            ),
          for (final c in _txt)
            AnimatedOpacity(
              key: ValueKey('t${c.id}'),
              opacity: c.opacity,
              duration: Duration(milliseconds: c.ms),
              child: c.child,
            ),
        ]),
      ),
    );
  }
}

/// Vídeo do Android, desenhado numa textura.
class _TexturaVideo extends StatelessWidget {
  const _TexturaVideo(this.v, this.fit);
  final VideoTextura v;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<int?>(
        valueListenable: v.textura,
        builder: (_, id, __) {
          if (id == null) return const SizedBox.expand();
          return ValueListenableBuilder<Size?>(
            valueListenable: v.tamanho,
            builder: (_, tam, __) {
              final t = tam ?? const Size(16, 9);
              return SizedBox.expand(
                child: FittedBox(
                  fit: fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(width: t.width, height: t.height, child: Texture(textureId: id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _TextoTelao extends StatelessWidget {
  const _TextoTelao(this.t);
  final core.StageText t;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final h = box.maxHeight;
      final estilo = TextStyle(
        color: const Color(0xFFEDE7DD),
        fontWeight: FontWeight.w800,
        fontSize: (h * t.size.scale).clamp(6.0, 400.0),
        height: 1.15,
        shadows: const [Shadow(color: Color(0x99000000), blurRadius: 12)],
      );
      switch (t.pos) {
        case core.TextPos.right:
          return Stack(children: [
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: w * .36,
              child: Container(
                color: const Color(0x9E0A0908),
                padding: EdgeInsets.symmetric(vertical: h * .05, horizontal: w * .04),
                alignment: Alignment.centerLeft,
                child: Text(t.text, style: estilo),
              ),
            ),
          ]);
        case core.TextPos.center:
          return Container(
            color: const Color(0x590A0908),
            padding: EdgeInsets.symmetric(vertical: h * .08, horizontal: w * .10),
            alignment: Alignment.center,
            child: Text(t.text, style: estilo, textAlign: TextAlign.center),
          );
        case core.TextPos.bottom:
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0908), Color(0xCC0A0908)],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(w * .06, h * .04, w * .06, h * .06),
                child: Text(t.text, style: estilo),
              ),
            ),
          ]);
      }
    });
  }
}

/// Telão em tela cheia (no aparelho ou numa janela levada ao segundo monitor).
class TelaoCheio extends StatelessWidget {
  const TelaoCheio({super.key, required this.stage});
  final StageController stage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onDoubleTap: () => Navigator.pop(context),
        child: Stack(children: [
          Positioned.fill(child: StageView(stage: stage, mostrarApagado: false)),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Fechar (ou toque duas vezes)',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Cores.textoApagado),
            ),
          ),
        ]),
      ),
    );
  }
}
