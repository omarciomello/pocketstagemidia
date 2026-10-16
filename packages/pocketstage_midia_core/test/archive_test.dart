import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('psm_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String p(String name) => '${tmp.path}${Platform.pathSeparator}$name';

  Show demo() {
    final audioFile = File(p('abertura.mp3'))..writeAsBytesSync(List.generate(3000, (i) => i % 251));
    final imgFile = File(p('cartaz.png'))..writeAsBytesSync([137, 80, 78, 71, 1, 2, 3]);
    return Show(
      id: 'orig',
      name: 'Noite / de Stand-up!',
      count: 8,
      lineup: [
        LineupItem({'id': 'L1', 'name': 'Caio Vidal', 'extra': true}),
      ],
      cells: [
        Cue(id: 'a1', uri: audioFile.path, name: 'Abertura', kind: MediaKind.audio, linkId: 'L1'),
        Cue(id: 'i1', uri: Uri.file(imgFile.path).toString(), name: 'Cartaz', kind: MediaKind.image),
        const Cue(id: 't1', uri: '', name: 'Aviso', kind: MediaKind.text, text: 'Desliguem os celulares'),
        Cue(id: 'a2', uri: p('sumiu.mp3'), name: 'Sumiu', kind: MediaKind.audio),
      ],
    );
  }

  const log = [LogEntry(t: 1, type: 'cue_go', ref: 'a1', linkId: 'L1', text: 'Trilha · Caio Vidal')];

  Map<String, List<int>> unzip(String path) {
    final a = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
    return {
      for (final f in a.files)
        if (f.isFile) f.name: f.content as List<int>,
    };
  }

  test('exporta com show.json, log.json e as mídias', () {
    final r = PsShow.exportTo(demo(), log, p('saida'));
    expect(r.missing, 1);
    expect(r.path, endsWith('Noite  de Stand-up.psshow'));
    final files = unzip(r.path);
    expect(files.keys, containsAll(['show.json', 'log.json', 'media/a1.mp3', 'media/i1.png']));
    expect(files['media/a1.mp3'], File(p('abertura.mp3')).readAsBytesSync());
    final o = jsonDecode(utf8.decode(files['show.json']!)) as Map<String, dynamic>;
    expect(o['format'], 'pocketstage.show');
    expect(o['version'], 1);
    final cells = (o['media'] as Map)['cells'] as List;
    expect(cells[0]['uri'], 'media/a1.mp3');
    expect(cells[1]['uri'], 'media/i1.png');
    expect(cells[2]['text'], 'Desliguem os celulares');
    expect(cells[3]['uri'], p('sumiu.mp3'), reason: 'arquivo faltando fica como estava');
    expect(jsonDecode(utf8.decode(files['log.json']!)), [log.first.toJson()]);
  });

  test('exportar só a estrutura: sem mídias, e elas voltam como arquivo faltando', () {
    final r = PsShow.exportTo(demo(), log, p('saida'), withMedia: false);
    expect(r.path, endsWith('(estrutura).psshow'));
    final files = unzip(r.path);
    expect(files.keys.where((k) => k.startsWith('media/')), isEmpty);
    final imp = PsShow.importFile(r.path, p('midias'));
    expect(imp.show.cells[0]!.uri, 'media/a1.mp3');
    expect(File(imp.show.cells[0]!.uri).existsSync(), isFalse);
    expect(imp.show.cells[2]!.text, 'Desliguem os celulares');
    expect(PsShow.mediaSize(demo()), 3000 + 7);
  });

  test('importa como show novo, com as mídias copiadas', () {
    final r = PsShow.exportTo(demo(), log, p('saida'));
    final imp = PsShow.importFile(r.path, p('midias'), now: 77);
    expect(imp.show.id, isNot('orig'));
    expect(imp.show.name, 'Noite / de Stand-up!');
    expect(imp.show.updatedAt, 77);
    expect(imp.show.lineup.first.raw['extra'], isTrue);
    final a1 = imp.show.cells[0]!;
    expect(a1.uri, startsWith(imp.mediaDir));
    expect(File(a1.uri).readAsBytesSync(), File(p('abertura.mp3')).readAsBytesSync());
    expect(imp.show.cells[2]!.text, 'Desliguem os celulares');
    expect(imp.log.single.text, 'Trilha · Caio Vidal');
  });

  test('importar duas vezes cria dois shows diferentes', () {
    final r = PsShow.exportTo(demo(), log, p('saida'));
    final a = PsShow.importFile(r.path, p('midias'));
    final b = PsShow.importFile(r.path, p('midias'));
    expect(a.show.id, isNot(b.show.id));
    expect(a.mediaDir, isNot(b.mediaDir));
  });

  test('show.json solto também é aceito', () {
    File(p('solto.json')).writeAsStringSync(demo().toJsonString());
    final imp = PsShow.importFile(p('solto.json'), p('midias'));
    expect(imp.show.cells[0]!.name, 'Abertura');
    expect(imp.log, isEmpty);
  });

  test('versão mais nova é recusada com a mensagem combinada', () {
    final o = demo().toJson()..['version'] = 2;
    writeStoredZip(p('novo.psshow'), {'show.json': utf8.encode(jsonEncode(o))});
    expect(
      () => PsShow.importFile(p('novo.psshow'), p('midias')),
      throwsA(isA<ArchiveError>().having((e) => e.message, 'message', PsShow.versionError)),
    );
    expect(Directory(p('midias')).existsSync() ? Directory(p('midias')).listSync() : [], isEmpty);
  });

  test('arquivo de outro formato é recusado', () {
    File(p('outro.json')).writeAsStringSync('{"format":"outra.coisa","id":"x"}');
    expect(
      () => PsShow.importFile(p('outro.json'), p('midias')),
      throwsA(isA<ArchiveError>().having((e) => e.message, 'message', PsShow.formatError)),
    );
  });

  test('zip sem show.json ou com JSON quebrado é recusado', () {
    writeStoredZip(p('vazio.psshow'), {'log.json': utf8.encode('[]')});
    expect(() => PsShow.importFile(p('vazio.psshow'), p('midias')), throwsA(isA<ArchiveError>()));
    writeStoredZip(p('quebrado.psshow'), {'show.json': utf8.encode('{nada')});
    expect(() => PsShow.importFile(p('quebrado.psshow'), p('midias')), throwsA(isA<ArchiveError>()));
  });

  test('caminhos que tentam sair da pasta são ignorados', () {
    writeStoredZip(p('mau.psshow'), {
      'show.json': utf8.encode(demo().toJsonString()),
      'media/../fora.txt': utf8.encode('x'),
      'media/.oculto': utf8.encode('x'),
    });
    final imp = PsShow.importFile(p('mau.psshow'), p('midias'));
    expect(File(p('midias${Platform.pathSeparator}fora.txt')).existsSync(), isFalse);
    expect(Directory(imp.mediaDir).existsSync(), isFalse);
  });
}
