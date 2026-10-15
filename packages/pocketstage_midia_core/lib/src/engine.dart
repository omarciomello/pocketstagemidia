import 'dart:async';
import 'dart:math' as math;

import 'backend.dart';
import 'levels.dart';
import 'model.dart';
import 'protocol.dart';
import 'scheduler.dart';

/// Temporizador que congela no Pausar e continua no Retomar.
class _Pausable {
  _Pausable(this._s, int ms, this._action) : _left = math.max(0, ms) {
    _start();
  }

  final Scheduler _s;
  final void Function() _action;
  int _left;
  int _startedAt = 0;
  TimerHandle? _h;
  bool _done = false;

  void _start() {
    _startedAt = _s.nowMs;
    _h = _s.after(_left, () {
      _h = null;
      _done = true;
      _action();
    });
  }

  void freeze() {
    if (_done || _h == null) return;
    _h!.cancel();
    _h = null;
    _left = math.max(0, _left - (_s.nowMs - _startedAt));
  }

  void thaw() {
    if (_done || _h != null) return;
    _start();
  }

  void cancel() {
    _h?.cancel();
    _h = null;
    _done = true;
  }

  int get remainingMs {
    if (_done) return 0;
    if (_h == null) return _left;
    return math.max(0, _left - (_s.nowMs - _startedAt));
  }
}

/// Rampa (fade, ducking) que avança em passos curtos e não anda durante o Pausar.
class _Ramp {
  _Ramp(this.durMs, this.onStep, this.onEnd, {this.ignorePause = false});

  final int durMs;
  final void Function(double k) onStep;
  final void Function() onEnd;
  final bool ignorePause;
  int elapsed = 0;
  int last = 0;
  TimerHandle? h;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    h?.cancel();
  }
}

class _Pb {
  _Pb(this.index, this.cue, this.player, this.startedAt);

  final int index;
  final Cue cue;
  final MediaPlayer? player;
  final int startedAt;

  /// Envelope de fade (0–1).
  double env = 1;

  /// Ducking (0–1).
  double duck = 1;
  bool started = false;

  /// Vídeo terminado e congelado no último quadro.
  bool held = false;
  bool disposed = false;
  final Map<String, _Pausable> timers = {};
  _Ramp? fade;
  _Ramp? duckRamp;
  int pausedTotal = 0;
  int? pausedAt;

  void clearTimers() {
    for (final t in timers.values) {
      t.cancel();
    }
    timers.clear();
  }
}

/// Motor de reprodução: aplica as regras do PocketStage Mídia.
///
/// - 4 colunas; cada coluna toca uma mídia por vez (a nova corta a anterior da coluna).
/// - Colunas diferentes tocam juntas.
/// - O telão mostra uma imagem ou um vídeo por vez, e um texto por cima.
///
/// Recebe [Command]s, publica o log em [log], avisos em [messages] e mudanças em [changes].
/// Não toca nada sozinho: quem toca e desenha é o [MediaBackend] da plataforma.
class Engine {
  Engine({
    required MediaBackend backend,
    Scheduler? scheduler,
    Settings settings = const Settings(),
    int Function()? wallClock,
  })  : _backend = backend,
        _s = scheduler ?? RealScheduler(),
        _settings = settings,
        _wall = wallClock ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Passo das rampas de volume.
  static const int stepMs = 30;

  /// Duração do ducking (subir e descer).
  static const int duckMs = 300;

  /// Saída do texto anterior quando entra um texto novo.
  static const int textSwapMs = 200;

  /// Saída rápida do telão quando a mídia não tem fade de saída.
  static const int quickExitMs = 120;

  final MediaBackend _backend;
  final Scheduler _s;
  final int Function() _wall;

  Settings _settings;
  Show? _show;
  bool _locked = false;
  bool _paused = false;
  int? _currentRow;

