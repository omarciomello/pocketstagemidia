import 'dart:convert';
import 'dart:math';

import 'cronometro.dart';

/// Colunas fixas da grade.
const int cols = 4;

/// Máximo de botões num show.
const int maxCells = 64;

/// Quantidades de botões permitidas.
const List<int> allowedCounts = [4, 8, 12, 16, 20, 24, 28, 32, 48, 64];

/// Formato e versão do show.json.
const String showFormat = 'pocketstage.show';
const int showVersion = 1;

final Random _rnd = Random.secure();

/// UUID v4 aleatório.
String newId() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Cópia profunda de um valor JSON.
Object? deepCopyJson(Object? v) => v == null ? null : jsonDecode(jsonEncode(v));

// ---------- leitura tolerante de JSON ----------

double _d(Map<String, dynamic> o, String k, double def) {
  final v = o[k];
  if (v is num && !v.isNaN) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? def;
  return def;
}

double? _dn(Map<String, dynamic> o, String k) {
  final v = o[k];
  if (v is num && !v.isNaN) return v.toDouble();
  return null;
}

int _i(Map<String, dynamic> o, String k, int def) {
  final v = o[k];
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

bool _b(Map<String, dynamic> o, String k, bool def) {
  final v = o[k];
  return v is bool ? v : def;
}

String _s(Map<String, dynamic> o, String k, [String def = '']) {
  final v = o[k];
  return v is String ? v : def;
}

String? _sn(Map<String, dynamic> o, String k) {
  final v = o[k];
  return v is String && v.trim().isNotEmpty ? v : null;
}

Map<String, dynamic>? _obj(Object? v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : null;

// ---------- enums ----------

enum MediaKind {
  audio('AUDIO', 'ÁUDIO', 'Trilha'),
  video('VIDEO', 'VÍDEO', 'Vídeo'),
  image('IMAGE', 'IMAGEM', 'Imagem'),
  text('TEXT', 'TEXTO', 'Texto');

  const MediaKind(this.key, this.label, this.logWord);
  final String key;
  final String label;
  final String logWord;

  bool get isVisual => this != audio;

  static MediaKind from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => audio);
}

/// Onde o texto fica no telão, por cima da imagem ou do vídeo.
enum TextPos {
  right('direita', 'Coluna à direita'),
  center('centro', 'Centro'),
  bottom('embaixo', 'Embaixo');

  const TextPos(this.key, this.label);
  final String key;
  final String label;

  static TextPos from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => bottom);
}

/// Tamanho do texto como fração da altura do telão.
enum TextSize {
  p('P', 'Pequeno', 0.05),
  m('M', 'Médio', 0.075),
  g('G', 'Grande', 0.11);

  const TextSize(this.key, this.label, this.scale);
  final String key;
  final String label;
  final double scale;

  static TextSize from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => m);
}

/// Curva do fade de som.
enum FadeCurve {
  linear('linear', 'Linear'),
  suave('suave', 'Suave');

  const FadeCurve(this.key, this.label);
  final String key;
  final String label;

  static FadeCurve from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => linear);
}

/// Quando "Seguir com" dispara a próxima deixa.
enum FollowMode {
  fim('fim', 'Quando esta terminar'),
  tempo('tempo', 'Após X segundos');

  const FollowMode(this.key, this.label);
  final String key;
  final String label;

  static FollowMode from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => fim);
}

/// Como a imagem, o vídeo ou o texto entra no telão.
enum Transition {
  fade('fade', 'Fade cruzado'),
  preto('preto', 'Pelo preto'),
  corte('corte', 'Corte');

  const Transition(this.key, this.label);
  final String key;
  final String label;

  static Transition from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => fade);
}

/// Como a imagem ou o vídeo ocupa o telão.
enum Fit {
  contain('CONTAIN', 'Inteiro na tela'),
  cover('COVER', 'Preencher a tela');

  const Fit(this.key, this.label);
  final String key;
  final String label;

  static Fit from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => contain);
}

