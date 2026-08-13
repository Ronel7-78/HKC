import 'package:flutter/material.dart';

void main() => runApp(const HotKokiApp());

class HotKokiApp extends StatelessWidget {
  const HotKokiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hot Koki Chaud',
      theme: HotKokiTheme.light,
      home: const MainShell(role: UserRole.client),
    );
  }
}

enum UserRole { client, vendeur, admin }

class HotKokiColors {
  static const leaf900 = Color(0xFF1F3524);
  static const leaf700 = Color(0xFF2E4E36);
  static const leaf100 = Color(0xFFE7EEE4);
  static const cream = Color(0xFFF6EAC9);
  static const cream2 = Color(0xFFFBF4E1);
  static const flame600 = Color(0xFFC9491E);
  static const flame500 = Color(0xFFE0672F);
  static const flame100 = Color(0xFFFBD9C4);
  static const muted100 = Color(0xFFECE7DA);
  static const ink = Color(0xFF2A2117);
  static const inkSoft = Color(0xFF6B5F4E);
}

class HotKokiTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: HotKokiColors.cream2,
      colorScheme: ColorScheme.fromSeed(
        seedColor: HotKokiColors.flame500,
        primary: HotKokiColors.flame500,
        secondary: HotKokiColors.leaf700,
        surface: Colors.white,
      ),
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: HotKokiColors.leaf900,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: HotKokiColors.leaf900,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: HotKokiColors.ink),
      ),
    );
  }
}

class AppTab {
  const AppTab(this.label, this.icon, this.screen);

  final String label;
  final IconData icon;
  final Widget screen;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.role});

  final UserRole role;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<AppTab> get _tabs {
    switch (widget.role) {
      case UserRole.client:
        return const [
          AppTab('Accueil', Icons.home_outlined, ClientHomeScreen()),
          AppTab('Menu', Icons.restaurant_menu, PlaceholderScreen('Menu')),
          AppTab('Recherche', Icons.search, PlaceholderScreen('Recherche')),
          AppTab(
            'Commandes',
            Icons.receipt_long_outlined,
            PlaceholderScreen('Mes commandes'),
          ),
          AppTab(
            'Compte',
            Icons.person_outline,
            PlaceholderScreen('Mon compte'),
          ),
        ];
      case UserRole.vendeur:
        return const [
          AppTab(
            'Accueil',
            Icons.dashboard_outlined,
            PlaceholderScreen('Espace vendeur'),
          ),
          AppTab(
            'Commandes',
            Icons.receipt_long_outlined,
            PlaceholderScreen('Commandes vendeur'),
          ),
          AppTab(
            'Produits',
            Icons.inventory_2_outlined,
            PlaceholderScreen('Produits'),
          ),
          AppTab(
            'Compte',
            Icons.storefront_outlined,
            PlaceholderScreen('Compte vendeur'),
          ),
        ];
      case UserRole.admin:
        return const [
          AppTab(
            'Accueil',
            Icons.dashboard_outlined,
            PlaceholderScreen('Espace administrateur'),
          ),
          AppTab(
            'Vendeurs',
            Icons.store_outlined,
            PlaceholderScreen('Vendeurs'),
          ),
          AppTab(
            'Catalogue',
            Icons.inventory_2_outlined,
            PlaceholderScreen('Catalogue'),
          ),
          AppTab('Litiges', Icons.gavel_outlined, PlaceholderScreen('Litiges')),
          AppTab(
            'Compte',
            Icons.admin_panel_settings_outlined,
            PlaceholderScreen('Compte administrateur'),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs.map((tab) => tab.screen).toList(),
      ),
      bottomNavigationBar: _RoleNavigationBar(
        tabs: tabs,
        selectedIndex: _currentIndex,
        onSelected: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _RoleNavigationBar extends StatelessWidget {
  const _RoleNavigationBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      height: 72,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: Colors.white,
      indicatorColor: HotKokiColors.leaf100,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: tabs
          .map(
            (tab) => NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.icon, color: HotKokiColors.flame600),
              label: tab.label,
            ),
          )
          .toList(),
    );
  }
}

class ClientHomeScreen extends StatelessWidget {
  const ClientHomeScreen({super.key});

