import 'package:flutter/material.dart';

/// Cores do PocketStage Mídia.
class Cores {
  static const fundo = Color(0xFF090A0F);
  static const painel = Color(0xFF12141C);
  static const texto = Color(0xFFE2E4E9);
  static const textoFraco = Color(0xFF8B8F9E);
  static const ciano = Color(0xFF6FD3DF);
  static const lilas = Color(0xFFE0A6F0);
}

void main() => runApp(const PocketStageMidia());

class PocketStageMidia extends StatelessWidget {
  const PocketStageMidia({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PocketStage Mídia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Cores.fundo,
        fontFamily: 'Archivo',
        colorScheme: const ColorScheme.dark(
          surface: Cores.painel,
          primary: Cores.ciano,
          secondary: Cores.lilas,
        ),
      ),
      home: const TelaInicial(),
    );
  }
}

/// Tela provisória da etapa 1: só confirma que o app abre em cada plataforma.
class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PocketStage Mídia',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Cores.texto),
            ),
            SizedBox(height: 8),
            Text(
              'versão 0.1 · build de teste',
              style: TextStyle(fontFamily: 'ChivoMono', fontSize: 13, color: Cores.textoFraco),
            ),
          ],
        ),
      ),
    );
  }
}