/// Para que serve a mídia em relação ao item da fila a que está ligada.
enum Role {
  entrada('entrada', 'Entrada'),
  saida('saida', 'Saída'),
  fundo('fundo', 'Fundo'),
  livre('livre', 'Livre');

  const Role(this.key, this.label);
  final String key;
  final String label;

  static Role from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => livre);
}

/// O que acontece ao tocar de novo no botão que está tocando.
enum Retrigger {
  parar('parar', 'Para'),
  reiniciar('reiniciar', 'Recomeça do início'),
  ignorar('ignorar', 'Ignora o toque');

  const Retrigger(this.key, this.label);
  final String key;
  final String label;

  static Retrigger from(String? k) =>
      values.firstWhere((e) => e.key == k, orElse: () => parar);
}

/// Ações dos atalhos gerais (teclado ou pedal).
enum ShortcutAction {
  go('go', 'Próxima linha (GO)'),
  prev('prev', 'Linha anterior'),
  stopAll('stopAll', 'Parar tudo'),
  pause('pause', 'Pausar / Retomar'),
  blackout('blackout', 'Apagar telão');

  const ShortcutAction(this.key, this.label);
  final String key;
  final String label;
}

// ---------- mídia ----------

const Set<String> _cueKeys = {
  'id', 'uri', 'name', 'kind', 'volume', 'loop', 'fadeIn', 'fadeOut', 'fit', 'hold', 'linkId', 'role', //
  'text', 'textPos', 'textSize', 'visualId', 'visualStays', //
  'startSec', 'endSec', 'fadeInSec', 'fadeOutSec', 'fadeCurve', 'pan', 'repeat', 'duckDb', 'muted', //
  'preWaitSec', 'autoStopSec', 'followId', 'followMode', 'followSec', 'stopCols', 'stopAllOnGo', 'lockAfter', //
  'transition', 'transSec', 'color', 'note', 'hotkey',
};

const Object _keep = Object();

/// Uma mídia (deixa) da grade.
class Cue {
  /// Fixo para sempre. Trocar o arquivo mantém; remover e adicionar de novo gera outro.
  final String id;
  final String uri;
  final String name;
  final MediaKind kind;

  /// Volume linear: 0 = mudo, 1 = 0 dB, 2 ≈ +6 dB.
  final double volume;
  final bool loop;
  final bool fadeIn;
  final bool fadeOut;
  final Fit fit;

  /// Vídeo: ao terminar, congela no último quadro em vez de apagar o telão.
  final bool hold;

  /// Id do item da fila (lineup) a que esta mídia pertence.
  final String? linkId;
  final Role role;

  /// Texto: o que aparece no telão.
  final String text;
  final TextPos textPos;
  final TextSize textSize;

  /// Trilha: id da imagem, vídeo ou texto que entra no telão junto com ela.
  final String? visualId;

  /// Trilha: a imagem ligada fica no telão quando a trilha acaba (padrão) ou sai junto.
  final bool visualStays;

  // avançado: som
  final double startSec;

  /// 0 = até o fim do arquivo.
  final double endSec;

  /// Fade próprio; null = ajuste geral.
  final double? fadeInSec;
  final double? fadeOutSec;

  /// null = curva dos Ajustes.
  final FadeCurve? fadeCurve;

  /// −1 esquerda, 0 centro, 1 direita.
  final double pan;

  /// Com Repetir: quantas vezes toca. 0 = sem fim.
  final int repeat;

  /// Enquanto toca, abaixa as outras colunas nesta quantidade (dB ≤ 0). 0 = desligado.
  final double duckDb;

  /// Vídeo sem som.
  final bool muted;

  // avançado: disparo
  final double preWaitSec;

  /// Áudio/vídeo: para sozinho. Imagem/texto: tempo na tela. 0 = sem limite.
  final double autoStopSec;
  final String? followId;
  final FollowMode followMode;
  final double followSec;

  /// Ao tocar, para também estas colunas (0–3).
  final List<int> stopCols;
  final bool stopAllOnGo;

