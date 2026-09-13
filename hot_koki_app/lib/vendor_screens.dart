import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'app_feedback.dart';
import 'cart_screen.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf700 = Color(0xFF2E4E36);
const _leaf100 = Color(0xFFE7EEE4);
const _cream2 = Color(0xFFF4F3F1);
const _flame600 = Color(0xFFD94B16);
const _flame500 = Color(0xFFF06424);
const _inkSoft = Color(0xFF6B6864);

class VendorData {
  const VendorData({
    required this.id,
    required this.publicId,
    required this.name,
    required this.address,
    required this.rating,
    required this.distance,
    required this.products,
    required this.latitude,
    required this.longitude,
    required this.phone,
  });
  final int id;
  final String publicId;
  final String name;
  final String address;
  final double rating;
  final double? distance;
  final List<VendorProduct> products;
  final double latitude;
  final double longitude;
  final String? phone;

  factory VendorData.fromJson(Map<String, dynamic> json) => VendorData(
    id: int.parse(json['id'].toString()),
    publicId: apiResourceId(json),
    name: json['nom_boutique'].toString(),
    address: (json['adresse_texte'] ?? 'Adresse non renseignée').toString(),
    rating: double.tryParse(json['note_moyenne'].toString()) ?? 0,
    distance: double.tryParse(json['distance_km']?.toString() ?? ''),
    latitude: double.parse(json['latitude'].toString()),
    longitude: double.parse(json['longitude'].toString()),
    phone: (json['user'] as Map<String, dynamic>?)?['telephone']?.toString(),
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

  static Future<VendorData> show(String id) async {
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

class _LegacyVendorSearchScreen extends StatefulWidget {
  const _LegacyVendorSearchScreen();

  @override
  State<_LegacyVendorSearchScreen> createState() =>
      _LegacyVendorSearchScreenState();
}

class _LegacyVendorSearchScreenState extends State<_LegacyVendorSearchScreen> {
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
          builder: (_) => VendorDetailScreen(vendorId: vendor.publicId),
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
                  color: const Color(0xFFF6D2BC),
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

class VendorSearchScreen extends StatefulWidget {
  const VendorSearchScreen({super.key, this.onShowOrders});
  final VoidCallback? onShowOrders;

  @override
  State<VendorSearchScreen> createState() => _VendorMapScreenState();
}

class _VendorMapScreenState extends State<VendorSearchScreen> {
  final _search = TextEditingController();
  final _mapController = MapController();
  List<VendorData> _vendors = const [];
  Position? _position;
  Timer? _refreshTimer;
  Timer? _searchTimer;
  bool _loading = true;
  bool _locating = false;
  int _tileErrors = 0;
  int _tileGeneration = 0;
  String? _error;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _loadPosition();
    _fetchVendors();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchVendors(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    if (_locating) return;
    if (mounted) {
      setState(() {
        _locating = true;
        _locationMessage = null;
      });
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(
          'Activez la localisation du téléphone pour afficher votre position.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          permission == LocationPermission.deniedForever
              ? 'La localisation est bloquée dans les paramètres du téléphone.'
              : 'La permission de localisation a été refusée.',
        );
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() => _position = lastKnown);
        _mapController.move(
          LatLng(lastKnown.latitude, lastKnown.longitude),
          13,
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locating = false;
        _locationMessage = null;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 13);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _locationMessage = error is TimeoutException
            ? 'Le GPS tarde à répondre. La carte reste utilisable ; réessayez à l’extérieur.'
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onTileError(Object tile, Object error, StackTrace? stackTrace) {
    if (_tileErrors >= 6) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tileErrors >= 6) return;
      setState(() => _tileErrors++);
    });
  }

  void _retryTiles() {
    setState(() {
      _tileErrors = 0;
      _tileGeneration++;
    });
  }

  Future<void> _fetchVendors({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final vendors = await VendorApi.nearby(_search.text);
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _loading = false;
        _error = null;
      });
      if (!silent && vendors.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusOnVendors(vendors);
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _focusOnVendors(List<VendorData> vendors) {
    if (vendors.length == 1) {
      _mapController.move(
        LatLng(vendors.first.latitude, vendors.first.longitude),
        15,
      );
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: vendors
            .map((vendor) => LatLng(vendor.latitude, vendor.longitude))
            .toList(),
        padding: const EdgeInsets.fromLTRB(48, 150, 48, 80),
        maxZoom: 15,
      ),
    );
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 450), _fetchVendors);
  }

