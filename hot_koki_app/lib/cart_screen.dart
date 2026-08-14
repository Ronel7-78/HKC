import 'package:flutter/material.dart';

import 'client_screens.dart';
import 'app_feedback.dart';

const _leaf900 = Color(0xFF242424);
const _leaf100 = Color(0xFFF2F4F7);
const _flame600 = Color(0xFFD92D20);
const _inkSoft = Color(0xFF667085);

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
}

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedBuilder(
      animation: CartStore.instance,
      builder: (context, _) {
        final cart = CartStore.instance;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Mon panier',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (cart.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  cart.items.first.vendorName,
                  style: const TextStyle(color: _inkSoft),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: cart.items.isEmpty
                  ? const _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _CartLine(item: cart.items[index]),
                    ),
            ),
            if (cart.items.isNotEmpty) _CartSummary(cart: cart),
          ],
        );
      },
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
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 52,
            height: 52,
            child: item.photo == null
                ? const ColoredBox(
                    color: _leaf100,
                    child: Icon(Icons.restaurant, color: _leaf900),
                  )
                : Image.network(item.photo!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 11),
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
              Text(
                '${item.unitPrice * item.quantity} F CFA',
                style: const TextStyle(
                  color: _flame600,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _QuantityButton(
          icon: Icons.remove,
          onPressed: () => CartStore.instance.changeQuantity(item.key, -1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: () => CartStore.instance.changeQuantity(item.key, 1),
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
    onPressed: onPressed,
    icon: Icon(icon, size: 17),
  );
}

class _CartSummary extends StatelessWidget {
  const _CartSummary({required this.cart});
  final CartStore cart;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 15, 20, 18),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${cart.count} article${cart.count > 1 ? 's' : ''}'),
            Text(
              '${cart.total} F CFA',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _preview;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() {
    final client = _profile!['client'] as Map<String, dynamic>;
    final items = CartStore.instance.items;
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
      'adresse_livraison': client['adresse_texte'],
      'latitude_client': client['latitude'],
      'longitude_client': client['longitude'],
    };
  }

  Future<void> _load() async {
    try {
      _profile =
          await ClientApi.request('GET', '/client/profile')
              as Map<String, dynamic>;
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
    if (_phone.text.trim().isEmpty) {
      setState(() => _error = 'Renseignez le numéro MTN MoMo à débiter.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created =
          await ClientApi.request('POST', '/commandes', body: _payload())
              as Map<String, dynamic>;
      final order = created['commande'] as Map<String, dynamic>;
      CartStore.instance.clear();
      final result =
          await ClientApi.request(
                'POST',
                '/commandes/${order['id']}/paiements',
                body: {
                  'fournisseur': 'mtn_momo',
                  'telephone': _phone.text.trim(),
                },
              )
              as Map<String, dynamic>;
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            payment: result['paiement'] as Map<String, dynamic>,
          ),
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFFDFC),
    appBar: AppBar(title: const Text('Valider la commande')),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _flame600))
        : _preview == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error ?? 'Aperçu indisponible',
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            ),
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: _flame600),
                  title: Text(
                    (_profile!['client'] as Map)['adresse_texte'].toString(),
                  ),
                  subtitle: Text(
                    '${(_preview!['vendeur'] as Map)['nom_boutique']} · ${(_preview!['vendeur'] as Map)['distance_km']} km',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Paiement MTN MoMo',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro à débiter',
                  hintText: '6XXXXXXXX',
                  prefixIcon: Icon(Icons.phone_android),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              _AmountLine(label: 'Sous-total', value: _preview!['sous_total']),
              _AmountLine(
                label: 'Livraison',
                value: _preview!['frais_livraison'],
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Commander et payer'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le paiement n’est confirmé qu’après le statut final de MTN.',
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
