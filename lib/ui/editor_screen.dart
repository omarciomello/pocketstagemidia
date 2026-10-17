import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../state.dart';
import '../theme.dart';
import 'cue_editor.dart';
import 'widgets.dart';

const _videoExt = {'mp4', 'm4v', 'mov', 'mkv', 'webm', '3gp', 'ts', 'ogv', 'avi'};
const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'avif', 'heic'};

MediaKind kindDoArquivo(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  final ext = dot > 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (_videoExt.contains(ext)) return MediaKind.video;
  if (_imageExt.contains(ext)) return MediaKind.image;
  return MediaKind.audio;
}

String nomeDoArquivo(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Escolhe um arquivo do aparelho e prepara a mídia (copia no celular).
Future<Cue?> escolherArquivo(AppState app, String showId, Cue? atual) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, dialogTitle: 'Escolher mídia');
  final src = res?.files.single.path;
  if (src == null) return null;
  final id = atual?.id ?? newId();
  final kind = kindDoArquivo(src);
  final uri = app.prepareMedia(showId, id, src);
  final nome = nomeDoArquivo(src);
  if (atual != null) return atual.copyWith(uri: uri, kind: kind, name: atual.kind == MediaKind.text ? nome : atual.name);
  return Cue(id: id, uri: uri, name: nome, kind: kind, fadeIn: kind != MediaKind.audio);
}

