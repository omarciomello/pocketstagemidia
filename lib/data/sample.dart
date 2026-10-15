import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import 'store.dart';

/// Cria o show de exemplo "Noite de Stand-up (exemplo)" com as mídias embutidas no app.
Future<Show> createSampleShow(Store store) async {
  final showId = newId();
  final dir = store.mediaDir(showId)..createSync(recursive: true);

  Future<String> asset(String name) async {
    final data = await rootBundle.load('assets/sample/$name');
    final path = '${dir.path}${Platform.pathSeparator}$name';
    File(path).writeAsBytesSync(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    return path;
  }

  Map<String, dynamic> fila(String name, String kind, int min, int yel) =>
      {'id': newId(), 'kind': kind, 'name': name, 'min': min, 'yel': yel, 'red': 1};
  final lineup = [
    fila('Abertura · MC Duda', 'set', 5, 1),
    fila('Caio Vidal', 'set', 10, 2),
    fila('Intervalo', 'break', 15, 3),
    fila('Bia Soares', 'set', 12, 2),
    fila('Final de show', 'end', 5, 2),
  ];
  final caio = lineup[1]['id'] as String;
  final intervalo = lineup[2]['id'] as String;

  Cue som(String file, String name, {bool fadeOut = true, double volume = 0.9}) =>
      Cue(id: newId(), uri: '', name: name, kind: MediaKind.audio, volume: volume, fadeOut: fadeOut)
          .copyWith(uri: file);
  Cue img(String file, String name) =>
      Cue(id: newId(), uri: file, name: name, kind: MediaKind.image, fadeIn: true, volume: 0.9);
  Cue txt(String text, {TextPos pos = TextPos.bottom, TextSize size = TextSize.m}) => Cue(
        id: newId(),
        uri: '',
        name: text.split('\n').first,
        kind: MediaKind.text,
        text: text,
        textPos: pos,
        textSize: size,
        fadeIn: true,
      );

  const vermelho = '#E2604F';
  final c = List<Cue?>.filled(maxCells, null);
  // linha 1: abertura da casa
  c[0] = som(await asset('sinal1.wav'), '1º sinal', fadeOut: false).copyWith(color: vermelho, hotkey: '1');
  c[1] = som(await asset('espera.wav'), 'Tom de espera', volume: 0.7)
      .copyWith(loop: true, fadeIn: true, fadeCurve: FadeCurve.suave);
  c[2] = img(await asset('cartaz.png'), 'Cartaz do show');
  c[3] = txt('Desliguem os celulares').copyWith(autoStopSec: 8, note: 'sai sozinho em 8 s');
  // linha 2: entrada do Caio (a vinheta puxa o fundo de céu, que fica depois que ela acaba)
  c[4] = som(await asset('sinal2.wav'), '2º sinal', fadeOut: false).copyWith(color: vermelho, hotkey: '2');
  c[6] = img(await asset('ceu.png'), 'Fundo céu noturno').copyWith(fit: Fit.cover, linkId: caio, role: Role.fundo);
  c[5] = som(await asset('vinheta.wav'), 'Vinheta Caio', fadeOut: false).copyWith(
    linkId: caio,
    role: Role.entrada,
    visualId: c[6]!.id,
    visualStays: true,
    color: '#E8C547',
    note: 'quando o MC chamar',
    duckDb: -10,
  );
  c[7] = txt('Caio Vidal\nstand-up · 10 min', pos: TextPos.right, size: TextSize.g)
      .copyWith(linkId: caio, role: Role.entrada);
  // linha 3: intervalo
  c[8] = som(await asset('sinal3.wav'), '3º sinal', fadeOut: false).copyWith(color: vermelho, hotkey: '3');
  c[9] = som(await asset('plateia.wav'), 'Ruído de plateia').copyWith(lockAfter: true);
  c[10] = img(await asset('intervalo.png'), 'Intervalo 15 min').copyWith(linkId: intervalo, role: Role.entrada);
  c[11] = txt('Bar aberto no foyer')
      .copyWith(linkId: intervalo, role: Role.entrada, preWaitSec: 3, transition: Transition.preto);

  return Show(
    id: showId,
    name: 'Noite de Stand-up (exemplo)',
    count: 12,
    cells: c,
    date: '2026-10-17',
    start: '21:00',
    eventType: 'standup',
    lineup: [for (final l in lineup) LineupItem(l)],
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}
