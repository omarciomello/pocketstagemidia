import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  group('colunas', () {
    test('mídia nova corta a anterior da mesma coluna, com fade', () {
      final h = H()..load({0: audio('a1'), 4: audio('a2')});
      h.go('a1');
      h.go('a2');
      expect(h.col(0), 'a2');
      expect(h.st.fadingIdx, contains(0));
      expect(h.be.last('a1').disposed, isFalse);
      h.run(3100); // fade de saída padrão: 3 s
      expect(h.be.last('a1').disposed, isTrue);
      expect(h.st.fadingIdx, isEmpty);
      expect(h.be.last('a2').playing, isTrue);
    });

    test('colunas diferentes tocam juntas', () {
      final h = H()..load({0: audio('a1'), 1: audio('a2'), 2: audio('a3'), 3: audio('a4')});
      for (final id in ['a1', 'a2', 'a3', 'a4']) {
        h.go(id);
      }
      expect([for (var c = 0; c < 4; c++) h.col(c)], ['a1', 'a2', 'a3', 'a4']);
      expect(h.be.players.every((p) => p.playing), isTrue);
    });

    test('só as mídias dentro da quantidade de botões respondem', () {
      final h = H()..load({12: audio('fora')}, count: 12);
      h.go('fora');
      expect(h.col(0), isNull);
      expect(h.msgs.last, 'Deixa não encontrada neste show.');
    });
  });

  group('tocar de novo', () {
    test('padrão: para', () {
      final h = H()..load({0: audio('a1')});
      h.go('a1');
      h.go('a1');
      expect(h.col(0), isNull);
      expect(h.logs.last.type, LogEntry.cueStop);
      expect(h.logs.last.text, 'Parou · Trilha · a1');
    });

    test('recomeça', () {
      final h = H(settings: const Settings(retrigger: Retrigger.reiniciar))..load({0: audio('a1')});
      h.go('a1');
      h.go('a1');
      expect(h.col(0), 'a1');
      expect(h.be.of('a1'), hasLength(2));
      h.run(400); // fade do Parar tudo: 0,35 s
      expect(h.be.of('a1').first.disposed, isTrue);
      expect(h.be.of('a1').last.playing, isTrue);
    });

    test('ignora', () {
      final h = H(settings: const Settings(retrigger: Retrigger.ignorar))..load({0: audio('a1')});
      h.go('a1');
      h.go('a1');
      expect(h.be.of('a1'), hasLength(1));
      expect(h.be.last('a1').playing, isTrue);
    });
  });

  group('telão', () {
    test('uma imagem ou vídeo por vez; texto é camada por cima', () {
      final h = H()..load({0: image('i1'), 1: video('v1'), 2: text('t1', 'Olá'), 3: text('t2', 'Tchau')});
      h.go('i1');
      expect(h.st.screenCueId, 'i1');
      h.go('t1');
      expect(h.st.textCueId, 't1');
      expect(h.st.screenCueId, 'i1');
      expect(h.be.text?.text, 'Olá');
      h.go('v1');
      expect(h.st.screenCueId, 'v1');
      expect(h.col(0), isNull, reason: 'a imagem sai do telão e libera a coluna');
      expect(h.st.textCueId, 't1', reason: 'o texto continua por cima');
      h.go('t2');
      expect(h.st.textCueId, 't2');
      expect(h.col(2), isNull, reason: 'texto novo substitui o texto');
      expect(h.be.text?.text, 'Tchau');
    });

    test('texto vazio mostra o nome da mídia', () {
      final h = H()..load({0: text('Desliguem os celulares', '')});
      h.go('Desliguem os celulares');
      expect(h.be.text?.text, 'Desliguem os celulares');
    });

    test('sem "Entra com fade" a entrada é corte', () {
      final h = H()..load({0: image('i1'), 1: image('i2').copyWith(fadeIn: true)});
      h.go('i1');
      expect(h.be.lastTransition, Transition.corte);
      h.go('i2');
      expect(h.be.lastTransition, Transition.fade);
      expect(h.be.lastMs, 1000);
    });

    test('Apagar telão tira imagem e texto e deixa o som', () {
      final h = H()..load({0: image('i1'), 1: text('t1', 'x'), 2: audio('a1')});
      h.go('i1');
      h.go('t1');
      h.go('a1');
      h.e.dispatch(const Blackout());
      expect(h.st.screenCueId, isNull);
      expect(h.st.textCueId, isNull);
      expect(h.be.visual, isNull);
      expect(h.be.text, isNull);
      expect(h.col(2), 'a1');
      expect(h.logs.last.type, LogEntry.blackout);
    });

    test('imagem que não abre sai do telão com aviso', () {
      final h = H()..load({0: image('i1')});
      h.go('i1');
      h.e.visualFailed('i1');
      expect(h.st.screenCueId, isNull);
      expect(h.col(0), isNull);
      expect(h.msgs.last, contains('Não consegui abrir a imagem'));
    });
  });

  group('fim natural', () {
    test('libera a coluna e registra no log', () {
      final h = H()..load({0: audio('a1')});
      h.go('a1');
      h.be.last('a1').finish();
      expect(h.col(0), isNull);
      expect(h.be.last('a1').disposed, isTrue);
      expect(h.logs.last.type, LogEntry.cueEnd);
      expect(h.logs.last.text, 'Terminou · Trilha · a1');
    });

    test('vídeo apaga o telão ao terminar', () {
      final h = H()..load({0: video('v1')});
      h.go('v1');
      h.be.last('v1').finish();
      expect(h.st.screenCueId, isNull);
      expect(h.be.visual, isNull);
    });

    test('vídeo fixo no último quadro continua no telão', () {
      final h = H()..load({0: video('v1').copyWith(hold: true)});
      h.go('v1');
      h.be.last('v1').finish();
      expect(h.st.screenCueId, 'v1');
      expect(h.col(0), 'v1');
      expect(h.logs.last.text, startsWith('Terminou (congelado)'));
      h.e.dispatch(const Pause());
      h.e.dispatch(const Resume());
      expect(h.be.last('v1').playing, isFalse, reason: 'congelado não volta a tocar no Retomar');
    });

    test('erro ao tocar libera a coluna sem registrar fim', () {
      final h = H()..load({0: audio('a1')});
      h.go('a1');
      h.be.last('a1').onError();
      expect(h.col(0), isNull);
      expect(h.types, isNot(contains(LogEntry.cueEnd)));
      expect(h.msgs.last, contains('Não consegui tocar'));
    });

    test('arquivo que não abre não ocupa a coluna', () {
      final h = H()..load({0: audio('a1')});
      h.be.failOpen.add('a1');
      h.go('a1');
      expect(h.col(0), isNull);
      expect(h.types, isNot(contains(LogEntry.cueGo)));
      expect(h.msgs.last, 'Não consegui abrir “a1”.');
    });
  });

  group('trilha com imagem ligada', () {
    test('a imagem entra junto e fica quando a trilha acaba (padrão)', () {
      final h = H()..load({0: audio('a1').copyWith(visualId: 'i1'), 1: image('i1')});
      h.go('a1');
      expect(h.col(1), 'i1');
      expect(h.st.screenCueId, 'i1');
      h.be.last('a1').finish();
      expect(h.st.screenCueId, 'i1');
    });

    test('com "sai junto", a imagem sai quando a trilha acaba ou para', () {
      final h = H()..load({0: audio('a1').copyWith(visualId: 'i1', visualStays: false), 1: image('i1')});
      h.go('a1');
      h.be.last('a1').finish();
      expect(h.st.screenCueId, isNull);
      h.go('a1');
      expect(h.st.screenCueId, 'i1');
      h.go('a1'); // tocar de novo = para
      expect(h.st.screenCueId, isNull);
    });

    test('se a imagem já está no telão, não é disparada de novo', () {
      final h = H()..load({0: audio('a1').copyWith(visualId: 'i1'), 1: image('i1')});
      h.go('i1');
      h.go('a1');
      expect(h.be.presented.where((id) => id == 'i1'), hasLength(1));
    });
  });

  group('linhas e GO', () {
    Map<int, Cue> grade() => {
          0: audio('a1').copyWith(visualId: 'i1'),
          1: image('i1'),
          2: audio('a2'),
          4: audio('a3'),
        };

    test('▶ da linha para tudo e toca a linha', () {
      final h = H()..load(grade(), count: 8);
      h.go('a3');
      h.e.dispatch(const PlayRow(0));
      expect([h.col(0), h.col(1), h.col(2)], ['a1', 'i1', 'a2']);
      expect(h.be.presented.where((id) => id == 'i1'), hasLength(1), reason: 'imagem ligada entra pela trilha');
      expect(h.st.currentRow, 0);
      h.e.dispatch(const PlayRow(1));
      expect(h.col(0), 'a3');
      expect([h.col(1), h.col(2)], [null, null]);
      expect(h.st.currentRow, 1);
    });

    test('▶ da linha atual de novo para tudo', () {
      final h = H()..load(grade(), count: 8);
      h.e.dispatch(const PlayRow(1));
      h.e.dispatch(const PlayRow(1));
      expect(h.st.columns.every((c) => c == null), isTrue);
      expect(h.st.currentRow, isNull);
      expect(h.logs.last.text, 'Parou a linha 2');
    });

    test('GO anda linha a linha e avisa nas pontas', () {
      final h = H()..load(grade(), count: 8);
      h.e.stepRow(1);
      expect(h.st.currentRow, 0);
      h.e.stepRow(1);
      expect(h.st.currentRow, 1);
      h.e.stepRow(1);
      expect(h.msgs.last, 'Última linha do show.');
      expect(h.st.currentRow, 1);
      h.e.stepRow(-1);
      expect(h.st.currentRow, 0);
      h.e.stepRow(-1);
      expect(h.msgs.last, 'Já está na primeira linha.');
    });

    test('linha anterior sem linha atual avisa', () {
      final h = H()..load(grade(), count: 8);
      h.e.stepRow(-1);
      expect(h.msgs.last, 'Já está na primeira linha.');
    });
  });

  group('pausar', () {
    test('congela a pré-espera', () {
      final h = H()..load({0: audio('a1').copyWith(preWaitSec: 3)});
      h.go('a1');
      expect(h.st.waitingMs[0], 3000);
      h.run(1000);
      h.e.dispatch(const Pause());
      h.run(10000);
      expect(h.be.players, isEmpty);
      expect(h.st.waitingMs[0], 2000);
      h.e.dispatch(const Resume());
      h.run(1999);
      expect(h.be.players, isEmpty);
      h.run(1);
      expect(h.be.last('a1').playing, isTrue);
      expect(h.st.waitingMs, isEmpty);
    });

    test('congela o tempo na tela e os players', () {
      final h = H()..load({0: image('i1').copyWith(autoStopSec: 5), 1: audio('a1')});
      h.go('i1');
      h.go('a1');
      h.run(2000);
      h.e.dispatch(const Pause());
      expect(h.be.last('a1').playing, isFalse);
      h.run(10000);
      expect(h.st.screenCueId, 'i1');
      expect(h.st.columns[0]!.posMs, 2000, reason: 'relógio parado no Pausar');
      h.e.dispatch(const Resume());
      expect(h.be.last('a1').playing, isTrue);
      h.run(2999);
      expect(h.st.screenCueId, 'i1');
      h.run(1);
      expect(h.st.screenCueId, isNull);
      expect(h.logs.last.text, 'Tempo esgotado · Imagem · i1');
    });

    test('pausado não dispara nada', () {
      final h = H()..load({0: audio('a1')});
      h.e.dispatch(const Pause());
      h.go('a1');
      expect(h.be.players, isEmpty);
      expect(h.msgs.last, 'Pausado. Toque em Retomar primeiro.');
    });

    test('som saindo em fade termina na hora ao pausar', () {
      final h = H()..load({0: audio('a1'), 4: audio('a2')});
      h.go('a1');
      h.go('a2');
      h.e.dispatch(const Pause());
      expect(h.be.last('a1').disposed, isTrue);
    });
  });

  group('Parar tudo e bloquear', () {
    test('Parar tudo para todas as colunas com o fade curto e despausa', () {
      final h = H()..load({0: audio('a1'), 1: image('i1'), 2: text('t1', 'x')});
      h.go('a1');
      h.go('i1');
      h.go('t1');
      h.e.dispatch(const Pause());
      h.e.dispatch(const StopAll());
      expect(h.st.columns.every((c) => c == null), isTrue);
      expect(h.st.paused, isFalse);
      expect(h.be.visual, isNull);
      expect(h.be.text, isNull);
      expect(h.logs.last.type, LogEntry.stopAll);
    });

    test('Parar tudo cancela pré-esperas', () {
      final h = H()..load({0: audio('a1').copyWith(preWaitSec: 1)});
      h.go('a1');
      h.e.dispatch(const StopAll());
      h.run(2000);
      expect(h.be.players, isEmpty);
    });

    test('bloqueada, a mesa não dispara deixas nem linhas', () {
      final h = H()..load({0: audio('a1')});
      h.e.dispatch(const Lock());
      h.go('a1');
      h.e.dispatch(const PlayRow(0));
      h.e.stepRow(1);
      expect(h.be.players, isEmpty);
      expect(h.msgs, contains('Mesa bloqueada: a deixa não foi disparada.'));
      h.e.dispatch(const Unlock());
      h.go('a1');
      expect(h.col(0), 'a1');
      expect(h.types, containsAllInOrder([LogEntry.lock, LogEntry.unlock, LogEntry.cueGo]));
    });
  });

  group('opções avançadas', () {
    test('travar depois de tocar, e liberar', () {
      final h = H()..load({0: audio('a1').copyWith(lockAfter: true)});
      h.go('a1');
      h.go('a1'); // para
      h.go('a1'); // travada
      expect(h.col(0), isNull);
      expect(h.msgs.last, contains('travada'));
      expect(h.st.usedCueIds, contains('a1'));
      h.e.dispatch(const ReleaseLocks());
      h.go('a1');
      expect(h.col(0), 'a1');
    });

    test('tocar de novo durante a pré-espera cancela', () {
      final h = H()..load({0: audio('a1').copyWith(preWaitSec: 2)});
      h.go('a1');
      h.go('a1');
      expect(h.msgs.last, 'Pré-espera de “a1” cancelada.');
      h.run(3000);
      expect(h.be.players, isEmpty);
    });

    test('seguir quando esta terminar', () {
      final h = H()..load({0: audio('a1').copyWith(followId: 'a2'), 1: audio('a2')});
      h.go('a1');
      expect(h.col(1), isNull);
      h.be.last('a1').finish();
      expect(h.col(1), 'a2');
    });

    test('seguir após X segundos', () {
      final h = H()
        ..load({
          0: audio('a1').copyWith(followId: 'a2', followMode: FollowMode.tempo, followSec: 2),
          1: audio('a2'),
        });
      h.go('a1');
      h.run(1999);
      expect(h.col(1), isNull);
      h.run(1);
      expect(h.col(1), 'a2');
      expect(h.col(0), 'a1');
    });

    test('parar sozinha e seguir', () {
      final h = H()..load({0: audio('a1').copyWith(autoStopSec: 4, followId: 'i1'), 1: image('i1')});
      h.go('a1');
      h.run(4000);
      expect(h.col(0), isNull);
      expect(h.st.screenCueId, 'i1');
    });

    test('ao tocar, parar colunas escolhidas ou todas', () {
      final h = H()
        ..load({
          0: audio('a1'),
          1: audio('a2'),
          2: audio('a3').copyWith(stopCols: [0]),
          3: audio('a4').copyWith(stopAllOnGo: true),
        });
      h.go('a1');
      h.go('a2');
      h.go('a3');
      expect([h.col(0), h.col(1), h.col(2)], [null, 'a2', 'a3']);
      h.go('a4');
      expect([h.col(0), h.col(1), h.col(2), h.col(3)], [null, null, null, 'a4']);
    });

    test('ducking abaixa as outras colunas e devolve no fim', () {
      final h = H()..load({0: audio('a1'), 1: audio('a2').copyWith(duckDb: -20)});
      h.go('a1');
      expect(h.be.last('a1').gain, closeTo(1, 1e-9));
      h.go('a2');
      h.run(Engine.duckMs + Engine.stepMs);
      expect(h.be.last('a1').gain, closeTo(0.1, 1e-6));
      expect(h.be.last('a2').gain, closeTo(1, 1e-9));
      h.be.last('a2').finish();
      h.run(Engine.duckMs + Engine.stepMs);
      expect(h.be.last('a1').gain, closeTo(1, 1e-6));
    });

    test('fade de entrada sobe o volume no tempo dos Ajustes', () {
      final h = H()..load({0: audio('a1').copyWith(fadeIn: true)});
      h.go('a1');
      expect(h.be.last('a1').gain, 0);
      h.run(990); // passo de 30 ms
      expect(h.be.last('a1').gain, closeTo(0.495, 1e-6));
      h.run(1100);
      expect(h.be.last('a1').gain, closeTo(1, 1e-9));
    });

    test('fade próprio da mídia vence o dos Ajustes', () {
      final h = H()..load({0: audio('a1').copyWith(fadeIn: true, fadeInSec: 0.3)});
      h.go('a1');
      h.run(300);
      expect(h.be.last('a1').gain, closeTo(1, 1e-9));
    });

    test('volume da mídia, mudo e volume geral entram no ganho', () {
      final h = H(settings: const Settings(masterDb: -6))
        ..load({0: audio('a1').copyWith(volume: 2), 1: video('v1').copyWith(muted: true)});
      h.go('a1');
      h.go('v1');
      expect(h.be.last('a1').gain, closeTo(2 * dbToLin(-6), 1e-9));
      expect(h.be.last('v1').gain, 0);
    });

    test('Ajustes novos mudam o ganho na hora', () {
      final h = H()..load({0: audio('a1')});
      h.go('a1');
      h.e.dispatch(SetSettings(const Settings(masterDb: -60).toJson()));
      expect(h.be.last('a1').gain, 0);
    });
  });

  group('log e comandos', () {
    test('texto do log usa o artista da fila e o papel', () {
      final h = H()
        ..load(
          {0: audio('a1').copyWith(linkId: 'L1', role: Role.entrada)},
          lineup: [
            {'id': 'L1', 'name': 'Caio Vidal', 'kind': 'artista'},
          ],
        );
      h.go('a1');
      final l = h.logs.last;
      expect(l.type, LogEntry.cueGo);
      expect(l.text, 'Trilha entrada · Caio Vidal');
      expect(l.ref, 'a1');
      expect(l.linkId, 'L1');
      expect(l.t, 1000);
      expect(l.toJson(), {
        't': 1000,
        'source': 'midia',
        'type': 'cue_go',
        'ref': 'a1',
        'linkId': 'L1',
        'text': 'Trilha entrada · Caio Vidal',
      });
    });

    test('comandos em JSON', () {
      final h = H();
      final show = Show(id: 's9', name: 'Remoto', count: 4, cells: [audio('a1')]);
      expect(h.e.dispatchJson(LoadShow(show.toJson()).toJsonString()), isTrue);
      expect(h.e.show?.id, 's9');
      expect(h.e.dispatchJson('{"cmd":"go","cueId":"a1"}'), isTrue);
      expect(h.col(0), 'a1');
      expect(h.e.dispatchJson('{"cmd":"stop","cueId":"a1"}'), isTrue);
      expect(h.col(0), isNull);
      expect(h.e.dispatchJson('{"cmd":"voar"}'), isFalse);
      expect(h.e.dispatchJson('isso não é json'), isFalse);
    });

    test('trocar de show para tudo na hora e zera as travas', () {
      final h = H()..load({0: audio('a1').copyWith(lockAfter: true), 1: image('i1')});
      h.go('a1');
      h.go('i1');
      h.e.loadShow(Show(id: 'outro', name: 'Outro', count: 4, cells: const []));
      expect(h.be.last('a1').disposed, isTrue);
      expect(h.be.visual, isNull);
      expect(h.st.usedCueIds, isEmpty);
      expect(h.st.columns.every((c) => c == null), isTrue);
    });

    test('o estado vira JSON', () {
      final h = H()..load({0: audio('a1')});
      h.go('a1');
      final j = h.st.toJson();
      expect((j['columns'] as List).first['cueId'], 'a1');
      expect(j['paused'], isFalse);
    });
  });
}
