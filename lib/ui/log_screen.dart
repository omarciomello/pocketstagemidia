import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:share_plus/share_plus.dart';

import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

String _d2(int v) => v.toString().padLeft(2, '0');
String _hora(DateTime d) => '${_d2(d.hour)}:${_d2(d.minute)}:${_d2(d.second)}';
String _dia(DateTime d) => '${_d2(d.day)}/${_d2(d.month)}/${d.year}';

/// Registro do show: tudo o que a mesa e o cronômetro fizeram, em ordem.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.app, required this.show});
  final AppState app;
  final Show show;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  AppState get app => widget.app;
  List<LogEntry> _log = [];
  Timer? _tick;
  final _rolagem = ScrollController();

  @override
  void initState() {
    super.initState();
    _ler(rolarAteOFim: true);
    // O show pode estar rodando: as linhas novas aparecem sozinhas.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) => _ler());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  void _ler({bool rolarAteOFim = false}) {
    final novo = app.store.loadLog(widget.show.id);
    if (!mounted) return;
    final noFim = !_rolagem.hasClients || _rolagem.position.pixels >= _rolagem.position.maxScrollExtent - 40;
    final mudou = novo.length != _log.length;
    setState(() => _log = novo);
    if (mudou && (rolarAteOFim || noFim)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_rolagem.hasClients) _rolagem.jumpTo(_rolagem.position.maxScrollExtent);
      });
    }
  }

  String _texto() {
    final b = StringBuffer('Registro · ${widget.show.name}\n');
    String? dia;
    for (final e in _log) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.t);
      if (_dia(d) != dia) {
        dia = _dia(d);
        b.write('\n$dia\n');
      }
      b.write('${_hora(d)}  ${e.text}\n');
    }
    return b.toString();
  }

  Future<void> _exportar() async {
    if (_log.isEmpty) return;
    final agora = DateTime.now();
    final nome = '${PsShow.safe('Registro - ${widget.show.name}')} ${agora.year}-${_d2(agora.month)}-${_d2(agora.day)}.txt';
    final dir = app.store.exportDir..createSync(recursive: true);
    final arq = File('${dir.path}${Platform.pathSeparator}$nome')..writeAsStringSync(_texto());
    if (Platform.isAndroid || Platform.isIOS) {
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles([XFile(arq.path)],
          subject: 'Registro · ${widget.show.name}',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size);
    } else {
      final dest = await FilePicker.platform.saveFile(dialogTitle: 'Salvar registro', fileName: nome);
      if (dest == null) return;
      arq.copySync(dest);
      if (mounted) aviso(context, 'Registro salvo.');
    }
  }

  Future<void> _limpar() async {
    if (_log.isEmpty) return;
    final ok = await confirmar(context, 'Limpar o registro?', 'As ${_log.length} linhas deste show serão apagadas.',
        ok: 'Limpar', perigo: true);
    if (!ok) return;
    app.store.writeLog(widget.show.id, const []);
    _ler();
  }

  Color _cor(LogEntry e) {
    if (e.type == 'timer') return Cores.ciano;
    if (e.type == LogEntry.stopAll || e.type == LogEntry.blackout) return Cores.vermelho;
    if (e.type == LogEntry.pause || e.type == LogEntry.resume || e.type == LogEntry.lock || e.type == LogEntry.unlock) {
      return Cores.laranja;
    }
    return Cores.texto;
  }

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    String? dia;
    for (final e in _log) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.t);
      if (_dia(d) != dia) {
        dia = _dia(d);
        linhas.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(dia,
              style: TextStyle(color: Cores.textoFraco, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        ));
      }
      linhas.add(Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Cores.linha))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_hora(d), style: mono(size: 13, color: Cores.textoFraco)),
          const SizedBox(width: 14),
          Expanded(child: Text(e.text, style: TextStyle(color: _cor(e), fontSize: 15))),
        ]),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Registro do show'),
          Text(widget.show.name, style: const TextStyle(fontSize: 12, color: Cores.textoFraco)),
        ]),
        actions: [
          Btn('Limpar', compacto: true, onTap: _log.isEmpty ? null : _limpar),
          const SizedBox(width: 8),
          Btn('Exportar', tipo: BtnTipo.primario, compacto: true, onTap: _log.isEmpty ? null : _exportar),
          const SizedBox(width: 12),
        ],
      ),
      body: _log.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nada registrado ainda. Cada mídia disparada, parada e cada comando do cronômetro aparecem aqui.',
                    textAlign: TextAlign.center, style: TextStyle(color: Cores.textoFraco)),
              ),
            )
          : ListView(controller: _rolagem, padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: linhas),
    );
  }
}
