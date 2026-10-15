import 'package:flutter_test/flutter_test.dart';
import 'package:pocketstage_midia/main.dart';

void main() {
  testWidgets('abre com o nome do app', (tester) async {
    await tester.pumpWidget(const PocketStageMidia());
    expect(find.text('PocketStage Mídia'), findsOneWidget);
  });
}
