import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/payment_method_card.dart';

void main() {
  testWidgets('le dialogue de paiement affiche ses cartes sans erreur', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Choisir le paiement'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PaymentMethodCard(
                          code: 'mtn_momo',
                          name: 'MTN MoMo',
                          selected: true,
                          available: true,
                          onTap: () {},
                        ),
                        const PaymentMethodCard(
                          code: 'orange_money',
                          name: 'Orange Money',
                          selected: false,
                          available: false,
                          onTap: null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('Payer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Payer'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir le paiement'), findsOneWidget);
    expect(find.text('MTN MoMo'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