  final List<_Pb?> _columns = List<_Pb?>.filled(cols, null);
  final Set<_Pb> _fading = {};
  _Pb? _visual;
  _Pb? _textOn;
  final Set<String> _used = {};
  final Map<int, _Pausable> _waiting = {};

  final StreamController<LogEntry> _log = StreamController<LogEntry>.broadcast(sync: true);
  final StreamController<String> _messages = StreamController<String>.broadcast(sync: true);
  final StreamController<void> _changes = StreamController<void>.broadcast(sync: true);

  Settings get settings => _settings;
  Show? get show => _show;
  bool get locked => _locked;
  bool get paused => _paused;
  int? get currentRow => _currentRow;

  /// Log no formato do PocketStage.
  Stream<LogEntry> get log => _log.stream;

  /// Avisos para o operador (toast).
  Stream<String> get messages => _messages.stream;

  /// Algo mudou no estado (para a tela redesenhar).
  Stream<void> get changes => _changes.stream;

  // ---------- comandos ----------

  void dispatch(Command cmd) {
    switch (cmd) {
      case Go(:final cueId):
        _go(cueId);
      case Stop(:final cueId):
        _stopCue(cueId);
      case StopAll():
        _stopAll();
      case Blackout():
        _blackout();
      case Pause():
        _pause();
      case Resume():
        _resume();
      case Lock():
        _setLocked(true);
      case Unlock():
        _setLocked(false);
      case PlayRow(:final row):
        _playRow(row);
      case ReleaseLocks():
        _used.clear();
      case LoadShow(:final show):
        _loadShow(show);
      case SetSettings(:final settings):
        _settings = Settings.fromJson(settings);
        for (final pb in _columns) {
          if (pb != null) _applyGain(pb);
        }
    }
    _changed();
  }

  /// Comando em JSON. false = não reconhecido.
  bool dispatchJson(String json) {
    final c = Command.fromJsonString(json);
    if (c == null) return false;
    dispatch(c);
    return true;
  }

  /// Carrega um show já lido (sem passar por JSON).
  void loadShow(Show s) {
    if (s.id != _show?.id) _used.clear();
    hardStop();
    _show = s;
    _changed();
  }

  /// Troca os ajustes gerais.
  void setSettings(Settings s) {
    _settings = s;
    for (final pb in _columns) {
      if (pb != null) _applyGain(pb);
    }
    _changed();
  }

  /// GO (+1) ou linha anterior (−1).
  void stepRow(int step) {
    final s = _show;
    if (s == null) return;
    if (_locked) {
      _msg('Mesa bloqueada.');
      return;
    }
    final cur = _currentRow;
    final next = cur == null ? (step > 0 ? 0 : -1) : cur + step;
    if (next < 0) {
      _msg('Já está na primeira linha.');
      return;
    }
    if (next >= s.rows) {
      _msg('Última linha do show.');
      return;
    }
    dispatch(PlayRow(next));
  }

  /// A plataforma não conseguiu abrir a imagem [cueId].
  void visualFailed(String cueId) {
    final v = _visual;
    if (v == null || v.cue.id != cueId) return;
    _visual = null;
    final col = v.index % cols;
    if (identical(_columns[col], v)) _columns[col] = null;
    v.clearTimers();
    _backend.present(null, Transition.fade, 150);
    _msg('Não consegui abrir a imagem “${v.cue.name}”. O arquivo pode ter sido movido.');
    _changed();
  }

  void _loadShow(Map<String, dynamic> json) {
    Show s;
    try {
      s = Show.fromJson(json);
    } catch (_) {
      _msg('Show inválido.');
      return;
    }
    loadShow(s);
  }

  void _setLocked(bool v) {
    if (_locked == v) return;
    _locked = v;
    _logEv(v ? LogEntry.lock : LogEntry.unlock, null, v ? 'Mesa bloqueada' : 'Mesa desbloqueada');
  }

  // ---------- tempos ----------

