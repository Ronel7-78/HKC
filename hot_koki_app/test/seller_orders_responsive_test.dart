import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/seller_screens.dart';

void main() {
  testWidgets('une commande vendeur ne déborde pas sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final order = <String, dynamic>{
      'id': 123456,
      'public_id': 'commande-test',
      'statut': 'recue',
      'total': 125000,
      'distance_km': 12.45,
      'frais_livraison': 500,
      'livraison_express': true,
      'client': {
        'nom': 'Client avec un nom volontairement très long',
        'user': {
          'name': 'Client avec un nom volontairement très long',
          'telephone': '237600000000',
        },
      },
      'items': <dynamic>[],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerOrderCard(order: order, onChanged: () async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Marquer comme livrée'), findsOneWidget);
  });
}
