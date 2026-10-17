import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import '../state.dart';
import '../theme.dart';
import 'editor_screen.dart';
import 'transfer.dart';
import 'widgets.dart';

/// Shows salvos: abrir, criar, editar, exportar, importar e excluir.
class ShowsScreen extends StatelessWidget {
  const ShowsScreen({super.key, required this.app});
  final AppState app;

  void _abrir(BuildContext context, Show s) {
    app.openShow(s.id);
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _editar(BuildContext context, Show? s) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EditorScreen(app: app, show: s)));

  Future<void> _duplicar(BuildContext context, Show s) async {
    aviso(context, 'Duplicando…');
    try {
      final c = await app.duplicateShow(s);
      if (context.mounted) aviso(context, '“${c.name}” criado. Está logo abaixo do original.');
    } catch (e) {
      if (context.mounted) aviso(context, 'Não consegui duplicar: $e');
    }
  }

  Future<void> _excluir(BuildContext context, Show s) async {
    final ok = await confirmar(
      context,
      'Excluir “${s.name}”?',
      'O show, o log e as mídias copiadas para o app são apagados. Não dá para desfazer.',
      ok: 'Excluir',
      perigo: true,
    );
    if (ok) app.deleteShow(s.id);
  }

  @override
  Widget build(BuildContext context) {
    final podeVoltar = Navigator.of(context).canPop();
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final lista = app.shows;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: podeVoltar,
            title: const Text('Shows'),
            actions: [
              Btn('Importar', compacto: true, onTap: () => importarShow(context, app)),
              const SizedBox(width: 8),
              Btn('Novo show', compacto: true, tipo: BtnTipo.primario, onTap: () => _editar(context, null)),
              const SizedBox(width: 12),
            ],
          ),
          body: lista.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Nenhum show salvo ainda.', style: TextStyle(color: Cores.textoFraco)),
                    const SizedBox(height: 12),
                    Btn('Novo show', tipo: BtnTipo.primario, onTap: () => _editar(context, null)),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = lista[i];
                    final emUso = app.active?.id == s.id;
                    final sub = [
                      if (s.date != null) s.date!,
                      if (s.start != null) s.start!,
                      if (s.lineup.isNotEmpty) '${s.lineup.length} na fila',
                      '${s.usedCount()}/${s.count} mídias',
                    ].join(' · ');
                    return Material(
                      color: Cores.painel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: emUso ? Cores.ciano : Cores.linha),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        title: Text(s.name.isEmpty ? '(sem nome)' : s.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        subtitle: Text(sub, style: const TextStyle(color: Cores.textoFraco, fontSize: 13)),
                        onTap: () => _abrir(context, s),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (emUso)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Text('EM USO',
                                  style: TextStyle(color: Cores.ciano, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2)),
                            ),
                          PopupMenuButton<String>(
                            color: Cores.painel2,
                            onSelected: (v) {
                              switch (v) {
                                case 'abrir':
                                  _abrir(context, s);
                                case 'editar':
                                  _editar(context, s);
                                case 'duplicar':
                                  _duplicar(context, s);
                                case 'exportar':
                                  exportarShow(context, app, s);
                                case 'completo':
                                  exportarShow(context, app, s, completo: true);
                                case 'excluir':
                                  _excluir(context, s);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'abrir', child: Text('Abrir')),
                              PopupMenuItem(value: 'editar', child: Text('Editar')),
                              PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                              PopupMenuItem(value: 'exportar', child: Text('Exportar show')),
                              PopupMenuItem(value: 'completo', child: Text('Exportar show completo')),
                              PopupMenuItem(value: 'excluir', child: Text('Excluir', style: TextStyle(color: Cores.vermelho))),
                            ],
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
