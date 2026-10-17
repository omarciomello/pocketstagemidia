import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

import 'store.dart';

/// Versão do show de exemplo; ao subir, o app acrescenta o novo exemplo uma vez.
const versaoExemplo = 3;

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
    fila('Abertura', 'set', 5, 1),
    fila('Comediante 01', 'set', 10, 2),
    fila('Intervalo', 'break', 15, 3),
    fila('Comediante 02', 'set', 12, 2),
    fila('Final de show', 'end', 5, 2),
  ];
  final com01 = lineup[1]['id'] as String;
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
  c[0] = som(await asset('sinal1.mp3'), '1º sinal', fadeOut: false).copyWith(color: vermelho);
  c[1] = som(await asset('espera.wav'), 'Tom de espera', volume: 0.7)
      .copyWith(loop: true, fadeIn: true, fadeCurve: FadeCurve.suave);
  c[2] = img(await asset('cartaz.png'), 'Cartaz do show');
  c[3] = txt('Desliguem os celulares').copyWith(autoStopSec: 8, note: 'sai sozinho em 8 s');
  // linha 2: entrada do Comediante 01 (a vinheta puxa o fundo de céu, que fica depois que ela acaba)
  c[4] = som(await asset('sinal2.mp3'), '2º sinal', fadeOut: false).copyWith(color: vermelho);
  c[6] = img(await asset('ceu.png'), 'Fundo céu noturno').copyWith(fit: Fit.cover, linkId: com01, role: Role.fundo);
  c[5] = som(await asset('vinheta.wav'), 'Vinheta de entrada', fadeOut: false).copyWith(
    linkId: com01,
    role: Role.entrada,
    visualId: c[6]!.id,
    visualStays: true,
    color: '#E8C547',
    note: 'quando o apresentador chamar',
    duckDb: -10,
  );
  c[7] = txt('Comediante 01\nstand-up · 10 min', pos: TextPos.right, size: TextSize.g)
      .copyWith(linkId: com01, role: Role.entrada);
  // linha 3: intervalo
  c[8] = som(await asset('sinal3.mp3'), '3º sinal', fadeOut: false).copyWith(color: vermelho);
  c[9] = som(await asset('plateia.wav'), 'Ruído de plateia').copyWith(lockAfter: true);
  c[10] = img(await asset('intervalo.png'), 'Intervalo 15 min').copyWith(linkId: intervalo, role: Role.entrada);
  c[11] = txt('Bar aberto no foyer')
      .copyWith(linkId: intervalo, role: Role.entrada, preWaitSec: 3, transition: Transition.preto);
  // linha 4: trilhas de entrada de convidados
  const azul = '#5B8DEF';
  c[12] = som(await asset('entrada_rock.mp3'), 'Entrada · Rock').copyWith(color: azul, note: 'entrada de convidado');
  c[13] = som(await asset('entrada_pop.mp3'), 'Entrada · Pop').copyWith(color: azul, note: 'entrada de convidado');
  c[14] = som(await asset('entrada_hiphop.mp3'), 'Entrada · HipHop').copyWith(color: azul, note: 'entrada de convidado');

  return Show(
    id: showId,
    name: 'Noite de Stand-up (exemplo)',
    count: 16,
    cells: c,
    date: '2026-10-17',
    start: '21:00',
    eventType: 'standup',
    lineup: [for (final l in lineup) LineupItem(l)],
    updatedAt: DateTime.now().millisecondsSinceEpoch,
  );
}
