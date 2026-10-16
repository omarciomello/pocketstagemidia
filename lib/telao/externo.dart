import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../media/backend.dart';
import 'canal.dart';

/// Vídeo que toca no telão externo. A mesa controla; o telão toca e informa a posição.
class RemotePlayer implements MediaPlayer {
  RemotePlayer(this._t, this.id, this.cue, this.onEnd, this.onError) {
    _t._enviar({'t': 'open', 'id': id, 'cue': cue.toJson()});
  }

  final TelaoExterno _t;
  final int id;
  final Cue cue;
  final void Function() onEnd;
  final void Function() onError;
  bool _tocando = false;
  bool disposed = false;
  int _pos = 0;
  int? _dur;
  final Stopwatch _desde = Stopwatch()..start();

  void _posicao(int pos, int? dur) {
    _pos = pos;
    _dur = dur;
    _desde.reset();
  }

  @override
  void play() {
    _tocando = true;
    _desde.reset();
    _t._enviar({'t': 'play', 'id': id});
  }

  @override
  void pause() {
    _pos = positionMs;
    _tocando = false;
    _t._enviar({'t': 'pause', 'id': id});
  }

  @override
  void setGain(double gain) => _t._enviar({'t': 'gain', 'id': id, 'g': gain});

  @override
  int get positionMs {
    final p = _tocando ? _pos + _desde.elapsedMilliseconds : _pos;
    final d = _dur;
    return d != null && p > d ? d : p;
  }

  @override
  int? get durationMs => _dur;

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    _t._players.remove(id);
    _t._enviar({'t': 'dispose', 'id': id});
  }
}

/// Mesa: liga o telão externo (HDMI no Android) ao [StageController].
class TelaoExterno extends ChangeNotifier {
  TelaoExterno(this.stage) {
    if (!Platform.isAndroid) return;
    _canal.eventos.listen(_evento);
    _canal.mensagens.listen(_mensagem);
    _canal.erros.listen((e) => onAviso?.call(e));
    stage.addListener(_mudou);
    _canal.estado().then((n) {
      if (n != null && conectado == null) _evento(n);
    });
  }

  final StageController stage;
  final CanalTelao _canal = CanalTelao.instancia;

  /// Resolução do telão ("1920×1080") ou null sem telão.
  String? conectado;
  final Map<int, RemotePlayer> _players = {};
  int _proximo = 1;
  int _frame = -1;
  int _texto = -1;

  /// Chamado quando o telão cai com vídeo tocando.
  void Function(String msg)? onAviso;

  bool get ativo => conectado != null;

  Future<String> diagnostico() => _canal.diagnostico();

  Future<void> reconectar() => _canal.reconectar();

  void _enviar(Map<String, dynamic> m) {
    if (ativo) _canal.enviar(m);
  }

  MediaPlayer abrirVideo(Cue cue, void Function() onEnd, void Function() onError) {
    final p = RemotePlayer(this, _proximo++, cue, onEnd, onError);
    _players[p.id] = p;
    return p;
  }

  void _evento(String? nome) {
    if (nome != null) {
      conectado = nome;
      _frame = -1;
      _texto = -1;
      _mudou();
    } else {
      conectado = null;
      final perdidos = _players.values.toList();
      _players.clear();
      for (final p in perdidos) {
        if (!p.disposed) p.onError();
      }
      if (perdidos.isNotEmpty) onAviso?.call('Telão desconectado: o vídeo parou.');
    }
    notifyListeners();
  }

  void _mensagem(Map<String, dynamic> m) {
    final id = m['id'] is num ? (m['id'] as num).toInt() : -1;
    final p = _players[id];
    switch (m['t']) {
      case 'pos':
        p?._posicao((m['pos'] as num).toInt(), (m['dur'] as num?)?.toInt());
      case 'end':
        if (p != null && !p.disposed) p.onEnd();
      case 'error':
        if (p != null && !p.disposed) p.onError();
      case 'imgerr':
        final c = m['cueId'];
        if (c is String) stage.onImageError?.call(c);
    }
  }

  /// Repassa ao telão cada troca de imagem/vídeo e de texto.
  void _mudou() {
    if (!ativo) return;
    final f = stage.frame;
    if (f.serial != _frame) {
      _frame = f.serial;
      final v = f.visual;
      final remoto = v?.player is RemotePlayer ? (v!.player as RemotePlayer).id : null;
      // vídeo aberto antes de o telão conectar continua só na mesa
      final mandar = v != null && (v.cue.kind != MediaKind.video || remoto != null);
      _canal.enviar({
        't': 'visual',
        'cue': mandar ? v.cue.toJson() : null,
        'player': remoto,
        'tr': f.transition.key,
        'ms': f.ms,
      });
    }
    final t = stage.text;
    if (t.serial != _texto) {
      _texto = t.serial;
      final x = t.text;
      _canal.enviar({
        't': 'text',
        'text': x?.text,
        'pos': x?.pos.key,
        'size': x?.size.key,
        'in': t.inMs,
        'out': t.outMs,
      });
    }
  }
}
