import 'model.dart';

/// Um player de áudio ou vídeo aberto pela plataforma.
///
/// Recorte (startSec/endSec), Repetir (loop/repeat), pan e "sem som" vêm da [Cue]
/// e são aplicados pela plataforma ao abrir. O motor só controla tocar, pausar e o ganho.
abstract class MediaPlayer {
  void play();
  void pause();

  /// Ganho final, linear (0 = mudo, 1 = 0 dB, até 2 ≈ +6 dB). Já inclui fades,
  /// ducking, volume da mídia e volume geral.
  void setGain(double gain);

  int get positionMs;

  /// Duração do trecho que toca; null enquanto não se sabe.
  int? get durationMs;

  /// Libera o player. Depois disso nada mais é chamado nele.
  void dispose();
}

/// O que o telão mostra: uma imagem ou um vídeo.
class StageVisual {
  const StageVisual(this.cue, this.player);
  final Cue cue;

  /// Player do vídeo; null para imagem.
  final MediaPlayer? player;
}

/// Texto sobreposto no telão.
class StageText {
  const StageText(this.text, this.pos, this.size);
  final String text;
  final TextPos pos;
  final TextSize size;

  @override
  bool operator ==(Object other) =>
      other is StageText && other.text == text && other.pos == pos && other.size == size;

  @override
  int get hashCode => Object.hash(text, pos, size);
}

/// O que a plataforma oferece ao motor: abrir players e desenhar o telão.
abstract class MediaBackend {
  /// Abre o arquivo da mídia (áudio ou vídeo) sem tocar ainda.
  /// [onEnd] = terminou sozinho (todas as repetições). [onError] = não deu para tocar.
  /// Retorna null se não conseguir abrir.
  MediaPlayer? open(Cue cue, {required void Function() onEnd, required void Function() onError});

  /// Troca a imagem/vídeo do telão. null = apaga. [ms] = duração da transição.
  /// Para imagem, a plataforma carrega o arquivo; se falhar, chama `Engine.visualFailed`.
  void present(StageVisual? visual, Transition transition, int ms);

  /// Troca o texto do telão. null = tira. [inMs] = entrada; [outMs] = saída do anterior.
  void presentText(StageText? text, int inMs, int outMs);
}
