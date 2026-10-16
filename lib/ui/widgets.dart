import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../media/android_player.dart';
import '../state.dart';
import '../theme.dart';

// ---------- botões ----------

enum BtnTipo { normal, primario, perigo, ligado }

/// Botão da barra (mesmo desenho do protótipo).
class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onTap, this.tipo = BtnTipo.normal, this.icon, this.compacto = false});

  final String label;
  final VoidCallback? onTap;
  final BtnTipo tipo;
  final IconData? icon;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    final (fg, bg, bd) = switch (tipo) {
      BtnTipo.primario => (Cores.tinta, Cores.ciano, Cores.ciano),
      BtnTipo.perigo => (const Color(0xFFFF8F8F), const Color(0x1AFF6B6B), const Color(0x40FF6B6B)),
      BtnTipo.ligado => (Cores.ciano, Cores.cianoFundo, Cores.ciano),
      BtnTipo.normal => (Cores.texto, Cores.painel2, Cores.linha),
    };
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: bd)),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: compacto ? 34 : 40,
            padding: EdgeInsets.symmetric(horizontal: compacto ? 10 : 14),
            child: Center(
              widthFactor: 1,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), if (label.isNotEmpty) const SizedBox(width: 6)],
              if (label.isNotEmpty)
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: .2)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão que só age depois de segurado por [segundos] (desbloquear a mesa).
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.label, required this.segundos, required this.onDone});

  final String label;
  final double segundos;
  final VoidCallback onDone;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.segundos * 1000).round()),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        HapticFeedback.mediumImpact();
        widget.onDone();
        _c.reset();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(from: 0),
      onTapUp: (_) => _c.reset(),
      onTapCancel: () => _c.reset(),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x0F6FD3DF),
          border: Border.all(color: Cores.ciano),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _c.value,
                child: Container(color: Cores.cianoFundo),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(widget.label, style: const TextStyle(color: Cores.ciano, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ---------- diálogos ----------

Future<bool> confirmar(BuildContext context, String titulo, String texto,
    {String ok = 'Confirmar', bool perigo = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(texto, style: const TextStyle(color: Cores.textoFraco, height: 1.4)),
      actions: [
        Btn('Cancelar', onTap: () => Navigator.pop(c, false)),
        Btn(ok, tipo: perigo ? BtnTipo.perigo : BtnTipo.primario, onTap: () => Navigator.pop(c, true)),
      ],
    ),
  );
  return r ?? false;
}

void aviso(BuildContext context, String texto) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 3)));
}

/// Nome da tecla no formato do show.json ("1", "A", "PageDown", "Space", "F5"…), ou null.
String? keyNameOf(KeyEvent e) {
  final k = e.logicalKey;
  final special = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
    LogicalKeyboardKey.mediaPlayPause: 'MediaPlayPause',
    LogicalKeyboardKey.mediaTrackNext: 'MediaNext',
    LogicalKeyboardKey.mediaTrackPrevious: 'MediaPrev',
  };
  final s = special[k];
  if (s != null) return s;
  final l = k.keyLabel;
  if (l.length == 1 && RegExp(r'[A-Za-z0-9]').hasMatch(l)) return l.toUpperCase();
  return null;
}

/// Espera o operador apertar uma tecla ou o pedal.
Future<String?> capturarTecla(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (c) => Focus(
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is KeyDownEvent) {
          if (e.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(c);
            return KeyEventResult.handled;
          }
          final n = keyNameOf(e);
          if (n != null) {
            Navigator.pop(c, n);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        title: const Text('Aperte a tecla ou o pedal…', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Esc cancela.', style: TextStyle(color: Cores.textoFraco)),
        actions: [Btn('Cancelar', onTap: () => Navigator.pop(c))],
      ),
    ),
  );
}

// ---------- formatos ----------

