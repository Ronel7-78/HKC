import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/legal_screen.dart';

void main() {
  testWidgets('les conditions affichent leur version et les paiements', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalScreen(document: LegalDocument.terms)),
    );

    expect(find.text('Conditions d’utilisation de Hot Koki'), findsOneWidget);
    expect(find.text('Version du 20 août 2026'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('4. Paiements Mobile Money'),
      300,
    );
    expect(find.text('4. Paiements Mobile Money'), findsOneWidget);
  });

  testWidgets('la politique explique la géolocalisation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalScreen(document: LegalDocument.privacy)),
    );

    expect(
      find.text('Politique de confidentialité de Hot Koki'),
      findsOneWidget,
    );
    expect(find.text('2. Géolocalisation'), findsOneWidget);
  });
}
