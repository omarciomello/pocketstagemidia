import 'model.dart';

/// Cronômetro de palco: o mesmo modelo `run` do PocketStage, guardado dentro do show.
/// Horários em milissegundos desde 1970; tempos em milissegundos. Tempos da fila em minutos.
class Run {
  const Run({
    this.curId,
    this.running = false,
    this.runStart = 0,
    this.acc = 0,
    this.extra = 0,
    this.showStart,
    this.showEnd,
    this.countMode = 'down',
    this.done = const {},
    this.paused = const {},
    this.overLoggedId,
  });

  final String? curId;
  final bool running;
  final int runStart;
  final int acc;
  final int extra;
  final int? showStart;
  final int? showEnd;

  /// "down" (regressiva) ou "up" (progressiva).
  final String countMode;
  final Map<String, int> done;
  final Map<String, int> paused;
  final String? overLoggedId;

  bool get regressiva => countMode != 'up';

  Run copyWith({
    Object? curId = _x,
    bool? running,
    int? runStart,
    int? acc,
    int? extra,
    Object? showStart = _x,
    Object? showEnd = _x,
    String? countMode,
    Map<String, int>? done,
    Map<String, int>? paused,
    Object? overLoggedId = _x,
  }) =>
      Run(
        curId: identical(curId, _x) ? this.curId : curId as String?,
        running: running ?? this.running,
        runStart: runStart ?? this.runStart,
        acc: acc ?? this.acc,
        extra: extra ?? this.extra,
        showStart: identical(showStart, _x) ? this.showStart : showStart as int?,
        showEnd: identical(showEnd, _x) ? this.showEnd : showEnd as int?,
        countMode: countMode ?? this.countMode,
        done: done ?? this.done,
        paused: paused ?? this.paused,
        overLoggedId: identical(overLoggedId, _x) ? this.overLoggedId : overLoggedId as String?,
      );

  Map<String, dynamic> toJson() => {
        'curId': curId,
        'running': running,
        'runStart': runStart,
        'acc': acc,
        'extra': extra,
        'showStart': showStart,
        'showEnd': showEnd,
        'countMode': countMode,
        'done': Map<String, int>.of(done),
        'paused': Map<String, int>.of(paused),
        'overLoggedId': overLoggedId,
      };

