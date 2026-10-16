import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

/// Cronômetro solto da mesa, abaixo do telão: Play, Pause, Stop e regressiva/progressiva.
/// Usa o modelo `run` do PocketStage, guardado no show.
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
      if (!mounted) return;
      final c = app.cronometro;
      if (c.run.running) {
        app.cronometroCmd((c, agora) => c.verificarEstouro(agora));
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  static const _amarelo = Color(0xFFFFC531);
  static const _vermelho = Color(0xFFFF3B30);
  static const _azul = Color(0xFF7AA2FF);

  Color _cor(Fase f) => switch (f) {
        Fase.green => Cores.texto,
        Fase.yellow => _amarelo,
        Fase.red || Fase.over => _vermelho,
        Fase.brk => _azul,
        Fase.idle => Cores.textoFraco,
      };

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now().millisecondsSinceEpoch;
    final c = app.cronometro;
    final semFila = c.lineup.isEmpty;
    final fase = c.fase(agora);
    final rel = c.relogio(agora);
    final atual = c.atual;
    final seguir = c.aSeguir;
    final travado = app.engine.state().locked;
    void cmd(RunPasso Function(Cronometro c, int agora) f) {
      if (!travado) app.cronometroCmd(f);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Cores.painel2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fase == Fase.over ? _vermelho : Cores.linha),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('CRONÔMETRO',
              style: TextStyle(color: Cores.textoFraco, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          const Spacer(),
          Text('SHOW ', style: TextStyle(color: Cores.textoApagado, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          Text(c.tempoDeShow(agora), style: mono(size: 12, color: Cores.textoFraco)),
        ]),
        const SizedBox(height: 6),
        if (semFila)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Sem fila neste show. Monte a fila em Editar show para usar o cronômetro.',
                style: TextStyle(color: Cores.textoFraco, fontSize: 13)),
          )
        else ...[
          Text(c.estado(agora).toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Cores.textoFraco, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(rel, style: mono(size: 48, color: _cor(fase))),
          ),
          if (atual != null)
            Text(atual.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Cores.textoFraco, fontSize: 13)),
          if (seguir != null && seguir.id != atual?.id) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(children: [
                const TextSpan(
                    text: 'A SEGUIR  ',
                    style: TextStyle(color: Cores.textoFraco, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                TextSpan(
                    text: seguir.name,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Btn('Play',
                  icon: Icons.play_arrow,
                  compacto: true,
                  tipo: c.run.running ? BtnTipo.ligado : BtnTipo.normal,
                  onTap: travado || c.run.running || (atual == null && c.primeiroEmAberto == null)
                      ? null
                      : () => cmd((c, a) => c.play(a))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Btn('Pause',
                  icon: Icons.pause,
                  compacto: true,
                  onTap: travado || !c.run.running ? null : () => cmd((c, a) => c.pause(a))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Btn('Stop',
                  icon: Icons.stop,
                  compacto: true,
                  onTap: travado || atual == null ? null : () => cmd((c, a) => c.stop(a))),
            ),
          ]),
          const SizedBox(height: 6),
          Btn(c.run.regressiva ? 'Regressiva' : 'Progressiva',
              icon: c.run.regressiva ? Icons.south : Icons.north,
              compacto: true,
              onTap: travado ? null : () => cmd((c, a) => c.contagem())),
        ],
      ]),
    );
  }
}
