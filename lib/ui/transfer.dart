import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';
import 'package:share_plus/share_plus.dart';

import '../state.dart';
import 'widgets.dart';

String _tamanho(int b) {
  if (b < 1024 * 1024) return '${(b / 1024).ceil()} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2).replaceAll('.', ',')} GB';
}

/// Exporta o show como .psshow: no celular abre o compartilhar; no computador, "Salvar como".
/// [completo] = com todas as mídias; sem ele, só a estrutura do show.
Future<void> exportarShow(BuildContext context, AppState app, Show s, {bool completo = false}) async {
  if (completo) {
    final tam = PsShow.mediaSize(s);
    final ok = await confirmar(
      context,
      'Exportar show completo',
      'O arquivo leva todas as mídias e vai ter cerca de ${_tamanho(tam)}.'
          '${tam > 200 * 1024 * 1024 ? ' Vídeos deixam o arquivo grande; pode demorar.' : ''}',
      ok: 'Exportar',
    );
    if (!ok || !context.mounted) return;
  }
  aviso(context, 'Preparando o arquivo…');
  final box = context.findRenderObject() as RenderBox?;
  final origem = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  ExportResult r;
  try {
    r = await app.exportShow(s, completo: completo);
  } on ArchiveError catch (e) {
    if (context.mounted) aviso(context, e.message);
    return;
  } catch (e) {
    if (context.mounted) aviso(context, 'Não consegui exportar: $e');
    return;
  }
  final nome = r.path.split(RegExp(r'[/\\]')).last;
  if (Platform.isAndroid || Platform.isIOS) {
    await Share.shareXFiles([XFile(r.path)], subject: s.name, sharePositionOrigin: origem);
  } else {
    final dest = await FilePicker.platform.saveFile(dialogTitle: 'Salvar show', fileName: nome);
    if (dest == null) return;
    File(r.path).copySync(dest);
  }
  if (!context.mounted) return;
  aviso(
    context,
    !completo
        ? 'Show exportado (só a estrutura, sem as mídias).'
        : r.missing > 0
            ? 'Show exportado. ${r.missing} mídia(s) não foram encontradas e ficaram de fora.'
            : 'Show exportado com todas as mídias.',
  );
}

/// Importa um .psshow (ou show.json) como show novo.
Future<Show?> importarShow(BuildContext context, AppState app) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.any, dialogTitle: 'Importar show');
  final path = res?.files.single.path;
  if (path == null) return null;
  if (context.mounted) aviso(context, 'Importando…');
  try {
    final s = await app.importShow(path);
    if (context.mounted) aviso(context, '“${s.name}” importado. Está na lista de shows.');
    return s;
  } on ArchiveError catch (e) {
    if (context.mounted) aviso(context, e.message);
  } catch (e) {
    if (context.mounted) aviso(context, 'Não consegui importar: $e');
  }
  return null;
}
