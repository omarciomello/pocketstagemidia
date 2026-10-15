import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'model.dart';
import 'protocol.dart';

/// Erro de exportação ou importação, com mensagem pronta para o operador.
class ArchiveError implements Exception {
  const ArchiveError(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExportResult {
  const ExportResult(this.path, this.missing);

  /// Caminho do .psshow criado.
  final String path;

  /// Mídias cujo arquivo não foi encontrado (ficaram de fora do pacote).
  final int missing;
}

class ImportResult {
  const ImportResult(this.show, this.log, this.mediaDir);

  /// Show com id novo e mídias apontando para [mediaDir].
  final Show show;
  final List<LogEntry> log;
  final String mediaDir;
}

/// Arquivo .psshow: ZIP com
/// - `show.json` — show com o cabeçalho `{"format":"pocketstage.show","version":1, …}`
/// - `log.json` — log do show
/// - `media/<cueId>.<ext>` — cópia de cada arquivo usado
class PsShow {
  PsShow._();

  static const String versionError = 'Este show foi criado numa versão mais nova do PocketStage. Atualize o app.';
  static const String formatError = 'Este arquivo não é um show do PocketStage.';

  /// Nome seguro para arquivo e pasta.
  static String safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Nome do arquivo exportado (sem extensão) a partir do nome do show.
  static String baseName(Show show) {
    var b = show.name.replaceAll(RegExp(r'[^\p{L}\p{N} _-]', unicode: true), '').trim();
    if (b.isEmpty) b = 'show';
    return b.length > 60 ? b.substring(0, 60).trim() : b;
  }

  /// Caminho local de uma mídia (aceita caminho simples ou file://).
  static String localPath(String uri) {
    if (uri.startsWith('file:')) {
      try {
        return Uri.parse(uri).toFilePath();
      } catch (_) {
        return uri;
      }
    }
    return uri;
  }

  static String _ext(String path) {
    final name = path.split(RegExp(r'[/\\]')).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return 'bin';
    final e = name.substring(dot + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(e) ? e : 'bin';
  }

  /// Exporta [show] e o [log] para `<outDir>/<nome>.psshow`.
  static ExportResult exportTo(Show show, List<LogEntry> log, String outDir) {
    Directory(outDir).createSync(recursive: true);
    final out = '$outDir${Platform.pathSeparator}${baseName(show)}.psshow';
    final zip = _ZipWriter(out);
    var missing = 0;
    try {
      final cells = <Cue?>[];
      for (final c in show.cells) {
        if (c == null || c.kind == MediaKind.text || c.uri.isEmpty) {
          cells.add(c);
          continue;
        }
        final path = localPath(c.uri);
        final f = File(path);
        if (!f.existsSync()) {
          missing++;
          cells.add(c);
          continue;
        }
        final entry = 'media/${safe(c.id)}.${_ext(path)}';
        zip.addFile(entry, f);
        cells.add(c.copyWith(uri: entry));
      }
      final body = show.copyWith(cells: cells).toJsonString(pretty: true);
      zip.addBytes('show.json', utf8.encode(body));
      zip.addBytes('log.json', utf8.encode(jsonEncode([for (final e in log) e.toJson()])));
      zip.close();
    } catch (e) {
      zip.abort();
      if (e is ArchiveError) rethrow;
      throw ArchiveError('Não consegui exportar: $e');
    }
    return ExportResult(out, missing);
  }

  /// Importa um .psshow (ou um show.json solto) de [path]. As mídias vão para
  /// `<mediaRoot>/<idNovo>/`. Sempre cria um show novo; nunca sobrescreve.
  static ImportResult importFile(String path, String mediaRoot, {int? now}) {
    final newShowId = newId();
    final dir = Directory('$mediaRoot${Platform.pathSeparator}${safe(newShowId)}');
    try {
      final f = File(path);
      if (!f.existsSync()) throw const ArchiveError('Não consegui abrir o arquivo.');
      final bytes = f.readAsBytesSync();
      String? showJson;
      String? logJson;
      final files = <String, String>{};

      final isZip = bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
      if (isZip) {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final e in archive.files) {
          if (!e.isFile) continue;
          final name = e.name;
          if (name == 'show.json') {
            showJson = utf8.decode(e.content as List<int>, allowMalformed: true);
          } else if (name == 'log.json') {
            logJson = utf8.decode(e.content as List<int>, allowMalformed: true);
          } else if (name.startsWith('media/')) {
            final fileName = name.substring(6);
            // evita caminhos que escapem da pasta
            if (fileName.isEmpty || fileName.contains('/') || fileName.contains('\\') || fileName.startsWith('.')) {
              continue;
            }
            dir.createSync(recursive: true);
            final target = '${dir.path}${Platform.pathSeparator}$fileName';
            File(target).writeAsBytesSync(e.content as List<int>, flush: true);
            files[name] = target;
          }
        }
      } else {
        showJson = utf8.decode(bytes, allowMalformed: true);
      }

      if (showJson == null) throw const ArchiveError('Arquivo inválido: falta o show.json.');
      Object? decoded;
      try {
        decoded = jsonDecode(showJson);
      } catch (_) {
        throw const ArchiveError('Arquivo inválido: show.json com erro.');
      }
      if (decoded is! Map) throw const ArchiveError('Arquivo inválido: show.json com erro.');
      final o = decoded.map((k, v) => MapEntry(k.toString(), v));
      final format = o['format'] is String ? o['format'] as String : showFormat;
      if (format != showFormat) throw const ArchiveError(formatError);
      final version = o['version'] is num ? (o['version'] as num).toInt() : 1;
      if (version > showVersion) throw const ArchiveError(versionError);

      final s = Show.fromJson(o);
      final cells = [
        for (final c in s.cells)
          if (c == null) null else (files[c.uri] != null ? c.copyWith(uri: files[c.uri]) : c),
      ];
      final log = <LogEntry>[];
      if (logJson != null) {
        try {
          final l = jsonDecode(logJson);
          if (l is List) {
            for (final e in l) {
              if (e is Map) log.add(LogEntry.fromJson(e.map((k, v) => MapEntry(k.toString(), v))));
            }
          }
        } catch (_) {
          // log com erro: importa o show mesmo assim
        }
      }
      final show = s.copyWith(
        id: newShowId,
        cells: cells,
        updatedAt: now ?? DateTime.now().millisecondsSinceEpoch,
      );
      return ImportResult(show, log, dir.path);
    } catch (e) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      if (e is ArchiveError) rethrow;
      throw ArchiveError('Não consegui importar: ${e is FormatException ? 'arquivo inválido' : e}.');
    }
  }
}

/// Grava um ZIP sem compressão com as [entries] (nome → bytes). Útil para testes e ferramentas.
void writeStoredZip(String path, Map<String, List<int>> entries) {
  final z = _ZipWriter(path);
  entries.forEach(z.addBytes);
  z.close();
}

/// Escreve um ZIP sem compressão (vídeo e áudio já vêm comprimidos), arquivo por arquivo,
/// sem carregar as mídias inteiras na memória.
class _ZipWriter {
  _ZipWriter(this.path) : _raf = File(path).openSync(mode: FileMode.write);

