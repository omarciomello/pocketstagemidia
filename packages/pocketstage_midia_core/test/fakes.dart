import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

class FakePlayer implements MediaPlayer {
  FakePlayer(this.cue, this.onEnd, this.onError);
  final Cue cue;
  final void Function() onEnd;
  final void Function() onError;
  bool playing = false;
  bool disposed = false;
  double gain = -1;
  @override
  int positionMs = 0;
  @override
  int? durationMs = 10000;

  @override
  void play() => playing = true;
  @override
  void pause() => playing = false;
  @override
  void setGain(double g) => gain = g;
  @override
  void dispose() {
    disposed = true;
    playing = false;
  }

  /// Simula o fim natural do arquivo.
  void finish() {
    playing = false;
    onEnd();
  }
}

class FakeBackend implements MediaBackend {
  final List<FakePlayer> players = [];
  final Set<String> failOpen = {};
  StageVisual? visual;
  StageText? text;
  Transition? lastTransition;
  int? lastMs;
  final List<String?> presented = [];

  @override
  MediaPlayer? open(Cue cue, {required void Function() onEnd, required void Function() onError}) {
    if (failOpen.contains(cue.id)) return null;
    final p = FakePlayer(cue, onEnd, onError);
    players.add(p);
    return p;
  }

  @override
  void present(StageVisual? v, Transition transition, int ms) {
    visual = v;
    lastTransition = transition;
    lastMs = ms;
    presented.add(v?.cue.id);
  }

  @override
  void presentText(StageText? t, int inMs, int outMs) => text = t;

  FakePlayer last(String cueId) => players.lastWhere((p) => p.cue.id == cueId);
  List<FakePlayer> of(String cueId) => players.where((p) => p.cue.id == cueId).toList();
}

Cue audio(String id, {String? name}) => Cue(id: id, uri: '/m/$id.mp3', name: name ?? id, kind: MediaKind.audio);
Cue video(String id) => Cue(id: id, uri: '/m/$id.mp4', name: id, kind: MediaKind.video);
Cue image(String id) => Cue(id: id, uri: '/m/$id.png', name: id, kind: MediaKind.image);
Cue text(String id, String t) => Cue(id: id, uri: '', name: id, kind: MediaKind.text, text: t);

/// Monta motor, relógio manual e coletores de log e avisos.
class H {
  H({Settings settings = const Settings()}) {
    e = Engine(backend: be, scheduler: clock, settings: settings, wallClock: () => 1000);
    e.log.listen(logs.add);
    e.messages.listen(msgs.add);
  }

  final ManualScheduler clock = ManualScheduler();
  final FakeBackend be = FakeBackend();
  late final Engine e;
  final List<LogEntry> logs = [];
  final List<String> msgs = [];

  void load(Map<int, Cue> cells, {int count = 12, List<Map<String, dynamic>> lineup = const []}) {
    final list = List<Cue?>.filled(maxCells, null);
    cells.forEach((i, c) => list[i] = c);
    e.loadShow(Show(
      id: 'show1',
      name: 'Teste',
      count: count,
      cells: list,
      lineup: [for (final l in lineup) LineupItem(l)],
    ));
  }

  void go(String id) => e.dispatch(Go(id));
  void run(int ms) => clock.advance(ms);
  EngineState get st => e.state();
  String? col(int c) => st.columns[c]?.cueId;
  List<String> get types => [for (final l in logs) l.type];
}