  int _ms(double sec) => (sec * 1000).round();
  double _fadeInSec(Cue c) => c.fadeIn ? (c.fadeInSec ?? _settings.fadeInSec) : 0;
  double _fadeOutSec(Cue c) => c.fadeOut ? (c.fadeOutSec ?? _settings.fadeOutSec) : 0;
  int _transMs(Cue c) => _ms(c.transSec ?? _settings.visualFadeSec);
  Curve _curveOf(Cue c) => c.fadeCurve ?? _settings.fadeCurve;
  Transition _transOf(Cue c) => c.transition ?? _settings.transition;

  /// Como a mídia visual entra: sem "Entra com fade" é corte.
  Transition _entryMode(Cue c) => c.fadeIn ? _transOf(c) : Transition.corte;

  int _exitMs(Cue c, bool quick) {
    if (quick) return _ms(_settings.stopAllFadeSec);
    if (c.fadeOut && _transOf(c) != Transition.corte) return _transMs(c);
    return quickExitMs;
  }

  // ---------- tocar ----------

  void _go(String cueId) {
    final s = _show;
    if (s == null) {
      _msg('Nenhum show carregado.');
      return;
    }
    if (_locked) {
      _msg('Mesa bloqueada: a deixa não foi disparada.');
      return;
    }
    final i = s.indexOf(cueId);
    if (i < 0) {
      _msg('Deixa não encontrada neste show.');
      return;
    }
    _toggle(s.cells[i]!, i);
  }

  void _stopCue(String cueId) {
    for (var col = 0; col < cols; col++) {
      final pb = _columns[col];
      if (pb != null && pb.cue.id == cueId) {
        _stopColumn(col, quick: false);
        _logEv(LogEntry.cueStop, pb.cue, 'Parou · ${_cueText(pb.cue)}');
        return;
      }
    }
  }

  void _toggle(Cue cue, int index, {bool now = false}) {
    if (_paused) {
      _msg('Pausado. Toque em Retomar primeiro.');
      return;
    }
    final col = index % cols;
    final cur = _columns[col];
    if (cur != null && cur.index == index && !now) {
      final rt = _settings.retrigger;
      if (rt == Retrigger.ignorar) return;
      if (rt == Retrigger.parar) {
        _stopColumn(col, quick: false);
        _logEv(LogEntry.cueStop, cue, 'Parou · ${_cueText(cue)}');
        return;
      }
      _stopColumn(col, quick: true); // recomeça
    }
    final w = _waiting.remove(index);
    if (w != null) {
      w.cancel();
      _msg('Pré-espera de “${cue.name}” cancelada.');
      return;
    }
    if (cue.lockAfter && _used.contains(cue.id)) {
      _msg('“${cue.name}” já tocou e está travada. Menu › Liberar deixas travadas.');
      return;
    }
    if (cue.preWaitSec > 0 && !now) {
      _waiting[index] = _Pausable(_s, _ms(cue.preWaitSec), () {
        _waiting.remove(index);
        _toggle(cue, index, now: true);
        _changed();
      });
      return;
    }

    // ao tocar, parar outras colunas
    if (cue.stopAllOnGo) {
      for (var k = 0; k < cols; k++) {
        if (k != col) _stopColumn(k, quick: false);
      }
    } else {
      for (final k in cue.stopCols) {
        if (k != col && k >= 0 && k < cols) _stopColumn(k, quick: false);
      }
    }

    // Imagem/vídeo novo tira o anterior do telão; texto novo tira o texto anterior.
    if (cue.kind == MediaKind.video || cue.kind == MediaKind.image) _replaceVisual();
    if (cue.kind == MediaKind.text) _replaceText();
    _stopColumn(col, quick: false);
    if (cue.lockAfter) _used.add(cue.id);

    switch (cue.kind) {
      case MediaKind.audio:
        final pb = _open(cue, index);
        if (pb == null) return;
        _columns[col] = pb;
        _start(pb);
        _logEv(LogEntry.cueGo, cue, _cueText(cue));
        _triggerLinked(cue);
        _arm(pb);
        return;
      case MediaKind.text:
        final pb = _Pb(index, cue, null, _s.nowMs)..started = true;
        _columns[col] = pb;
        _textOn = pb;
        final cut = _entryMode(cue) == Transition.corte;
        _backend.presentText(_toText(cue), cut ? 0 : _transMs(cue), cut ? 0 : textSwapMs);
        _arm(pb);
      case MediaKind.video:
        final pb = _open(cue, index);
        if (pb == null) {
          _backend.present(null, Transition.fade, 150);
          return;
        }
        _columns[col] = pb;
        _visual = pb;
        _backend.present(StageVisual(cue, pb.player), _entryMode(cue), _transMs(cue));
        _start(pb);
        _arm(pb);
      case MediaKind.image:
        final pb = _Pb(index, cue, null, _s.nowMs)..started = true;
        _columns[col] = pb;
        _visual = pb;
        _backend.present(StageVisual(cue, null), _entryMode(cue), _transMs(cue));
        _arm(pb);
    }
    _logEv(LogEntry.cueGo, cue, _cueText(cue));
  }