  /// Depois de tocar uma vez, fica travada até "Liberar deixas travadas".
  final bool lockAfter;

  // avançado: telão
  final Transition? transition;
  final double? transSec;

  // avançado: botão
  /// #RRGGBB; vazio = sem cor.
  final String color;
  final String note;

  /// Tecla de atalho ("1", "A", "Space", "PageDown"…); vazio = nenhuma.
  final String hotkey;

  /// Campos que este app não conhece: guardados e devolvidos sem mudança.
  final Map<String, dynamic>? extra;

  const Cue({
    required this.id,
    required this.uri,
    required this.name,
    required this.kind,
    this.volume = 1,
    this.loop = false,
    this.fadeIn = false,
    this.fadeOut = true,
    this.fit = Fit.contain,
    this.hold = false,
    this.linkId,
    this.role = Role.livre,
    this.text = '',
    this.textPos = TextPos.bottom,
    this.textSize = TextSize.m,
    this.visualId,
    this.visualStays = true,
    this.startSec = 0,
    this.endSec = 0,
    this.fadeInSec,
    this.fadeOutSec,
    this.fadeCurve,
    this.pan = 0,
    this.repeat = 0,
    this.duckDb = 0,
    this.muted = false,
    this.preWaitSec = 0,
    this.autoStopSec = 0,
    this.followId,
    this.followMode = FollowMode.fim,
    this.followSec = 0,
    this.stopCols = const [],
    this.stopAllOnGo = false,
    this.lockAfter = false,
    this.transition,
    this.transSec,
    this.color = '',
    this.note = '',
    this.hotkey = '',
    this.extra,
  });

  bool get isVisual => kind.isVisual;

  /// Cópia com mudanças. Campos anuláveis: passe `null` para limpar; omita para manter.
  Cue copyWith({
    String? id,
    String? uri,
    String? name,
    MediaKind? kind,
    double? volume,
    bool? loop,
    bool? fadeIn,
    bool? fadeOut,
    Fit? fit,
    bool? hold,
    Object? linkId = _keep,
    Role? role,
    String? text,
    TextPos? textPos,
    TextSize? textSize,
    Object? visualId = _keep,
    bool? visualStays,
    double? startSec,
    double? endSec,
    Object? fadeInSec = _keep,
    Object? fadeOutSec = _keep,
    Object? fadeCurve = _keep,
    double? pan,
    int? repeat,
    double? duckDb,
    bool? muted,
    double? preWaitSec,
    double? autoStopSec,
    Object? followId = _keep,
    FollowMode? followMode,
    double? followSec,
    List<int>? stopCols,
    bool? stopAllOnGo,
    bool? lockAfter,
    Object? transition = _keep,
    Object? transSec = _keep,
    String? color,
    String? note,
    String? hotkey,
  }) =>
      Cue(
        id: id ?? this.id,
        uri: uri ?? this.uri,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        volume: volume ?? this.volume,
        loop: loop ?? this.loop,
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        fit: fit ?? this.fit,
        hold: hold ?? this.hold,
        linkId: identical(linkId, _keep) ? this.linkId : linkId as String?,
        role: role ?? this.role,
        text: text ?? this.text,
        textPos: textPos ?? this.textPos,
        textSize: textSize ?? this.textSize,
        visualId: identical(visualId, _keep) ? this.visualId : visualId as String?,
        visualStays: visualStays ?? this.visualStays,
        startSec: startSec ?? this.startSec,
        endSec: endSec ?? this.endSec,
        fadeInSec: identical(fadeInSec, _keep) ? this.fadeInSec : fadeInSec as double?,
        fadeOutSec: identical(fadeOutSec, _keep) ? this.fadeOutSec : fadeOutSec as double?,
        fadeCurve: identical(fadeCurve, _keep) ? this.fadeCurve : fadeCurve as FadeCurve?,
        pan: pan ?? this.pan,
        repeat: repeat ?? this.repeat,
        duckDb: duckDb ?? this.duckDb,
        muted: muted ?? this.muted,
        preWaitSec: preWaitSec ?? this.preWaitSec,
        autoStopSec: autoStopSec ?? this.autoStopSec,
        followId: identical(followId, _keep) ? this.followId : followId as String?,
        followMode: followMode ?? this.followMode,
        followSec: followSec ?? this.followSec,
        stopCols: stopCols ?? this.stopCols,
        stopAllOnGo: stopAllOnGo ?? this.stopAllOnGo,
        lockAfter: lockAfter ?? this.lockAfter,
        transition: identical(transition, _keep) ? this.transition : transition as Transition?,
        transSec: identical(transSec, _keep) ? this.transSec : transSec as double?,
        color: color ?? this.color,
        note: note ?? this.note,
        hotkey: hotkey ?? this.hotkey,
        extra: extra,
      );

