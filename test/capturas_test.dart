// Capturas das telas para conferência visual. Só roda com CAPTURAS=1:
//   CAPTURAS=1 flutter test test/capturas_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketstage_midia/data/store.dart';
import 'package:pocketstage_midia/media/backend.dart';
import 'package:pocketstage_midia/state.dart';
import 'package:pocketstage_midia/theme.dart';
import 'package:pocketstage_midia/ui/cue_editor.dart';
import 'package:pocketstage_midia/ui/editor_screen.dart';
import 'package:pocketstage_midia/ui/settings_screen.dart';
import 'package:pocketstage_midia/ui/show_screen.dart';
import 'package:pocketstage_midia/ui/shows_screen.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

final bool ligado = Platform.environment['CAPTURAS'] == '1';

class _P implements MediaPlayer {
  _P(this.dur);
  final int dur;
  @override
  int positionMs = 0;
  @override
  int? get durationMs => dur;
  @override
  void dispose() {}
  @override
  void pause() {}
  @override
  void play() {}
  @override
  void setGain(double gain) {}
}

class _Backend implements MediaBackend {
  _Backend(this.stage);
  final StageController stage;
  final Map<String, _P> players = {};
  @override
  MediaPlayer? open(Cue cue, {required void Function() onEnd, required void Function() onError}) =>
      players[cue.id] = _P(cue.kind == MediaKind.video ? 95000 : 184000);
  @override
  void present(StageVisual? visual, Transition transition, int ms) => stage.present(visual, transition, ms);
  @override
  void presentText(StageText? text, int inMs, int outMs) => stage.presentText(text, inMs, outMs);
}

