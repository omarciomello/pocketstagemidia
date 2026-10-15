import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

void main() {
  test('todos os comandos vão e voltam em JSON', () {
    final cmds = <Command>[
      const Go('a1'),
      const Stop('a1'),
      const StopAll(),
      const Blackout(),
      const Pause(),
      const Resume(),
      const Lock(),
      const Unlock(),
      const ReleaseLocks(),
      const PlayRow(2),
      const LoadShow({'id': 's', 'name': 'x'}),
      SetSettings(const Settings().toJson()),
    ];
    final names = <String>[];
    for (final c in cmds) {
      final back = Command.fromJsonString(c.toJsonString());
      expect(back, isNotNull, reason: c.toJsonString());
      expect(back!.toJson(), c.toJson());
      names.add(c.toJson()['cmd'] as String);
    }
    expect(names, [
      'go', 'stop', 'stop_all', 'blackout', 'pause', 'resume', //
      'lock', 'unlock', 'release_locks', 'play_row', 'load_show', 'set_settings',
    ]);
  });

  test('comandos incompletos ou desconhecidos são recusados', () {
    expect(Command.fromJson({'cmd': 'go'}), isNull);
    expect(Command.fromJson({'cmd': 'play_row'}), isNull);
    expect(Command.fromJson({'cmd': 'load_show', 'show': 'x'}), isNull);
    expect(Command.fromJson({'cmd': 'dançar'}), isNull);
    expect(Command.fromJsonString('[1,2]'), isNull);
  });

  test('log lido de JSON', () {
    final l = LogEntry.fromJson({'t': 5, 'type': 'cue_go', 'ref': 'a', 'linkId': null, 'text': 'x'});
    expect(l.toJson(), {'t': 5, 'source': 'midia', 'type': 'cue_go', 'ref': 'a', 'linkId': null, 'text': 'x'});
  });
}
