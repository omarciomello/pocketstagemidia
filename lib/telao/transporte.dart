import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Mesa ↔ telão: mensagens em JSON. No Android vai pelo canal nativo; no computador, entre janelas.
abstract class TransporteMesa {
  Stream<Map<String, dynamic>> get mensagens;

  /// Nome do telão ao conectar; null ao desconectar.
  Stream<String?> get eventos;
  Stream<String> get erros;
  void enviar(Map<String, dynamic> m);
  Future<String?> estado();
}

abstract class TransporteTelao {
  Stream<Map<String, dynamic>> get mensagens;
  void enviar(Map<String, dynamic> m);
  Future<void> pronto();
}

const _paraTelao = WindowMethodChannel('psm/para-telao', mode: ChannelMode.unidirectional);
const _paraMesa = WindowMethodChannel('psm/para-mesa', mode: ChannelMode.unidirectional);

/// Computador, lado da mesa: abre e fecha a janela do telão.
class JanelaTelao implements TransporteMesa {
  JanelaTelao() {
    // A janela do telão foi fechada (Alt+F4, por exemplo).
    onWindowsChanged.listen((_) async {
      final j = _janela;
      if (j == null) return;
      final todas = await WindowController.getAll();
      if (!todas.any((w) => w.windowId == j.windowId)) {
        _janela = null;
        if (_aberta) {
          _aberta = false;
          _eventos.add(null);
        }
      }
    });
    _paraMesa.setMethodCallHandler((call) async {
      final m = jsonDecode(call.arguments as String);
      if (m is! Map<String, dynamic>) return null;
      switch (m['t']) {
        case 'pronto':
          _aberta = true;
          _eventos.add(m['nome'] as String? ?? 'janela');
        case 'fechou':
          _aberta = false;
          _janela = null;
          _eventos.add(null);
        default:
          _msgs.add(m);
      }
      return null;
    });
  }

  final StreamController<Map<String, dynamic>> _msgs = StreamController.broadcast();
  final StreamController<String?> _eventos = StreamController.broadcast();
  final StreamController<String> _erros = StreamController.broadcast();
  WindowController? _janela;
  bool _aberta = false;

  bool get aberta => _aberta || _janela != null;

  @override
  Stream<Map<String, dynamic>> get mensagens => _msgs.stream;
  @override
  Stream<String?> get eventos => _eventos.stream;
  @override
  Stream<String> get erros => _erros.stream;

  @override
  Future<String?> estado() async => null;

  @override
  void enviar(Map<String, dynamic> m) {
    _paraTelao.invokeMethod<void>('msg', jsonEncode(m)).catchError((_) {});
  }

  Future<void> abrir() async {
    if (_janela != null) return;
    try {
      _janela = await WindowController.create(const WindowConfiguration(arguments: 'telao', hiddenAtLaunch: true));
      Timer(const Duration(seconds: 10), () {
        if (_janela != null && !_aberta) _erros.add('O telão não respondeu. Feche a janela dele e tente de novo.');
      });
    } catch (e) {
      _erros.add('Não consegui abrir a janela do telão: $e');
    }
  }

  void fechar() {
    enviar({'t': 'fechar'});
  }
}

/// Computador, lado do telão.
class JanelaTelaoLado implements TransporteTelao {
  JanelaTelaoLado(this.nome);

  final String nome;
  final StreamController<Map<String, dynamic>> _msgs = StreamController.broadcast();

  @override
  Stream<Map<String, dynamic>> get mensagens => _msgs.stream;

  @override
  void enviar(Map<String, dynamic> m) {
    _paraMesa.invokeMethod<void>('msg', jsonEncode(m)).catchError((_) {});
  }

  @override
  Future<void> pronto() async {
    await _paraTelao.setMethodCallHandler((call) async {
      final m = jsonDecode(call.arguments as String);
      if (m is Map<String, dynamic>) _msgs.add(m);
      return null;
    });
    enviar({'t': 'pronto', 'nome': nome});
  }
}
