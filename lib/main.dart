import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'diagnostico.dart';
import 'state.dart';
import 'telao/telao_app.dart';
import 'telao/transporte.dart';
import 'theme.dart';
import 'ui/show_screen.dart';
import 'ui/shows_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Computador: esta pode ser a janela do telão.
  if (Platform.isWindows || Platform.isMacOS) {
    try {
      final w = await WindowController.fromCurrentEngine();
      if (w.arguments == 'telao') return await telaoDesktop();
    } catch (_) {}
  }
  // A tela nunca apaga com o app aberto (obrigatório).
  try {
    await WakelockPlus.enable();
  } catch (_) {}
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Som de palco: toca com a tela bloqueada e com o app minimizado.
  try {
    final sessao = await AudioSession.instance;
    await sessao.configure(const AudioSessionConfiguration.music());
  } catch (_) {}
  final app = await AppState.create();
  if (Platform.isWindows || Platform.isMacOS) {
    await Diagnostico.iniciar('mesa');
    // Fechar a janela pergunta antes (tudo já está salvo automaticamente).
    try {
      await windowManager.ensureInitialized();
      await windowManager.setPreventClose(true);
      windowManager.addListener(_FecharMesa(app));
    } catch (_) {}
  }
  runApp(PocketStageMidia(app: app));
}

final GlobalKey<NavigatorState> chaveNavegacao = GlobalKey<NavigatorState>();

class _FecharMesa with WindowListener {
  _FecharMesa(this.app);
  final AppState app;
  bool _perguntando = false;

  @override
  void onWindowClose() async {
    if (_perguntando) return;
    final ctx = chaveNavegacao.currentContext;
    var ok = true;
    if (app.settings.confirmExit && ctx != null) {
      _perguntando = true;
      ok = await showDialog<bool>(
            context: ctx,
            builder: (c) => AlertDialog(
              title: const Text('Fechar o PocketStage Mídia?', style: TextStyle(fontWeight: FontWeight.w800)),
              content: const Text('Tudo já está salvo. O que estiver tocando para e o telão fecha.',
                  style: TextStyle(color: Color(0xFF8B8F9E), height: 1.4)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Fechar')),
              ],
            ),
          ) ??
          false;
      _perguntando = false;
    }
    if (!ok) return;
    Diagnostico.log('fechando o app');
    app.telao?.janela?.fechar();
    app.engine.hardStop();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await windowManager.destroy();
  }
}

/// Entrada do telão externo (segundo motor, aberto pelo Android no monitor HDMI).
@pragma('vm:entry-point')
void telaoMain() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(TelaoApp());
}

/// Windows: a janela é posta no monitor do telão por código nativo (canal psm/janela),
/// em pixels reais e em dois passos, para não ficar entre dois monitores de escalas diferentes.
Future<void> telaoWindows() async {
  await Diagnostico.iniciar('telao');
  const janela = MethodChannel('psm/janela');
  var nome = 'janela';
  try {
    nome = '${await janela.invokeMethod<String>('entrar') ?? 'monitor'} · janela';
  } catch (_) {}
  final t = JanelaTelaoLado(nome);
  runApp(TelaoApp(
    transporte: t,
    onFechar: () async {
      t.enviar({'t': 'fechou'});
      try {
        await janela.invokeMethod<void>('fechar');
      } catch (_) {}
    },
  ));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  try {
    await janela.invokeMethod<void>('ocupar');
  } catch (_) {}
}

class _AoFechar with WindowListener {
  _AoFechar(this.t);
  final TransporteTelao t;

  @override
  void onWindowClose() async {
    t.enviar({'t': 'fechou'});
    await windowManager.destroy();
  }
}

/// Computador: janela do telão, em tela cheia no segundo monitor (ou no único, se só houver um).
Future<void> telaoDesktop() async {
  if (Platform.isWindows) return telaoWindows();
  await windowManager.ensureInitialized();
  Display alvo;
  try {
    final telas = await screenRetriever.getAllDisplays();
    final principal = await screenRetriever.getPrimaryDisplay();
    alvo = telas.firstWhere((d) => d.id != principal.id, orElse: () => principal);
  } catch (_) {
    alvo = await screenRetriever.getPrimaryDisplay();
  }
  final pos = alvo.visiblePosition ?? Offset.zero;
  final tam = alvo.size;
  final nome = '${(tam.width * (alvo.scaleFactor ?? 1)).round()}×${(tam.height * (alvo.scaleFactor ?? 1)).round()} · janela';
  final t = JanelaTelaoLado(nome);
  // Primeiro o app, depois a janela: sem borda, do tamanho exato do monitor.
  runApp(TelaoApp(
    transporte: t,
    onFechar: () async {
      t.enviar({'t': 'fechou'});
      await windowManager.destroy();
    },
  ));
  const opcoes = WindowOptions(title: 'PocketStage Mídia · Telão', backgroundColor: Colors.black);
  windowManager.waitUntilReadyToShow(opcoes, () async {
    final area = Rect.fromLTWH(pos.dx, pos.dy, tam.width, tam.height);
    if (Platform.isMacOS) {
      await windowManager.setBounds(area);
      await windowManager.show();
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setAsFrameless();
      await windowManager.setBounds(area);
      await windowManager.show();
    }
    await windowManager.setPreventClose(true);
    windowManager.addListener(_AoFechar(t));
  });
}

class PocketStageMidia extends StatelessWidget {
  const PocketStageMidia({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: chaveNavegacao,
      title: 'PocketStage Mídia',
      debugShowCheckedModeBanner: false,
      theme: temaPocketStage(),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) => app.hasActive ? ShowScreen(app: app) : ShowsScreen(app: app),
      ),
    );
  }
}
