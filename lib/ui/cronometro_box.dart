import 'dart:async';

import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

/// Cronômetro solto da mesa, abaixo do telão: só Play, Pause e Stop, contando para cima.
/// Guarda o estado no `run` do show (modelo do PocketStage), para crescer nas próximas fases.
class CronometroBox extends StatefulWidget {
  const CronometroBox({super.key, required this.app});
  final AppState app;

  @override
  State<CronometroBox> createState() => _CronometroBoxState();
}

class _CronometroBoxState extends State<CronometroBox> {
  AppState get app => widget.app;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && app.cronometroSolto.run.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now().millisecondsSinceEpoch;
    final c = app.cronometroSolto;
    final rodando = c.run.running;
    final travado = app.engine.state().locked;
    final cor = rodando ? Cores.texto : (c.zerado ? Cores.textoFraco : Cores.laranja);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Cores.linha),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('CRONÔMETRO',
            style: TextStyle(color: Cores.textoFraco, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(c.relogio(agora), style: mono(size: 28, color: cor)),
            ),
          ),
          const SizedBox(width: 6),
          Btn('',
              icon: Icons.play_arrow,
              compacto: true,
              tipo: rodando ? BtnTipo.ligado : BtnTipo.normal,
              onTap: travado || rodando ? null : () => app.cronometroSoltoCmd((c, a) => c.play(a))),
          const SizedBox(width: 4),
          Btn('',
              icon: Icons.pause,
              compacto: true,
              onTap: travado || !rodando ? null : () => app.cronometroSoltoCmd((c, a) => c.pause(a))),
          const SizedBox(width: 4),
          Btn('',
              icon: Icons.stop,
              compacto: true,
              onTap: travado || c.zerado ? null : () => app.cronometroSoltoCmd((c, a) => c.stop(a))),
        ]),
      ]),
    );
  }
}
