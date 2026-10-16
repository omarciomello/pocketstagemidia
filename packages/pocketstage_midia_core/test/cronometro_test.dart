import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

void main() {
  final fila = [
    LineupItem({'id': 'a', 'kind': 'set', 'name': 'Abertura', 'min': 5, 'yel': 1, 'red': 0.5}),
    LineupItem({'id': 'b', 'kind': 'break', 'name': 'Intervalo', 'min': 15, 'yel': 3, 'red': 1}),
    LineupItem({'id': 'c', 'kind': 'set', 'name': 'Comediante 02', 'min': 10, 'yel': 2, 'red': 1}),
  ];
  Cronometro cr(Run r) => Cronometro(fila, r);
  const t0 = 1000000;

  test('estado inicial', () {
    final c = cr(const Run());
    expect(c.estado(t0), 'Aguardando início');
    expect(c.relogio(t0), ' 00:00');
    expect(c.fase(t0), Fase.idle);
    expect(c.aSeguir?.name, 'Abertura');
  });

  test('Play, Pause, Play continua, Stop e fases', () {
    var p = cr(const Run()).play(t0);
    expect(p.log, ['Show iniciado', 'Play · Abertura']);
    expect(p.run.curId, 'a');
    expect(p.run.showStart, t0);
    var c = cr(p.run);
    expect(c.estado(t0 + 1000), 'Em cena');
    expect(c.relogio(t0 + 60000), ' 04:00');
    expect(c.fase(t0 + 60000), Fase.green);
    expect(c.fase(t0 + 4 * 60000 + 1), Fase.yellow);
    expect(c.fase(t0 + 4 * 60000 + 31000), Fase.red);
    expect(c.fase(t0 + 5 * 60000), Fase.over);
    expect(c.relogio(t0 + 5 * 60000 + 7000), '+00:07');

    p = c.pause(t0 + 70000);
    expect(p.log, ['Pause · Abertura (01:10)']);
    expect(p.run.acc, 70000);
    c = cr(p.run);
    expect(c.estado(t0 + 80000), 'Pausado');

    p = c.play(t0 + 100000);
    expect(p.log, ['Play · Abertura (continua de 01:10)']);
    c = cr(p.run);
    expect(c.elapsed(t0 + 110000), 80000);

    p = c.stop(t0 + 110000);
    expect(p.log, ['Saiu · Abertura · fila 05:00 · fez 01:20 (−03:40 devendo)']);
    expect(p.run.done, {'a': 80000});
    expect(p.run.curId, 'b');
    expect(p.run.running, false);
    expect(p.run.acc, 0);
    c = cr(p.run);
    expect(c.fase(t0), Fase.brk);
    expect(c.estado(t0), 'Intervalo');
  });

  test('estouro registrado uma vez e Stop com saldo estourado', () {
    var c = cr(cr(const Run()).play(t0).run);
    expect(c.verificarEstouro(t0 + 60000).log, isEmpty);
    final p = c.verificarEstouro(t0 + 5 * 60000);
    expect(p.log, ['Estourou o tempo · Abertura · fila 05:00 · luz automática']);
    c = cr(p.run);
    expect(c.verificarEstouro(t0 + 6 * 60000).log, isEmpty);
    expect(c.stop(t0 + 6 * 60000).log.first, 'Saiu · Abertura · fila 05:00 · fez 06:00 (+01:00 estourou)');
  });

  test('Próximo inicia o seguinte; fim do show', () {
    var c = cr(cr(const Run()).play(t0).run);
    var p = c.proximoCmd(t0 + 300000);
    expect(p.log.last, 'Próximo · entra Intervalo');
    expect(p.run.running, true);
    p = cr(p.run).proximoCmd(t0 + 400000);
    expect(p.run.curId, 'c');
    p = cr(p.run).stop(t0 + 500000);
    expect(p.log.last, 'Fim do show');
    expect(p.run.curId, null);
    expect(p.run.showEnd, t0 + 500000);
    c = cr(p.run);
    expect(c.estado(t0), 'Fim do show');
    expect(c.relogio(t0), 'FIM');
    expect(c.tempoDeShow(t0 + 999999), '00:08:20');
  });

  test('contagem progressiva', () {
    final p = cr(const Run()).contagem();
    expect(p.log, ['Contagem progressiva']);
    final c = cr(cr(p.run).play(t0).run);
    expect(c.relogio(t0 + 65000), ' 01:05');
    expect(cr(c.run).contagem().log, ['Contagem regressiva']);
  });

  test('selecionar guarda o tempo de quem foi pausado', () {
    var p = cr(const Run()).play(t0);
    p = cr(p.run).pause(t0 + 30000);
    p = cr(p.run).selecionar('c');
    expect(p.run.paused, {'a': 30000});
    expect(p.log, ['Selecionado · Comediante 02']);
    p = cr(p.run).selecionar('a');
    expect(p.log, ['Selecionado · Abertura · continua de 00:30']);
    expect(p.run.acc, 30000);
    expect(p.run.paused, isEmpty);
  });

  test('run vai e volta no show.json', () {
    final r = cr(cr(const Run()).play(t0).run).pause(t0 + 5000).run.copyWith(done: {'x': 1}, paused: {'y': 2});
    final s = Show(id: 's', name: 'S', count: 4, cells: const [], lineup: fila, run: r);
    final back = Show.fromJsonString(s.toJsonString());
    expect(back.run, r);
    expect(back.toJson()['run'], r.toJson());
    expect(Show(id: 's', name: 'S', count: 4, cells: const []).toJson().containsKey('run'), false);
  });
}