/// 83500 ms → "01:23".
String relogio(int ms) {
  final s = math.max(0, (ms / 1000).floor());
  final m = s ~/ 60;
  return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

String dbLabel(double db) {
  if (db <= -60) return '−∞ dB';
  final sinal = db > 0 ? '+' : (db < 0 ? '−' : '');
  return '$sinal${db.abs().toStringAsFixed(1).replaceAll('.', ',')} dB';
}

String panLabel(double pan) {
  if (pan.abs() < 0.005) return 'Centro';
  final p = (pan.abs() * 100).round();
  return pan < 0 ? 'E $p' : 'D $p';
}

/// "1:23,5", "83" ou "83,5" → segundos.
double parseTempo(String v) {
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  if (t.contains(':')) {
    final p = t.split(':');
    return math.max(0, (double.tryParse(p[0]) ?? 0) * 60 + (double.tryParse(p.length > 1 ? p[1] : '0') ?? 0));
  }
  return math.max(0, double.tryParse(t) ?? 0);
}

String fmtTempo(double s) {
  if (s <= 0) return '';
  final m = (s / 60).floor();
  final r = s - m * 60;
  final rs = (r * 10).round() / 10;
  final txt = rs == rs.roundToDouble() ? rs.toInt().toString() : rs.toString().replaceAll('.', ',');
  return '$m:${rs < 10 ? '0' : ''}$txt';
}

double? parseNum(String v) {
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String numTxt(double? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

Color? corDe(String hex) {
  final h = hex.replaceAll('#', '').trim();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

const List<(String, String)> coresBotao = [
  ('', 'Nenhuma'),
  ('#E2604F', 'Vermelho'),
  ('#F08A3C', 'Laranja'),
  ('#E8C547', 'Amarelo'),
  ('#7FC38A', 'Verde'),
  ('#6FB7E0', 'Azul'),
  ('#A98BE0', 'Roxo'),
  ('#E07FB3', 'Rosa'),
];

/// Rótulo pequeno em maiúsculas (seções).
class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key, this.cor = Cores.textoFraco});
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(texto.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: cor)),
      );
}

/// Grupo de opções exclusivas em "chips".
class Escolha<T> extends StatelessWidget {
  const Escolha({super.key, required this.opcoes, required this.valor, required this.onChanged});

  final List<(T, String)> opcoes;
  final T valor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (v, l) in opcoes)
        ChoiceChip(
          label: Text(l),
          selected: v == valor,
          showCheckmark: false,
          onSelected: (_) => onChanged(v),
          selectedColor: Cores.cianoFundo,
          backgroundColor: Cores.painel2,
          side: BorderSide(color: v == valor ? Cores.ciano : Cores.linha),
          labelStyle: TextStyle(color: v == valor ? Cores.ciano : Cores.texto, fontWeight: FontWeight.w600),
        ),
    ]);
  }
}

/// Linha com interruptor.
class Chave extends StatelessWidget {
  const Chave(this.label, {super.key, required this.valor, required this.onChanged, this.dica});
  final String label;
  final bool valor;
  final ValueChanged<bool> onChanged;
  final String? dica;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 15)),
        subtitle: dica == null ? null : Text(dica!, style: const TextStyle(color: Cores.textoFraco, fontSize: 12)),
        value: valor,
        onChanged: onChanged,
      );
}

/// Campo numérico curto (aceita vírgula).
class CampoNum extends StatelessWidget {
  const CampoNum({super.key, required this.label, required this.controller, this.dica, this.largura = 120});
  final String label;
  final TextEditingController controller;
  final String? dica;
  final double largura;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: largura,
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, hintText: dica),
        ),
      );
}

/// Seção com título dentro de um cartão.
class Secao extends StatelessWidget {
  const Secao(this.titulo, {super.key, required this.children});
  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Material(
          color: Cores.painel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Cores.linha)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Rotulo(titulo, cor: Cores.ciano),
              ...children,
            ]),
          ),
        ),
      );
}

String kindLabel(MediaKind k) => k.label;

/// Android: escolher por onde o som sai (telefone, adaptador, HDMI do telão…).
Future<void> escolherSaidaSom(BuildContext context, AppState app) async {
  final som = SomAndroid.instancia;
  await som.carregarSaidas();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => ListenableBuilder(
      listenable: som,
      builder: (c, _) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Saída de som', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            for (final s in som.saidas)
              ListTile(
                leading: Icon(
                  som.escolhida == s.tipo ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: som.escolhida == s.tipo ? Cores.ciano : Cores.textoFraco,
                ),
                title: Text(s.tipo == 0 ? '${s.nome} · padrão' : s.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: s.produto.isEmpty ? null : Text(s.produto, style: const TextStyle(color: Cores.textoFraco, fontSize: 12)),
                onTap: () {
                  app.escolherSaida(s.tipo);
                  Navigator.pop(c);
                },
              ),
            if (!som.escolhidaPresente)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text('A saída escolhida não está conectada: o som está saindo pelo telefone.',
                    style: TextStyle(color: Cores.laranja, fontSize: 12)),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Vale para trilhas e vídeos. Se a saída escolhida for desconectada, o som volta para o telefone.',
                  style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            ),
          ]),
        ),
      ),
    ),
  );
}
