import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

/// Canal "psm/telao" entre a mesa e o telão externo (Android).
/// Os dois lados usam a mesma classe: cada mensagem é um JSON.
class CanalTelao {
  CanalTelao._() {
    _c.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'msg':
          final m = jsonDecode(call.arguments as String);
          if (m is Map<String, dynamic>) _msgs.add(m);
        case 'conectado':
          _eventos.add(call.arguments as String? ?? 'externo');
        case 'desconectado':
          _eventos.add(null);
      }
      return null;
    });
  }

  static final CanalTelao instancia = CanalTelao._();

  final MethodChannel _c = const MethodChannel('psm/telao');
  final StreamController<Map<String, dynamic>> _msgs = StreamController.broadcast();
  final StreamController<String?> _eventos = StreamController.broadcast();

  /// Mensagens vindas do outro lado.
  Stream<Map<String, dynamic>> get mensagens => _msgs.stream;

  /// Mesa: nome do telão ao conectar (ex.: "1920×1080"), null ao desconectar.
  Stream<String?> get eventos => _eventos.stream;

  void enviar(Map<String, dynamic> m) {
    _c.invokeMethod<void>('enviar', jsonEncode(m)).catchError((_) {});
  }

  /// Mesa: telão já conectado ao abrir o app.
  Future<String?> estado() async {
    try {
      return await _c.invokeMethod<String>('estado');
    } catch (_) {
      return null;
    }
  }

  /// Telão: avisa que já está ouvindo.
  Future<void> pronto() async {
    try {
      await _c.invokeMethod<void>('pronto');
    } catch (_) {}
  }
}
