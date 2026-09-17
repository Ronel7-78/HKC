import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'admin_screens.dart';
import 'app_feedback.dart';
import 'app_preferences.dart';
import 'app_states.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';
import 'client_screens.dart';
import 'notifications_screen.dart';
import 'local_notification_service.dart';
import 'push_notification_service.dart';
import 'seller_screens.dart';
import 'vendor_screens.dart';
import 'vendor_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await AppPreferences.instance.load().timeout(const Duration(seconds: 3));
  } catch (_) {
    // Les préférences ne doivent jamais empêcher l'application de démarrer.
  }
  runApp(const HotKokiApp());
  unawaited(LocalNotificationService.initializeSafely());
  unawaited(PushNotificationService.initializeSafely());
}

class HotKokiApp extends StatelessWidget {
  const HotKokiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferences.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hot Koki Chaud',
        locale: AppPreferences.instance.locale,
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
          child: child!,
        ),
        theme: HotKokiTheme.light,
        // Mode sombre désactivé jusqu'à validation de sa direction visuelle.
        // darkTheme: HotKokiTheme.dark,
        // themeMode: AppPreferences.instance.themeMode,
        home: const MainShell(),
      ),
    );
  }
}

enum UserRole { client, vendeur, admin }

class HotKokiColors {
  static const leaf900 = Color(0xFF1F3524);
  static const leaf700 = Color(0xFF2E4E36);
  static const leaf100 = Color(0xFFE7EEE4);
  static const cream = Color(0xFFFAF9F7);
  static const cream2 = Color(0xFFF4F3F1);
  static const flame600 = Color(0xFFD94B16);
  static const flame500 = Color(0xFFF06424);
  static const flame100 = Color(0xFFFFF0E7);
  static const muted100 = Color(0xFFE8E5E1);
  static const ink = Color(0xFF211F1D);
  static const inkSoft = Color(0xFF6B6864);
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
      appBarTheme: const AppBarTheme(
        backgroundColor: HotKokiColors.cream2,
        foregroundColor: HotKokiColors.leaf900,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: HotKokiColors.muted100),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HotKokiColors.muted100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HotKokiColors.muted100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: HotKokiColors.flame500,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: HotKokiColors.flame100,
        elevation: 8,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HotKokiColors.cream,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: HotKokiColors.muted100,
        thickness: 1,
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

