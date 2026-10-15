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
  bool get _novo => widget.show == null;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _set(Show s) => setState(() {
        _draft = s;
        _mudou = true;
      });

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

  Future<void> _tocarCelula(int i) async {
    final atual = _draft.cells[i];
    if (atual != null) return _editar(i, atual, novo: false);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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

  void _salvar() {
    final nome = _nome.text.trim();
    final s = _draft.copyWith(name: nome.isEmpty ? 'Show sem nome' : nome);
    widget.app.saveShow(s);
    if (!widget.app.hasActive) widget.app.openShow(s.id);
    _mudou = false;
    aviso(context, 'Show salvo.');
    Navigator.of(context).pop();
  }

  Future<void> _cancelar() async {
    if (_mudou && !await confirmar(context, 'Descartar mudanças?', 'O que você mudou neste show não será salvo.', ok: 'Descartar', perigo: true)) {
      return;
    }
    widget.app.discardEdit(_draft);
    _mudou = false;
    if (mounted) Navigator.of(context).pop();
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
      canPop: !_mudou,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelar();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _cancelar),
          title: Text(_novo ? 'Novo show' : 'Editar show'),
          actions: [
            Btn('Salvar', tipo: BtnTipo.primario, compacto: true, onTap: _salvar),
            const SizedBox(width: 12),
          ],
        ),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          TextField(
            controller: _nome,
            maxLength: 60,
            onChanged: (_) => _mudou = true,
            decoration: const InputDecoration(labelText: 'Nome do show', hintText: 'Ex.: Estreia sexta'),
          ),
          const Rotulo('Quantidade de botões'),
          Escolha<int>(
            opcoes: [for (final n in allowedCounts) (n, n.toString().padLeft(2, '0'))],
            valor: d.count,
            onChanged: _quantidade,
          ),
          const SizedBox(height: 16),
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
            'Toque num botão vazio para escolher áudio, vídeo, imagem ou texto. Cada coluna toca uma mídia por vez; '
            'colunas diferentes tocam juntas. No show, o ▶ de cada linha para o resto e toca a linha inteira.',
            style: TextStyle(color: Cores.textoFraco, fontSize: 13, height: 1.45),
          ),
        ]),
      ),
    );
  }

  Widget _celula(int i) {
    final c = _draft.cells[i];
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
          Padding(
            padding: const EdgeInsets.all(9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
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
        ]),
      ),
    );
  }
}