  Map<String, dynamic> toJson() {
    final o = <String, dynamic>{};
    if (extra != null) o.addAll(deepCopyJson(extra) as Map<String, dynamic>);
    o
      ..['id'] = id
      ..['uri'] = uri
      ..['name'] = name
      ..['kind'] = kind.key
      ..['volume'] = volume
      ..['loop'] = loop
      ..['fadeIn'] = fadeIn
      ..['fadeOut'] = fadeOut
      ..['fit'] = fit.key
      ..['hold'] = hold
      ..['linkId'] = linkId
      ..['role'] = role.key;
    if (kind == MediaKind.text) {
      o['text'] = text;
      o['textPos'] = textPos.key;
      o['textSize'] = textSize.key;
    }
    if (kind == MediaKind.audio) {
      o['visualId'] = visualId;
      o['visualStays'] = visualStays;
    }
    if (startSec > 0) o['startSec'] = startSec;
    if (endSec > 0) o['endSec'] = endSec;
    if (fadeInSec != null) o['fadeInSec'] = fadeInSec;
    if (fadeOutSec != null) o['fadeOutSec'] = fadeOutSec;
    if (fadeCurve != null) o['fadeCurve'] = fadeCurve!.key;
    if (pan != 0) o['pan'] = pan;
    if (repeat > 0) o['repeat'] = repeat;
    if (duckDb != 0) o['duckDb'] = duckDb;
    if (muted) o['muted'] = true;
    if (preWaitSec > 0) o['preWaitSec'] = preWaitSec;
    if (autoStopSec > 0) o['autoStopSec'] = autoStopSec;
    if (followId != null) {
      o['followId'] = followId;
      o['followMode'] = followMode.key;
      o['followSec'] = followSec;
    }
    if (stopCols.isNotEmpty) o['stopCols'] = List<int>.of(stopCols);
    if (stopAllOnGo) o['stopAllOnGo'] = true;
    if (lockAfter) o['lockAfter'] = true;
    if (transition != null) o['transition'] = transition!.key;
    if (transSec != null) o['transSec'] = transSec;
    if (color.trim().isNotEmpty) o['color'] = color;
    if (note.trim().isNotEmpty) o['note'] = note;
    if (hotkey.trim().isNotEmpty) o['hotkey'] = hotkey;
    return o;
  }