  // La définition du thème sombre sera recréée après discussion et validation
  // de la palette. L'application reste explicitement sur ce thème clair.
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
  int _ordersGeneration = 0;
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
          if (_role == UserRole.vendeur) {
            unawaited(VendorLocationService.start());
          }
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
    unawaited(VendorLocationService.stop());
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
    if (_role == UserRole.vendeur) {
      unawaited(VendorLocationService.start());
    }
  }

  void _startNotificationRefresh() {
    _notificationTimer?.cancel();
    unawaited(PushNotificationService.registerAuthenticatedDevice());
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => NotificationStore.refresh(),
    );
  }

  void _showClientOrders() {
    if (!mounted) return;
    setState(() {
      _ordersGeneration++;
      _currentIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    });
  }

  void _openCart() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartScreen(onShowOrders: _showClientOrders),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      if (_role == UserRole.client && index == 1) {
        _ordersGeneration++;
      }
    });
    if ((_role == UserRole.client && index == 3) ||
        (_role == UserRole.vendeur && index == 2)) {
      unawaited(NotificationStore.refresh());
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    unawaited(VendorLocationService.stop());
    super.dispose();
  }

  List<AppTab> get _tabs {
    if (_role == null) {
      return [
        AppTab(
          context.tr('home'),
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
            context.tr('home'),
            Icons.home_rounded,
            ClientHomeScreen(userName: _userName, onCart: _openCart),
          ),
          AppTab(
            context.tr('order'),
            Icons.receipt_long_rounded,
            ClientOrdersScreen(key: ValueKey(_ordersGeneration)),
          ),
          AppTab(
            context.tr('search'),
            Icons.search_rounded,
            VendorSearchScreen(onShowOrders: _showClientOrders),
          ),
          AppTab(
            context.tr('notification'),
            Icons.notifications_rounded,
            NotificationsScreen(),
          ),
          AppTab(
            context.tr('account'),
            Icons.person_rounded,
            ClientAccountScreen(onLogout: _logout),
          ),
        ];
      case UserRole.vendeur:
        return [
          AppTab(
            context.tr('dashboard'),
            Icons.dashboard_rounded,
            const SellerDashboardScreen(),
          ),
          AppTab(
            context.tr('orders'),
            Icons.receipt_long_rounded,
            const SellerOrdersScreen(),
          ),
          AppTab(
            context.tr('notifications'),
            Icons.notifications_rounded,
            NotificationsScreen(),
          ),
          AppTab(
            context.tr('products'),
            Icons.inventory_2_rounded,
            const SellerProductsScreen(),
          ),
          AppTab(
            context.tr('account'),
            Icons.storefront_rounded,
            SellerAccountScreen(onLogout: _logout),
          ),
        ];
      case UserRole.admin:
        return [
          AppTab(
            context.tr('dashboard'),
            Icons.dashboard_rounded,
            const AdminDashboardScreen(),
          ),
          AppTab(
            context.tr('vendors'),
            Icons.storefront_rounded,
            const AdminVendorsScreen(),
          ),
          AppTab(
            context.tr('catalog'),
            Icons.restaurant_menu_rounded,
            const AdminCatalogueScreen(),
          ),
          AppTab(
            context.tr('orders'),
            Icons.receipt_long_rounded,
            const AdminOrdersScreen(),
          ),
          AppTab(
            context.tr('account'),
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
        onSelected: _selectTab,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        return NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(
                fontSize: compact ? 9 : 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child: NavigationBar(
            height: compact ? 70 : 78,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: HotKokiColors.flame100,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: tabs.map((tab) {
              final primary = tab.icon == Icons.search_rounded;
              Widget withBadge(Widget icon) {
                if (tab.icon != Icons.notifications_rounded) return icon;
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
          ),
        );
      },
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
  String _deliveryMode = 'standard';

  @override
  void initState() {
    super.initState();
    _products = CatalogueApi.fetchProducts(
      widget.userName != null,
      _deliveryMode,
    );
    _content = HomeApi.fetch();
    _deliveryAddress = _loadDeliveryAddress();
  }

  @override
  void didUpdateWidget(covariant ClientHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userName != widget.userName) {
      _deliveryAddress = _loadDeliveryAddress();
      _products = CatalogueApi.fetchProducts(
        widget.userName != null,
        _deliveryMode,
      );
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
    HomeVendorOption? selectedVendor;
    if (product.vendors.length == 1) {
      selectedVendor = product.vendors.first;
    } else if (product.vendors.length > 1) {
      selectedVendor = await showModalBottomSheet<HomeVendorOption>(
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
                  'Choisissez votre vendeur',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Classés par proximité. Vous gardez toujours le choix.',
                  style: TextStyle(color: HotKokiColors.inkSoft),
                ),
                const SizedBox(height: 8),
                ...product.vendors.map(
                  (vendor) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.storefront_rounded),
                    ),
                    title: Text(vendor.name),
                    subtitle: Text(
                      '${vendor.distance?.toStringAsFixed(1) ?? '—'} km · ★ ${vendor.rating.toStringAsFixed(1)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, vendor),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selectedVendor == null || !mounted) return;
    }
    final complement = await showModalBottomSheet<HomeComplement>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisissez un complément',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: product.complements.length,
                    itemBuilder: (context, index) {
                      final item = product.complements[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.radio_button_unchecked,
                          color: HotKokiColors.flame600,
                        ),
                        title: Text(item.name),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (complement == null || !mounted) return;
    CartStore.instance.setDeliveryMode(_deliveryMode);
    final added = CartStore.instance.add(
      CartItem(
        vendorId: selectedVendor?.id ?? product.vendorId!,
        vendorName: selectedVendor?.name ?? product.vendorName!,
        productId: product.id!,
        productName: product.name,
        unitPrice: product.price,
        complementId: complement.id,
        complementName: complement.name,
        photo: product.photoUrl,
        vendorType: 'ambulant',
      ),
    );
    if (!mounted) return;
    if (added) {
      widget.onCart?.call();
    } else {
      await AppFeedback.error(
        context,
        message: 'Terminez d’abord le panier du vendeur actuel.',
      );
    }
  }

  Future<void> _openAnnouncement(HomeAnnouncement announcement) async {
    if (announcement.productId == null) return;
    try {
      final products = await _products;
      final matches = products.where(
        (product) => product.id == announcement.productId,
      );
      if (!mounted) return;
      if (matches.isEmpty) {
        await AppFeedback.error(
          context,
          message: 'Ce plat n’est pas disponible actuellement.',
        );
        return;
      }
      await _addFromHome(matches.first);
    } catch (_) {
      if (mounted) {
        await AppFeedback.error(
          context,
          message: 'Impossible d’ouvrir cette offre pour le moment.',
        );
      }
    }
  }

  void _openAllReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PublicReviewsScreen()),
    );
  }

  Future<void> _selectDeliveryMode(String mode) async {
    if (mode == _deliveryMode) return;
    if (mode == 'express') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.bolt_rounded,
            color: HotKokiColors.flame600,
            size: 38,
          ),
          title: const Text('Livraison express'),
          content: const Text(
            'Un point de vente fixe disponible prendra la commande en priorité. Des frais fixes de 500 FCFA seront ajoutés.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() {
      _deliveryMode = mode;
      _products = CatalogueApi.fetchProducts(widget.userName != null, mode);
    });
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
                    onTap: _openAnnouncement,
                  ),
                ),
                const SizedBox(height: 22),
                _HomeDeliveryMode(
                  selected: _deliveryMode,
                  onChanged: _selectDeliveryMode,
                ),
                const SizedBox(height: 22),
                const _SectionHeader(
                  title: 'Le menu du jour',
                  action: 'Glissez pour découvrir',
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
                        _deliveryMode,
                      );
                      _content = HomeApi.fetch();
                    }),
                  );
                }
                final products = snapshot.data ?? const <ProductData>[];
                if (products.isEmpty) {
                  return const AppEmptyState(
                    title: 'Le menu arrive bientôt',
                    message: 'Aucun plat réel n’est disponible actuellement.',
                    icon: Icons.restaurant_menu_rounded,
                  );
                }
                return SizedBox(
                  height: 342,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 13),
                    itemBuilder: (_, index) => SizedBox(
                      width:
                          MediaQuery.sizeOf(context).width.clamp(280, 340) *
                          .82,
                      child: ProductCard(
                        product: products[index],
                        onAdd: () => _addFromHome(products[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: FutureBuilder<HomeContent>(
              future: _content,
              builder: (context, snapshot) => _FixedPointsSection(
                points: snapshot.data?.fixedPoints ?? const [],
                authenticated: widget.userName != null,
                onLogin: widget.onLogin,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
            sliver: SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Ils parlent de nous',
                action: 'Voir tous les avis',
                onAction: _openAllReviews,
              ),
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

class _FixedPointsSection extends StatelessWidget {
  const _FixedPointsSection({
    required this.points,
    required this.authenticated,
    this.onLogin,
  });
  final List<HomeFixedPoint> points;
  final bool authenticated;
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 20, bottom: 9),
            child: _SectionHeader(
              title: 'Points de vente',
              action: 'À découvrir près de vous',
            ),
          ),
          SizedBox(
            height: 184,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final point = points[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    if (!authenticated) return onLogin?.call();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VendorDetailScreen(vendorId: point.id),
                      ),
                    );
                  },
                  child: Container(
                    width: 244,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: HotKokiColors.muted100),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -18,
                          top: -20,
                          child: Container(
                            width: 112,
                            height: 112,
                            decoration: const BoxDecoration(
                              color: HotKokiColors.flame100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: HotKokiColors.flame500,
                              size: 49,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: HotKokiColors.leaf100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'POINT FIXE',
                                  style: TextStyle(
                                    color: HotKokiColors.leaf700,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                point.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: HotKokiColors.leaf900,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${point.products} plat${point.products > 1 ? 's' : ''} disponible${point.products > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: HotKokiColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (point.express)
                                    const _MiniFeature(
                                      icon: Icons.bolt_rounded,
                                      label: 'Livraison Express',
                                    ),
                                  const Spacer(),
                                  const Text(
                                    'Voir la boutique',
                                    style: TextStyle(
                                      color: HotKokiColors.flame600,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 15,
                                    color: HotKokiColors.flame600,
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
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: HotKokiColors.flame600),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          color: HotKokiColors.flame600,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _HomeDeliveryMode extends StatelessWidget {
  const _HomeDeliveryMode({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Comment recevoir votre commande ? (Type de Livraison)',
        style: TextStyle(
          color: HotKokiColors.leaf900,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 9),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'standard',
            icon: Icon(Icons.local_shipping_outlined),
            label: Text('Standard'),
          ),
          ButtonSegment(
            value: 'express',
            icon: Icon(Icons.bolt_rounded),
            label: Text('Express'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (values) => onChanged(values.first),
      ),
      const SizedBox(height: 6),
      Text(
        selected == 'express'
            ? '500 FCFA · assuré par un point de vente fixe'
            : '0 FCFA · livraison par un vendeur ambulant',
        style: const TextStyle(color: HotKokiColors.inkSoft, fontSize: 11),
      ),
    ],
  );
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

class _Announcements extends StatefulWidget {
  const _Announcements({required this.announcements, required this.onTap});
  final List<HomeAnnouncement> announcements;
  final ValueChanged<HomeAnnouncement> onTap;

  @override
  State<_Announcements> createState() => _AnnouncementsState();
}

class _AnnouncementsState extends State<_Announcements> {
  final _controller = PageController(viewportFraction: .94);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _Announcements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.announcements.length != widget.announcements.length) {
      _index = 0;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.announcements.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.announcements.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcements.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 184,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.announcements.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.only(right: 9),
              child: _AnnouncementCard(
                announcement: widget.announcements[index],
                onTap: () => widget.onTap(widget.announcements[index]),
              ),
            ),
          ),
        ),
        if (widget.announcements.length > 1) ...[
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.announcements.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == _index ? 20 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: index == _index
                      ? HotKokiColors.flame500
                      : HotKokiColors.muted100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement, required this.onTap});
  final HomeAnnouncement announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: HotKokiColors.leaf900,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: announcement.productId == null ? null : onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (announcement.imageUrl != null)
            Image.network(
              announcement.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF21F3524),
                  Color(0xA61F3524),
                  Color(0x221F3524),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          announcement.label.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        announcement.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (announcement.productId != null) ...[
                        const SizedBox(height: 10),
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Commander maintenant',
                              style: TextStyle(
                                color: Color(0xFFFFB28E),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFFFFB28E),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HotKokiColors.leaf900,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onAction,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    color: HotKokiColors.flame600,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (onAction != null) ...[
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: HotKokiColors.flame600,
                  ),
                ],
              ],
            ),
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
    this.vendors = const [],
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
  final List<HomeVendorOption> vendors;

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
      vendors:
          (json['vendeurs_disponibles'] is List
                  ? json['vendeurs_disponibles'] as List<dynamic>
                  : const <dynamic>[])
              .map(
                (item) =>
                    HomeVendorOption.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }
}

class HomeVendorOption {
  const HomeVendorOption({
    required this.id,
    required this.name,
    this.distance,
    required this.rating,
  });
  final int id;
  final String name;
  final double? distance;
  final double rating;

  factory HomeVendorOption.fromJson(Map<String, dynamic> json) =>
      HomeVendorOption(
        id: int.parse(json['id'].toString()),
        name: json['nom_boutique'].toString(),
        distance: double.tryParse(json['distance_km']?.toString() ?? ''),
        rating: double.tryParse(json['note_moyenne']?.toString() ?? '') ?? 0,
      );
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
    this.productId,
  });
  final String type;
  final String label;
  final String title;
  final String description;
  final String? imageUrl;
  final int? productId;

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
      productId: int.tryParse(
        (json['produit_id'] ?? product?['id'] ?? '').toString(),
      ),
    );
  }
}

