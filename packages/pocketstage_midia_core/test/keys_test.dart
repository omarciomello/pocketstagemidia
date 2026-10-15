import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

void main() {
  final show = Show(id: 's', name: 'x', count: 4, cells: [
    const Cue(id: 'a1', uri: '', name: 'Sinal 1', kind: MediaKind.audio, hotkey: '1'),
    const Cue(id: 'a2', uri: '', name: 'Sinal 2', kind: MediaKind.audio, hotkey: 'PageDown'),
    null,
    null,
    const Cue(id: 'fora', uri: '', name: 'Fora', kind: MediaKind.audio, hotkey: 'Z'),
  ]);

  test('atalho de mídia', () {
    final a = resolveKey('1', const Settings(), show);
    expect(a, isA<CueKeyAction>().having((x) => x.cueId, 'cueId', 'a1'));
  });

  test('atalho geral vence atalho de mídia', () {
    final a = resolveKey('PageDown', const Settings(), show);
    expect(a, isA<GlobalKeyAction>().having((x) => x.key, 'key', GlobalKey.go));
  });

  test('botões fora da quantidade em uso não respondem', () {
    expect(resolveKey('Z', const Settings(), show), isNull);
    expect(resolveKey('', const Settings(), show), isNull);
  });

  test('conflito de tecla', () {
    expect(keyConflict('PageUp', const Settings(), show), 'Linha anterior');
    expect(keyConflict('1', const Settings(), show), 'Sinal 1');
    expect(keyConflict('1', const Settings(), show, exceptCueId: 'a1'), isNull);
    expect(keyLabel('PageDown'), 'PgDn');
  });
}
