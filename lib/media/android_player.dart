import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

/// Vídeo desenhado numa textura do Flutter (Android).
abstract class VideoTextura {
  ValueListenable<int?> get textura;
  ValueListenable<Size?> get tamanho;
}

/// Uma saída de som do aparelho. tipo 0 = alto-falante do telefone (padrão).
class SaidaSom {
  const SaidaSom(this.tipo, this.nome, this.produto);
  final int tipo;
  final String nome;
  final String produto;
}

/// Player nativo do Android (ExoPlayer), com a saída de som escolhida pelo operador.
class PlayerAndroid implements MediaPlayer, VideoTextura {
  PlayerAndroid._(this._som, this.id, this.cue, this.alvo, this.onEnd, this.onError);

  final SomAndroid _som;
  final int id;
  final Cue cue;

  /// "telao", "mesa" ou null (só som).
  final String? alvo;
  final void Function() onEnd;
  final void Function() onError;

  @override
  final ValueNotifier<int?> textura = ValueNotifier(null);
  @override
  final ValueNotifier<Size?> tamanho = ValueNotifier(null);

  /// Onde o vídeo ficou de fato ("telao" ou "mesa").
  String? onde;
  bool disposed = false;
  bool _tocando = false;
  int _pos = 0;
  int? _dur;
  final Stopwatch _desde = Stopwatch()..start();

  void _posicao(int pos, int? dur) {
    _pos = pos;
    _dur = dur;
    _desde.reset();
  }

  @override
  void play() {
    _tocando = true;
    _desde.reset();
    _som._call('play', {'id': id});
  }

  @override
  void pause() {
    _pos = positionMs;
    _tocando = false;
    _som._call('pause', {'id': id});
  }

  @override
  void setGain(double gain) => _som._call('ganho', {'id': id, 'g': gain.clamp(0.0, 2.0)});

  @override
  int get positionMs {
    final p = _tocando ? _pos + _desde.elapsedMilliseconds : _pos;
    final d = _dur;
    return d != null && p > d ? d : p;
  }

  @override
  int? get durationMs => _dur;

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    _som._players.remove(id);
    _som._call('liberar', {'id': id});
  }
}

/// Canal "psm/player": players nativos e saídas de som do Android.
class SomAndroid extends ChangeNotifier {
  SomAndroid._() {
    _c.setMethodCallHandler(_recebe);
    carregarSaidas();
  }

  static final SomAndroid instancia = SomAndroid._();

  final MethodChannel _c = const MethodChannel('psm/player');
  final Map<int, PlayerAndroid> _players = {};
  int _proximo = 1;
  Timer? _poll;

  /// Saídas disponíveis agora (a primeira é o telefone).
  List<SaidaSom> saidas = const [SaidaSom(0, 'Telefone (alto-falante)', '')];

  /// Saída escolhida (0 = telefone).
  int escolhida = 0;

  /// Chamado quando aparece uma saída nova (ex.: ligou o adaptador).
  void Function(List<String> novas)? onNovaSaida;

  String nomeDe(int tipo) {
    for (final s in saidas) {
      if (s.tipo == tipo) return s.nome;
    }
    return tipo == 0 ? 'Telefone' : 'Saída desconectada';
  }

  /// A escolhida está conectada agora?
  bool get escolhidaPresente => escolhida == 0 || saidas.any((s) => s.tipo == escolhida);

  void _call(String m, Map<String, dynamic> a) {
    _c.invokeMethod<void>(m, a).catchError((_) {});
  }

  Future<dynamic> _recebe(MethodCall call) async {
    final a = call.arguments is Map ? Map<String, dynamic>.from(call.arguments as Map) : const <String, dynamic>{};
    final p = a['id'] is num ? _players[(a['id'] as num).toInt()] : null;
    switch (call.method) {
      case 'fim':
        if (p != null && !p.disposed) p.onEnd();
      case 'erro':
        if (p != null && !p.disposed) p.onError();
      case 'tamanho':
        p?.tamanho.value = Size((a['w'] as num).toDouble(), (a['h'] as num).toDouble());
      case 'saidas':
        _lerSaidas(a['lista']);
        final novas = (a['novas'] as List?)?.whereType<String>().toList() ?? const [];
        if (novas.isNotEmpty) onNovaSaida?.call(novas);
    }
    return null;
  }

  void _lerSaidas(Object? lista) {
    if (lista is! List) return;
    final out = <SaidaSom>[];
    for (final e in lista) {
      if (e is Map) {
        out.add(SaidaSom((e['tipo'] as num).toInt(), e['nome'] as String? ?? '', e['produto'] as String? ?? ''));
      }
    }
    if (out.isNotEmpty) saidas = out;
    notifyListeners();
  }

  Future<void> carregarSaidas() async {
    try {
      _lerSaidas(await _c.invokeMethod<List<dynamic>>('saidas'));
    } catch (_) {}
  }

  void escolher(int tipo) {
    escolhida = tipo;
    _call('saida', {'tipo': tipo});
    notifyListeners();
  }

  PlayerAndroid abrir(Cue cue, {String? alvo, required void Function() onEnd, required void Function() onError}) {
    final p = PlayerAndroid._(this, _proximo++, cue, alvo, onEnd, onError);
    _players[p.id] = p;
    _c.invokeMethod<Map<dynamic, dynamic>>('abrir', {
      'id': p.id,
      'uri': PsShow.localPath(cue.uri),
      'start': cue.startSec,
      'end': cue.endSec,
      'loop': cue.loop,
      'repeat': cue.repeat,
      'pan': cue.pan,
      'boost': cue.volume > 1 ? cue.volume : 1.0,
      'alvo': alvo,
    }).then((r) {
      if (r == null) return;
      p.onde = r['onde'] as String?;
      final t = r['textura'];
      if (t is num) p.textura.value = t.toInt();
    }).catchError((Object _) {
      if (!p.disposed) p.onError();
    });
    _poll ??= Timer.periodic(const Duration(milliseconds: 100), (_) => _atualizar());
    return p;
  }

  Future<void> _atualizar() async {
    if (_players.isEmpty) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    try {
      final m = await _c.invokeMethod<Map<dynamic, dynamic>>('estado');
      m?.forEach((k, v) {
        final p = _players[int.tryParse('$k') ?? -1];
        if (p != null && v is List && v.length == 2) {
          final d = (v[1] as num).toInt();
          p._posicao((v[0] as num).toInt(), d > 0 ? d : null);
        }
      });
    } catch (_) {}
  }
}