  factory Cue.fromJson(Map<String, dynamic> o) {
    final extra = <String, dynamic>{};
    o.forEach((k, v) {
      if (!_cueKeys.contains(k)) extra[k] = deepCopyJson(v);
    });
    final sc = o['stopCols'];
    final id = _s(o, 'id');
    return Cue(
      id: id.trim().isEmpty ? newId() : id,
      uri: _s(o, 'uri'),
      name: _s(o, 'name', 'Sem nome'),
      kind: MediaKind.from(_sn(o, 'kind')),
      volume: _d(o, 'volume', 1).clamp(0, 2).toDouble(),
      loop: _b(o, 'loop', false),
      fadeIn: _b(o, 'fadeIn', false),
      fadeOut: _b(o, 'fadeOut', true),
      fit: Fit.from(_sn(o, 'fit')),
      hold: _b(o, 'hold', false),
      linkId: _sn(o, 'linkId'),
      role: Role.from(_sn(o, 'role')),
      text: _s(o, 'text'),
      textPos: TextPos.from(_sn(o, 'textPos')),
      textSize: TextSize.from(_sn(o, 'textSize')),
      visualId: _sn(o, 'visualId'),
      visualStays: _b(o, 'visualStays', true),
      startSec: max(0.0, _d(o, 'startSec', 0)),
      endSec: max(0.0, _d(o, 'endSec', 0)),
      fadeInSec: _dn(o, 'fadeInSec'),
      fadeOutSec: _dn(o, 'fadeOutSec'),
      fadeCurve: _sn(o, 'fadeCurve') == null ? null : FadeCurve.from(_sn(o, 'fadeCurve')),
      pan: _d(o, 'pan', 0).clamp(-1, 1).toDouble(),
      repeat: max(0, _i(o, 'repeat', 0)),
      duckDb: min(0.0, _d(o, 'duckDb', 0)),
      muted: _b(o, 'muted', false),
      preWaitSec: max(0.0, _d(o, 'preWaitSec', 0)),
      autoStopSec: max(0.0, _d(o, 'autoStopSec', 0)),
      followId: _sn(o, 'followId'),
      followMode: FollowMode.from(_sn(o, 'followMode')),
      followSec: max(0.0, _d(o, 'followSec', 0)),
      stopCols: sc is List
          ? sc.whereType<num>().map((e) => e.toInt()).where((e) => e >= 0 && e < cols).toList()
          : const [],
      stopAllOnGo: _b(o, 'stopAllOnGo', false),
      lockAfter: _b(o, 'lockAfter', false),
      transition: _sn(o, 'transition') == null ? null : Transition.from(_sn(o, 'transition')),
      transSec: _dn(o, 'transSec'),
      color: _s(o, 'color'),
      note: _s(o, 'note'),
      hotkey: _s(o, 'hotkey'),
      extra: extra.isEmpty ? null : extra,
    );
  }
}

// ---------- fila ----------

/// Item da fila do PocketStage. O Mídia só lê id, nome e tipo; o resto passa sem mudança.
class LineupItem {
  LineupItem(this.raw);
  final Map<String, dynamic> raw;

  String get id => _s(raw, 'id');
  String get name => _s(raw, 'name');
  String get kind => _s(raw, 'kind');

  /// Tempos da fila, em minutos.
  double get min => _d(raw, 'min', 0);
  double get yel => _d(raw, 'yel', 0);
  double get red => _d(raw, 'red', 0);
}

// ---------- show ----------

const Set<String> _showKeys = {
  'id', 'name', 'lineup', 'media', 'updatedAt', 'count', 'cells', 'format', 'version', 'run',
};
const List<String> _showOptional = ['date', 'start', 'eventType', 'local', 'showType'];

/// Show compatível com o PocketStage. A parte do Mídia fica em `media`.
class Show {
  final String id;
  final String name;

  /// Botões em uso: 4 a 32, de 4 em 4.
  final int count;

  /// Sempre com [maxCells] posições; null = botão vazio.
  final List<Cue?> cells;
  final String? date;
  final String? start;

  /// "standup", "teatro" ou "banda".
  final String? eventType;

  /// Onde é o show (ex.: "Teatro X").
  final String? local;

  /// "solo", "elenco" ou "festival".
  final String? showType;
  final List<LineupItem> lineup;

  /// Cronômetro de palco (modelo `run` do PocketStage); null até o primeiro uso.
  final Run? run;
  final int updatedAt;
  final Map<String, dynamic>? extra;

  Show({
    required this.id,
    required this.name,
    required this.count,
    required List<Cue?> cells,
    this.date,
    this.start,
    this.eventType,
    this.local,
    this.showType,
    this.lineup = const [],
    this.run,
    this.updatedAt = 0,
    this.extra,
  }) : cells = List<Cue?>.unmodifiable(
          List<Cue?>.generate(maxCells, (i) => i < cells.length ? cells[i] : null),
        );

