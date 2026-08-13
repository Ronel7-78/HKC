import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_koki_app/main.dart';

void main() {
  testWidgets('affiche accueil et navigation client', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const HotKokiApp());
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue chez Hot Koki 👋'), findsOneWidget);
    expect(find.text('Le menu du jour'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Inscription'), findsOneWidget);
  });
}
