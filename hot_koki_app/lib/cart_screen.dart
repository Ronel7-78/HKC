import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'app_feedback.dart';
import 'app_states.dart';
import 'client_screens.dart';
import 'delivery_fee_info.dart';
import 'payment_method_card.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf100 = Color(0xFFE7EEE4);
const _flame600 = Color(0xFFD94B16);
const _inkSoft = Color(0xFF6B6864);

class CartItem {
  CartItem({
    required this.vendorId,
    required this.vendorName,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.complementId,
    required this.complementName,
    required this.photo,
    this.quantity = 1,
  });

  final int vendorId;
  final String vendorName;
  final int productId;
  final String productName;
  final int unitPrice;
  final int complementId;
  final String complementName;
  final String? photo;
  int quantity;

  String get key => '$productId-$complementId';
}

class CartStore extends ChangeNotifier {
  CartStore._();
  static final instance = CartStore._();
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);
  int get total =>
      _items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);
  int get count => _items.fold(0, (sum, item) => sum + item.quantity);

  bool add(CartItem incoming) {
    if (_items.isNotEmpty && _items.first.vendorId != incoming.vendorId) {
      return false;
    }
    final index = _items.indexWhere((item) => item.key == incoming.key);
    if (index < 0) {
      _items.add(incoming);
    } else if (_items[index].quantity < 20) {
      _items[index].quantity++;
    }
    notifyListeners();
    return true;
  }

  void changeQuantity(String key, int delta) {
    final index = _items.indexWhere((item) => item.key == key);
    if (index < 0) return;
    final quantity = _items[index].quantity + delta;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else if (quantity <= 20) {
      _items[index].quantity = quantity;
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void remove(String key) {
    _items.removeWhere((item) => item.key == key);
    notifyListeners();
  }
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F3F1),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF4F3F1),
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'Mon panier',
        style: TextStyle(color: _leaf900, fontWeight: FontWeight.w800),
      ),
      actions: [
        AnimatedBuilder(
          animation: CartStore.instance,
          builder: (context, _) => CartStore.instance.items.isEmpty
              ? const SizedBox.shrink()
              : TextButton(
                  onPressed: () => CartStore.instance.clear(),
                  child: const Text('Vider'),
                ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: AnimatedBuilder(
        animation: CartStore.instance,
        builder: (context, _) {
          final cart = CartStore.instance;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cart.items.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: _leaf100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, color: _leaf900),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          cart.items.first.vendorName,
                          style: const TextStyle(
                            color: _leaf900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${cart.count} article${cart.count > 1 ? 's' : ''}',
                        style: const TextStyle(color: _inkSoft, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: cart.items.isEmpty
                    ? const _EmptyCart()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: cart.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) =>
                            _CartLine(item: cart.items[index]),
                      ),
              ),
              if (cart.items.isNotEmpty) _CartSummary(cart: cart),
            ],
          );
        },
      ),
    ),
  );
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8E5E1)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D1F3524),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 72,
            height: 72,
            child: item.photo == null
                ? const ColoredBox(
                    color: _leaf100,
                    child: Icon(Icons.restaurant, color: _leaf900),
                  )
                : Image.network(item.photo!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                item.complementName,
                style: const TextStyle(color: _inkSoft, fontSize: 11),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Text(
                    '${item.unitPrice * item.quantity} F CFA',
                    style: const TextStyle(
                      color: _flame600,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  _QuantityButton(
                    icon: Icons.remove,
                    onPressed: () =>
                        CartStore.instance.changeQuantity(item.key, -1),
                  ),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${item.quantity}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _QuantityButton(
                    icon: Icons.add,
                    onPressed: () =>
                        CartStore.instance.changeQuantity(item.key, 1),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Retirer du panier',
          onPressed: () => CartStore.instance.remove(item.key),
          icon: const Icon(Icons.close_rounded, color: _inkSoft, size: 20),
        ),
      ],
    ),
  );
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    padding: EdgeInsets.zero,
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
  );
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});
  final CartStore cart;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A1F3524),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sous-total', style: TextStyle(color: _inkSoft)),
            Text(
              '${cart.total} F CFA',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Livraison', style: TextStyle(color: _inkSoft)),
            Text('Calculée à l’étape suivante', style: TextStyle(fontSize: 11)),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 11),
          child: Divider(height: 1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total provisoire',
              style: TextStyle(color: _leaf900, fontWeight: FontWeight.w800),
            ),
            Text(
              '${cart.total} F CFA',
              style: const TextStyle(
                color: _flame600,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _flame600,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Continuer la commande'),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shopping_basket_outlined, size: 54, color: _inkSoft),
        SizedBox(height: 10),
        Text('Votre panier est vide.', style: TextStyle(color: _inkSoft)),
      ],
    ),
  );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _phone = TextEditingController();
  final _deliveryAddress = TextEditingController();
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _locating = false;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  List<Map<String, dynamic>> _paymentMethods = const [];
  String _provider = 'mtn_momo';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _deliveryAddress.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload([List<CartItem>? source]) {
    final items = source ?? CartStore.instance.items;
    if (items.isEmpty) {
      throw const ApiException(
        'Votre panier est vide. Ajoutez de nouveau les produits après la réinitialisation des données.',
      );
    }
    return {
      'items': items
          .map(
            (item) => {
              'produit_id': item.productId,
              'quantite': item.quantity,
              'complements': [item.complementId],
            },
          )
          .toList(),
      'vendeur_id': items.first.vendorId,
      'adresse_livraison': _deliveryAddress.text.trim(),
      'latitude_client': _deliveryLatitude,
      'longitude_client': _deliveryLongitude,
    };
  }

  Future<void> _load() async {
    try {
      _profile =
          await ClientApi.request('GET', '/client/profile')
              as Map<String, dynamic>;
      final methods = await ClientApi.request('GET', '/paiements-moyens');
      _paymentMethods = (methods as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final client = _profile!['client'] as Map<String, dynamic>;
      _deliveryAddress.text = client['adresse_texte']?.toString() ?? '';
      _deliveryLatitude = double.tryParse(client['latitude']?.toString() ?? '');
      _deliveryLongitude = double.tryParse(
        client['longitude']?.toString() ?? '',
      );
      final preview = await ClientApi.request(
        'POST',
        '/commandes/preview',
        body: _payload(),
      );
      if (mounted) {
        setState(() {
          _preview = preview as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirm() async {
    final cartItems = CartStore.instance.items;
    if (cartItems.isEmpty) {
      setState(() => _error = 'Votre panier est vide. Ajoutez un produit.');
      return;
    }
    if (_deliveryAddress.text.trim().isEmpty ||
        _deliveryLatitude == null ||
        _deliveryLongitude == null) {
      setState(
        () => _error =
            'Renseignez l’adresse de livraison et sa position avant de continuer.',
      );
      return;
    }
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Renseignez le numéro Mobile Money à débiter.');
      return;
    }
    final selected = _paymentMethods.where(
      (method) => method['code'] == _provider,
    );
    if (selected.isEmpty || selected.first['disponible'] != true) {
      setState(
        () => _error = 'Ce moyen de paiement n’est pas encore disponible.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created =
          await ClientApi.request(
                'POST',
                '/commandes',
                body: _payload(cartItems),
              )
              as Map<String, dynamic>;
      final order = created['commande'] as Map<String, dynamic>;
      final result =
          await ClientApi.request(
                'POST',
                '/commandes/${apiResourceId(order)}/paiements',
                body: {
                  'fournisseur': _provider,
                  'telephone': _phone.text.trim(),
                },
              )
              as Map<String, dynamic>;
      CartStore.instance.clear();
      if (!mounted) return;
      final payment = result['paiement'] as Map<String, dynamic>;
      final orangeUrl = Uri.tryParse(payment['url_paiement']?.toString() ?? '');
      if (_provider == 'orange_money' &&
          orangeUrl != null &&
          orangeUrl.scheme == 'https' &&
          orangeUrl.host.isNotEmpty) {
        await launchUrl(orangeUrl, mode: LaunchMode.externalApplication);
        if (!mounted) return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(payment: payment),
        ),
      );
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() {
          _error = message;
          _submitting = false;
        });
        await AppFeedback.error(
          context,
          title: 'Commande non finalisée',
          message: message,
        );
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('La permission de localisation a été refusée.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      var label = 'Position actuelle';
      try {
        final places = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          label =
              [
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                  ]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .toSet()
                  .join(', ');
        }
      } catch (_) {
        // Les coordonnées restent utilisables même sans adresse inversée.
      }
      if (!mounted) return;
      setState(() {
        _deliveryLatitude = position.latitude;
        _deliveryLongitude = position.longitude;
        _deliveryAddress.text = label;
        _locating = false;
      });
      await _refreshPreview();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshPreview() async {
    try {
      final preview = await ClientApi.request(
        'POST',
        '/commandes/preview',
        body: _payload(),
      );
      if (mounted) setState(() => _preview = preview as Map<String, dynamic>);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F3F1),
    appBar: AppBar(title: const Text('Valider la commande')),
    body: _loading
        ? const AppLoadingState(label: 'Calcul de votre commande…')
        : _preview == null
        ? AppErrorState(
            message: _error ?? 'L’aperçu de la commande est indisponible.',
            onRetry: _load,
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Livraison',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: _deliveryAddress,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Adresse de livraison',
                  helperText: 'Vous pouvez la modifier pour cette commande.',
                  prefixIcon: Icon(Icons.location_on, color: _flame600),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _locating
                      ? 'Localisation en cours…'
                      : 'Utiliser ma position actuelle',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${(_preview!['vendeur'] as Map)['nom_boutique']} · ${formatDistanceKm((_preview!['vendeur'] as Map)['distance_km'])}',
                style: const TextStyle(color: _inkSoft, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _preview!['livraison_gratuite'] == true
                      ? _leaf100
                      : const Color(0xFFFFF0E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _preview!['livraison_gratuite'] == true
                          ? Icons.local_shipping_outlined
                          : Icons.route_outlined,
                      color: _preview!['livraison_gratuite'] == true
                          ? _leaf900
                          : _flame600,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: DeliveryFeeLabel(
                        fee: _preview!['frais_livraison'],
                        color: _leaf900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Moyen de paiement',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              ..._paymentMethods.map((method) {
                final available = method['disponible'] == true;
                final selected = _provider == method['code'];
                return PaymentMethodCard(
                  code: method['code'].toString(),
                  name: method['nom'].toString(),
                  selected: selected,
                  available: available,
                  onTap: () =>
                      setState(() => _provider = method['code'].toString()),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro Mobile Money à débiter',
                  hintText: '6XXXXXXXX',
                  prefixIcon: Icon(Icons.phone_android),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _AmountLine(label: 'Sous-total', value: _preview!['sous_total']),
              DeliveryFeeLabel(
                fee: _preview!['frais_livraison'],
                color: _leaf900,
                fontSize: 14,
              ),
              const Divider(),
              _AmountLine(
                label: 'Total',
                value: _preview!['total'],
                strong: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submitting ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: _flame600,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _submitting
                    ? const AppButtonLoading(label: 'Envoi sécurisé…')
                    : const Text('Commander et payer'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le paiement n’est confirmé qu’après le statut final de l’opérateur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _inkSoft, fontSize: 11),
              ),
            ],
          ),
  );
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label;
  final dynamic value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: strong ? FontWeight.w800 : null),
        ),
        Text(
          '${double.tryParse(value.toString())?.round() ?? value} F CFA',
          style: TextStyle(
            color: strong ? _flame600 : _leaf900,
            fontSize: strong ? 18 : 14,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