  StageText _toText(Cue c) => StageText(c.text.trim().isEmpty ? c.name : c.text, c.textPos, c.textSize);

  /// "Parar sozinha" / tempo na tela e "Seguir após X s".
  void _arm(_Pb pb) {
    final c = pb.cue;
    final col = pb.index % cols;
    if (c.autoStopSec > 0) {
      pb.timers['auto'] = _Pausable(_s, _ms(c.autoStopSec), () {
        if (!identical(_columns[col], pb)) return;
        _stopColumn(col, quick: false);
        _logEv(LogEntry.cueEnd, c, 'Tempo esgotado · ${_cueText(c)}');
        if (c.followMode == FollowMode.fim) _follow(c);
        _changed();
      });
    }
    if (c.followId != null && c.followMode == FollowMode.tempo) {
      pb.timers['follow'] = _Pausable(_s, _ms(c.followSec), () {
        _follow(c);
        _changed();
      });
    }
  }

  void _follow(Cue c) {
    final id = c.followId;
    final s = _show;
    if (id == null || s == null) return;
    final j = s.indexOf(id);
    if (j < 0 || _columns[j % cols]?.index == j) return;
    _toggle(s.cells[j]!, j);
  }

  /// Tira a imagem/vídeo atual (o som do vídeo sai com fade); quem entra faz a troca no telão.
  void _replaceVisual() {
    final v = _visual;
    if (v == null) return;
    _visual = null;
    final col = v.index % cols;
    if (identical(_columns[col], v)) _columns[col] = null;
    v.clearTimers();
    if (v.player != null) _stopPlayer(v, _fadeOutSec(v.cue));
    _applyDuck();
  }

  void _replaceText() {
    final t = _textOn;
    if (t == null) return;
    _textOn = null;
    final col = t.index % cols;
    if (identical(_columns[col], t)) _columns[col] = null;
    t.clearTimers();
  }

  /// Trilha com imagem ligada: a imagem entra junto, se ainda não estiver no ar.
  void _triggerLinked(Cue cue) {
    final id = cue.visualId;
    final s = _show;
    if (id == null || s == null) return;
    final j = s.indexOf(id);
    if (j < 0 || _columns[j % cols]?.index == j) return;
    _toggle(s.cells[j]!, j, now: true);
  }

  /// Ao parar ou terminar a trilha, a imagem ligada sai junto se o ajuste mandar.
  void _releaseLinked(_Pb pb) {
    final c = pb.cue;
    final s = _show;
    if (c.kind != MediaKind.audio || c.visualId == null || c.visualStays || s == null) return;
    final j = s.indexOf(c.visualId!);
    if (j >= 0 && _columns[j % cols]?.index == j) _stopColumn(j % cols, quick: false);
  }

