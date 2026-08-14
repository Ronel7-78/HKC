import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_feedback.dart';
import 'cart_screen.dart';

const _leaf900 = Color(0xFF242424);
const _leaf700 = Color(0xFF475467);
const _leaf100 = Color(0xFFF2F4F7);
const _cream2 = Color(0xFFFFFDFC);
const _flame600 = Color(0xFFD92D20);
const _flame500 = Color(0xFFE5483B);
const _inkSoft = Color(0xFF667085);

class VendorData {
  const VendorData({
    required this.id,
    required this.name,
    required this.address,
    required this.rating,
    required this.distance,
    required this.products,
  });
  final int id;
  final String name;
  final String address;
  final double rating;
  final double? distance;
  final List<VendorProduct> products;

  factory VendorData.fromJson(Map<String, dynamic> json) => VendorData(
    id: int.parse(json['id'].toString()),
    name: json['nom_boutique'].toString(),
    address: (json['adresse_texte'] ?? 'Adresse non renseignée').toString(),
    rating: double.tryParse(json['note_moyenne'].toString()) ?? 0,
    distance: double.tryParse(json['distance_km']?.toString() ?? ''),
    products: (json['produits'] as List<dynamic>? ?? [])
        .map((item) => VendorProduct.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class VendorProduct {
  const VendorProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.photo,
    required this.complements,
  });
  final int id;
  final String name;
  final String description;
  final int price;
  final String? photo;
  final List<ProductComplement> complements;

  factory VendorProduct.fromJson(Map<String, dynamic> json) => VendorProduct(
    id: int.parse(json['id'].toString()),
    name: json['nom'].toString(),
    description: (json['description'] ?? 'Préparé avec soin.').toString(),
    price: double.parse(json['prix'].toString()).round(),
    photo: json['photo'] == null
        ? null
        : ApiConfig.resolveMediaUrl(json['photo'].toString()),
    complements: (json['complements'] as List<dynamic>? ?? [])
        .map((item) => ProductComplement.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class ProductComplement {
  const ProductComplement({required this.id, required this.name});
  final int id;
  final String name;

  factory ProductComplement.fromJson(Map<String, dynamic> json) =>
      ProductComplement(
        id: int.parse(json['id'].toString()),
        name: json['nom'].toString(),
      );
}

class VendorApi {
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'auth_token');
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<VendorData>> nearby([String query = '']) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/client/vendeurs').replace(
      queryParameters: query.trim().isEmpty ? null : {'q': query.trim()},
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Recherche indisponible');
    }
    return (body['vendeurs'] as List<dynamic>)
        .map((item) => VendorData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<VendorData> show(int id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/client/vendeurs/$id'),
      headers: await _headers(),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(body['message'] ?? 'Vendeur indisponible');
    }
    return VendorData.fromJson(body['vendeur'] as Map<String, dynamic>);
  }
}

class VendorSearchScreen extends StatefulWidget {
  const VendorSearchScreen({super.key});

  @override
  State<VendorSearchScreen> createState() => _VendorSearchScreenState();
}

class _VendorSearchScreenState extends State<VendorSearchScreen> {
  final _search = TextEditingController();
  late Future<List<VendorData>> _vendors;

  @override
  void initState() {
    super.initState();
    _vendors = VendorApi.nearby();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _vendors = VendorApi.nearby(_search.text));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AUTOUR DE VOUS',
                  style: TextStyle(
                    color: _flame600,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Trouver un vendeur',
                  style: TextStyle(
                    color: _leaf900,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _reload(),
                  decoration: InputDecoration(
                    hintText: 'Vendeur, quartier ou produit…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: _reload,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<VendorData>>(
              future: _vendors,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _flame500),
                  );
                }
                if (snapshot.hasError) {
                  return _MessageState(
                    message: snapshot.error.toString().replaceFirst(
                      'Exception: ',
                      '',
                    ),
                    onRetry: _reload,
                  );
                }
                final vendors = snapshot.data ?? [];
                if (vendors.isEmpty) {
                  return const _MessageState(
                    message: 'Aucun vendeur disponible pour le moment.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                    itemCount: vendors.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 11),
                    itemBuilder: (context, index) =>
                        _VendorCard(vendor: vendors[index]),
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

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});
  final VendorData vendor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VendorDetailScreen(vendorId: vendor.id),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: _leaf100,
              child: Icon(Icons.storefront, color: _leaf700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    vendor.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _inkSoft, fontSize: 11),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Disponible · ⭐ ${vendor.rating.toStringAsFixed(1)} · ${vendor.products.length} plats',
                    style: const TextStyle(
                      color: _leaf700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (vendor.distance != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBD9C4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${vendor.distance!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: _flame600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VendorDetailScreen extends StatelessWidget {
  const VendorDetailScreen({super.key, required this.vendorId});
  final int vendorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream2,
      body: FutureBuilder<VendorData>(
        future: VendorApi.show(vendorId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return snapshot.hasError
                ? _MessageState(message: snapshot.error.toString())
                : const Center(
                    child: CircularProgressIndicator(color: _flame500),
                  );
          }
          final vendor = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 190,
                pinned: true,
                foregroundColor: Colors.white,
                backgroundColor: _leaf900,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [_leaf700, _leaf900]),
                    ),
                    child: const Icon(
                      Icons.storefront,
                      size: 90,
                      color: Colors.white12,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.name,
                            style: const TextStyle(
                              fontSize: 22,
                              color: _leaf900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const _StatusPill(),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '⭐ ${vendor.rating.toStringAsFixed(1)}  ·  ${vendor.distance?.toStringAsFixed(1) ?? '—'} km',
                      style: const TextStyle(color: _inkSoft),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      vendor.address,
                      style: const TextStyle(color: _inkSoft),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Produits disponibles',
                      style: TextStyle(
                        fontSize: 17,
                        color: _leaf900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...vendor.products.map(
                      (product) =>
                          _VendorProductCard(vendor: vendor, product: product),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VendorProductCard extends StatelessWidget {
  const _VendorProductCard({required this.vendor, required this.product});
  final VendorData vendor;
  final VendorProduct product;

  Future<void> _addToCart(BuildContext context) async {
    if (product.complements.isEmpty) {
      AppFeedback.error(
        context,
        message: 'Aucun complément disponible pour ce produit.',
      );
      return;
    }
    final complement = await showModalBottomSheet<ProductComplement>(
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _leaf900,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              ...product.complements.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.radio_button_unchecked,
                    color: _flame600,
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
    if (complement == null || !context.mounted) return;
    final added = CartStore.instance.add(
      CartItem(
        vendorId: vendor.id,
        vendorName: vendor.name,
        productId: product.id,
        productName: product.name,
        unitPrice: product.price,
        complementId: complement.id,
        complementName: complement.name,
        photo: product.photo,
      ),
    );
    if (added) {
      await AppFeedback.success(
        context,
        title: 'Ajouté au panier',
        message: '${product.name} a bien été ajouté.',
      );
    } else {
      await AppFeedback.error(
        context,
        message: 'Terminez d’abord le panier du vendeur actuel.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.photo == null
                ? const ColoredBox(
                    color: _leaf100,
                    child: Icon(Icons.restaurant, color: _leaf700),
                  )
                : Image.network(product.photo!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                product.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _inkSoft, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          '${product.price} F',
          style: const TextStyle(color: _flame600, fontWeight: FontWeight.w800),
        ),
        IconButton(
          tooltip: 'Ajouter au panier',
          onPressed: () => _addToCart(context),
          icon: const Icon(Icons.add_circle, color: _flame600),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _flame500,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Disponible',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, size: 42, color: _inkSoft),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inkSoft),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}
