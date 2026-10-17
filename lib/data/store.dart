import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

/// Guarda shows, ajustes e logs em arquivos JSON na pasta do app.
///
/// shows/<id>.json · media/<showId>/<cueId>.<ext> · logs/<showId>.jsonl · prefs.json
class Store {
  Store(this.root);

  final Directory root;

  static Future<Store> open() async {
    final d = await getApplicationSupportDirectory();
    final s = Store(d);
    s._showsDir.createSync(recursive: true);
    s._logsDir.createSync(recursive: true);
    s.mediaRoot.createSync(recursive: true);
    return s;
  }

  String _p(List<String> parts) => parts.join(Platform.pathSeparator);

  Directory get _showsDir => Directory(_p([root.path, 'shows']));
  Directory get _logsDir => Directory(_p([root.path, 'logs']));
  Directory get mediaRoot => Directory(_p([root.path, 'media']));
  Directory mediaDir(String showId) => Directory(_p([mediaRoot.path, PsShow.safe(showId)]));
  Directory get exportDir => Directory(_p([root.path, 'exportar']));
  File get _prefs => File(_p([root.path, 'prefs.json']));

  // ---------- shows ----------

  List<Show> loadShows() {
    final out = <Show>[];
    for (final f in _showsDir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        out.add(Show.fromJsonString(f.readAsStringSync()));
      } catch (_) {
        // arquivo com erro: fica de fora da lista, mas não é apagado
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  void saveShow(Show s) => _writeAtomic(File(_p([_showsDir.path, '${PsShow.safe(s.id)}.json'])), s.toJsonString());

  void deleteShow(String id) {
    final f = File(_p([_showsDir.path, '${PsShow.safe(id)}.json']));
    if (f.existsSync()) f.deleteSync();
    final m = mediaDir(id);
    if (m.existsSync()) m.deleteSync(recursive: true);
    final l = _logFile(id);
    if (l.existsSync()) l.deleteSync();
  }

  /// Copia um arquivo escolhido para a pasta do show. Retorna o caminho novo.
  String copyMedia(String showId, String cueId, String src) {
    final target = mediaTarget(showId, cueId, src);
    File(src).copySync(target);
    return target;
  }

  /// Caminho onde a cópia de [src] vai morar na pasta do show (cria a pasta, não copia).
  String mediaTarget(String showId, String cueId, String src) {
    final dir = mediaDir(showId)..createSync(recursive: true);
    final name = src.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : 'bin';
    return _p([dir.path, '${PsShow.safe(cueId)}-${DateTime.now().millisecondsSinceEpoch}.$ext']);
  }

  /// Apaga da pasta do show os arquivos que nenhuma mídia usa mais.
  void cleanMedia(Show s) {
    final dir = mediaDir(s.id);
    if (!dir.existsSync()) return;
    final used = {for (final c in s.cells) if (c != null) c.uri};
    for (final f in dir.listSync().whereType<File>()) {
      if (!used.contains(f.path)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  // ---------- log ----------

  File _logFile(String showId) => File(_p([_logsDir.path, '${PsShow.safe(showId)}.jsonl']));

  void appendLog(String showId, LogEntry e) {
    try {
      final f = _logFile(showId)..parent.createSync(recursive: true);
      f.writeAsStringSync('${jsonEncode(e.toJson())}\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  void writeLog(String showId, List<LogEntry> log) {
    _logFile(showId).writeAsStringSync(log.map((e) => '${jsonEncode(e.toJson())}\n').join());
  }

  List<LogEntry> loadLog(String showId) {
    final f = _logFile(showId);
    if (!f.existsSync()) return [];
    final out = <LogEntry>[];
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        out.add(LogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  // ---------- preferências ----------

  Map<String, dynamic> _readPrefs() {
    try {
      if (_prefs.existsSync()) return jsonDecode(_prefs.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
    return {};
  }

  void _writePrefs(Map<String, dynamic> p) => _writeAtomic(_prefs, jsonEncode(p));

  Settings loadSettings() {
    final s = _readPrefs()['settings'];
    return s is Map<String, dynamic> ? Settings.fromJson(s) : const Settings();
  }

  void saveSettings(Settings s) => _writePrefs({..._readPrefs(), 'settings': s.toJson()});

  String? get activeId => _readPrefs()['active'] as String?;
  set activeId(String? v) => _writePrefs({..._readPrefs(), 'active': v});

  bool get tvOpen => _readPrefs()['tvOpen'] as bool? ?? true;
  set tvOpen(bool v) => _writePrefs({..._readPrefs(), 'tvOpen': v});

  bool get sampleCreated => _readPrefs()['sample'] == true;
  set sampleCreated(bool v) => _writePrefs({..._readPrefs(), 'sample': v});

  /// Versão do show de exemplo já criada (0 = nenhuma ou a primeira).
  int get sampleVersion => (_readPrefs()['sampleVersion'] as num?)?.toInt() ?? 0;
  set sampleVersion(int v) => _writePrefs({..._readPrefs(), 'sampleVersion': v});

  void _writeAtomic(File f, String text) {
    f.parent.createSync(recursive: true);
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(text, flush: true);
    tmp.renameSync(f.path);
  }
}