  /// ▶ da linha: para todo o resto e dispara as mídias da linha. Na linha atual, para tudo.
  void _playRow(int row) {
    final s = _show;
    if (s == null) return;
    if (_locked) {
      _msg('Mesa bloqueada.');
      return;
    }
    if (_paused) {
      _msg('Pausado. Toque em Retomar primeiro.');
      return;
    }
    if (row < 0 || row >= s.rows) return;
    _clearWaiting();
    for (var c = 0; c < cols; c++) {
      _stopColumn(c, quick: false);
    }
    if (_currentRow == row) {
      _currentRow = null;
      _logEv(LogEntry.cueStop, null, 'Parou a linha ${row + 1}');
      return;
    }
    _currentRow = row;
    final idx = [for (var c = 0; c < cols; c++) row * cols + c].where((i) => s.cells[i] != null).toList();
    // mídias puxadas por uma trilha da própria linha entram pela trilha
    final linked = {
      for (final i in idx)
        if (s.cells[i]!.kind == MediaKind.audio && s.cells[i]!.visualId != null) s.cells[i]!.visualId!,
    };
    for (final i in idx) {
      final c = s.cells[i]!;
      if (!linked.contains(c.id)) _toggle(c, i);
    }
  }

  void _stopColumn(int col, {required bool quick}) {
    final pb = _columns[col];
    if (pb == null) return;
    _columns[col] = null;
    pb.clearTimers();
    if (pb.player != null) _stopPlayer(pb, quick ? _settings.stopAllFadeSec : _fadeOutSec(pb.cue));
    if (identical(_visual, pb)) {
      _visual = null;
      _backend.present(null, quick ? Transition.fade : _transOf(pb.cue), _exitMs(pb.cue, quick));
    }
    if (identical(_textOn, pb)) {
      _textOn = null;
      _backend.presentText(null, 0, _exitMs(pb.cue, quick));
    }
    _applyDuck();
    _releaseLinked(pb);
  }

  void _clearWaiting() {
    for (final w in _waiting.values) {
      w.cancel();
    }
    _waiting.clear();
  }

  void _pause() {
    if (_paused) return;
    for (final pb in _fading.toList()) {
      _dispose(pb);
    }
    for (final w in _waiting.values) {
      w.freeze();
    }
    final now = _s.nowMs;
    for (final pb in _columns) {
      if (pb == null) continue;
      for (final t in pb.timers.values) {
        t.freeze();
      }
      pb.pausedAt = now;
      if (!pb.held) pb.player?.pause();
    }
    _paused = true;
    _logEv(LogEntry.pause, null, 'Pausado');
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    final now = _s.nowMs;
    for (final pb in _columns) {
      if (pb == null) continue;
      if (pb.pausedAt != null) {
        pb.pausedTotal += now - pb.pausedAt!;
        pb.pausedAt = null;
      }
      for (final t in pb.timers.values) {
        t.thaw();
      }
      if (!pb.held) pb.player?.play();
    }
    for (final w in _waiting.values) {
      w.thaw();
    }
    _logEv(LogEntry.resume, null, 'Retomado');
  }

  void _stopAll() {
    _clearWaiting();
    for (var c = 0; c < cols; c++) {
      _stopColumn(c, quick: true);
    }
    _paused = false;
    _currentRow = null;
    _logEv(LogEntry.stopAll, null, 'Parar tudo');
  }

  /// Apaga o telão: imagem/vídeo e texto.
  void _blackout() {
    final v = _visual;
    final t = _textOn;
    if (v == null && t == null) return;
    if (v != null) _stopColumn(v.index % cols, quick: false);
    if (t != null && identical(_textOn, t)) _stopColumn(t.index % cols, quick: false);
    _logEv(LogEntry.blackout, (v ?? t)!.cue, 'Telão apagado');
  }

