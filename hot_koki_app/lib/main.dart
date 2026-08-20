import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'admin_screens.dart';
import 'app_feedback.dart';
import 'app_states.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';
import 'client_screens.dart';
import 'notifications_screen.dart';
import 'seller_screens.dart';
import 'vendor_screens.dart';

void main() => runApp(const HotKokiApp());

class HotKokiApp extends StatelessWidget {
  const HotKokiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hot Koki Chaud',
      theme: HotKokiTheme.light,
      home: const MainShell(),
    );
  }
}

enum UserRole { client, vendeur, admin }

class HotKokiColors {
  static const leaf900 = Color(0xFF1F3524);
  static const leaf700 = Color(0xFF2E4E36);
  static const leaf100 = Color(0xFFE7EEE4);
  static const cream = Color(0xFFFFF8E1);
  static const cream2 = Color(0xFFFFF8EE);
  static const flame600 = Color(0xFFC9491E);
  static const flame500 = Color(0xFFE0672F);
  static const flame100 = Color(0xFFFFE8E5);
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
      navigationBarTheme: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: GoogleFonts.manropeTextTheme().copyWith(
        headlineSmall: TextStyle(
          color: HotKokiColors.leaf900,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: HotKokiColors.leaf900,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: GoogleFonts.manrope(color: HotKokiColors.ink),
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
  const MainShell({super.key, this.role});

  final UserRole? role;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  UserRole? _role;
  String? _userName;
  bool _restoringSession = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _role = widget.role;
    CartCleanup.clear = CartStore.instance.clear;
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final token = await ClientApi.storage.read(key: 'auth_token');
      if (token != null && _role == null) {
        final user =
            await ClientApi.request('GET', '/me') as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _role = UserRole.values.firstWhere(
              (role) => role.name == user['role'],
            );
            _userName = user['name']?.toString();
          });
          NotificationStore.refresh();
          _startNotificationRefresh();
        }
      }
    } catch (_) {
      try {
        await ClientApi.storage.delete(key: 'auth_token');
      } catch (_) {}
    }
    if (_role != null && _notificationTimer == null) {
      NotificationStore.refresh();
      _startNotificationRefresh();
    }
    if (mounted) setState(() => _restoringSession = false);
  }

  void _logout() {
    _notificationTimer?.cancel();
    NotificationStore.reset();
    setState(() {
      _role = null;
      _userName = null;
      _currentIndex = 0;
    });
  }

  Future<void> _openAuth(bool register) async {
    final result = await Navigator.push<AuthResult>(
      context,
      MaterialPageRoute(builder: (_) => AuthScreen(initialRegister: register)),
    );
    if (result == null || !mounted) return;
    setState(() {
      _role = UserRole.values.firstWhere((role) => role.name == result.role);
      _userName = result.name;
      _currentIndex = 0;
    });
    NotificationStore.refresh();
    _startNotificationRefresh();
  }

  void _startNotificationRefresh() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => NotificationStore.refresh(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  List<AppTab> get _tabs {
    if (_role == null) {
      return [
        AppTab(
          'Accueil',
          Icons.home_outlined,
          ClientHomeScreen(
            userName: null,
            onLogin: () => _openAuth(false),
            onRegister: () => _openAuth(true),
          ),
        ),
      ];
    }

    switch (_role!) {
      case UserRole.client:
        return [
          AppTab(
            'Accueil',
            Icons.home_rounded,
            ClientHomeScreen(
              userName: _userName,
              onCart: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              ),
            ),
          ),
          AppTab(
            'Commande',
            Icons.receipt_long_rounded,
            const ClientOrdersScreen(),
          ),
          const AppTab('Recherche', Icons.search_rounded, VendorSearchScreen()),
          const AppTab(
            'Notification',
            Icons.notifications_rounded,
            NotificationsScreen(),
          ),
          AppTab(
            'Compte',
            Icons.person_rounded,
            ClientAccountScreen(onLogout: _logout),
          ),
        ];
      case UserRole.vendeur:
        return [
          AppTab(
            'Tableau',
            Icons.dashboard_rounded,
            const SellerDashboardScreen(),
          ),
          AppTab(
            'Commandes',
            Icons.receipt_long_rounded,
            const SellerOrdersScreen(),
          ),
          const AppTab(
            'Notifications',
            Icons.notifications_rounded,
            NotificationsScreen(),
          ),
          AppTab(
            'Produits',
            Icons.inventory_2_rounded,
            const SellerProductsScreen(),
          ),
          AppTab(
            'Compte',
            Icons.storefront_rounded,
            SellerAccountScreen(onLogout: _logout),
          ),
        ];
      case UserRole.admin:
        return [
          AppTab(
            'Tableau',
            Icons.dashboard_rounded,
            const AdminDashboardScreen(),
          ),
          AppTab(
            'Vendeurs',
            Icons.storefront_rounded,
            const AdminVendorsScreen(),
          ),
          AppTab(
            'Catalogue',
            Icons.restaurant_menu_rounded,
            const AdminCatalogueScreen(),
          ),
          AppTab(
            'Commandes',
            Icons.receipt_long_rounded,
            const AdminOrdersScreen(),
          ),
          AppTab(
            'Compte',
            Icons.admin_panel_settings_rounded,
            AdminAccountScreen(onLogout: _logout),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
    if (tabs.length == 1) return const SizedBox.shrink();

    return NavigationBar(
      height: 76,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: Colors.white,
      indicatorColor: HotKokiColors.flame100,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: tabs.map((tab) {
        final primary = tab.label == 'Recherche';
        Widget withBadge(Widget icon) {
          if (!tab.label.startsWith('Notification')) return icon;
          return ValueListenableBuilder<int>(
            valueListenable: NotificationStore.unread,
            builder: (_, count, child) => Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              backgroundColor: HotKokiColors.flame600,
              child: child,
            ),
            child: icon,
          );
        }

        return NavigationDestination(
          icon: withBadge(
            primary
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: HotKokiColors.flame600,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33D92D20),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(tab.icon, color: Colors.white, size: 29),
                  )
                : Icon(tab.icon, size: 24),
          ),
          selectedIcon: withBadge(
            primary
                ? Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: HotKokiColors.flame600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(tab.icon, color: Colors.white, size: 30),
                  )
                : Icon(tab.icon, color: HotKokiColors.flame600, size: 26),
          ),
          label: tab.label,
        );
      }).toList(),
    );
  }
}

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.userName,
    this.onLogin,
    this.onRegister,
    this.onCart,
  });

  final String? userName;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  final VoidCallback? onCart;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late Future<List<ProductData>> _products;
  late Future<HomeContent> _content;
  late Future<String?> _deliveryAddress;

  @override
  void initState() {
    super.initState();
    _products = CatalogueApi.fetchProducts(widget.userName != null);
    _content = HomeApi.fetch();
    _deliveryAddress = _loadDeliveryAddress();
  }

  @override
  void didUpdateWidget(covariant ClientHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _deliveryAddress = _loadDeliveryAddress();
      _products = CatalogueApi.fetchProducts(widget.userName != null);
    }
  }

  Future<void> _addFromHome(ProductData product) async {
    if (widget.userName == null) {
      widget.onLogin?.call();
      return;
    }
    if (!product.available || product.vendorId == null || product.id == null) {
      await AppFeedback.error(
        context,
        message: 'Aucun vendeur disponible ne propose actuellement ce plat.',
      );
      return;
    }
    if (product.complements.isEmpty) {
      await AppFeedback.error(
        context,
        message: 'Aucun complément n’est configuré pour ce produit.',
      );
      return;
    }
    final complement = await showModalBottomSheet<HomeComplement>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choisissez un complément',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...product.complements.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.radio_button_unchecked,
                    color: HotKokiColors.flame600,
                  ),
                  title: Text(item.name),
                  onTap: () => Navigator.pop(context, item),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (complement == null || !mounted) return;
    final added = CartStore.instance.add(
      CartItem(
        vendorId: product.vendorId!,
        vendorName: product.vendorName!,
        productId: product.id!,
        productName: product.name,
        unitPrice: product.price,
        complementId: complement.id,
        complementName: complement.name,
        photo: product.photoUrl,
      ),
    );
    if (!mounted) return;
    if (added) {
      await AppFeedback.success(
        context,
        title: 'Ajouté au panier',
        message: '${product.name} a été ajouté depuis l’accueil.',
      );
    } else {
      await AppFeedback.error(
        context,
        message: 'Terminez d’abord le panier du vendeur actuel.',
      );
    }
  }

  Future<String?> _loadDeliveryAddress() async {
    if (widget.userName == null) return null;
    try {
      final profile =
          await ClientApi.request('GET', '/client/profile')
              as Map<String, dynamic>;
      final client = profile['client'] as Map<String, dynamic>;
      return client['adresse_texte']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverList.list(
              children: [
                _HomeTopBar(
                  isAuthenticated: widget.userName != null,
                  onLogin: widget.onLogin,
                  onRegister: widget.onRegister,
                  onCart: widget.onCart,
                ),
                const SizedBox(height: 18),
                Text(
                  widget.userName == null
                      ? 'Bienvenue chez Hot Koki 👋'
                      : 'Bonjour ${widget.userName} 👋',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: HotKokiColors.leaf900,
                  ),
                ),
                const SizedBox(height: 5),
                FutureBuilder<String?>(
                  future: _deliveryAddress,
                  builder: (context, snapshot) => _AddressRow(
                    address: snapshot.data,
                    loading:
                        snapshot.connectionState == ConnectionState.waiting,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<HomeContent>(
                  future: _content,
                  builder: (_, snapshot) => _Announcements(
                    announcements: snapshot.data?.announcements ?? const [],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeader(
                  title: 'Le menu du jour',
                  action: 'Nos plats',
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<List<ProductData>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppCardSkeleton();
                }
                if (snapshot.hasError) {
                  return AppErrorState(
                    title: 'Hot Koki est hors ligne',
                    message:
                        'Impossible de joindre le serveur. Vérifiez votre connexion Internet puis réessayez.',
                    onRetry: () => setState(() {
                      _products = CatalogueApi.fetchProducts(
                        widget.userName != null,
                      );
                      _content = HomeApi.fetch();
                    }),
                  );
                }
                final products = snapshot.data ?? const <ProductData>[];
                return Column(
                  children: [
                    if (products.isEmpty)
                      const AppEmptyState(
                        title: 'Le menu arrive bientôt',
                        message:
                            'Aucun plat réel n’est disponible actuellement.',
                        icon: Icons.restaurant_menu_rounded,
                      ),
                    ...products.map(
                      (product) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: ProductCard(
                          product: product,
                          onAdd: () => _addFromHome(product),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(title: 'Avis récents', action: 'Voir tout'),
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<HomeContent>(
              future: _content,
              builder: (_, snapshot) => _ReviewsList(
                reviews: snapshot.data?.reviews ?? const [],
                loading: snapshot.connectionState == ConnectionState.waiting,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({
    required this.isAuthenticated,
    this.onLogin,
    this.onRegister,
    this.onCart,
  });

  final bool isAuthenticated;
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  final VoidCallback? onCart;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 58,
          height: 48,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Transform.scale(
            scale: 2.15,
            child: Image.asset(
              'assets/images/hot_koki_logo.jpeg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (!isAuthenticated)
          _GuestActions(onLogin: onLogin, onRegister: onRegister)
        else
          AnimatedBuilder(
            animation: CartStore.instance,
            builder: (context, _) => Badge(
              isLabelVisible: CartStore.instance.count > 0,
              label: Text('${CartStore.instance.count}'),
              backgroundColor: HotKokiColors.flame600,
              child: IconButton.filledTonal(
                onPressed: onCart,
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: HotKokiColors.leaf900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GuestActions extends StatelessWidget {
  const _GuestActions({this.onLogin, this.onRegister});

  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: onLogin,
          style: OutlinedButton.styleFrom(
            foregroundColor: HotKokiColors.leaf700,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: const BorderSide(color: HotKokiColors.leaf700),
          ),
          child: const Text(
            'Connexion',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 7),
        FilledButton(
          onPressed: onRegister,
          style: FilledButton.styleFrom(
            backgroundColor: HotKokiColors.flame500,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text(
            'Inscription',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.loading});

  final String? address;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 16,
          color: HotKokiColors.inkSoft,
        ),
        const SizedBox(width: 5),
        const Text(
          'Livrer à ',
          style: TextStyle(color: HotKokiColors.inkSoft, fontSize: 13),
        ),
        Flexible(
          child: Text(
            loading
                ? 'Chargement de l’adresse…'
                : address?.trim().isNotEmpty == true
                ? address!
                : 'Adresse non renseignée',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: HotKokiColors.leaf700,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(
          Icons.keyboard_arrow_down,
          size: 18,
          color: HotKokiColors.inkSoft,
        ),
      ],
    );
  }
}

class _Announcements extends StatelessWidget {
  const _Announcements({required this.announcements});
  final List<HomeAnnouncement> announcements;

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 145,
      child: PageView.builder(
        controller: PageController(viewportFraction: .94),
        itemCount: announcements.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(right: 9),
          child: _AnnouncementCard(announcement: announcements[index]),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});
  final HomeAnnouncement announcement;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [HotKokiColors.flame500, HotKokiColors.flame600],
      ),
    ),
    child: Stack(
      children: [
        if (announcement.imageUrl != null)
          Positioned(
            right: -20,
            top: -30,
            bottom: -30,
            width: 145,
            child: Opacity(
              opacity: .28,
              child: Image.network(announcement.imageUrl!, fit: BoxFit.cover),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    announcement.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    announcement.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              announcement.type == 'produit'
                  ? Icons.restaurant_rounded
                  : Icons.campaign_rounded,
              size: 58,
              color: Colors.white24,
            ),
          ],
        ),
      ],
    ),
  );
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
    this.photoUrl,
    this.name,
    this.price,
    this.description,
    this.sides,
    this.available,
    this.eta, {
    this.id,
    this.vendorId,
    this.vendorName,
    this.complements = const [],
  });

  final String? photoUrl;
  final String name;
  final int price;
  final String description;
  final List<String> sides;
  final bool available;
  final String eta;
  final int? id;
  final int? vendorId;
  final String? vendorName;
  final List<HomeComplement> complements;

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final complements = (json['complements'] as List<dynamic>? ?? [])
        .map((item) => HomeComplement.fromJson(item as Map<String, dynamic>))
        .toList();
    final vendor = json['vendeur_choisi'] as Map<String, dynamic>?;

    return ProductData(
      json['photo'] == null || json['photo'].toString().isEmpty
          ? null
          : ApiConfig.resolveMediaUrl(json['photo'].toString()),
      json['nom'].toString(),
      double.parse(json['prix'].toString()).round(),
      (json['description'] ?? 'Préparé avec soin par nos vendeurs.').toString(),
      complements.map((item) => item.name).toList(),
      json['disponible'] == true,
      json['disponible'] == true ? 'Disponible' : 'Indisponible',
      id: int.tryParse(json['id'].toString()),
      vendorId: vendor == null ? null : int.tryParse(vendor['id'].toString()),
      vendorName: vendor?['nom_boutique']?.toString(),
      complements: complements,
    );
  }
}

class HomeComplement {
  const HomeComplement(this.id, this.name);
  final int id;
  final String name;

  factory HomeComplement.fromJson(Map<String, dynamic> json) =>
      HomeComplement(int.parse(json['id'].toString()), json['nom'].toString());
}

class HomeAnnouncement {
  const HomeAnnouncement({
    required this.type,
    required this.label,
    required this.title,
    required this.description,
    this.imageUrl,
  });
  final String type;
  final String label;
  final String title;
  final String description;
  final String? imageUrl;

  factory HomeAnnouncement.fromJson(Map<String, dynamic> json) {
    final product = json['produit'] as Map<String, dynamic>?;
    final image = json['image']?.toString().trim().isNotEmpty == true
        ? json['image'].toString()
        : product?['photo']?.toString();
    return HomeAnnouncement(
      type: json['type']?.toString() ?? 'promotion',
      label: json['etiquette']?.toString().trim().isNotEmpty == true
          ? json['etiquette'].toString()
          : 'À découvrir',
      title: json['titre'].toString(),
      description: json['description']?.toString() ?? '',
      imageUrl: image == null || image.isEmpty
          ? null
          : ApiConfig.resolveMediaUrl(image),
    );
  }
}

class HomeReview {
  const HomeReview({
    required this.name,
    required this.rating,
    required this.comment,
  });
  final String name;
  final int rating;
  final String comment;
  String get initials => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  factory HomeReview.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    final user = client?['user'] as Map<String, dynamic>?;
    return HomeReview(
      name: user?['name']?.toString() ?? 'Client Hot Koki',
      rating: int.tryParse(json['note'].toString()) ?? 0,
      comment: json['commentaire']?.toString() ?? '',
    );
  }
}

class HomeContent {
  const HomeContent({required this.announcements, required this.reviews});
  final List<HomeAnnouncement> announcements;
  final List<HomeReview> reviews;
}

class HomeApi {
  static Future<HomeContent> fetch() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/accueil'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Accueil indisponible');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return HomeContent(
      announcements: (body['annonces'] as List<dynamic>? ?? [])
          .map(
            (item) => HomeAnnouncement.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      reviews: (body['avis'] as List<dynamic>? ?? [])
          .map((item) => HomeReview.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CatalogueApi {
  static Future<List<ProductData>> fetchProducts(bool authenticated) async {
    final dynamic raw = authenticated
        ? await ClientApi.request('GET', '/client/catalogue')
        : jsonDecode(
            (await http
                    .get(Uri.parse('${ApiConfig.baseUrl}/catalogue'))
                    .timeout(const Duration(seconds: 8)))
                .body,
          );
    final body = raw as Map<String, dynamic>;
    return (body['produits'] as List<dynamic>)
        .map((item) => ProductData.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onAdd});

  final ProductData product;
  final VoidCallback onAdd;

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
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: HotKokiColors.flame100,
                borderRadius: BorderRadius.circular(15),
              ),
              child: product.photoUrl == null
                  ? const Icon(
                      Icons.restaurant_rounded,
                      color: HotKokiColors.flame600,
                      size: 27,
                    )
                  : Image.network(
                      product.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: HotKokiColors.inkSoft,
                      ),
                    ),
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
                        onTap: product.available ? onAdd : null,
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
  const _ReviewsList({required this.reviews, required this.loading});
  final List<HomeReview> reviews;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 118,
        child: AppLoadingState(
          label: 'Chargement des derniers avis…',
          compact: true,
        ),
      );
    }
    if (reviews.isEmpty) {
      return const SizedBox(
        height: 220,
        child: AppEmptyState(
          title: 'Pas encore d’avis',
          message: 'Les avis publiés après livraison apparaîtront ici.',
          icon: Icons.reviews_outlined,
        ),
      );
    }

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
                        review.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      review.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${List.filled(review.rating, '★').join()}${List.filled(5 - review.rating, '☆').join()}',
                      style: const TextStyle(
                        color: HotKokiColors.flame600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  review.comment,
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