class HomeReview {
  const HomeReview({
    required this.name,
    required this.rating,
    required this.comment,
    required this.vendorName,
    required this.createdAt,
  });
  final String name;
  final int rating;
  final String comment;
  final String? vendorName;
  final DateTime? createdAt;
  String get initials => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  factory HomeReview.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    final user = client?['user'] as Map<String, dynamic>?;
    final vendor = json['vendeur'] as Map<String, dynamic>?;
    return HomeReview(
      name: user?['name']?.toString() ?? 'Client Hot Koki',
      rating: int.tryParse(json['note'].toString()) ?? 0,
      comment: json['commentaire']?.toString() ?? '',
      vendorName: vendor?['nom_boutique']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class HomeContent {
  const HomeContent({
    required this.announcements,
    required this.reviews,
    required this.fixedPoints,
  });
  final List<HomeAnnouncement> announcements;
  final List<HomeReview> reviews;
  final List<HomeFixedPoint> fixedPoints;
}

class HomeFixedPoint {
  const HomeFixedPoint({
    required this.id,
    required this.name,
    required this.express,
    required this.products,
  });
  final String id;
  final String name;
  final bool express;
  final int products;

  factory HomeFixedPoint.fromJson(Map<String, dynamic> json) => HomeFixedPoint(
    id: apiResourceId(json),
    name: json['nom_boutique'].toString(),
    express: json['accepte_express'] == true,
    products: int.tryParse(json['produits_disponibles_count'].toString()) ?? 0,
  );
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
      fixedPoints: (body['points_fixes'] as List<dynamic>? ?? [])
          .map((item) => HomeFixedPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<List<HomeReview>> fetchReviews() async {
    final response = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/avis-publics?par_page=50'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Avis indisponibles');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>? ?? [])
        .map((item) => HomeReview.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class PublicReviewsScreen extends StatefulWidget {
  const PublicReviewsScreen({super.key});

  @override
  State<PublicReviewsScreen> createState() => _PublicReviewsScreenState();
}

class _PublicReviewsScreenState extends State<PublicReviewsScreen> {
  late Future<List<HomeReview>> _future = HomeApi.fetchReviews();

  Future<void> _reload() async {
    setState(() => _future = HomeApi.fetchReviews());
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tous les avis')),
    body: FutureBuilder<List<HomeReview>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingState(label: 'Chargement des avis…');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'Avis indisponibles',
            message: 'Vérifiez votre connexion puis réessayez.',
            onRetry: _reload,
          );
        }
        final reviews = snapshot.data ?? const [];
        if (reviews.isEmpty) {
          return const AppEmptyState(
            title: 'Pas encore d’avis',
            message: 'Les premiers commentaires apparaîtront ici.',
            icon: Icons.reviews_outlined,
          );
        }
        final average =
            reviews.fold<int>(0, (sum, item) => sum + item.rating) /
            reviews.length;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            itemCount: reviews.length + 1,
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 18 : 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HotKokiColors.leaf900,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '★★★★★',
                              style: TextStyle(
                                color: Color(0xFFFFB28E),
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '${reviews.length} commentaire${reviews.length > 1 ? 's' : ''} publié${reviews.length > 1 ? 's' : ''}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return _FullReviewCard(review: reviews[index - 1]);
            },
          ),
        );
      },
    ),
  );
}

