import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../state.dart';
import '../theme.dart';
import 'widgets.dart';

/// Ajustes gerais: som, telão, mesa, segurança e atalhos.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.app});
  final AppState app;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Map<String, dynamic> _s = widget.app.settings.toJson();
  late Map<String, String> _keys = Map.of(widget.app.settings.keys);
  final Map<String, TextEditingController> _num = {};

  TextEditingController _ctl(String k) => _num.putIfAbsent(k, () => TextEditingController(text: numTxt((_s[k] as num).toDouble())));

  @override
  void dispose() {
    for (final c in _num.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String k, Object v) => setState(() => _s[k] = v);

  void _restaurar() {
    setState(() {
      _s = const Settings().toJson();
      _keys = Map.of(const Settings().keys);
      for (final e in _num.entries) {
        e.value.text = numTxt((_s[e.key] as num).toDouble());
      }
    });
    aviso(context, 'Padrões carregados. Toque em Salvar para aplicar.');
  }

  void _salvar() {
    final j = Map<String, dynamic>.of(_s);
    for (final e in _num.entries) {
      final v = parseNum(e.value.text);
      if (v != null) j[e.key] = v;
    }
    j['keys'] = _keys;
    final nv = Settings.fromJson(j);
    widget.app.setSettings(nv);
    final show = widget.app.active;
    String? choque;
    if (show != null) {
      for (final k in _keys.values) {
        if (show.cells.any((c) => c != null && c.hotkey == k)) choque = k;
      }
    }
    aviso(
      context,
      choque != null
          ? 'Ajustes salvos. A tecla ${keyLabel(choque)} também está numa mídia; o atalho geral tem prioridade.'
          : 'Ajustes salvos.',
    );
    Navigator.pop(context);
  }

  Future<void> _definirTecla(ShortcutAction g) async {
    final k = await capturarTecla(context);
    if (k == null) return;
    setState(() {
      _keys.removeWhere((a, v) => v == k && a != g.key);
      _keys[g.key] = k;
    });
  }

  @override
  Widget build(BuildContext context) {
    double n(String k) => (_s[k] as num).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [
          Btn('Restaurar padrões', compacto: true, onTap: _restaurar),
          const SizedBox(width: 8),
          Btn('Salvar', tipo: BtnTipo.primario, compacto: true, onTap: _salvar),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 0, 14, 24), children: [
        Secao('Som', children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            CampoNum(label: 'Início suave (s)', controller: _ctl('fadeIn'), largura: 150),
            CampoNum(label: 'Fim suave (s)', controller: _ctl('fadeOut'), largura: 150),
            CampoNum(label: 'Fade do Parar tudo (s)', controller: _ctl('stopAllFade'), largura: 190),
          ]),
          const Rotulo('Curva padrão'),
          Escolha<String>(
            opcoes: [for (final c in FadeCurve.values) (c.key, c.label)],
            valor: _s['fadeCurve'] as String,
            onChanged: (v) => _set('fadeCurve', v),
          ),
          Row(children: [
            const Text('Volume geral', style: TextStyle(color: Cores.textoFraco)),
            Expanded(
              child: Slider(min: -60, max: 0, divisions: 120, value: n('masterDb'), onChanged: (v) => _set('masterDb', v)),
            ),
            SizedBox(width: 72, child: Text(dbLabel(n('masterDb')), style: mono(size: 13), textAlign: TextAlign.right)),
          ]),
          const Rotulo('Tocar de novo no botão que está tocando'),
          Escolha<String>(
            opcoes: [for (final r in Retrigger.values) (r.key, r.label)],
            valor: _s['retrigger'] as String,
            onChanged: (v) => _set('retrigger', v),
          ),
          const SizedBox(height: 6),
          Chave(
            'Pausar congela as pré-esperas',
            valor: _s['pausePreWait'] as bool,
            dica: 'Ligado: a contagem para e continua no Retomar. Desligado: pausar cancela as pré-esperas.',
            onChanged: (v) => _set('pausePreWait', v),
          ),
        ]),
        Secao('Telão', children: [
          const Rotulo('Transição padrão'),
          Escolha<String>(
            opcoes: [for (final t in Transition.values) (t.key, t.label)],
            valor: _s['transition'] as String,
            onChanged: (v) => _set('transition', v),
          ),
          const SizedBox(height: 12),
          CampoNum(label: 'Tempo da transição (s)', controller: _ctl('visFade'), largura: 200),
          const Rotulo('Texto novo · posição'),
          Escolha<String>(
            opcoes: [for (final p in TextPos.values) (p.key, p.label)],
            valor: _s['textPos'] as String,
            onChanged: (v) => _set('textPos', v),
          ),
          const Rotulo('Texto novo · tamanho'),
          Escolha<String>(
            opcoes: [for (final t in TextSize.values) (t.key, t.label)],
            valor: _s['textSize'] as String,
            onChanged: (v) => _set('textSize', v),
          ),
        ]),
        Secao('Mesa', children: [
          const Rotulo('Texto dos botões'),
          Escolha<String>(
            opcoes: const [('P', 'Pequeno'), ('M', 'Médio'), ('G', 'Grande')],
            valor: _s['btnSize'] as String,
            onChanged: (v) => _set('btnSize', v),
          ),
          const Rotulo('Relógio das colunas'),
          Escolha<String>(
            opcoes: const [('restante', 'Tempo restante'), ('decorrido', 'Tempo decorrido')],
            valor: _s['clockMode'] as String,
            onChanged: (v) => _set('clockMode', v),
          ),
          const SizedBox(height: 12),
          CampoNum(label: 'Aviso de fim (s)', controller: _ctl('endWarnSec'), largura: 170),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('relógio pisca no fim · 0 desliga', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
          ),
          Chave('Mostrar o ▶ das linhas', valor: _s['showRowGo'] as bool, onChanged: (v) => _set('showRowGo', v)),
        ]),
        Secao('Segurança', children: [
          Chave('Confirmar antes de Parar tudo', valor: _s['confirmStopAll'] as bool, onChanged: (v) => _set('confirmStopAll', v)),
          Chave('Bloquear a mesa ao abrir um show', valor: _s['lockOnOpen'] as bool, onChanged: (v) => _set('lockOnOpen', v)),
          const SizedBox(height: 8),
          CampoNum(label: 'Segurar para desbloquear (s)', controller: _ctl('holdSec'), largura: 230),
          const SizedBox(height: 4),
          Chave('Pedir confirmação ao sair', valor: _s['confirmExit'] as bool, onChanged: (v) => _set('confirmExit', v)),
          Chave('Dica do modo avião ao abrir show', valor: _s['tipAirplane'] as bool, onChanged: (v) => _set('tipAirplane', v)),
        ]),
        Secao('Atalhos gerais (teclado ou pedal)', children: [
          for (final g in ShortcutAction.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(g.label)),
                Btn(_keys[g.key]?.isNotEmpty == true ? keyLabel(_keys[g.key]!) : 'Definir', onTap: () => _definirTecla(g)),
                if (_keys[g.key]?.isNotEmpty == true) ...[
                  const SizedBox(width: 6),
                  Btn('Limpar', onTap: () => setState(() => _keys.remove(g.key))),
                ],
              ]),
            ),
          const SizedBox(height: 6),
          const Text(
            'Atalhos gerais valem antes dos atalhos das mídias. Pedais Bluetooth costumam mandar PgUp/PgDn ou as setas.',
            style: TextStyle(color: Cores.textoFraco, fontSize: 12, height: 1.4),
          ),
        ]),
        const SizedBox(height: 14),
        const Text(
          'A tela fica sempre ligada com o app aberto: é obrigatório, não há ajuste.',
          style: TextStyle(color: Cores.textoFraco, fontSize: 12, height: 1.4),
        ),
      ]),
    );
  }
}
