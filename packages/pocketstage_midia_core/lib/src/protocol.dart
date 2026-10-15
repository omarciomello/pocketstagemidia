import 'dart:convert';

import 'model.dart';

/// Comandos do motor, serializáveis em JSON. Toda ação de reprodução passa por aqui.
///
/// `{"cmd":"go","cueId":"…"}` · `{"cmd":"play_row","row":0}` ·
/// `{"cmd":"load_show","show":{…}}` · `{"cmd":"set_settings","settings":{…}}`
sealed class Command {
  const Command();

  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());

  /// null se o comando não for reconhecido ou estiver incompleto.
  static Command? fromJson(Map<String, dynamic> o) {
    String? str(String k) => o[k] is String && (o[k] as String).isNotEmpty ? o[k] as String : null;
    Map<String, dynamic>? obj(String k) =>
        o[k] is Map ? (o[k] as Map).map((k, v) => MapEntry(k.toString(), v)) : null;
    switch (o['cmd']) {
      case 'go':
        final id = str('cueId');
        return id == null ? null : Go(id);
      case 'stop':
        final id = str('cueId');
        return id == null ? null : Stop(id);
      case 'stop_all':
        return const StopAll();
      case 'blackout':
        return const Blackout();
      case 'pause':
        return const Pause();
      case 'resume':
        return const Resume();
      case 'lock':
        return const Lock();
      case 'unlock':
        return const Unlock();
      case 'release_locks':
        return const ReleaseLocks();
      case 'play_row':
        final r = o['row'];
        return r is num ? PlayRow(r.toInt()) : null;
      case 'load_show':
        final s = obj('show');
        return s == null ? null : LoadShow(s);
      case 'set_settings':
        final s = obj('settings');
        return s == null ? null : SetSettings(s);
    }
    return null;
  }

  static Command? fromJsonString(String s) {
    try {
      final o = jsonDecode(s);
      if (o is! Map) return null;
      return fromJson(o.map((k, v) => MapEntry(k.toString(), v)));
    } catch (_) {
      return null;
    }
  }
}

/// Dispara a deixa (mesma regra do toque no botão).
class Go extends Command {
  const Go(this.cueId);
  final String cueId;
  @override
  Map<String, dynamic> toJson() => {'cmd': 'go', 'cueId': cueId};
}

/// Para a deixa, se estiver tocando.
class Stop extends Command {
  const Stop(this.cueId);
  final String cueId;
  @override
  Map<String, dynamic> toJson() => {'cmd': 'stop', 'cueId': cueId};
}

class StopAll extends Command {
  const StopAll();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'stop_all'};
}

class Blackout extends Command {
  const Blackout();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'blackout'};
}

class Pause extends Command {
  const Pause();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'pause'};
}

class Resume extends Command {
  const Resume();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'resume'};
}

class Lock extends Command {
  const Lock();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'lock'};
}

class Unlock extends Command {
  const Unlock();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'unlock'};
}

/// Libera as deixas com "Travar depois de tocar" que já tocaram.
class ReleaseLocks extends Command {
  const ReleaseLocks();
  @override
  Map<String, dynamic> toJson() => {'cmd': 'release_locks'};
}

/// ▶ da linha [row] (0 = primeira): para todo o resto e toca a linha. Na linha atual, para tudo.
class PlayRow extends Command {
  const PlayRow(this.row);
  final int row;
  @override
  Map<String, dynamic> toJson() => {'cmd': 'play_row', 'row': row};
}

class LoadShow extends Command {
  const LoadShow(this.show);
  final Map<String, dynamic> show;
  @override
  Map<String, dynamic> toJson() => {'cmd': 'load_show', 'show': show};
}

class SetSettings extends Command {
  const SetSettings(this.settings);
  final Map<String, dynamic> settings;
  @override
  Map<String, dynamic> toJson() => {'cmd': 'set_settings', 'settings': settings};
}

// ---------- estado ----------

/// O que está tocando numa coluna.
class ColumnState {
  const ColumnState({
    required this.cueId,
    required this.index,
    required this.name,
    required this.kind,
    required this.posMs,
    required this.durMs,
    required this.loop,
    required this.onScreen,
  });

  final String cueId;
  final int index;
  final String name;
  final MediaKind kind;
  final int posMs;

  /// 0 = sem duração conhecida (imagem/texto sem tempo, ou ainda carregando).
  final int durMs;
  final bool loop;
  final bool onScreen;

  Map<String, dynamic> toJson() => {
        'cueId': cueId,
        'index': index,
        'name': name,
        'kind': kind.key,
        'posMs': posMs,
        'durMs': durMs,
        'loop': loop,
        'onScreen': onScreen,
      };
}

/// Retrato do motor num instante. A tela desenha a partir dele.
class EngineState {
  const EngineState({
    required this.showId,
    required this.columns,
    required this.screenCueId,
    required this.textCueId,
    required this.currentRow,
    required this.usedCueIds,
    required this.waitingMs,
    required this.fadingIdx,
    required this.paused,
    required this.locked,
  });

  final String? showId;
  final List<ColumnState?> columns;
  final String? screenCueId;
  final String? textCueId;
  final int? currentRow;

  /// Deixas travadas (já tocaram e têm "Travar depois de tocar").
  final Set<String> usedCueIds;

  /// Pré-espera em andamento: índice do botão → ms que faltam.
  final Map<int, int> waitingMs;

  /// Botões cujo som ainda está saindo em fade.
  final Set<int> fadingIdx;
  final bool paused;
  final bool locked;

  bool isPlaying(String cueId) => columns.any((c) => c?.cueId == cueId);

  bool isPlayingIndex(int i) => columns.any((c) => c?.index == i);

  Map<String, dynamic> toJson() => {
        'showId': showId,
        'columns': [for (final c in columns) c?.toJson()],
        'screen': screenCueId,
        'text': textCueId,
        'currentRow': currentRow,
        'used': usedCueIds.toList(),
        'waiting': {for (final e in waitingMs.entries) '${e.key}': e.value},
        'fading': fadingIdx.toList(),
        'paused': paused,
        'locked': locked,
      };
}

// ---------- log ----------

/// Entrada de log no formato do PocketStage. `t` = relógio do aparelho (ms desde 1970).
class LogEntry {
  const LogEntry({
    required this.t,
    required this.type,
    required this.ref,
    required this.linkId,
    required this.text,
    this.source = 'midia',
  });

  final int t;
  final String type;
  final String? ref;
  final String? linkId;
  final String text;
  final String source;

  static const cueGo = 'cue_go';
  static const cueStop = 'cue_stop';
  static const cueEnd = 'cue_end';
  static const stopAll = 'stop_all';
  static const blackout = 'blackout';
  static const pause = 'pause';
  static const resume = 'resume';
  static const lock = 'lock';
  static const unlock = 'unlock';

  Map<String, dynamic> toJson() => {
        't': t,
        'source': source,
        'type': type,
        'ref': ref,
        'linkId': linkId,
        'text': text,
      };

  factory LogEntry.fromJson(Map<String, dynamic> o) => LogEntry(
        t: o['t'] is num ? (o['t'] as num).toInt() : 0,
        type: o['type'] is String ? o['type'] as String : '',
        ref: o['ref'] is String ? o['ref'] as String : null,
        linkId: o['linkId'] is String ? o['linkId'] as String : null,
        text: o['text'] is String ? o['text'] as String : '',
        source: o['source'] is String ? o['source'] as String : 'midia',
      );

  @override
  String toString() => '$type: $text';
}