  factory Show.empty({String name = '', int? now}) => Show(
        id: newId(),
        name: name,
        count: 12,
        cells: const [],
        updatedAt: now ?? DateTime.now().millisecondsSinceEpoch,
      );

  int get rows => count ~/ cols;

  int usedCount() => cells.take(count).where((c) => c != null).length;

  /// Índice da mídia na parte em uso da grade, ou −1.
  int indexOf(String cueId) {
    for (var i = 0; i < count; i++) {
      if (cells[i]?.id == cueId) return i;
    }
    return -1;
  }

  Cue? cueById(String cueId) {
    final i = indexOf(cueId);
    return i < 0 ? null : cells[i];
  }

  String? lineupName(String? linkId) {
    if (linkId == null) return null;
    for (final l in lineup) {
      if (l.id == linkId) return l.name.trim().isEmpty ? null : l.name;
    }
    return null;
  }

  Show copyWith({
    String? id,
    String? name,
    int? count,
    List<Cue?>? cells,
    int? updatedAt,
    List<LineupItem>? lineup,
    Run? run,
  }) =>
      Show(
        id: id ?? this.id,
        name: name ?? this.name,
        count: count ?? this.count,
        cells: cells ?? this.cells,
        date: date,
        start: start,
        eventType: eventType,
        local: local,
        showType: showType,
        lineup: lineup ?? this.lineup,
        run: run ?? this.run,
        updatedAt: updatedAt ?? this.updatedAt,
        extra: extra,
      );

  /// Move a mídia do botão [de] para o botão [para]; se [para] estiver ocupado, os dois trocam de lugar.
  /// A mídia mantém o id, então ligações (imagem ligada, seguir) continuam valendo.
  Show moverCelula(int de, int para) {
    if (de == para || de < 0 || para < 0 || de >= maxCells || para >= maxCells) return this;
    final c = List<Cue?>.of(cells);
    final t = c[para];
    c[para] = c[de];
    c[de] = t;
    return copyWith(cells: c);
  }

  /// Copia a mídia do botão [de] para o botão [para] com todos os ajustes, id novo e sem tecla de atalho
  /// (uma tecla só faz uma ação). Substitui o que estiver em [para].
  Show copiarCelula(int de, int para, {String? novoId}) {
    final orig = (de >= 0 && de < maxCells) ? cells[de] : null;
    if (orig == null || para < 0 || para >= maxCells || de == para) return this;
    return colarCue(orig, para, novoId: novoId);
  }

  /// Cola uma cópia de [cue] no botão [para] (id novo, sem tecla de atalho).
  Show colarCue(Cue cue, int para, {String? novoId}) {
    if (para < 0 || para >= maxCells) return this;
    final c = List<Cue?>.of(cells);
    c[para] = cue.copyWith(id: novoId ?? newId(), hotkey: '');
    return copyWith(cells: c);
  }

  /// Até 32 botões o JSON tem 32 posições, como no PocketStage; acima disso, até o último botão preenchido.
  int _celulasNoJson() {
    var n = 32;
    for (var i = maxCells - 1; i >= 32; i--) {
      if (cells[i] != null || i < count) {
        n = i + 1;
        break;
      }
    }
    return n;
  }

  /// show.json completo, com o cabeçalho de formato e versão.
  Map<String, dynamic> toJson() {
    final o = <String, dynamic>{
      'format': showFormat,
      'version': showVersion,
      'id': id,
      'name': name,
    };
    if (date != null) o['date'] = date;
    if (start != null) o['start'] = start;
    if (eventType != null) o['eventType'] = eventType;
    if (local != null) o['local'] = local;
    if (showType != null) o['showType'] = showType;
    o['lineup'] = [for (final l in lineup) deepCopyJson(l.raw)];
    o['media'] = {
      'count': count,
      'cells': [for (final c in cells.take(_celulasNoJson())) c?.toJson()],
    };
    if (run != null) o['run'] = run!.toJson();
    o['updatedAt'] = updatedAt;
    extra?.forEach((k, v) => o.putIfAbsent(k, () => deepCopyJson(v)));
    return o;
  }

