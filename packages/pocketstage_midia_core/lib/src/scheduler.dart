import 'dart:async';

/// Temporizador que pode ser cancelado.
abstract class TimerHandle {
  void cancel();
}

/// Relógio e temporizadores do motor. Em produção usa [RealScheduler];
/// nos testes, um relógio manual que avança quando o teste manda.
abstract class Scheduler {
  /// Milissegundos de um relógio que só anda para frente.
  int get nowMs;

  /// Chama [fn] daqui a [ms] milissegundos.
  TimerHandle after(int ms, void Function() fn);
}

class _RealHandle implements TimerHandle {
  _RealHandle(this.t);
  final Timer t;
  @override
  void cancel() => t.cancel();
}

class RealScheduler implements Scheduler {
  final Stopwatch _sw = Stopwatch()..start();

  @override
  int get nowMs => _sw.elapsedMilliseconds;

  @override
  TimerHandle after(int ms, void Function() fn) =>
      _RealHandle(Timer(Duration(milliseconds: ms < 0 ? 0 : ms), fn));
}

class _ManualTask implements TimerHandle {
  _ManualTask(this.due, this.seq, this.fn);
  final int due;
  final int seq;
  final void Function() fn;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
}

/// Relógio manual, para testes: nada acontece até [advance].
class ManualScheduler implements Scheduler {
  int _now = 0;
  int _seq = 0;
  final List<_ManualTask> _tasks = [];

  @override
  int get nowMs => _now;

  @override
  TimerHandle after(int ms, void Function() fn) {
    final t = _ManualTask(_now + (ms < 0 ? 0 : ms), _seq++, fn);
    _tasks.add(t);
    return t;
  }

  /// Avança o relógio [ms] milissegundos, rodando na ordem tudo o que vencer.
  void advance(int ms) {
    final end = _now + ms;
    while (true) {
      _tasks.removeWhere((t) => t.cancelled);
      _ManualTask? next;
      for (final t in _tasks) {
        if (t.due <= end && (next == null || t.due < next.due || (t.due == next.due && t.seq < next.seq))) {
          next = t;
        }
      }
      if (next == null) break;
      _tasks.remove(next);
      if (next.due > _now) _now = next.due;
      next.fn();
    }
    _now = end;
  }

  /// Temporizadores ainda pendentes.
  int get pending => _tasks.where((t) => !t.cancelled).length;
}
