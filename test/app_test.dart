import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketstage_midia/media/backend.dart';
import 'package:pocketstage_midia/theme.dart';
import 'package:pocketstage_midia/ui/stage_view.dart';
import 'package:pocketstage_midia_core/pocketstage_midia_core.dart';

void main() {
  testWidgets('telão começa apagado e mostra o texto enviado', (tester) async {
    final stage = StageController();
    await tester.pumpWidget(MaterialApp(
      theme: temaPocketStage(),
      home: Scaffold(body: SizedBox(width: 320, height: 180, child: StageView(stage: stage))),
    ));
    expect(find.text('TELÃO APAGADO'), findsOneWidget);
    stage.presentText(const StageText('Desliguem os celulares', TextPos.bottom, TextSize.m), 0, 0);
    await tester.pump();
    expect(find.text('Desliguem os celulares'), findsOneWidget);
    expect(find.text('TELÃO APAGADO'), findsNothing);
    stage.presentText(null, 0, 0);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Desliguem os celulares'), findsNothing);
  });
}
