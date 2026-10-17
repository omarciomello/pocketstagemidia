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
    expect(a, isA<GlobalKeyAction>().having((x) => x.key, 'key', ShortcutAction.go));
  });

  test('botões fora da quantidade em uso não respondem', () {
    expect(resolveKey('Z', const Settings(), show), isNull);
    expect(resolveKey('', const Settings(), show), isNull);
  });

  test('teclas 1 a 9 e 0 tocam as linhas; mídia com a mesma tecla vence', () {
    final grande = Show(id: 'g', name: 'g', count: 48, cells: const []);
    expect(resolveKey('1', const Settings(), grande), isA<RowKeyAction>().having((x) => x.row, 'row', 0));
    expect(resolveKey('9', const Settings(), grande), isA<RowKeyAction>().having((x) => x.row, 'row', 8));
    expect(resolveKey('0', const Settings(), grande), isA<RowKeyAction>().having((x) => x.row, 'row', 9));
    expect(resolveKey('2', const Settings(), show), isNull); // só 1 linha
    expect(keyOfRow(0), '1');
    expect(keyOfRow(9), '0');
    expect(keyOfRow(10), isNull);
  });

  test('conflito de tecla', () {
    expect(keyConflict('PageUp', const Settings(), show), 'Linha anterior');
    expect(keyConflict('1', const Settings(), show), 'Sinal 1');
    expect(keyConflict('1', const Settings(), show, exceptCueId: 'a1'), 'Linha 1');
    expect(keyConflict('2', const Settings(), show), isNull);
    expect(keyLabel('PageDown'), 'PgDn');
  });
}
