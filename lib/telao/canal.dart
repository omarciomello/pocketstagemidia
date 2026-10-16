import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'transporte.dart';

/// Canal "psm/telao" entre a mesa e o telão externo (Android).
/// Os dois lados usam a mesma classe: cada mensagem é um JSON.
class CanalTelao implements TransporteMesa, TransporteTelao {
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
        case 'erro':
          _erros.add(call.arguments as String? ?? 'Erro no telão.');
      }
      return null;
    });
  }

  static final CanalTelao instancia = CanalTelao._();

  final MethodChannel _c = const MethodChannel('psm/telao');
  final StreamController<Map<String, dynamic>> _msgs = StreamController.broadcast();
  final StreamController<String?> _eventos = StreamController.broadcast();
  final StreamController<String> _erros = StreamController.broadcast();

  /// Mesa: erros ao abrir o telão.
  @override
  Stream<String> get erros => _erros.stream;

  /// Mesa: lista das telas que o aparelho informa (para descobrir problemas).
  Future<String> diagnostico() async {
    try {
      return await _c.invokeMethod<String>('diagnostico') ?? '';
    } catch (e) {
      return 'Diagnóstico indisponível: $e';
    }
  }

  /// Mesa: tenta abrir o telão de novo.
  Future<void> reconectar() async {
    try {
      await _c.invokeMethod<String>('reconectar');
    } catch (_) {}
  }

  /// Mensagens vindas do outro lado.
  @override
  Stream<Map<String, dynamic>> get mensagens => _msgs.stream;

  /// Mesa: nome do telão ao conectar (ex.: "1920×1080"), null ao desconectar.
  @override
  Stream<String?> get eventos => _eventos.stream;

  @override
  void enviar(Map<String, dynamic> m) {
    _c.invokeMethod<void>('enviar', jsonEncode(m)).catchError((_) {});
  }

  /// Mesa: telão já conectado ao abrir o app.
  @override
  Future<String?> estado() async {
    try {
      return await _c.invokeMethod<String>('estado');
    } catch (_) {
      return null;
    }
  }

  /// Telão: avisa que já está ouvindo.
  @override
  Future<void> pronto() async {
    try {
      await _c.invokeMethod<void>('pronto');
    } catch (_) {}
  }
}
