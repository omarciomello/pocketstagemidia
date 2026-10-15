import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../media/backend.dart';
import '../state.dart';
import '../theme.dart';
import 'editor_screen.dart';
import 'widgets.dart';

class CueEditResult {
  const CueEditResult.saved(Cue this.cue) : removed = false;
  const CueEditResult.removed()
      : cue = null,
        removed = true;
  final Cue? cue;
  final bool removed;
}

/// Ajustes de uma mídia: básicos e, em "Avançado", som, disparo, telão e botão.
class CueEditor extends StatefulWidget {
  const CueEditor({super.key, required this.app, required this.show, required this.index, required this.cue, required this.isNew});

  final AppState app;
  final Show show;
  final int index;
  final Cue cue;
  final bool isNew;

  @override
  State<CueEditor> createState() => _CueEditorState();
}

class _CueEditorState extends State<CueEditor> {
  late Cue c = widget.cue;
  late final _texto = TextEditingController(text: c.text);
  late final _nome = TextEditingController(text: c.name);
  late final _ini = TextEditingController(text: fmtTempo(c.startSec));
  late final _fim = TextEditingController(text: fmtTempo(c.endSec));
  late bool _fadeProprio = c.fadeInSec != null || c.fadeOutSec != null;
  late final _fin = TextEditingController(text: numTxt(c.fadeInSec ?? widget.app.settings.fadeInSec));
  late final _fout = TextEditingController(text: numTxt(c.fadeOutSec ?? widget.app.settings.fadeOutSec));
  late final _rep = TextEditingController(text: c.repeat > 0 ? '${c.repeat}' : '');
  late final _espera = TextEditingController(text: c.preWaitSec > 0 ? numTxt(c.preWaitSec) : '');
  late final _auto = TextEditingController(text: c.autoStopSec > 0 ? numTxt(c.autoStopSec) : '');
  late final _segSec = TextEditingController(text: c.followSec > 0 ? numTxt(c.followSec) : '');
  late final _transSec = TextEditingController(text: numTxt(c.transSec));
  late final _nota = TextEditingController(text: c.note);
  late String _modoParar = c.stopAllOnGo ? 'tudo' : (c.stopCols.isNotEmpty ? 'colunas' : 'coluna');
  final Preview _preview = Preview();
  bool _ouvindo = false;

  bool get _temSom => c.kind == MediaKind.audio || c.kind == MediaKind.video;
  bool get _visual => c.kind != MediaKind.audio;
  bool get _ehTexto => c.kind == MediaKind.text;
  int get _coluna => widget.index % cols;

  @override
  void dispose() {
    _preview.stop();
    for (final t in [_texto, _nome, _ini, _fim, _fin, _fout, _rep, _espera, _auto, _segSec, _transSec, _nota]) {
      t.dispose();
    }
    super.dispose();
  }

  void _up(Cue n) => setState(() => c = n);

  List<(int, Cue)> _outras({bool Function(Cue)? filtro}) => [
        for (var k = 0; k < widget.show.count; k++)
          if (k != widget.index && widget.show.cells[k] != null && (filtro == null || filtro(widget.show.cells[k]!)))
            (k, widget.show.cells[k]!),
      ];

  Future<void> _escolherFica() async {
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quando a trilha acabar', style: TextStyle(fontWeight: FontWeight.w800)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A imagem fica no telão', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Padrão. Bom para vinheta de entrada.', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('A imagem sai junto com a trilha', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    _up(c.copyWith(visualStays: v ?? true));
  }

  Future<void> _ouvir() async {
    if (_ouvindo) {
      await _preview.stop();
      setState(() => _ouvindo = false);
      return;
    }
    setState(() => _ouvindo = true);
    try {
      await _preview.play(PsShow.localPath(c.uri), gain: c.volume, startSec: parseTempo(_ini.text));
    } catch (_) {
      if (mounted) {
        setState(() => _ouvindo = false);
        aviso(context, 'Não consegui tocar este arquivo.');
      }
    }
  }

  Future<void> _trocarArquivo() async {
    final n = await escolherArquivo(widget.app, widget.show.id, c);
    if (n == null) return;
    await _preview.stop();
    setState(() {
      c = n;
      _ouvindo = false;
      if (_ehTexto) _nome.text = n.name;
    });
  }

  Future<void> _tecla() async {
    final k = await capturarTecla(context);
    if (k == null || !mounted) return;
    final conflito = keyConflict(k, widget.app.settings, widget.show, exceptCueId: c.id);
    if (conflito != null) {
      aviso(context, 'A tecla ${keyLabel(k)} já é de “$conflito”. Atalho geral tem prioridade sobre o da mídia.');
    }
    _up(c.copyWith(hotkey: k));
  }