  /// Para tudo na hora, sem fades e sem log (trocar de show, sair do app).
  void hardStop() {
    _clearWaiting();
    for (var c = 0; c < cols; c++) {
      final pb = _columns[c];
      if (pb != null) {
        pb.clearTimers();
        _dispose(pb);
      }
      _columns[c] = null;
    }
    for (final pb in _fading.toList()) {
      _dispose(pb);
    }
    final hadVisual = _visual != null;
    final hadText = _textOn != null;
    _visual = null;
    _textOn = null;
    _currentRow = null;
    _paused = false;
    if (hadVisual) _backend.present(null, Transition.corte, 0);
    if (hadText) _backend.presentText(null, 0, 0);
  }

  /// Libera tudo. O motor não deve ser usado depois.
  void dispose() {
    hardStop();
    _log.close();
    _messages.close();
    _changes.close();
  }

  // ---------- players e volume ----------

  _Pb? _open(Cue cue, int index) {
    _Pb? pb;
    final p = _backend.open(
      cue,
      onEnd: () {
        final x = pb;
        if (x != null) _onEnded(x, error: false);
      },
      onError: () {
        final x = pb;
        if (x == null) return;
        _msg('Não consegui tocar “${cue.name}”. O arquivo pode ter sido movido ou o formato não é suportado.');
        _onEnded(x, error: true);
      },
    );
    if (p == null) {
      _msg('Não consegui abrir “${cue.name}”.');
      return null;
    }
    pb = _Pb(index, cue, p, _s.nowMs);
    return pb;
  }

  double _cueGain(Cue c) => c.muted ? 0 : c.volume;

  void _applyGain(_Pb pb) {
    final p = pb.player;
    if (p == null || pb.disposed) return;
    p.setGain(pb.env * pb.duck * _cueGain(pb.cue) * dbToLin(_settings.masterDb));
  }

  void _start(_Pb pb) {
    final p = pb.player;
    if (p == null) return;
    final c = pb.cue;
    pb.started = true;
    final fi = _fadeInSec(c);
    if (fi > 0) {
      pb.env = 0;
      _applyGain(pb);
      p.play();
      _fadeEnv(pb, 0, 1, fi, _curveOf(c), null);
    } else {
      pb.env = 1;
      _applyGain(pb);
      p.play();
    }
    _applyDuck();
  }

  void _onEnded(_Pb pb, {required bool error}) {
    if (pb.disposed) return;
    final col = _columns.indexWhere((x) => identical(x, pb));
    if (col < 0) {
      _dispose(pb);
      return;
    }
    if (!error && pb.cue.kind == MediaKind.video && pb.cue.hold) {
      pb.held = true;
      _logEv(LogEntry.cueEnd, pb.cue, 'Terminou (congelado) · ${_cueText(pb.cue)}');
      _changed();
      return;
    }
    _columns[col] = null;
    pb.clearTimers();
    if (identical(_visual, pb)) {
      _visual = null;
      _backend.present(null, _transOf(pb.cue), _exitMs(pb.cue, false));
    }
    _dispose(pb);
    _applyDuck();
    if (!error) _logEv(LogEntry.cueEnd, pb.cue, 'Terminou · ${_cueText(pb.cue)}');
    _releaseLinked(pb);
    if (!error && pb.cue.followMode == FollowMode.fim) _follow(pb.cue);
    _changed();
  }

  void _stopPlayer(_Pb pb, double sec) {
    if (pb.player == null || pb.disposed) return;
    pb.duckRamp?.cancel();
    if (sec <= 0 || _paused || pb.held) {
      _dispose(pb);
      return;
    }
    _fading.add(pb);
    _fadeEnv(pb, pb.env, 0, sec, _curveOf(pb.cue), () => _dispose(pb), ignorePause: true);
  }

  void _dispose(_Pb pb) {
    pb.fade?.cancel();
    pb.duckRamp?.cancel();
    pb.fade = null;
    pb.duckRamp = null;
    final wasFading = _fading.remove(pb);
    if (!pb.disposed) {
      pb.disposed = true;
      pb.player?.dispose();
    }
    if (wasFading) _changed();
  }

