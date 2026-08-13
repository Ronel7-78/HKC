import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/main.dart';

void main() {
  testWidgets('affiche accueil et navigation client', (tester) async {
    await tester.pumpWidget(const HotKokiApp());

    expect(find.text('Bonjour Ronel 👋'), findsOneWidget);
    expect(find.text('Le menu du jour'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);
  });
}