  void _salvar() {
    var nome = _nome.text.trim();
    final texto = _texto.text.trim();
    if (_ehTexto && texto.isEmpty) {
      aviso(context, 'Escreva o texto que vai aparecer no telão.');
      return;
    }
    if (nome.isEmpty) nome = _ehTexto ? texto.split('\n').first : 'Sem nome';
    final rep = int.tryParse(_rep.text.trim()) ?? 0;
    final out = c.copyWith(
      name: nome,
      text: _ehTexto ? texto : c.text,
      startSec: _temSom ? parseTempo(_ini.text) : 0,
      endSec: _temSom ? parseTempo(_fim.text) : 0,
      fadeInSec: _temSom && _fadeProprio ? (parseNum(_fin.text) ?? widget.app.settings.fadeInSec).clamp(0, 30).toDouble() : null,
      fadeOutSec: _temSom && _fadeProprio ? (parseNum(_fout.text) ?? widget.app.settings.fadeOutSec).clamp(0, 30).toDouble() : null,
      repeat: rep < 0 ? 0 : rep,
      preWaitSec: (parseNum(_espera.text) ?? 0).clamp(0, 3600).toDouble(),
      autoStopSec: (parseNum(_auto.text) ?? 0).clamp(0, 36000).toDouble(),
      followSec: (parseNum(_segSec.text) ?? 0).clamp(0, 3600).toDouble(),
      transSec: parseNum(_transSec.text)?.clamp(0, 10).toDouble(),
      note: _nota.text.trim(),
      stopAllOnGo: _modoParar == 'tudo',
      stopCols: _modoParar == 'colunas' ? c.stopCols : const [],
    );
    Navigator.pop(context, CueEditResult.saved(out));
  }