Future<void> _fontes() async {
  Future<void> f(String family, List<String> paths) async {
    final l = FontLoader(family);
    for (final p in paths) {
      l.addFont(rootBundle.load(p));
    }
    await l.load();
  }

  await f('Archivo', ['assets/fonts/archivo_400.ttf', 'assets/fonts/archivo_600.ttf', 'assets/fonts/archivo_800.ttf']);
  await f('ChivoMono', ['assets/fonts/chivo_mono_500.ttf', 'assets/fonts/chivo_mono_700.ttf']);
  try {
    await f('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  } catch (_) {}
}

Show _show() {
  String id(int i) => 'c$i';
  final caio = 'L2';
  final c = List<Cue?>.filled(maxCells, null);
  c[0] = Cue(id: id(0), uri: '/x.wav', name: '1º sinal', kind: MediaKind.audio, color: '#E2604F', hotkey: '1', fadeOut: false);
  c[1] = Cue(id: id(1), uri: '/x.wav', name: 'Tom de espera', kind: MediaKind.audio, loop: true, fadeIn: true);
  c[2] = Cue(id: id(2), uri: '/x.png', name: 'Cartaz do show', kind: MediaKind.image, fadeIn: true);
  c[3] = Cue(id: id(3), uri: '', name: 'Desliguem os celulares', kind: MediaKind.text, text: 'Desliguem os celulares', autoStopSec: 8, note: 'sai sozinho em 8 s');
  c[4] = Cue(id: id(4), uri: '/x.wav', name: '2º sinal', kind: MediaKind.audio, color: '#E2604F', hotkey: '2');
  c[5] = Cue(id: id(5), uri: '/x.wav', name: 'Vinheta Caio', kind: MediaKind.audio, linkId: caio, role: Role.entrada, visualId: id(6), color: '#E8C547', note: 'quando o MC chamar', duckDb: -10);
  c[6] = Cue(id: id(6), uri: '/x.png', name: 'Fundo céu noturno', kind: MediaKind.image, linkId: caio, role: Role.fundo);
  c[7] = Cue(id: id(7), uri: '', name: 'Caio Vidal', kind: MediaKind.text, text: 'Caio Vidal\nstand-up · 10 min', textPos: TextPos.right, textSize: TextSize.g, linkId: caio, role: Role.entrada);
  c[8] = Cue(id: id(8), uri: '/x.wav', name: '3º sinal', kind: MediaKind.audio, color: '#E2604F', hotkey: '3');
  c[9] = Cue(id: id(9), uri: '/x.wav', name: 'Ruído de plateia', kind: MediaKind.audio, lockAfter: true);
  c[10] = Cue(id: id(10), uri: '/x.mp4', name: 'Abertura em vídeo', kind: MediaKind.video);
  c[11] = Cue(id: id(11), uri: '', name: 'Bar aberto no foyer', kind: MediaKind.text, text: 'Bar aberto no foyer', preWaitSec: 3);
  return Show(
    id: 'demo',
    name: 'Noite de Stand-up (exemplo)',
    count: 16,
    cells: c,
    date: '2026-10-17',
    start: '21:00',
    lineup: [
      LineupItem({'id': 'L1', 'name': 'Abertura · MC Duda'}),
      LineupItem({'id': caio, 'name': 'Caio Vidal'}),
    ],
  );
}

Future<(AppState, _Backend, ManualScheduler)> _app() async {
  final dir = Directory.systemTemp.createTempSync('psm_cap_');
  final store = Store(dir);
  final stage = StageController();
  final be = _Backend(stage);
  final clock = ManualScheduler();
  final engine = Engine(backend: be, scheduler: clock);
  final show = _show();
  final app = AppState.forTest(store, stage, engine, shows: [show]);
  engine.loadShow(show);
  return (app, be, clock);
}

Future<void> _tela(WidgetTester t, Size size, Widget w, String nome, {Future<void> Function()? antes}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await t.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: temaPocketStage(), home: w));
  if (antes != null) await antes();
  await t.pump(const Duration(milliseconds: 50));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$nome.png'));
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(_fontes);

  testWidgets('mesa tocando', (t) async {
    final (app, be, clock) = await _app();
    app.dispatch(const Go('c1'));
    app.dispatch(const Go('c5'));
    app.dispatch(const Go('c7'));
    app.dispatch(const Go('c11'));
    clock.advance(1200);
    be.players['c1']!.positionMs = 63000;
    be.players['c5']!.positionMs = 181500;
    await _tela(t, const Size(1280, 720), ShowScreen(app: app), 'mesa_1280x720');
  }, skip: !ligado);

  testWidgets('mesa no celular deitado', (t) async {
    final (app, _, __) = await _app();
    app.dispatch(const PlayRow(0));
    await _tela(t, const Size(844, 390), ShowScreen(app: app), 'mesa_844x390');
  }, skip: !ligado);

  testWidgets('mesa com telão oculto e bloqueada', (t) async {
    final (app, _, __) = await _app();
    app.tvOpen = false;
    app.dispatch(const Lock());
    await _tela(t, const Size(1280, 720), ShowScreen(app: app), 'mesa_oculto_bloqueada');
  }, skip: !ligado);

  testWidgets('lista de shows', (t) async {
    final (app, _, __) = await _app();
    await _tela(t, const Size(844, 390), ShowsScreen(app: app), 'shows');
  }, skip: !ligado);

  testWidgets('editor do show', (t) async {
    final (app, _, __) = await _app();
    await _tela(t, const Size(1280, 720), EditorScreen(app: app, show: app.shows.first), 'editor');
  }, skip: !ligado);

  testWidgets('ajustes da mídia', (t) async {
    final (app, _, __) = await _app();
    final s = app.shows.first;
    await _tela(t, const Size(430, 1400), CueEditor(app: app, show: s, index: 5, cue: s.cells[5]!, isNew: false), 'midia');
  }, skip: !ligado);

  testWidgets('ajustes gerais', (t) async {
    final (app, _, __) = await _app();
    await _tela(t, const Size(430, 1600), SettingsScreen(app: app), 'ajustes');
  }, skip: !ligado);
}
