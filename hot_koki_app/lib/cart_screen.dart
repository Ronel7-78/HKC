import 'package:flutter/material.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf100 = Color(0xFFE7EEE4);
const _cream = Color(0xFFFBF4E1);
const _flame600 = Color(0xFFC9491E);
const _inkSoft = Color(0xFF6B5F4E);

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
  int get total => _items.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);
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
                      itemBuilder: (_, index) => _CartLine(item: cart.items[index]),
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(item.complementName, style: const TextStyle(color: _inkSoft, fontSize: 11)),
              Text(
                '${item.unitPrice * item.quantity} F CFA',
                style: const TextStyle(color: _flame600, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        _QuantityButton(icon: Icons.remove, onPressed: () => CartStore.instance.changeQuantity(item.key, -1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        _QuantityButton(icon: Icons.add, onPressed: () => CartStore.instance.changeQuantity(item.key, 1)),
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
            Text('${cart.total} F CFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Validation et paiement : prochaine étape.')),
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