  Future<void> _remover() async {
    if (await confirmar(context, 'Remover “${c.name}”?', 'O botão fica vazio.', ok: 'Remover', perigo: true)) {
      if (mounted) Navigator.pop(context, const CueEditResult.removed());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.app.settings;
    final db = linToDb(c.volume).clamp(-60.0, 6.0);
    final visuais = _outras(filtro: (x) => x.kind == MediaKind.image || x.kind == MediaKind.text);
    final outras = _outras();
    final fila = widget.show.lineup;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(widget.isNew ? 'Nova mídia' : 'Ajustes da mídia'),
        actions: [
          Btn(widget.isNew ? 'Adicionar' : 'Salvar', tipo: BtnTipo.primario, compacto: true, onTap: _salvar),
          const SizedBox(width: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
            if (!widget.isNew) Btn('Remover', tipo: BtnTipo.perigo, onTap: _remover),
            if (!widget.isNew) Btn(_ehTexto ? 'Trocar por arquivo' : 'Trocar arquivo', onTap: _trocarArquivo),
            if (_temSom) Btn(_ouvindo ? 'Parar' : 'Ouvir', tipo: _ouvindo ? BtnTipo.ligado : BtnTipo.normal, onTap: _ouvir),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 24), children: [
        Text(c.kind.label,
            style: TextStyle(color: _visual ? Cores.lilas : Cores.textoFraco, fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: 12)),
        const SizedBox(height: 10),
        if (_ehTexto) ...[
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Texto no telão', hintText: 'Ex.: Caio Vidal\nstand-up · 10 min'),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _nome,
          maxLength: 40,
          decoration: InputDecoration(labelText: 'Nome no botão', hintText: _ehTexto ? 'Usa a 1ª linha do texto' : null),
        ),
        if (_temSom) ...[
          Row(children: [
            const Text('Ganho', style: TextStyle(color: Cores.textoFraco)),
            Expanded(
              child: Slider(
                min: -60,
                max: 6,
                divisions: 132,
                value: db,
                onChanged: (v) {
                  final g = dbToLin(v);
                  _up(c.copyWith(volume: g));
                  _preview.setGain(g);
                },
              ),
            ),
            SizedBox(width: 72, child: Text(dbLabel(db), style: mono(size: 13), textAlign: TextAlign.right)),
          ]),
          Chave('Repetir', valor: c.loop, onChanged: (v) => _up(c.copyWith(loop: v))),
        ],
        Chave(c.kind == MediaKind.audio ? 'Início suave' : 'Entra com fade', valor: c.fadeIn, onChanged: (v) => _up(c.copyWith(fadeIn: v))),
        Chave(c.kind == MediaKind.audio ? 'Fim suave' : 'Sai com fade', valor: c.fadeOut, onChanged: (v) => _up(c.copyWith(fadeOut: v))),
        if (_ehTexto) ...[
          const Rotulo('Posição no telão'),
          Escolha<TextPos>(
            opcoes: [for (final p in TextPos.values) (p, p.label)],
            valor: c.textPos,
            onChanged: (v) => _up(c.copyWith(textPos: v)),
          ),
          const Rotulo('Tamanho'),
          Escolha<TextSize>(
            opcoes: [for (final t in TextSize.values) (t, t.label)],
            valor: c.textSize,
            onChanged: (v) => _up(c.copyWith(textSize: v)),
          ),
        ],
        if (_visual && !_ehTexto) ...[
          const Rotulo('No telão'),
          Escolha<Fit>(opcoes: [for (final f in Fit.values) (f, f.label)], valor: c.fit, onChanged: (v) => _up(c.copyWith(fit: v))),
          if (c.kind == MediaKind.video)
            Chave('Ao terminar, ficar fixo no último quadro', valor: c.hold, onChanged: (v) => _up(c.copyWith(hold: v))),
        ],
        if (c.kind == MediaKind.audio) ...[
          const Rotulo('Mostrar no telão junto'),
          if (visuais.isEmpty)
            const Text('Adicione uma imagem ou um texto no show para poder ligar a esta trilha.',
                style: TextStyle(color: Cores.textoFraco, fontSize: 13))
          else ...[
            Escolha<String?>(
              opcoes: [(null, 'Nada'), for (final (_, x) in visuais) (x.id, '${x.name} (${x.kind.label.toLowerCase()})')],
              valor: c.visualId,
              onChanged: (v) {
                _up(c.copyWith(visualId: v));
                if (v != null) _escolherFica();
              },
            ),
            if (c.visualId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      'Quando a trilha acabar, ${c.visualStays ? 'a imagem fica no telão' : 'a imagem sai junto'}.',
                      style: const TextStyle(color: Cores.textoFraco, fontSize: 13),
                    ),
                  ),
                  Btn('Mudar', compacto: true, onTap: _escolherFica),
                ]),
              ),
          ],
        ],
        if (fila.isNotEmpty) ...[
          const Rotulo('Ligar à fila'),
          Escolha<String?>(
            opcoes: [(null, 'Nada'), for (final l in fila) (l.id, l.name.isEmpty ? '(sem nome)' : l.name)],
            valor: c.linkId,
            onChanged: (v) => _up(c.copyWith(linkId: v)),
          ),
          const Rotulo('Papel'),
          Escolha<Role>(opcoes: [for (final r in Role.values) (r, r.label)], valor: c.role, onChanged: (v) => _up(c.copyWith(role: v))),
        ],
        const SizedBox(height: 10),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: !widget.isNew,
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Avançado', style: TextStyle(fontWeight: FontWeight.w800)),
            children: [
              if (_temSom) _secaoSom(s),
              _secaoDisparo(outras),
              if (_visual) _secaoTelao(s),
              _secaoBotao(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Fades gerais: som ${numTxt(s.fadeInSec)} s / ${numTxt(s.fadeOutSec)} s, telão ${numTxt(s.visualFadeSec)} s (Menu › Ajustes).',
          style: const TextStyle(color: Cores.textoFraco, fontSize: 12),
        ),
      ]),
    );
  }

  Widget _secaoSom(Settings s) {
    return Secao('Som', children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        CampoNum(label: 'Início', controller: _ini, dica: '0:00'),
        CampoNum(label: 'Fim', controller: _fim, dica: 'até o fim'),
      ]),
      Chave('Fade próprio', valor: _fadeProprio, onChanged: (v) => setState(() => _fadeProprio = v)),
      if (_fadeProprio)
        Wrap(spacing: 12, runSpacing: 12, children: [
          CampoNum(label: 'Entrada (s)', controller: _fin),
          CampoNum(label: 'Saída (s)', controller: _fout),
        ]),
      const Rotulo('Curva'),
      Escolha<FadeCurve?>(
        opcoes: [(null, 'Padrão'), for (final k in FadeCurve.values) (k, k.label)],
        valor: c.fadeCurve,
        onChanged: (v) => _up(c.copyWith(fadeCurve: v)),
      ),
      Row(children: [
        const Text('Pan', style: TextStyle(color: Cores.textoFraco)),
        Expanded(
          child: Slider(min: -1, max: 1, divisions: 40, value: c.pan, onChanged: (v) => _up(c.copyWith(pan: v))),
        ),
        SizedBox(width: 72, child: Text(panLabel(c.pan), style: mono(size: 13), textAlign: TextAlign.right)),
      ]),
      CampoNum(label: 'Repetir quantas vezes', controller: _rep, dica: 'sem fim', largura: 200),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('vale com Repetir ligado', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
      ),
      const Rotulo('Ducking'),
      Escolha<double>(
        opcoes: [for (final v in const [0.0, -3.0, -6.0, -10.0, -15.0, -20.0, -30.0]) (v, v == 0 ? 'Desligado' : '−${(-v).toInt()} dB')],
        valor: c.duckDb,
        onChanged: (v) => _up(c.copyWith(duckDb: v)),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('Enquanto esta toca, as outras colunas abaixam.', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
      ),
      if (c.kind == MediaKind.video) Chave('Vídeo sem som', valor: c.muted, onChanged: (v) => _up(c.copyWith(muted: v))),
    ]);
  }

  Widget _secaoDisparo(List<(int, Cue)> outras) {
    return Secao('Disparo', children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        CampoNum(label: 'Pré-espera (s)', controller: _espera, dica: '0', largura: 150),
        CampoNum(
          label: _temSom ? 'Parar sozinha após (s)' : 'Duração na tela (s)',
          controller: _auto,
          dica: 'sem limite',
          largura: 200,
        ),
      ]),
      const Rotulo('Seguir com'),
      DropdownButtonFormField<String?>(
        value: outras.any((x) => x.$2.id == c.followId) ? c.followId : null,
        isExpanded: true,
        dropdownColor: Cores.painel2,
        items: [
          const DropdownMenuItem(value: null, child: Text('Nada')),
          for (final (_, x) in outras) DropdownMenuItem(value: x.id, child: Text('${x.name} (${x.kind.label.toLowerCase()})')),
        ],
        onChanged: (v) => _up(c.copyWith(followId: v)),
      ),
      if (c.followId != null) ...[
        const SizedBox(height: 8),
        Escolha<FollowMode>(
          opcoes: [for (final m in FollowMode.values) (m, m.label)],
          valor: c.followMode,
          onChanged: (v) => _up(c.copyWith(followMode: v)),
        ),
        if (c.followMode == FollowMode.tempo) ...[
          const SizedBox(height: 10),
          CampoNum(label: 'Segundos', controller: _segSec),
        ],
      ],
      const Rotulo('Ao tocar, parar'),
      Escolha<String>(
        opcoes: const [('coluna', 'Só a própria coluna'), ('colunas', 'Também as colunas'), ('tudo', 'Tudo')],
        valor: _modoParar,
        onChanged: (v) => setState(() => _modoParar = v),
      ),
      if (_modoParar == 'colunas')
        Wrap(spacing: 8, children: [
          for (var k = 0; k < cols; k++)
            if (k != _coluna)
              FilterChip(
                label: Text('Coluna ${k + 1}'),
                selected: c.stopCols.contains(k),
                onSelected: (on) {
                  final l = [...c.stopCols.where((x) => x != k), if (on) k]..sort();
                  _up(c.copyWith(stopCols: l));
                },
              ),
        ]),
      Chave('Travar depois de tocar',
          valor: c.lockAfter,
          dica: 'Só toca de novo depois de Menu › Liberar deixas travadas.',
          onChanged: (v) => _up(c.copyWith(lockAfter: v))),
    ]);
  }

  Widget _secaoTelao(Settings s) {
    return Secao('Telão', children: [
      const Rotulo('Transição'),
      Escolha<Transition?>(
        opcoes: [(null, 'Padrão'), for (final t in Transition.values) (t, t.label)],
        valor: c.transition,
        onChanged: (v) => _up(c.copyWith(transition: v)),
      ),
      const SizedBox(height: 12),
      CampoNum(label: 'Tempo da transição (s)', controller: _transSec, dica: numTxt(s.visualFadeSec), largura: 200),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('vazio usa o geral', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
      ),
    ]);
  }

  Widget _secaoBotao() {
    return Secao('Botão', children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (hex, nome) in coresBotao)
          Tooltip(
            message: nome,
            child: InkWell(
              onTap: () => _up(c.copyWith(color: hex)),
              customBorder: const CircleBorder(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: corDe(hex) ?? Colors.transparent,
                  border: Border.all(color: c.color.toUpperCase() == hex ? Cores.texto : Cores.linha, width: 2),
                ),
                alignment: Alignment.center,
                child: hex.isEmpty ? const Text('—', style: TextStyle(color: Cores.textoFraco)) : null,
              ),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _nota,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Nota', hintText: 'Ex.: entra depois da fala do Caio'),
      ),
      Row(children: [
        const Text('Atalho', style: TextStyle(color: Cores.textoFraco)),
        const SizedBox(width: 12),
        Btn(c.hotkey.isEmpty ? 'Definir tecla' : keyLabel(c.hotkey), onTap: _tecla),
        if (c.hotkey.isNotEmpty) ...[
          const SizedBox(width: 8),
          Btn('Limpar', onTap: () => _up(c.copyWith(hotkey: ''))),
        ],
      ]),
    ]);
  }
}
