import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'state.dart';
import 'telao/telao_app.dart';
import 'theme.dart';
import 'ui/show_screen.dart';
import 'ui/shows_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
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
  runApp(PocketStageMidia(app: app));
}

/// Entrada do telão externo (segundo motor, aberto pelo Android no monitor HDMI).
@pragma('vm:entry-point')
void telaoMain() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const TelaoApp());
}

class PocketStageMidia extends StatelessWidget {
  const PocketStageMidia({super.key, required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