  final String path;
  final RandomAccessFile _raf;
  final List<_Entry> _entries = [];
  int _offset = 0;
  static const int _chunk = 1 << 20;
  static const int _limit = 0xFFFFFFFF;

  void addBytes(String name, List<int> data) {
    final crc = getCrc32(data);
    _header(name, crc, data.length);
    _raf.writeFromSync(data);
    _offset += data.length;
  }

  void addFile(String name, File f) {
    final size = f.lengthSync();
    if (size >= _limit || _offset + size >= _limit) {
      throw const ArchiveError('O show passa de 4 GB e não cabe num .psshow.');
    }
    var crc = 0;
    final r = f.openSync();
    try {
      while (true) {
        final b = r.readSync(_chunk);
        if (b.isEmpty) break;
        crc = getCrc32(b, crc);
      }
    } finally {
      r.closeSync();
    }
    _header(name, crc, size);
    final r2 = f.openSync();
    try {
      while (true) {
        final b = r2.readSync(_chunk);
        if (b.isEmpty) break;
        _raf.writeFromSync(b);
      }
    } finally {
      r2.closeSync();
    }
    _offset += size;
  }

  void _header(String name, int crc, int size) {
    final n = utf8.encode(name);
    final e = _Entry(n, crc, size, _offset);
    _entries.add(e);
    final h = <int>[];
    _u32(h, 0x04034b50);
    _u16(h, 20); // versão
    _u16(h, 0x0800); // nomes em UTF-8
    _u16(h, 0); // sem compressão
    _u16(h, _dosTime);
    _u16(h, _dosDate);
    _u32(h, crc);
    _u32(h, size);
    _u32(h, size);
    _u16(h, n.length);
    _u16(h, 0);
    h.addAll(n);
    final bytes = h;
    _raf.writeFromSync(bytes);
    _offset += bytes.length;
  }

  void close() {
    final cdStart = _offset;
    final h = <int>[];
    for (final e in _entries) {
      _u32(h, 0x02014b50);
      _u16(h, 20);
      _u16(h, 20);
      _u16(h, 0x0800);
      _u16(h, 0);
      _u16(h, _dosTime);
      _u16(h, _dosDate);
      _u32(h, e.crc);
      _u32(h, e.size);
      _u32(h, e.size);
      _u16(h, e.name.length);
      _u16(h, 0);
      _u16(h, 0);
      _u16(h, 0);
      _u16(h, 0);
      _u32(h, 0);
      _u32(h, e.offset);
      h.addAll(e.name);
    }
    final cd = h;
    final end = <int>[];
    _u32(end, 0x06054b50);
    _u16(end, 0);
    _u16(end, 0);
    _u16(end, _entries.length);
    _u16(end, _entries.length);
    _u32(end, cd.length);
    _u32(end, cdStart);
    _u16(end, 0);
    _raf.writeFromSync(cd);
    _raf.writeFromSync(end);
    _raf.closeSync();
  }

  void abort() {
    try {
      _raf.closeSync();
    } catch (_) {}
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  static final DateTime _now = DateTime.now();
  static int get _dosTime => (_now.hour << 11) | (_now.minute << 5) | (_now.second ~/ 2);
  static int get _dosDate => ((_now.year - 1980).clamp(0, 127) << 9) | (_now.month << 5) | _now.day;

  static void _u16(List<int> b, int v) => b.addAll([v & 0xff, (v >> 8) & 0xff]);
  static void _u32(List<int> b, int v) =>
      b.addAll([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
}

class _Entry {
  _Entry(this.name, this.crc, this.size, this.offset);
  final List<int> name;
  final int crc;
  final int size;
  final int offset;
}
