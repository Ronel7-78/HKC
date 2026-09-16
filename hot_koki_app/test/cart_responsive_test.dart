import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/cart_screen.dart';

void main() {
  testWidgets('le panier ne déborde pas sur un petit téléphone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    CartStore.instance.clear();
    CartStore.instance.add(
      CartItem(
        vendorId: 1,
        vendorName: 'Point de vente avec un nom volontairement très long',
        productId: 1,
        productName: 'Koki chaud avec une très longue désignation',
        unitPrice: 2500,
        complementId: 1,
        complementName: 'Banane plantain et manioc',
        photo: null,
      ),
    );
    addTearDown(CartStore.instance.clear);

    await tester.pumpWidget(const MaterialApp(home: CartScreen()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