  String toJsonString({bool pretty = false}) =>
      pretty ? const JsonEncoder.withIndent('  ').convert(toJson()) : jsonEncode(toJson());

  /// Lê o formato novo e o antigo (count/cells no topo), convertendo.
  factory Show.fromJson(Map<String, dynamic> o) {
    final media = _obj(o['media']);
    final countRaw = media != null ? _i(media, 'count', 12) : _i(o, 'count', 12);
    final arr = (media?['cells'] ?? o['cells']);
    final cells = List<Cue?>.filled(maxCells, null);
    if (arr is List) {
      for (var i = 0; i < arr.length && i < maxCells; i++) {
        final c = _obj(arr[i]);
        if (c != null) {
          try {
            cells[i] = Cue.fromJson(c);
          } catch (_) {
            cells[i] = null;
          }
        }
      }
    }
    final lu = o['lineup'];
    final lineup = <LineupItem>[
      if (lu is List)
        for (final e in lu)
          if (_obj(e) != null) LineupItem(deepCopyJson(_obj(e)) as Map<String, dynamic>),
    ];
    final extra = <String, dynamic>{};
    o.forEach((k, v) {
      final known = _showKeys.contains(k) || (_showOptional.contains(k) && v is String);
      if (!known) extra[k] = deepCopyJson(v);
    });
    final id = _s(o, 'id');
    return Show(
      id: id.trim().isEmpty ? newId() : id,
      name: _s(o, 'name', 'Show'),
      count: allowedCounts.contains(countRaw) ? countRaw : 12,
      cells: cells,
      date: o['date'] is String ? o['date'] as String : null,
      start: o['start'] is String ? o['start'] as String : null,
      eventType: o['eventType'] is String ? o['eventType'] as String : null,
      local: o['local'] is String ? o['local'] as String : null,
      showType: o['showType'] is String ? o['showType'] as String : null,
      lineup: lineup,
      run: _obj(o['run']) == null ? null : Run.fromJson(_obj(o['run'])!),
      updatedAt: _i(o, 'updatedAt', 0),
      extra: extra.isEmpty ? null : extra,
    );
  }

  factory Show.fromJsonString(String s) {
    final o = _obj(jsonDecode(s));
    if (o == null) throw const FormatException('show.json não é um objeto');
    return Show.fromJson(o);
  }
}

// ---------- ajustes ----------

/// Ajustes gerais do app. Os nomes no JSON são os mesmos do protótipo web.
/// A tela sempre ligada é obrigatória, por isso não existe ajuste para ela.
class Settings {
  // som
  final double fadeInSec;
  final double fadeOutSec;
  final FadeCurve fadeCurve;

  /// Fade do "Parar tudo".
  final double stopAllFadeSec;

  /// Volume geral, de −60 (mudo) a 0 dB.
  final double masterDb;
  final Retrigger retrigger;

  /// Pausar congela as pré-esperas (true) ou cancela (false).
  final bool pauseHoldsPreWait;

  /// Saída de áudio no Android (AudioDeviceInfo.TYPE_*). 0 = automático.
  final int audioDeviceType;

  // telão
  final Transition transition;
  final double visualFadeSec;
  final TextPos textPos;
  final TextSize textSize;

  // mesa
  /// Tamanho do texto dos botões: P, M ou G.
  final String btnSize;

  /// Relógio das colunas: "restante" ou "decorrido".
  final String clockMode;

  /// Relógio pisca nos últimos N segundos. 0 = desligado.
  final double endWarnSec;
  final bool showRowGo;

  // segurança
  final bool confirmStopAll;
  final double holdSec;
  final bool lockOnOpen;
  final bool confirmExit;
  final bool tipAirplane;

  /// Atalhos gerais: ação (ShortcutAction.key) → tecla.
  final Map<String, String> keys;

  static const Map<String, String> defaultKeys = {'go': 'PageDown', 'prev': 'PageUp'};

