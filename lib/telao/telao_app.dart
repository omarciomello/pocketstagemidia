import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../media/android_player.dart';
import '../theme.dart';
import '../media/backend.dart';
import '../ui/stage_view.dart';
import 'canal.dart';
import 'transporte.dart';

/// Vídeo nativo (Android) desenhado numa textura deste telão.
class _VideoNoTelao implements MediaPlayer, VideoTextura {
  @override
  final ValueNotifier<int?> textura = ValueNotifier(null);
  @override
  final ValueNotifier<Size?> tamanho = ValueNotifier(null);
  @override
  void play() {}
  @override
  void pause() {}
  @override
  void setGain(double gain) {}
  @override
  int get positionMs => 0;
  @override
  int? get durationMs => null;
  @override
  void dispose() {}
}

/// O app que roda no monitor externo: só o palco, em tela cheia.
class TelaoApp extends StatefulWidget {
  TelaoApp({super.key, TransporteTelao? transporte, this.onFechar}) : transporte = transporte ?? CanalTelao.instancia;

  final TransporteTelao transporte;

  /// Computador: a mesa pediu para fechar a janela do telão.
  final VoidCallback? onFechar;

  @override
  State<TelaoApp> createState() => _TelaoAppState();
}

class _TelaoAppState extends State<TelaoApp> {
  final StageController _stage = StageController();
  final Map<int, MkPlayer> _players = {};
  final Map<int, _VideoNoTelao> _nativos = {};
  late final TransporteTelao _canal = widget.transporte;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _pos;

  @override
  void initState() {
    super.initState();
    _stage.onImageError = (id) => _canal.enviar({'t': 'imgerr', 'cueId': id});
    _sub = _canal.mensagens.listen(_msg);
    _pos = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _players.forEach((id, p) {
        _canal.enviar({'t': 'pos', 'id': id, 'pos': p.positionMs, 'dur': p.durationMs});
      });
    });
    _canal.pronto();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pos?.cancel();
    for (final p in _players.values) {
      p.dispose();
    }
    super.dispose();
  }

  void _msg(Map<String, dynamic> m) {
    final id = m['id'] is num ? (m['id'] as num).toInt() : -1;
    switch (m['t']) {
      case 'fechar':
        widget.onFechar?.call();
      case 'open':
        final cue = Cue.fromJson(Map<String, dynamic>.from(m['cue'] as Map));
        _players[id] = MkPlayer.create(
          cue,
          () => _canal.enviar({'t': 'end', 'id': id}),
          () => _canal.enviar({'t': 'error', 'id': id}),
        );
      case 'play':
        _players[id]?.play();
      case 'pause':
        _players[id]?.pause();
      case 'gain':
        _players[id]?.setGain((m['g'] as num).toDouble());
      case 'dispose':
        _players.remove(id)?.dispose();
      case 'tex':
        final v = _nativos.putIfAbsent(id, _VideoNoTelao.new);
        v.textura.value = (m['tex'] as num?)?.toInt();
        final w = m['w'], h = m['h'];
        if (w is num && h is num) v.tamanho.value = Size(w.toDouble(), h.toDouble());
      case 'visual':
        final c = m['cue'];
        final pid = m['player'] is num ? (m['player'] as num).toInt() : null;
        final nid = m['nativo'] is num ? (m['nativo'] as num).toInt() : null;
        final MediaPlayer? pl = nid != null ? _nativos.putIfAbsent(nid, _VideoNoTelao.new) : (pid == null ? null : _players[pid]);
        _stage.present(
          c is Map ? StageVisual(Cue.fromJson(Map<String, dynamic>.from(c)), pl) : null,
          Transition.from(m['tr'] as String?),
          (m['ms'] as num?)?.toInt() ?? 0,
        );
      case 'text':
        final t = m['text'];
        _stage.presentText(
          t is String ? StageText(t, TextPos.from(m['pos'] as String?), TextSize.from(m['size'] as String?)) : null,
          (m['in'] as num?)?.toInt() ?? 0,
          (m['out'] as num?)?.toInt() ?? 0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: temaPocketStage(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(child: StageView(stage: _stage, mostrarApagado: false)),
      ),
    );
  }
}