class _FullReviewCard extends StatelessWidget {
  const _FullReviewCard({required this.review});
  final HomeReview review;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: HotKokiColors.leaf700,
                child: Text(
                  review.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (review.vendorName != null)
                      Text(
                        review.vendorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HotKokiColors.inkSoft,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                List.filled(review.rating, '★').join(),
                style: const TextStyle(color: HotKokiColors.flame600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment, style: const TextStyle(height: 1.45)),
        ],
      ),
    ),
  );
}

class CatalogueApi {
  static Future<List<ProductData>> fetchProducts(
    bool authenticated, [
    String mode = 'standard',
  ]) async {
    final dynamic raw = authenticated
        ? await ClientApi.request('GET', '/client/catalogue?mode=$mode')
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
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: HotKokiColors.muted100),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 178,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: HotKokiColors.flame100,
                    child: product.photoUrl == null
                        ? const Icon(
                            Icons.restaurant_rounded,
                            color: HotKokiColors.flame600,
                            size: 54,
                          )
                        : Image.network(
                            product.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: HotKokiColors.inkSoft,
                              size: 42,
                            ),
                          ),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _AvailabilityBadge(available: product.available),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${product.vendors.length} vendeur${product.vendors.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: HotKokiColors.leaf900,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HotKokiColors.leaf900,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${product.price} FCFA',
                          style: const TextStyle(
                            color: HotKokiColors.flame600,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HotKokiColors.inkSoft,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: product.available ? onAdd : null,
                        icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                        label: const Text('Commander'),
                        style: FilledButton.styleFrom(
                          backgroundColor: HotKokiColors.flame500,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
