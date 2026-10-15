import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

/// O que o telão deve mostrar agora. Cada troca ganha um número novo ([serial]).
class StageFrame {
  const StageFrame(this.serial, this.visual, this.transition, this.ms);
  final int serial;
  final StageVisual? visual;
  final Transition transition;
  final int ms;
}

class StageTextFrame {
  const StageTextFrame(this.serial, this.text, this.inMs, this.outMs);
  final int serial;
  final StageText? text;
  final int inMs;
  final int outMs;
}

/// Liga o motor às telas que desenham o telão (prévia no painel e, na etapa 4, a tela externa).
class StageController extends ChangeNotifier {
  int _serial = 0;
  StageFrame frame = const StageFrame(0, null, Transition.corte, 0);
  StageTextFrame text = const StageTextFrame(0, null, 0, 0);

  /// Chamado quando uma imagem não abre.
  void Function(String cueId)? onImageError;

  void present(StageVisual? v, Transition t, int ms) {
    frame = StageFrame(++_serial, v, t, ms);
    notifyListeners();
  }

  void presentText(StageText? t, int inMs, int outMs) {
    text = StageTextFrame(++_serial, t, inMs, outMs);
    notifyListeners();
  }

  bool get lit => frame.visual != null || text.text != null;
}

/// Player de áudio/vídeo sobre o media_kit (libmpv).
class MkPlayer implements MediaPlayer {
  MkPlayer._(this.cue, this.player, this.video);

  final Cue cue;
  final Player player;

  /// Só para vídeo.
  final VideoController? video;

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _ready = false;
  bool _want = false;
  bool _disposed = false;
  double _gain = 1;

  static MkPlayer create(Cue cue, void Function() onEnd, void Function() onError) {
    final p = Player(configuration: const PlayerConfiguration(title: 'PocketStage Mídia'));
    final vc = cue.kind == MediaKind.video ? VideoController(p) : null;
    final mk = MkPlayer._(cue, p, vc);
    mk._subs.add(p.stream.completed.listen((done) {
      if (done && !mk._disposed) onEnd();
    }));
    mk._subs.add(p.stream.error.listen((_) {
      // Erro só derruba a mídia se o arquivo nem chegou a abrir.
      if (!mk._disposed && p.state.duration == Duration.zero) onError();
    }));
    unawaited(mk._init(onError));
    return mk;
  }

  Future<void> _init(void Function() onError) async {
    try {
      final native = player.platform;
      if (native is NativePlayer) {
        await native.setProperty('volume-max', '200');
        if (cue.startSec > 0) await native.setProperty('start', cue.startSec.toStringAsFixed(3));
        if (cue.endSec > cue.startSec) await native.setProperty('end', cue.endSec.toStringAsFixed(3));
        // Repetir: sem fim, ou N vezes no total.
        final loop = !cue.loop ? 'no' : (cue.repeat > 1 ? '${cue.repeat - 1}' : (cue.repeat == 1 ? 'no' : 'inf'));
        await native.setProperty('loop-file', loop);
        if (cue.pan != 0) {
          await native.setProperty('af', 'lavfi=[stereotools=balance_out=${cue.pan.toStringAsFixed(2)}]');
        }
      }
      await player.setVolume(_gain * 100);
      await player.open(Media(PsShow.localPath(cue.uri)), play: false);
      if (_disposed) return;
      _ready = true;
      await player.setVolume(_gain * 100);
      if (_want) await player.play();
    } catch (_) {
      if (!_disposed) onError();
    }
  }

  @override
  void play() {
    _want = true;
    if (_ready && !_disposed) unawaited(player.play());
  }

  @override
  void pause() {
    _want = false;
    if (_ready && !_disposed) unawaited(player.pause());
  }

  @override
  void setGain(double gain) {
    _gain = gain.clamp(0.0, 2.0);
    if (!_disposed) unawaited(player.setVolume(_gain * 100));
  }

  @override
  int get positionMs => _disposed ? 0 : player.state.position.inMilliseconds;

  @override
  int? get durationMs {
    if (_disposed) return null;
    final d = player.state.duration.inMilliseconds;
    if (d <= 0) return null;
    final end = cue.endSec > cue.startSec ? (cue.endSec * 1000).round() : d;
    return end;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(player.setVolume(0));
    unawaited(player.pause());
    // O quadro do vídeo pode ainda estar saindo do telão; libera depois.
    Timer(const Duration(seconds: 6), () => unawaited(player.dispose()));
  }
}

/// Backend das plataformas: media_kit para som e vídeo, [StageController] para o telão.
class MediaKitBackend implements MediaBackend {
  MediaKitBackend(this.stage);

  final StageController stage;

  @override
  MediaPlayer? open(Cue cue, {required void Function() onEnd, required void Function() onError}) {
    if (cue.uri.isEmpty) return null;
    try {
      return MkPlayer.create(cue, onEnd, onError);
    } catch (_) {
      return null;
    }
  }

  @override
  void present(StageVisual? visual, Transition transition, int ms) => stage.present(visual, transition, ms);

  @override
  void presentText(StageText? text, int inMs, int outMs) => stage.presentText(text, inMs, outMs);
}

/// Toca um arquivo para conferir no editor ("Ouvir").
class Preview {
  Player? _p;

  bool get playing => _p != null;

  Future<void> play(String path, {double gain = 1, double startSec = 0}) async {
    await stop();
    final p = Player();
    _p = p;
    final native = p.platform;
    if (native is NativePlayer) {
      await native.setProperty('volume-max', '200');
      if (startSec > 0) await native.setProperty('start', startSec.toStringAsFixed(3));
    }
    await p.setVolume(gain.clamp(0.0, 2.0) * 100);
    await p.open(Media(path));
  }

  Future<void> setGain(double gain) async => _p?.setVolume(gain.clamp(0.0, 2.0) * 100);

  Future<void> stop() async {
    final p = _p;
    _p = null;
    if (p != null) await p.dispose();
  }
}
