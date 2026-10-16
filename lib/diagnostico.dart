import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Registro de diagnóstico no computador: Documentos/PocketStage-Midia-<nome>.txt.
/// A cada 2 s grava "vivo" e quantos quadros a tela desenhou: se o app travar,
/// a última linha mostra quando e se foi o código ou a tela que parou.
class Diagnostico {
  static IOSink? _s;
  static String? caminho;

  static Future<void> iniciar(String nome) async {
    if (!(Platform.isWindows || Platform.isMacOS)) return;
    try {
      final d = await getApplicationDocumentsDirectory();
      final f = File('${d.path}${Platform.pathSeparator}PocketStage-Midia-$nome.txt');
      if (f.existsSync() && f.lengthSync() > 2 * 1024 * 1024) f.deleteSync();
      caminho = f.path;
      _s = f.openWrite(mode: FileMode.append);
      log('=== início ${DateTime.now()} · ${Platform.operatingSystemVersion}');
      var quadros = 0;
      WidgetsBinding.instance.addPersistentFrameCallback((_) => quadros++);
      // Cliques e teclas que chegam ao app (para saber se a entrada parou).
      GestureBinding.instance.pointerRouter.addGlobalRoute((e) {
        if (e is PointerDownEvent) log('clique ${e.position.dx.round()},${e.position.dy.round()} · view=${e.viewId}');
      });
      HardwareKeyboard.instance.addHandler((e) {
        if (e is KeyDownEvent) log('tecla ${e.logicalKey.keyLabel}');
        return false;
      });
      Timer.periodic(const Duration(seconds: 2), (_) {
        log('vivo · quadros=$quadros');
        _s?.flush();
      });
    } catch (_) {}
  }

  static void log(String m) {
    try {
      _s?.writeln('${DateTime.now().toIso8601String().substring(11, 23)} $m');
    } catch (_) {}
  }
}
