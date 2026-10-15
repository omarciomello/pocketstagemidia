import 'dart:convert';

import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

void main() {
  group('Cue', () {
    test('ida e volta com todos os campos e campos desconhecidos', () {
      final j = {
        'id': 'c1',
        'uri': '/m/a.mp3',
        'name': 'Vinheta',
        'kind': 'AUDIO',
        'volume': 0.5,
        'loop': true,
        'fadeIn': true,
        'fadeOut': false,
        'fit': 'COVER',
        'hold': false,
        'linkId': 'L1',
        'role': 'entrada',
        'visualId': 'i1',
        'visualStays': false,
        'startSec': 1.5,
        'endSec': 9.0,
        'fadeInSec': 0.5,
        'fadeOutSec': 4.0,
        'fadeCurve': 'suave',
        'pan': -0.5,
        'repeat': 3,
        'duckDb': -10.0,
        'preWaitSec': 2.0,
        'autoStopSec': 30.0,
        'followId': 'c2',
        'followMode': 'tempo',
        'followSec': 5.0,
        'stopCols': [1, 2],
        'stopAllOnGo': true,
        'lockAfter': true,
        'transition': 'preto',
        'transSec': 2.0,
        'color': '#FF6B6B',
        'note': 'Só depois da piada',
        'hotkey': '1',
        'futuro': {'x': 1},
      };
      final c = Cue.fromJson(j);
      expect(c.kind, MediaKind.audio);
      expect(c.role, Role.entrada);
      expect(c.fadeCurve, FadeCurve.suave);
      expect(c.followMode, FollowMode.tempo);
      expect(c.transition, Transition.preto);
      expect(c.stopCols, [1, 2]);
      expect(c.extra, {
        'futuro': {'x': 1},
      });
      expect(jsonEncode(Cue.fromJson(c.toJson()).toJson()), jsonEncode(c.toJson()));
      expect(c.toJson()['futuro'], {'x': 1});
    });

    test('campos avançados vazios não vão para o JSON', () {
      final o = const Cue(id: 'c', uri: '/a', name: 'a', kind: MediaKind.audio).toJson();
      for (final k in ['startSec', 'pan', 'repeat', 'duckDb', 'followId', 'transition', 'hotkey', 'color']) {
        expect(o.containsKey(k), isFalse, reason: k);
      }
      expect(o['visualStays'], isTrue);
    });

    test('valores fora da faixa são corrigidos', () {
      final c = Cue.fromJson({
        'id': 'c',
        'kind': 'VIDEO',
        'volume': 9,
        'pan': 3,
        'duckDb': 6,
        'repeat': -2,
        'stopCols': [0, 7, -1, 'x'],
      });
      expect(c.volume, 2);
      expect(c.pan, 1);
      expect(c.duckDb, 0);
      expect(c.repeat, 0);
      expect(c.stopCols, [0]);
    });

    test('sem id ganha um id novo; tipo desconhecido vira áudio', () {
      final c = Cue.fromJson({'name': 'x', 'kind': '???'});
      expect(c.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(c.kind, MediaKind.audio);
    });

    test('copyWith limpa campos anuláveis com null e mantém quando omitido', () {
      final c = const Cue(id: 'c', uri: '', name: 'a', kind: MediaKind.audio, visualId: 'i1', fadeInSec: 1);
      expect(c.copyWith(name: 'b').visualId, 'i1');
      expect(c.copyWith(visualId: null).visualId, isNull);
      expect(c.copyWith(fadeInSec: null).fadeInSec, isNull);
    });
  });

  group('Show', () {
    test('formato novo com cabeçalho, fila e campos desconhecidos', () {
      final j = {
        'format': 'pocketstage.show',
        'version': 1,
        'id': 's1',
        'name': 'Noite de Stand-up',
        'date': '2026-10-20',
        'start': '21:00',
        'eventType': 'standup',
        'lineup': [
          {'id': 'L1', 'name': 'Caio Vidal', 'kind': 'artista', 'minutos': 12},
        ],
        'media': {
          'count': 8,
          'cells': [
            {'id': 'a1', 'kind': 'AUDIO', 'name': 'Abertura', 'uri': '/a.mp3'},
            null,
          ],
        },
        'updatedAt': 123,
        'producao': {'local': 'Teatro X'},
      };
      final s = Show.fromJson(j);
      expect(s.count, 8);
      expect(s.rows, 2);
      expect(s.cells, hasLength(32));
      expect(s.cells[0]?.name, 'Abertura');
      expect(s.usedCount(), 1);
      expect(s.lineupName('L1'), 'Caio Vidal');
      final o = s.toJson();
      expect(o['format'], 'pocketstage.show');
      expect(o['version'], 1);
      expect(o['date'], '2026-10-20');
      expect((o['lineup'] as List).first['minutos'], 12);
      expect(o['producao'], {'local': 'Teatro X'});
      expect((o['media'] as Map)['count'], 8);
      expect(((o['media'] as Map)['cells'] as List), hasLength(32));
      expect(jsonEncode(Show.fromJson(o).toJson()), jsonEncode(o));
    });

    test('formato antigo (count e cells no topo) é convertido', () {
      final s = Show.fromJson({
        'id': 's',
        'name': 'Velho',
        'count': 16,
        'cells': [
          {'id': 'x', 'kind': 'IMAGE', 'name': 'Cartaz'},
        ],
      });
      expect(s.count, 16);
      expect(s.cells[0]?.kind, MediaKind.image);
      expect(s.toJson().containsKey('cells'), isFalse);
    });

    test('quantidade inválida volta para 12 e excesso de botões é cortado', () {
      final s = Show.fromJson({
        'id': 's',
        'media': {
          'count': 10,
          'cells': List.generate(40, (i) => {'id': 'c$i', 'kind': 'AUDIO'}),
        },
      });
      expect(s.count, 12);
      expect(s.cells, hasLength(32));
      expect(s.indexOf('c12'), -1, reason: 'fora da parte em uso');
      expect(s.indexOf('c11'), 11);
    });

    test('lê de texto', () {
      final s = Show.fromJsonString('{"id":"s","name":"A","media":{"count":4,"cells":[]}}');
      expect(s.name, 'A');
      expect(() => Show.fromJsonString('[]'), throwsFormatException);
    });
  });

  group('Settings', () {
    test('padrões', () {
      const s = Settings();
      expect(s.fadeInSec, 2);
      expect(s.fadeOutSec, 3);
      expect(s.stopAllFadeSec, 0.35);
      expect(s.retrigger, Retrigger.parar);
      expect(s.visualFadeSec, 1);
      expect(s.endWarnSec, 5);
      expect(s.holdSec, 1.2);
      expect(s.pauseHoldsPreWait, isTrue);
      expect(Settings.fromJson({'pausePreWait': false}).pauseHoldsPreWait, isFalse);
      expect(s.key(ShortcutAction.go), 'PageDown');
      expect(s.key(ShortcutAction.prev), 'PageUp');
      expect(s.toJson().containsKey('keepAwake'), isFalse, reason: 'tela sempre ligada é obrigatória');
    });

    test('valores fora da faixa são corrigidos', () {
      final s = Settings.fromJson({
        'fadeIn': 99,
        'masterDb': 5,
        'holdSec': 0.1,
        'btnSize': 'X',
        'clockMode': 'outro',
        'retrigger': 'reiniciar',
        'keys': {'go': 'Space', 'pause': ''},
      });
      expect(s.fadeInSec, 10);
      expect(s.masterDb, 0);
      expect(s.holdSec, 0.5);
      expect(s.btnSize, 'M');
      expect(s.clockMode, 'restante');
      expect(s.retrigger, Retrigger.reiniciar);
      expect(s.keys, {'go': 'Space'});
    });

    test('ida e volta', () {
      final s = Settings.fromJson({
        'fadeOut': 5,
        'transition': 'preto',
        'textPos': 'direita',
        'textSize': 'G',
        'clockMode': 'decorrido',
        'confirmStopAll': true,
      });
      expect(jsonEncode(Settings.fromJson(s.toJson()).toJson()), jsonEncode(s.toJson()));
    });
  });

  group('níveis', () {
    test('dB e linear', () {
      expect(dbToLin(0), 1);
      expect(dbToLin(-60), 0);
      expect(dbToLin(-20), closeTo(0.1, 1e-12));
      expect(dbToLin(6), closeTo(1.995, 1e-3));
      expect(linToDb(1), 0);
      expect(linToDb(0), double.negativeInfinity);
    });

    test('curvas', () {
      expect(fadeShape(FadeCurve.linear, 0.5, true), 0.5);
      expect(fadeShape(FadeCurve.suave, 0, true), 0);
      expect(fadeShape(FadeCurve.suave, 1, true), closeTo(1, 1e-12));
      expect(fadeShape(FadeCurve.suave, 0.5, true), greaterThan(0.5));
      expect(fadeShape(FadeCurve.suave, 0.5, false), lessThan(0.5));
    });
  });
}
