import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/main.dart';

void main() {
  testWidgets('la grande carte menu reste responsive sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const product = ProductData(
      null,
      'Koki royal avec un nom volontairement très long',
      2500,
      'Une description suffisamment longue pour vérifier le comportement adaptatif.',
      [],
      true,
      'Disponible',
      id: 1,
      vendorId: 1,
      vendorName: 'Vendeur test',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              height: 342,
              child: ProductCard(product: product, onAdd: _noop),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Commander'), findsOneWidget);
  });
}

void _noop() {}