  LatLng get _initialCenter {
    if (_position != null) {
      return LatLng(_position!.latitude, _position!.longitude);
    }
    if (_vendors.isNotEmpty) {
      return LatLng(_vendors.first.latitude, _vendors.first.longitude);
    }
    return const LatLng(4.0511, 9.7679);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        ColoredBox(
          color: const Color(0xFFE7EEE4),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 12,
              minZoom: 4,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                key: ValueKey(_tileGeneration),
                urlTemplate: ApiConfig.mapTileUrl,
                fallbackUrl: ApiConfig.mapFallbackTileUrl,
                userAgentPackageName: 'com.hotkoki.app',
                errorTileCallback: _onTileError,
              ),
              MarkerLayer(
                markers: [
                  if (_position != null)
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 7),
                          ],
                        ),
                      ),
                    ),
                  ..._vendors.map(
                    (vendor) => Marker(
                      point: LatLng(vendor.latitude, vendor.longitude),
                      width: 70,
                      height: 70,
                      child: _VendorMapAvatar(
                        vendor: vendor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VendorDetailScreen(
                              vendorId: vendor.publicId,
                              onShowOrders: widget.onShowOrders,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('Humanitarian OpenStreetMap Team'),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  elevation: 5,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(18),
                  child: TextField(
                    controller: _search,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _fetchVendors(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Nom du vendeur ou menu…',
                      prefixIcon: const Icon(Icons.search, color: _leaf700),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                _fetchVendors();
                              },
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _loading
                          ? 'Recherche…'
                          : '${_vendors.length} vendeur${_vendors.length > 1 ? 's' : ''} disponible${_vendors.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: _leaf900,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _flame500)),
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MapMessage(
              message: _error!,
              onRetry: () => _fetchVendors(),
            ),
          )
        else if (_tileErrors >= 6)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MapMessage(
              message:
                  'Le fond de carte ne répond pas. Vérifiez la connexion puis réessayez.',
              onRetry: _retryTiles,
            ),
          )
        else if (_locationMessage != null && _position == null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MapMessage(
              message: _locationMessage!,
              onRetry: _loadPosition,
            ),
          )
        else if (!_loading && _vendors.isEmpty)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MapMessage(
              message: 'Aucun vendeur ne correspond à cette recherche.',
            ),
          ),
        Positioned(
          right: 16,
          bottom: 22,
          child: FloatingActionButton.small(
            heroTag: 'map-location',
            onPressed: _locating ? null : _loadPosition,
            backgroundColor: Colors.white,
            foregroundColor: _leaf700,
            child: _locating
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    ),
  );
}

class _VendorMapAvatar extends StatelessWidget {
  const _VendorMapAvatar({required this.vendor, required this.onTap});
  final VendorData vendor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _flame500,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              vendor.name.trim().isEmpty
                  ? 'V'
                  : vendor.name.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxWidth: 70),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: _leaf900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            vendor.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 8),
          ),
        ),
      ],
    ),
  );
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 6,
    borderRadius: BorderRadius.circular(16),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: _flame600),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

class VendorDetailScreen extends StatelessWidget {
  const VendorDetailScreen({
    super.key,
    required this.vendorId,
    this.onShowOrders,
  });
  final String vendorId;
  final VoidCallback? onShowOrders;

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
                    if (vendor.phone != null && vendor.phone!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri(
                                  scheme: 'tel',
                                  path: vendor.phone!.replaceAll(' ', ''),
                                );
                                if (!await launchUrl(uri)) {
                                  if (context.mounted) {
                                    await AppFeedback.error(
                                      context,
                                      message:
                                          'Impossible d’ouvrir l’application Téléphone.',
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.call_rounded),
                              label: const Text('Appeler'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _leaf700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openWhatsApp(context, vendor),
                              icon: const Icon(Icons.chat_rounded),
                              label: const Text('WhatsApp'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF128C4A),
                                side: const BorderSide(
                                  color: Color(0xFF128C4A),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                      (product) => _VendorProductCard(
                        vendor: vendor,
                        product: product,
                        onShowOrders: onShowOrders,
                      ),
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

Future<void> _openWhatsApp(BuildContext context, VendorData vendor) async {
  var digits = vendor.phone!.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = digits.substring(1);
  if (!digits.startsWith('237')) digits = '237$digits';

  final message = Uri.encodeComponent(
    'Bonjour ${vendor.name}, je vous contacte depuis Hot Koki.',
  );
  final uri = Uri.parse('https://wa.me/$digits?text=$message');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
      context.mounted) {
    await AppFeedback.error(
      context,
      message:
          'Impossible d’ouvrir WhatsApp. Vérifiez que l’application est installée.',
    );
  }
}

class _VendorProductCard extends StatelessWidget {
  const _VendorProductCard({
    required this.vendor,
    required this.product,
    this.onShowOrders,
  });
  final VendorData vendor;
  final VendorProduct product;
  final VoidCallback? onShowOrders;

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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _leaf900,
                    fontWeight: FontWeight.w800,
                  ),
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
                          color: _flame600,
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CartScreen(onShowOrders: onShowOrders),
        ),
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