  const Settings({
    this.fadeInSec = 2,
    this.fadeOutSec = 3,
    this.fadeCurve = FadeCurve.linear,
    this.stopAllFadeSec = 0.35,
    this.masterDb = 0,
    this.retrigger = Retrigger.parar,
    this.pauseHoldsPreWait = true,
    this.audioDeviceType = 0,
    this.transition = Transition.fade,
    this.visualFadeSec = 1,
    this.textPos = TextPos.bottom,
    this.textSize = TextSize.m,
    this.btnSize = 'M',
    this.clockMode = 'restante',
    this.endWarnSec = 5,
    this.showRowGo = true,
    this.confirmStopAll = false,
    this.holdSec = 1.2,
    this.lockOnOpen = false,
    this.confirmExit = true,
    this.tipAirplane = true,
    this.keys = defaultKeys,
  });

  String key(ShortcutAction k) => keys[k.key] ?? '';

  Map<String, dynamic> toJson() => {
        'fadeIn': fadeInSec,
        'fadeOut': fadeOutSec,
        'fadeCurve': fadeCurve.key,
        'stopAllFade': stopAllFadeSec,
        'masterDb': masterDb,
        'retrigger': retrigger.key,
        'pausePreWait': pauseHoldsPreWait,
        'audioDeviceType': audioDeviceType,
        'transition': transition.key,
        'visFade': visualFadeSec,
        'textPos': textPos.key,
        'textSize': textSize.key,
        'btnSize': btnSize,
        'clockMode': clockMode,
        'endWarnSec': endWarnSec,
        'showRowGo': showRowGo,
        'confirmStopAll': confirmStopAll,
        'holdSec': holdSec,
        'lockOnOpen': lockOnOpen,
        'confirmExit': confirmExit,
        'tipAirplane': tipAirplane,
        'keys': Map<String, String>.of(keys),
      };

  factory Settings.fromJson(Map<String, dynamic> o) {
    const d = Settings();
    double f(String k, double def, double lo, double hi) => _d(o, k, def).clamp(lo, hi).toDouble();
    final k = _obj(o['keys']);
    final keys = k == null
        ? d.keys
        : <String, String>{
            for (final e in k.entries)
              if (e.value is String && (e.value as String).trim().isNotEmpty) e.key: e.value as String,
          };
    final btn = _s(o, 'btnSize', 'M');
    return Settings(
      fadeInSec: f('fadeIn', d.fadeInSec, 0, 10),
      fadeOutSec: f('fadeOut', d.fadeOutSec, 0, 10),
      fadeCurve: FadeCurve.from(_sn(o, 'fadeCurve')),
      stopAllFadeSec: f('stopAllFade', d.stopAllFadeSec, 0, 5),
      masterDb: f('masterDb', 0, -60, 0),
      retrigger: Retrigger.from(_sn(o, 'retrigger')),
      pauseHoldsPreWait: _b(o, 'pausePreWait', true),
      audioDeviceType: _i(o, 'audioDeviceType', 0),
      transition: Transition.from(_sn(o, 'transition')),
      visualFadeSec: f('visFade', d.visualFadeSec, 0, 5),
      textPos: TextPos.from(_sn(o, 'textPos')),
      textSize: TextSize.from(_sn(o, 'textSize')),
      btnSize: const {'P', 'M', 'G'}.contains(btn) ? btn : 'M',
      clockMode: _s(o, 'clockMode') == 'decorrido' ? 'decorrido' : 'restante',
      endWarnSec: f('endWarnSec', d.endWarnSec, 0, 60),
      showRowGo: _b(o, 'showRowGo', true),
      confirmStopAll: _b(o, 'confirmStopAll', false),
      holdSec: f('holdSec', d.holdSec, 0.5, 5),
      lockOnOpen: _b(o, 'lockOnOpen', false),
      confirmExit: _b(o, 'confirmExit', true),
      tipAirplane: _b(o, 'tipAirplane', true),
      keys: keys,
    );
  }

  Settings withKeys(Map<String, String> keys) => Settings.fromJson({...toJson(), 'keys': keys});
}