  factory Run.fromJson(Map<String, dynamic> o) {
    int n(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
    int? nn(Object? v) => v is num ? v.toInt() : null;
    Map<String, int> m(Object? v) => {
          if (v is Map)
            for (final e in v.entries)
              if (e.value is num) '${e.key}': (e.value as num).toInt(),
        };
    return Run(
      curId: o['curId'] is String ? o['curId'] as String : null,
      running: o['running'] == true,
      runStart: n(o['runStart']),
      acc: n(o['acc']),
      extra: n(o['extra']),
      showStart: nn(o['showStart']),
      showEnd: nn(o['showEnd']),
      countMode: o['countMode'] == 'up' ? 'up' : 'down',
      done: m(o['done']),
      paused: m(o['paused']),
      overLoggedId: o['overLoggedId'] is String ? o['overLoggedId'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) => other is Run && _eqJson(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(curId, running, runStart, acc, extra, showStart, showEnd, countMode);
}

const Object _x = Object();

bool _eqJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_eqJson(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}

/// Fase do semáforo.
enum Fase { idle, brk, green, yellow, red, over }

/// Resultado de um comando: o novo estado e as linhas de log (textos do PocketStage).
class RunPasso {
  const RunPasso(this.run, [this.log = const []]);
  final Run run;
  final List<String> log;
}

/// Cálculos e comandos do cronômetro sobre a fila do show.
class Cronometro {
  Cronometro(this.lineup, this.run);

  final List<LineupItem> lineup;
  final Run run;

  LineupItem? _item(String? id) {
    if (id == null) return null;
    for (final l in lineup) {
      if (l.id == id) return l;
    }
    return null;
  }

  LineupItem? get atual => _item(run.curId);

  LineupItem? get primeiroEmAberto {
    for (final l in lineup) {
      if (!run.done.containsKey(l.id)) return l;
    }
    return null;
  }

  LineupItem? get proximo {
    final i = lineup.indexWhere((l) => l.id == run.curId);
    if (i < 0) return null;
    for (var k = i + 1; k < lineup.length; k++) {
      if (!run.done.containsKey(lineup[k].id)) return lineup[k];
    }
    return null;
  }

  /// "A seguir": o próximo depois do atual, ou o primeiro em aberto sem atual.
  LineupItem? get aSeguir => atual == null ? primeiroEmAberto : proximo;

  int elapsed(int agora) => run.acc + (run.running ? agora - run.runStart : 0);

  int remaining(int agora) {
    final a = atual;
    if (a == null) return 0;
    return (a.min * 60000).round() + run.extra - elapsed(agora);
  }

  bool get iniciado => run.showStart != null;
  bool get acabou => run.showEnd != null && run.curId == null;

  Fase fase(int agora) {
    final a = atual;
    if (a == null) return Fase.idle;
    if (a.kind != 'set') return Fase.brk;
    final e = elapsed(agora);
    if (!run.running && e == 0) return Fase.idle;
    final r = remaining(agora);
    if (r <= 0) return Fase.over;
    if (r <= a.red * 60000) return Fase.red;
    if (r <= a.yel * 60000) return Fase.yellow;
    return Fase.green;
  }

  /// Relógio: regressiva mostra o que falta; progressiva, o que passou.
  /// O primeiro caractere é o sinal ("+" no estouro da regressiva, senão espaço).
  String relogio(int agora) {
    if (atual == null) return acabou ? 'FIM' : ' 00:00';
    if (run.regressiva) {
      final r = remaining(agora);
      return r < 0 ? '+${mmss(-r)}' : ' ${mmss(r)}';
    }
    return ' ${mmss(elapsed(agora))}';
  }

  String tempoDeShow(int agora) {
    final s = run.showStart;
    if (s == null) return '00:00:00';
    return hhmmss((run.showEnd ?? agora) - s);
  }

  String estado(int agora) {
    if (!iniciado) return 'Aguardando início';
    if (acabou) return 'Fim do show';
    final a = atual;
    if (a != null && a.kind != 'set') return a.name;
    if (run.running) return 'Em cena';
    return elapsed(agora) > 0 ? 'Pausado' : 'Troca';
  }

  // ---------- comandos ----------

  RunPasso play(int agora) {
    if (run.running) return RunPasso(run);
    var r = run;
    final log = <String>[];
    var continua = 0;
    if (atual == null) {
      final p = primeiroEmAberto;
      if (p == null) return RunPasso(run);
      continua = r.paused[p.id] ?? 0;
      r = r.copyWith(curId: p.id, acc: continua, extra: 0, paused: _sem(r.paused, p.id), showEnd: null);
    } else {
      continua = r.acc;
    }
    if (r.showStart == null) {
      r = r.copyWith(showStart: agora);
      log.add('Show iniciado');
    }
    r = r.copyWith(running: true, runStart: agora);
    final nome = _item(r.curId)?.name ?? '';
    log.add(continua > 0 ? 'Play · $nome (continua de ${mmss(continua)})' : 'Play · $nome');
    return RunPasso(r, log);
  }

  RunPasso pause(int agora) {
    if (!run.running) return RunPasso(run);
    final r = run.copyWith(acc: run.acc + agora - run.runStart, running: false);
    return RunPasso(r, ['Pause · ${atual?.name ?? ''} (${mmss(r.acc)})']);
  }

  RunPasso stop(int agora) => _sair(agora, iniciaProximo: false);

  RunPasso proximoCmd(int agora) => _sair(agora, iniciaProximo: true);

  RunPasso _sair(int agora, {required bool iniciaProximo}) {
    final a = atual;
    if (a == null) return RunPasso(run);
    final feito = elapsed(agora);
    final fila = (a.min * 60000).round() + run.extra;
    final dif = feito - fila;
    final saldo = dif > 0 ? ' (+${mmss(dif)} estourou)' : (dif < 0 ? ' (−${mmss(-dif)} devendo)' : '');
    final log = <String>['Saiu · ${a.name} · fila ${mmss(fila)} · fez ${mmss(feito)}$saldo'];
    final done = {...run.done, a.id: feito};
    final paused = _sem(run.paused, a.id);
    final prox = proximo;
    var r = run.copyWith(done: done, paused: paused, acc: 0, extra: 0, runStart: 0, running: false);
    if (prox == null) {
      r = r.copyWith(curId: null, showEnd: agora);
      log.add('Fim do show');
      return RunPasso(r, log);
    }
    r = r.copyWith(curId: prox.id);
    if (iniciaProximo) {
      r = r.copyWith(running: true, runStart: agora);
      log.add('Próximo · entra ${prox.name}');
    }
    return RunPasso(r, log);
  }

  RunPasso selecionar(String id) {
    if (run.running) return RunPasso(run);
    final novo = _item(id);
    if (novo == null || novo.id == run.curId) return RunPasso(run);
    var paused = Map<String, int>.of(run.paused);
    final cur = run.curId;
    if (cur != null && run.acc > 0 && !run.done.containsKey(cur)) paused[cur] = run.acc;
    final acc = paused.remove(novo.id) ?? 0;
    final r = run.copyWith(curId: novo.id, acc: acc, extra: 0, paused: paused, done: _sem(run.done, novo.id), showEnd: null);
    return RunPasso(r, [acc > 0 ? 'Selecionado · ${novo.name} · continua de ${mmss(acc)}' : 'Selecionado · ${novo.name}']);
  }

  RunPasso reiniciar(String id) {
    final it = _item(id);
    if (it == null) return RunPasso(run);
    var r = run.copyWith(done: _sem(run.done, id), paused: _sem(run.paused, id));
    if (run.curId == id) r = r.copyWith(running: false, acc: 0, extra: 0, runStart: 0);
    if (r.showEnd != null) r = r.copyWith(showEnd: null);
    return RunPasso(r, ['Reiniciada · ${it.name} · volta para a fila']);
  }

  RunPasso contagem() {
    final up = run.regressiva;
    return RunPasso(run.copyWith(countMode: up ? 'up' : 'down'), [up ? 'Contagem progressiva' : 'Contagem regressiva']);
  }

  RunPasso estica(int minutos) => RunPasso(run.copyWith(extra: run.extra + minutos * 60000));

  /// Chamar periodicamente: registra o estouro uma vez por item.
  RunPasso verificarEstouro(int agora) {
    final a = atual;
    if (a == null || a.kind != 'set' || !run.running || run.overLoggedId == a.id) return RunPasso(run);
    if (remaining(agora) > 0) return RunPasso(run);
    final fila = (a.min * 60000).round() + run.extra;
    return RunPasso(
        run.copyWith(overLoggedId: a.id), ['Estourou o tempo · ${a.name} · fila ${mmss(fila)} · luz automática']);
  }

  static Map<String, int> _sem(Map<String, int> m, String k) => {
        for (final e in m.entries)
          if (e.key != k) e.key: e.value,
      };

  /// MM:SS, com o minuto sempre em 2 dígitos (ou mais).
  static String mmss(int ms) {
    final s = (ms < 0 ? 0 : ms) ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String hhmmss(int ms) {
    final s = (ms < 0 ? 0 : ms) ~/ 1000;
    String d(int v) => v.toString().padLeft(2, '0');
    return '${d(s ~/ 3600)}:${d(s % 3600 ~/ 60)}:${d(s % 60)}';
  }
}