  void _fadeEnv(_Pb pb, double from, double to, double sec, Curve curve, void Function()? end,
      {bool ignorePause = false}) {
    pb.fade?.cancel();
    final up = to >= from;
    pb.fade = _ramp(
      _ms(sec),
      (k) {
        pb.env = from + (to - from) * fadeShape(curve, k, up);
        _applyGain(pb);
      },
      () {
        pb.fade = null;
        end?.call();
      },
      ignorePause: ignorePause,
    );
  }

  _Ramp _ramp(int durMs, void Function(double k) step, void Function() end, {bool ignorePause = false}) {
    final r = _Ramp(durMs, step, end, ignorePause: ignorePause);
    if (durMs <= 0) {
      step(1);
      end();
      return r;
    }
    r.last = _s.nowMs;
    void tick() {
      if (r.cancelled) return;
      final now = _s.nowMs;
      if (r.ignorePause || !_paused) r.elapsed += now - r.last;
      r.last = now;
      final k = math.min(1.0, r.elapsed / r.durMs);
      step(k);
      if (k >= 1) {
        end();
      } else {
        r.h = _s.after(stepMs, tick);
      }
    }

    step(0);
    r.h = _s.after(stepMs, tick);
    return r;
  }

  /// Enquanto uma mídia com ducking toca, as outras colunas abaixam.
  void _applyDuck() {
    final live = _columns.whereType<_Pb>().where((p) => p.started && p.player != null && !p.disposed).toList();
    for (final pb in live) {
      var target = 1.0;
      for (final o in live) {
        if (!identical(o, pb) && o.cue.duckDb < 0) target *= dbToLin(o.cue.duckDb);
      }
      if ((target - pb.duck).abs() > 1e-9) {
        pb.duckRamp?.cancel();
        final from = pb.duck;
        pb.duckRamp = _ramp(duckMs, (k) {
          pb.duck = from + (target - from) * k;
          _applyGain(pb);
        }, () => pb.duckRamp = null);
      }
    }
  }

  // ---------- log ----------

  String _cueText(Cue c) {
    final artist = _show?.lineupName(c.linkId);
    if (artist != null) {
      final role = c.role == Role.livre ? '' : ' ${c.role.label.toLowerCase()}';
      return '${c.kind.logWord}$role · $artist';
    }
    return '${c.kind.logWord} · ${c.name}';
  }

  void _logEv(String type, Cue? c, String text) {
    _log.add(LogEntry(t: _wall(), type: type, ref: c?.id, linkId: c?.linkId, text: text));
  }

  void _msg(String m) => _messages.add(m);

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  // ---------- estado ----------

  EngineState state() {
    final now = _s.nowMs;
    final colsState = <ColumnState?>[
      for (final pb in _columns)
        if (pb == null)
          null
        else
          ColumnState(
            cueId: pb.cue.id,
            index: pb.index,
            name: pb.cue.name,
            kind: pb.cue.kind,
            posMs: pb.player?.positionMs ??
                ((pb.pausedAt ?? now) - pb.startedAt - pb.pausedTotal),
            durMs: pb.player != null
                ? (pb.player!.durationMs ?? 0)
                : (pb.cue.autoStopSec > 0 ? _ms(pb.cue.autoStopSec) : 0),
            loop: pb.cue.loop,
            onScreen: identical(pb, _visual) || identical(pb, _textOn),
          ),
    ];
    return EngineState(
      showId: _show?.id,
      columns: colsState,
      screenCueId: _visual?.cue.id,
      textCueId: _textOn?.cue.id,
      currentRow: _currentRow,
      usedCueIds: Set.of(_used),
      waitingMs: {for (final e in _waiting.entries) e.key: e.value.remainingMs},
      fadingIdx: {for (final pb in _fading) pb.index},
      paused: _paused,
      locked: _locked,
    );
  }
}
