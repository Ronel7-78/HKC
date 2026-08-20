import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final instance = AppPreferences._();
  static const _storage = FlutterSecureStorage();
  static const _localeKey = 'preference_locale';
  // Mode sombre volontairement désactivé en attendant la validation de sa
  // palette graphique.
  // static const _themeKey = 'preference_theme';

  Locale locale = const Locale('fr');
  // ThemeMode themeMode = ThemeMode.system;

  Future<void> load() async {
    final language = await _storage.read(key: _localeKey);
    locale = Locale(language == 'en' ? 'en' : 'fr');
  }

  Future<void> setLocale(String language) async {
    locale = Locale(language == 'en' ? 'en' : 'fr');
    notifyListeners();
    await _storage.write(key: _localeKey, value: locale.languageCode);
  }

  // Future<void> setThemeMode(ThemeMode value) async {
  //   themeMode = value;
  //   notifyListeners();
  //   await _storage.write(key: _themeKey, value: value.name);
  // }
}

const _translations = <String, Map<String, String>>{
  'fr': {
    'home': 'Accueil',
    'order': 'Commande',
    'orders': 'Commandes',
    'search': 'Recherche',
    'notification': 'Notification',
    'notifications': 'Notifications',
    'account': 'Compte',
    'dashboard': 'Tableau',
    'products': 'Produits',
    'vendors': 'Vendeurs',
    'catalog': 'Catalogue',
    'preferences': 'Préférences',
    'language': 'Langue',
    'appearance': 'Apparence',
    'french': 'Français',
    'english': 'English',
    'system': 'Selon le téléphone',
    'light': 'Clair',
    'dark': 'Sombre',
    'saved_auto':
        'Les changements sont appliqués et enregistrés automatiquement.',
    'my_account': 'Mon compte',
    'my_shop': 'Ma boutique',
    'edit': 'Modifier',
    'phone': 'Téléphone',
    'email': 'Email',
    'address': 'Adresse',
    'delivery_address': 'Adresse de livraison',
    'security': 'Sécurité',
    'change_password': 'Modifier mon mot de passe',
    'shop': 'Boutique',
    'edit_information': 'Modifier mes informations',
    'logout': 'Se déconnecter',
    'admin_account': 'Compte administrateur',
    'role': 'Rôle',
    'administrator': 'Administrateur',
  },
  'en': {
    'home': 'Home',
    'order': 'Order',
    'orders': 'Orders',
    'search': 'Search',
    'notification': 'Notification',
    'notifications': 'Notifications',
    'account': 'Account',
    'dashboard': 'Dashboard',
    'products': 'Products',
    'vendors': 'Vendors',
    'catalog': 'Catalog',
    'preferences': 'Preferences',
    'language': 'Language',
    'appearance': 'Appearance',
    'french': 'Français',
    'english': 'English',
    'system': 'Use device setting',
    'light': 'Light',
    'dark': 'Dark',
    'saved_auto': 'Changes are applied and saved automatically.',
    'my_account': 'My account',
    'my_shop': 'My shop',
    'edit': 'Edit',
    'phone': 'Phone',
    'email': 'Email',
    'address': 'Address',
    'delivery_address': 'Delivery address',
    'security': 'Security',
    'change_password': 'Change my password',
    'shop': 'Shop',
    'edit_information': 'Edit my information',
    'logout': 'Log out',
    'admin_account': 'Administrator account',
    'role': 'Role',
    'administrator': 'Administrator',
  },
};

extension AppTranslation on BuildContext {
  String tr(String key) {
    final language = Localizations.localeOf(this).languageCode;
    return _translations[language]?[key] ?? _translations['fr']![key] ?? key;
  }
}

class PreferencesCard extends StatelessWidget {
  const PreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferences.instance;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.primary),
                const SizedBox(width: 9),
                Text(
                  context.tr('preferences'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: preferences.locale.languageCode,
              decoration: InputDecoration(
                labelText: context.tr('language'),
                prefixIcon: const Icon(Icons.language_rounded),
              ),
              items: [
                DropdownMenuItem(
                  value: 'fr',
                  child: Text(context.tr('french')),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.tr('english')),
                ),
              ],
              onChanged: (value) {
                if (value != null) preferences.setLocale(value);
              },
            ),
            // Le sélecteur Clair/Sombre sera réactivé après validation de la
            // future palette sombre avec le client.
            const SizedBox(height: 9),
            Text(
              context.tr('saved_auto'),
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
