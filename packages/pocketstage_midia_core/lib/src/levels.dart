import 'dart:math' as math;

import 'model.dart';

/// dB → ganho linear. −60 dB ou menos = mudo.
double dbToLin(double db) => db <= -60 ? 0 : math.pow(10, db / 20).toDouble();

/// Ganho linear → dB (mudo = −∞).
double linToDb(double lin) => lin <= 0 ? double.negativeInfinity : 20 * math.log(lin) / math.ln10;

/// Posição da curva de fade para o progresso [k] (0–1), subindo ([up]) ou descendo.
double fadeShape(Curve curve, double k, bool up) {
  final t = k.clamp(0.0, 1.0);
  switch (curve) {
    case Curve.linear:
      return t;
    case Curve.suave:
      return up ? math.sin(t * math.pi / 2) : 1 - math.sin((1 - t) * math.pi / 2);
  }
}
