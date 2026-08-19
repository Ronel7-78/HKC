import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/app_states.dart';

void main() {
  testWidgets('le loader évite le flash avant 280 ms', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppLoadingState(label: 'Chargement test')),
    );

    expect(find.text('Chargement test'), findsOneWidget);
    final initialOpacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(initialOpacity.opacity, 0);

    await tester.pump(const Duration(milliseconds: 300));
    final visibleOpacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(visibleOpacity.opacity, 1);
  });

  testWidgets('la page vide propose une action utile', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppEmptyState(
          title: 'Aucun résultat',
          message: 'Essayez une autre recherche.',
          actionLabel: 'Rechercher',
          onAction: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Rechercher'));
    expect(tapped, isTrue);
  });
}