  static const products = [
    ProductData(
      '🌽',
      'Koki Pimenté',
      500,
      'Haricots de koki, huile rouge et épices',
      ['Manioc', 'Patate', 'Banane', 'Plantain'],
      true,
      '~15 min',
    ),
    ProductData(
      '🌽',
      'Koki Non Pimenté',
      500,
      'Koki doux préparé ce matin',
      ['Manioc', 'Patate', 'Banane', 'Plantain'],
      true,
      '~15 min',
    ),
    ProductData(
      '🍠',
      'Eru',
      200,
      'Water fufu, viande, crevettes et huile rouge',
      ['Water fufu', 'Tapioca'],
      true,
      '~10 min',
    ),
    ProductData(
      '🍌',
      'Ekwan',
      800,
      'Macabo, feuilles, huile rouge, viande et crevettes',
      ['Piment'],
      false,
      'Demain',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverList.list(
              children: const [
                _HomeTopBar(),
                SizedBox(height: 18),
                Text(
                  'Bonjour Ronel 👋',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: HotKokiColors.leaf900,
                  ),
                ),
                SizedBox(height: 5),
                _AddressRow(),
                SizedBox(height: 16),
                _PromoCard(),
                SizedBox(height: 22),
                _SectionHeader(title: 'Le menu du jour', action: '4 plats'),
                SizedBox(height: 10),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  ProductCard(product: products[index]),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(title: 'Avis récents', action: 'Voir tout'),
            ),
          ),
          const SliverToBoxAdapter(child: _ReviewsList()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Hkc',
                style: TextStyle(color: HotKokiColors.leaf900),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: HotKokiColors.flame600),
              ),
            ],
          ),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        Badge(
          label: const Text('3'),
          backgroundColor: HotKokiColors.flame600,
          child: IconButton.filledTonal(
            onPressed: () {},
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: HotKokiColors.leaf900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16,
          color: HotKokiColors.inkSoft,
        ),
        SizedBox(width: 5),
        Text(
          'Livrer à ',
          style: TextStyle(color: HotKokiColors.inkSoft, fontSize: 13),
        ),
        Flexible(
          child: Text(
            'Mokolo Safari, Bertoua',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HotKokiColors.leaf700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Icon(Icons.keyboard_arrow_down, size: 18, color: HotKokiColors.inkSoft),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [HotKokiColors.flame500, HotKokiColors.flame600],
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOUVEAUTÉ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Eru de retour',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Préparé ce matin — quantité limitée.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          Text('🌽', style: TextStyle(fontSize: 58)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: HotKokiColors.leaf900,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          action,
          style: const TextStyle(
            color: HotKokiColors.flame600,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class ProductData {
  const ProductData(
    this.emoji,
    this.name,
    this.price,
    this.description,
    this.sides,
    this.available,
    this.eta,
  );

  final String emoji;
  final String name;
  final int price;
  final String description;
  final List<String> sides;
  final bool available;
  final String eta;
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final ProductData product;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: product.available ? 1 : .6,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HotKokiColors.flame100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(product.emoji, style: const TextStyle(fontSize: 27)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${product.price} F',
                        style: const TextStyle(
                          color: HotKokiColors.flame600,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HotKokiColors.inkSoft,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: product.sides
                        .map((side) => _SideChip(label: side))
                        .toList(),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      _AvailabilityBadge(available: product.available),
                      const Spacer(),
                      const Icon(
                        Icons.schedule,
                        size: 13,
                        color: HotKokiColors.inkSoft,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.eta,
                        style: const TextStyle(
                          color: HotKokiColors.inkSoft,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: product.available ? () {} : null,
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: product.available
                              ? HotKokiColors.flame500
                              : HotKokiColors.muted100,
                          child: const Icon(
                            Icons.add,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideChip extends StatelessWidget {
  const _SideChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HotKokiColors.leaf100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '+ $label',
        style: const TextStyle(
          color: HotKokiColors.leaf700,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? HotKokiColors.leaf700 : HotKokiColors.inkSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: available ? HotKokiColors.leaf100 : HotKokiColors.muted100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'Disponible' : 'Terminé',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList();

  @override
  Widget build(BuildContext context) {
    const reviews = [
      (
        'EA',
        'Émile A.',
        'Koki toujours chaud à la livraison, franchement top.',
      ),
      ('MF', 'Marie F.', 'Le koki spicy est devenu mon péché mignon du soir.'),
      ('JD', 'Joel D.', 'Livraison un peu longue mais le goût compense.'),
    ];

    return SizedBox(
      height: 118,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: reviews.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final review = reviews[index];
          return Container(
            width: 210,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: HotKokiColors.leaf700,
                      child: Text(
                        review.$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      review.$2,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '★★★★★',
                      style: TextStyle(
                        color: HotKokiColors.flame600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  review.$3,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HotKokiColors.inkSoft,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
    );
  }
}