/// Criar ou editar um show: nome, quantidade de botões e as mídias da grade.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.app, this.show});
  final AppState app;
  final Show? show;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Show _draft = widget.show ?? Show.empty();
  late final TextEditingController _nome = TextEditingController(text: _draft.name);
  bool _mudou = false;
  bool _salvouAlgo = false;
  Timer? _timer;
  bool get _novo => widget.show == null;

  /// Mídia copiada ou recortada, à espera de "Colar".
  Cue? _area;

  /// Botão de onde a mídia foi recortada (colar move em vez de copiar).
  int? _recorteDe;

  @override
  void dispose() {
    if (_timer?.isActive ?? false) _salvarAgora();
    _timer?.cancel();
    _nome.dispose();
    super.dispose();
  }

  void _set(Show s) {
    setState(() => _draft = s);
    _agendar();
  }

  /// Salvamento automático: meio segundo depois da última mudança.
  void _agendar() {
    _mudou = true;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 500), _salvarAgora);
  }

  void _salvarAgora() {
    _timer?.cancel();
    if (!_mudou) return;
    final nome = _nome.text.trim();
    widget.app.saveShow(_draft.copyWith(name: nome.isEmpty ? 'Show sem nome' : nome));
    _mudou = false;
    _salvouAlgo = true;
    if (mounted) setState(() {});
  }

  void _setCell(int i, Cue? c) {
    final cells = List<Cue?>.of(_draft.cells);
    cells[i] = c;
    _set(_draft.copyWith(cells: cells));
  }

  void _quantidade(int n) {
    final perdidas = n < _draft.count ? _draft.cells.sublist(n, _draft.count).where((c) => c != null).length : 0;
    _set(_draft.copyWith(count: n));
    if (perdidas > 0) {
      aviso(context, '$perdidas mídia(s) ficaram fora da grade. Voltam se você aumentar a quantidade.');
    }
  }

  /// Arrastar: move; se o destino estiver ocupado, os dois trocam de lugar.
  void _mover(int de, int para) {
    final ocupado = _draft.cells[para] != null;
    _set(_draft.moverCelula(de, para));
    aviso(context, ocupado ? 'Mídias trocadas de lugar.' : 'Mídia movida.');
  }

  void _copiar(int i, {bool recortar = false}) {
    final c = _draft.cells[i];
    if (c == null) return;
    setState(() {
      _area = c;
      _recorteDe = recortar ? i : null;
    });
  }

  Future<void> _colar(int para) async {
    final area = _area;
    if (area == null) return;
    if (_recorteDe != null) {
      // recortar + colar = mover (a mídia mantém o id e as ligações)
      final de = _draft.cells.indexWhere((x) => x?.id == area.id);
      if (de >= 0) _set(_draft.moverCelula(de, para));
      setState(() {
        _area = null;
        _recorteDe = null;
      });
      return;
    }
    final atual = _draft.cells[para];
    if (atual != null &&
        !await confirmar(context, 'Substituir “${atual.name}”?', 'A cópia de “${area.name}” entra no lugar.', ok: 'Substituir')) {
      return;
    }
    _set(_draft.colarCue(area, para));
  }

  Future<void> _menuCelula(int i) async {
    final c = _draft.cells[i];
    if (c == null) return;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.tune), title: const Text('Ajustes da mídia'), onTap: () => Navigator.pop(ctx, 'editar')),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copiar'),
            subtitle: const Text('Depois toque em outro botão e escolha Colar', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            onTap: () => Navigator.pop(ctx, 'copiar'),
          ),
          ListTile(
            leading: const Icon(Icons.content_cut),
            title: const Text('Recortar (mover)'),
            subtitle: const Text('Ou segure e arraste o botão', style: TextStyle(color: Cores.textoFraco, fontSize: 12)),
            onTap: () => Navigator.pop(ctx, 'recortar'),
          ),
          if (_area != null && _area!.id != c.id)
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text('Colar “${_area!.name}” aqui'),
              onTap: () => Navigator.pop(ctx, 'colar'),
            ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (escolha) {
      case 'editar':
        await _editar(i, c, novo: false);
      case 'copiar':
        _copiar(i);
      case 'recortar':
        _copiar(i, recortar: true);
      case 'colar':
        await _colar(i);
    }
  }

  Future<void> _tocarCelula(int i) async {
    final atual = _draft.cells[i];
    if (atual != null) return _menuCelula(i);
    final area = _area;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (area != null)
            ListTile(
              leading: const Icon(Icons.content_paste, color: Cores.ciano),
              title: Text('Colar “${area.name}”'),
              subtitle: Text(_recorteDe != null ? 'MOVE PARA ESTE BOTÃO' : 'CÓPIA COM OS MESMOS AJUSTES',
                  style: const TextStyle(color: Cores.textoFraco, fontSize: 11, letterSpacing: 1)),
              onTap: () => Navigator.pop(c, 'colar'),
            ),
          ListTile(
            leading: const Icon(Icons.audio_file_outlined),
            title: const Text('Arquivo do aparelho…'),
            subtitle: const Text('ÁUDIO · VÍDEO · IMAGEM', style: TextStyle(color: Cores.textoFraco, fontSize: 11, letterSpacing: 1)),
            onTap: () => Navigator.pop(c, 'arquivo'),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Texto no telão'),
            subtitle: const Text('TEXTO', style: TextStyle(color: Cores.textoFraco, fontSize: 11, letterSpacing: 1)),
            onTap: () => Navigator.pop(c, 'texto'),
          ),
        ]),
      ),
    );
    if (!mounted || escolha == null) return;
    if (escolha == 'colar') return _colar(i);
    if (escolha == 'texto') {
      final s = widget.app.settings;
      return _editar(
        i,
        Cue(id: newId(), uri: '', name: '', kind: MediaKind.text, textPos: s.textPos, textSize: s.textSize, fadeIn: true),
        novo: true,
      );
    }
    final c = await escolherArquivo(widget.app, _draft.id, null);
    if (c != null && mounted) await _editar(i, c, novo: true);
  }

  Future<void> _editar(int i, Cue cue, {required bool novo}) async {
    final r = await Navigator.of(context).push<CueEditResult>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CueEditor(app: widget.app, show: _draft, index: i, cue: cue, isNew: novo),
    ));
    if (r == null || !mounted) return;
    _setCell(i, r.removed ? null : r.cue);
  }

  /// Sair do editor: tudo já está salvo; um show novo sem nada fica de fora.
  void _sair() {
    _salvarAgora();
    if (_novo && !_salvouAlgo) {
      widget.app.discardEdit(_draft);
    } else if (!widget.app.hasActive) {
      widget.app.openShow(_draft.id);
    }
    Navigator.of(context).pop();
  }

  List<String> _tags(Cue c) {
    final t = <String>[c.kind.label];
    if (c.kind == MediaKind.audio || c.kind == MediaKind.video) t.add('${(c.volume * 100).round()}%');
    if (c.visualId != null) t.add('+ IMAGEM');
    if (c.startSec > 0 || c.endSec > 0) t.add('TRECHO');
    if (c.preWaitSec > 0) t.add('ESPERA');
    if (c.followId != null) t.add('SEGUE');
    if (c.duckDb < 0) t.add('DUCK');
    if (c.autoStopSec > 0) t.add('AUTO');
    if (c.lockAfter) t.add('TRAVA');
    if (c.hotkey.isNotEmpty) t.add('[${keyLabel(c.hotkey)}]');
    if (c.loop) t.add('REPETE');
    if (c.fadeIn) t.add('IN');
    if (c.fadeOut) t.add('OUT');
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _sair();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _sair),
          title: Text(_novo ? 'Novo show' : 'Editar show'),
          actions: [
            Text(_mudou ? 'salvando…' : (_salvouAlgo ? 'salvo' : ''),
                style: const TextStyle(color: Cores.textoFraco, fontSize: 12)),
            const SizedBox(width: 10),
            Btn('Pronto', tipo: BtnTipo.primario, compacto: true, onTap: _sair),
            const SizedBox(width: 12),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          TextField(
            controller: _nome,
            maxLength: 60,
            onChanged: (_) => _agendar(),
            decoration: const InputDecoration(labelText: 'Nome do show', hintText: 'Ex.: Estreia sexta'),
          ),
          const Rotulo('Quantidade de botões'),
          Escolha<int>(
            opcoes: [for (final n in allowedCounts) (n, n.toString().padLeft(2, '0'))],
            valor: d.count,
            onChanged: _quantidade,
          ),
          const SizedBox(height: 16),
          if (_area != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
              decoration: BoxDecoration(
                color: Cores.cianoFundo,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Cores.ciano),
              ),
              child: Row(children: [
                const Icon(Icons.content_paste, size: 18, color: Cores.ciano),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_recorteDe != null ? 'Recortada' : 'Copiada'}: “${_area!.name}”. Toque no botão de destino e escolha Colar.',
                    style: const TextStyle(color: Cores.ciano, fontWeight: FontWeight.w600),
                  ),
                ),
                Btn('Cancelar', compacto: true, onTap: () => setState(() {
                      _area = null;
                      _recorteDe = null;
                    })),
              ]),
            ),
          for (var r = 0; r < d.rows; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 92,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: 10),
                    Expanded(child: _celula(r * cols + c)),
                  ],
                ]),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Toque num botão vazio para escolher áudio, vídeo, imagem ou texto. Toque num botão preenchido para ajustar, '
            'copiar ou recortar; segure e arraste para mover (num botão ocupado, os dois trocam). Cada coluna toca uma mídia por vez; '
            'colunas diferentes tocam juntas. No show, o botão de tocar a linha, à esquerda, para o resto e toca a linha inteira.',
            style: TextStyle(color: Cores.textoFraco, fontSize: 13, height: 1.45),
          ),
        ]),
      ),
    );
  }

  Widget _celula(int i) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != i,
      onAcceptWithDetails: (d) => _mover(d.data, i),
      builder: (context, candidatos, _) {
        final alvo = candidatos.isNotEmpty;
        final c = _draft.cells[i];
        Widget w = _celulaVisual(i);
        if (c != null) {
          w = LayoutBuilder(
            builder: (context, box) => LongPressDraggable<int>(
              data: i,
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: .85,
                  child: SizedBox(width: box.maxWidth, height: box.maxHeight, child: _celulaVisual(i)),
                ),
              ),
              childWhenDragging: Opacity(opacity: .35, child: w),
              child: w,
            ),
          );
        }
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: alvo ? Border.all(color: Cores.ciano, width: 2) : null,
          ),
          child: w,
        );
      },
    );
  }

  Widget _celulaVisual(int i) {
    final c = _draft.cells[i];
    final recortada = _recorteDe != null && _area != null && c?.id == _area!.id;
    if (c == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tocarCelula(i),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Cores.linha),
            color: const Color(0x05FFFFFF),
          ),
          alignment: Alignment.center,
          child: const Text('+ Mídia', style: TextStyle(color: Cores.textoFraco, fontWeight: FontWeight.w600)),
        ),
      );
    }
    final cor = corDe(c.color);
    final artista = _draft.lineupName(c.linkId);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _tocarCelula(i),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Cores.painel2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Cores.linha),
        ),
        child: Stack(children: [
          if (cor != null) Positioned(left: 0, right: 0, top: 0, height: 4, child: ColoredBox(color: cor)),
          if (recortada)
            const Positioned(right: 6, top: 6, child: Icon(Icons.content_cut, size: 14, color: Cores.ciano)),
          Padding(
            padding: const EdgeInsets.all(9),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxHeight: double.infinity,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(
                _tags(c).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w700,
                  color: c.kind == MediaKind.audio ? Cores.textoFraco : Cores.lilas,
                ),
              ),
              if (artista != null)
                Text(
                  artista + (c.role == Role.livre ? '' : ' · ${c.role.label.toLowerCase()}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Cores.textoFraco),
                ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
