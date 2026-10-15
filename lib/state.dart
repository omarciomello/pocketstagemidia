import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import 'data/sample.dart';
import 'data/store.dart';
import 'media/backend.dart';

/// Estado do app: shows salvos, show em uso, ajustes e o motor.
class AppState extends ChangeNotifier {
  AppState._(this.store, this.stage, this.engine, this._tvOpen);

  final Store store;
  final StageController stage;
  final Engine engine;

  List<Show> shows = [];
  bool _tvOpen;
  final StreamController<String> _toasts = StreamController<String>.broadcast();

  /// Avisos para o operador.
  Stream<String> get toasts => _toasts.stream;

  Settings get settings => engine.settings;
  Show? get active => engine.show;
  bool get tvOpen => _tvOpen;

  /// No celular e no tablet o arquivo escolhido é copiado para dentro do app;
  /// no computador a mídia fica onde está.
  static bool get copiesMedia => Platform.isAndroid || Platform.isIOS;

  /// Para testes e capturas de tela: sem show de exemplo e sem arquivos de mídia.
  @visibleForTesting
  static AppState forTest(Store store, StageController stage, Engine engine, {List<Show> shows = const []}) {
    final s = AppState._(store, stage, engine, true);
    s.shows = List.of(shows);
    engine.changes.listen((_) => s.notifyListeners());
    return s;
  }

  static Future<AppState> create() async {
    final store = await Store.open();
    final stage = StageController();
    final engine = Engine(backend: MediaKitBackend(stage), settings: store.loadSettings());
    final s = AppState._(store, stage, engine, store.tvOpen);
    await s._init();
    return s;
  }

  Future<void> _init() async {
    shows = store.loadShows();
    if (shows.isEmpty && !store.sampleCreated) {
      try {
        final sample = await createSampleShow(store);
        store.saveShow(sample);
        store.sampleCreated = true;
        shows = [sample];
        store.activeId = sample.id;
      } catch (_) {
        // sem o exemplo, o app abre na lista de shows
      }
    }
    engine.log.listen((e) {
      final id = engine.show?.id;
      if (id != null) store.appendLog(id, e);
    });
    engine.messages.listen(toast);
    engine.changes.listen((_) => notifyListeners());
    stage.onImageError = (id) => scheduleMicrotask(() => engine.visualFailed(id));
    final id = store.activeId;
    if (id != null && shows.any((x) => x.id == id)) openShow(id, announce: false);
  }

  void toast(String m) => _toasts.add(m);

  Show? byId(String id) {
    for (final s in shows) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------- show em uso ----------

  void openShow(String id, {bool announce = true}) {
    final s = byId(id);
    if (s == null) return;
    engine.loadShow(s);
    if (settings.lockOnOpen) engine.dispatch(const Lock());
    store.activeId = id;
    notifyListeners();
  }

  /// Fecha o show em uso (volta para a lista).
  void closeShow() {
    engine.unloadShow();
    store.activeId = null;
    notifyListeners();
  }

  /// Há um show aberto na mesa.
  bool get hasActive => engine.show != null;

  void dispatch(Command c) => engine.dispatch(c);

  // ---------- shows salvos ----------

  void saveShow(Show s) {
    final saved = s.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
    store.saveShow(saved);
    if (copiesMedia) store.cleanMedia(saved);
    final i = shows.indexWhere((x) => x.id == saved.id);
    if (i >= 0) {
      shows[i] = saved;
    } else {
      shows.insert(0, saved);
    }
    if (engine.show?.id == saved.id) engine.loadShow(saved);
    notifyListeners();
  }

  /// Desfaz arquivos copiados por uma edição cancelada.
  void discardEdit(Show draft) {
    final saved = byId(draft.id);
    if (saved == null) {
      final d = store.mediaDir(draft.id);
      if (d.existsSync()) d.deleteSync(recursive: true);
    } else if (copiesMedia) {
      store.cleanMedia(saved);
    }
  }

  void deleteShow(String id) {
    if (engine.show?.id == id) closeShow();
    store.deleteShow(id);
    shows.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  /// Copia (no celular) ou referencia (no computador) um arquivo escolhido para uma mídia.
  String prepareMedia(String showId, String cueId, String src) =>
      copiesMedia ? store.copyMedia(showId, cueId, src) : src;

  // ---------- ajustes ----------

  void setSettings(Settings s) {
    engine.setSettings(s);
    store.saveSettings(s);
    notifyListeners();
  }

  set tvOpen(bool v) {
    _tvOpen = v;
    store.tvOpen = v;
    notifyListeners();
  }

  // ---------- exportar e importar ----------

  /// Gera o .psshow e devolve o caminho e quantas mídias faltaram.
  Future<ExportResult> exportShow(Show s) {
    final log = store.loadLog(s.id);
    final dir = store.exportDir.path;
    return _exportar(s, log, dir);
  }

  Future<Show> importShow(String path) async {
    final root = store.mediaRoot.path;
    final r = await _importar(path, root);
    store.saveShow(r.show);
    store.writeLog(r.show.id, r.log);
    shows.insert(0, r.show);
    notifyListeners();
    return r.show;
  }
}

// Fora da classe, para a cópia de arquivos rodar em outro isolate sem levar o estado junto.
Future<ExportResult> _exportar(Show s, List<LogEntry> log, String dir) => Isolate.run(() => PsShow.exportTo(s, log, dir));

Future<ImportResult> _importar(String path, String root) => Isolate.run(() => PsShow.importFile(path, root));
