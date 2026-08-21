import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';
import 'app_feedback.dart';
import 'app_preferences.dart';
import 'client_screens.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf700 = Color(0xFF2E4E36);
const _leaf100 = Color(0xFFE7EEE4);
const _flame600 = Color(0xFFD94B16);
const _flame500 = Color(0xFFF06424);
const _inkSoft = Color(0xFF6B6864);

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});
  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/vendeur/dashboard',
    ).then((v) => v as Map<String, dynamic>);
  }

  Future<void> _availability(String value) async {
    try {
      await ClientApi.request(
        'PATCH',
        '/vendeur/disponibilite',
        body: {'statut_dispo': value},
      );
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: 'Disponibilité mise à jour',
        message: _availabilityLabel(value),
      );
      setState(_reload);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _SellerError(
                  error: snapshot.error!,
                  retry: () => setState(_reload),
                )
              : const Center(
                  child: CircularProgressIndicator(color: _flame500),
                );
        }
        final data = snapshot.data!;
        final seller = data['vendeur'] as Map<String, dynamic>;
        final stats = data['statistiques'] as Map<String, dynamic>;
        final revenues = data['revenus'] as Map<String, dynamic>? ?? {};
        final orders = data['commandes_recentes'] as List<dynamic>;
        final reviews = data['avis_recents'] as List<dynamic>;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const Text(
                'ESPACE VENDEUR',
                style: TextStyle(
                  color: _flame600,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              Text(
                seller['nom_boutique'].toString(),
                style: const TextStyle(
                  color: _leaf900,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _leaf900,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront, color: Colors.white),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'État de la boutique',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: seller['statut_dispo'].toString(),
                        dropdownColor: _leaf900,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        iconEnabledColor: Colors.white,
                        items: const [
                          DropdownMenuItem(
                            value: 'disponible',
                            child: Text('Disponible'),
                          ),
                          DropdownMenuItem(
                            value: 'pause',
                            child: Text('En pause'),
                          ),
                          DropdownMenuItem(
                            value: 'indisponible',
                            child: Text('Indisponible'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) _availability(v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _SellerTitle('Chiffre d’affaires confirmé'),
              const SizedBox(height: 9),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.45,
                children: [
                  _SellerStat(
                    icon: Icons.today_rounded,
                    label: 'Aujourd’hui',
                    value: '${_money(revenues['jour'])} F',
                  ),
                  _SellerStat(
                    icon: Icons.date_range_rounded,
                    label: 'Cette semaine',
                    value: '${_money(revenues['semaine'])} F',
                  ),
                  _SellerStat(
                    icon: Icons.calendar_month_rounded,
                    label: 'Ce mois',
                    value: '${_money(revenues['mois'])} F',
                  ),
                  _SellerStat(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Total',
                    value: '${_money(revenues['total'])} F',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SellerTitle('Activité'),
              const SizedBox(height: 9),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.45,
                children: [
                  _SellerStat(
                    icon: Icons.today,
                    label: 'Commandes du jour',
                    value: '${stats['commandes_du_jour']}',
                  ),
                  _SellerStat(
                    icon: Icons.soup_kitchen_outlined,
                    label: 'À préparer',
                    value: '${stats['a_preparer']}',
                  ),
                  _SellerStat(
                    icon: Icons.verified_outlined,
                    label: 'Paiements réussis',
                    value: '${revenues['paiements_reussis'] ?? 0}',
                  ),
                  _SellerStat(
                    icon: Icons.star_rounded,
                    label: 'Note · ${stats['nombre_avis']} avis',
                    value: double.parse(
                      stats['note_moyenne'].toString(),
                    ).toStringAsFixed(1),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SellerTitle('Commandes récentes'),
              const SizedBox(height: 8),
              if (orders.isEmpty)
                const _SellerEmpty('Aucune commande récente.')
              else
                ...orders.map(
                  (raw) => SellerOrderCard(
                    order: raw as Map<String, dynamic>,
                    compact: true,
                  ),
                ),
              const SizedBox(height: 20),
              const _SellerTitle('Derniers avis'),
              const SizedBox(height: 8),
              if (reviews.isEmpty)
                const _SellerEmpty('Aucun avis reçu.')
              else
                ...reviews.map(
                  (raw) => _ReviewCard(review: raw as Map<String, dynamic>),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  late Future<List<dynamic>> _future;
  String _filter = 'toutes';
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/vendeur/commandes',
    ).then((v) => v as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Mes commandes',
            style: TextStyle(
              color: _leaf900,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children:
                [
                      'toutes',
                      'recue',
                      'preparation',
                      'en_livraison',
                      'livree',
                      'annulee',
                    ]
                    .map(
                      (status) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(_statusLabel(status)),
                          selected: _filter == status,
                          onSelected: (_) => setState(() => _filter = status),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? _SellerError(
                        error: snapshot.error!,
                        retry: () => setState(_reload),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _flame500),
                      );
              }
              final orders = snapshot.data!
                  .where(
                    (raw) =>
                        _filter == 'toutes' ||
                        (raw as Map<String, dynamic>)['statut'] == _filter,
                  )
                  .toList();
              if (orders.isEmpty) {
                return const _SellerEmpty(
                  'Aucune commande dans cette catégorie.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => SellerOrderCard(
                    order: orders[i] as Map<String, dynamic>,
                    onChanged: () async {
                      setState(_reload);
                      await _future;
                    },
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

class SellerOrderCard extends StatelessWidget {
  const SellerOrderCard({
    super.key,
    required this.order,
    this.onChanged,
    this.compact = false,
  });
  final Map<String, dynamic> order;
  final Future<void> Function()? onChanged;
  final bool compact;
  String? get nextStatus => {
    'recue': 'preparation',
    'preparation': 'en_livraison',
    'en_livraison': 'livree',
  }[order['statut']];

  Future<void> _advance(BuildContext context) async {
    final next = nextStatus;
    if (next == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Passer à « ${_statusLabel(next)} » ?'),
        content: const Text('Le client verra immédiatement ce nouveau statut.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ClientApi.request(
        'PATCH',
        '/vendeur/commandes/${apiResourceId(order)}/statut',
        body: {'statut': next},
      );
      if (!context.mounted) return;
      await AppFeedback.success(
        context,
        title: 'Statut mis à jour',
        message: 'La commande est maintenant « ${_statusLabel(next)} ».',
      );
      await onChanged?.call();
    } catch (error) {
      if (context.mounted) await AppFeedback.error(context, message: error);
    }
  }

  Future<void> _details(BuildContext context) async {
    final pageContext = context;
    final client = order['client'] as Map<String, dynamic>? ?? {};
    final user = client['user'] as Map<String, dynamic>? ?? {};
    final items = order['items'] as List<dynamic>? ?? [];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order['id']}',
                  style: const TextStyle(
                    color: _leaf900,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user['name']?.toString() ??
                      client['nom']?.toString() ??
                      'Client',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  order['adresse_livraison'].toString(),
                  style: const TextStyle(color: _inkSoft),
                ),
                if (order['distance_km'] != null)
                  Text(
                    '${formatDistanceKm(order['distance_km'])} · ${deliveryFeeText(order['frais_livraison'])}',
                    style: const TextStyle(
                      color: _leaf700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (user['telephone'] != null)
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: user['telephone'].toString()),
                    ),
                    icon: const Icon(Icons.call),
                    label: Text(user['telephone'].toString()),
                  ),
                const Divider(height: 24),
                ...items.map((raw) {
                  final item = raw as Map<String, dynamic>;
                  final product = item['produit'] as Map<String, dynamic>?;
                  final complements =
                      item['complements'] as List<dynamic>? ?? [];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${item['quantite']}× ${product?['nom'] ?? 'Produit'}',
                    ),
                    subtitle: Text(
                      complements.map((c) => (c as Map)['nom']).join(', '),
                    ),
                    trailing: Text(
                      '${_money(double.parse(item['prix_unitaire'].toString()) * int.parse(item['quantite'].toString()))} F',
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${_money(order['total'])} F CFA',
                      style: const TextStyle(
                        color: _flame600,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                if (nextStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _advance(pageContext);
                        },
                        child: Text(
                          'Passer à « ${_statusLabel(nextStatus!)} »',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = order['client'] as Map<String, dynamic>?;
    final user = client?['user'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${order['id']} · ${user?['name'] ?? client?['nom'] ?? 'Client'}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${_money(order['total'])} F CFA',
                        style: const TextStyle(color: _inkSoft, fontSize: 12),
                      ),
                      if (order['distance_km'] != null)
                        Text(
                          '${formatDistanceKm(order['distance_km'])} · ${deliveryFeeText(order['frais_livraison'])}',
                          style: const TextStyle(
                            color: _leaf700,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                _OrderStatus(status: order['statut'].toString()),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _details(context),
                    child: const Text('Voir le détail'),
                  ),
                  const Spacer(),
                  if (nextStatus != null)
                    FilledButton(
                      onPressed: () => _advance(context),
                      child: Text(_statusLabel(nextStatus!)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});
  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final _search = TextEditingController();
  late Future<List<dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/vendeur/produits',
    ).then((v) => v as List<dynamic>);
  }

  Future<void> _toggle(Map<String, dynamic> product, bool available) async {
    try {
      await ClientApi.request(
        'PATCH',
        '/vendeur/produits/${apiResourceId(product)}/statut',
        body: {'statut': available ? 'disponible' : 'rupture'},
      );
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: 'Produit mis à jour',
        message:
            '${product['nom']} est ${available ? 'disponible' : 'en rupture'}.',
      );
      setState(_reload);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mes produits',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un produit…',
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? _SellerError(
                        error: snapshot.error!,
                        retry: () => setState(_reload),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _flame500),
                      );
              }
              final q = _search.text.toLowerCase();
              final products = snapshot.data!
                  .where(
                    (raw) => (raw as Map<String, dynamic>)['nom']
                        .toString()
                        .toLowerCase()
                        .contains(q),
                  )
                  .toList();
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, i) {
                    final p = products[i] as Map<String, dynamic>;
                    final available = p['mon_statut'] == 'disponible';
                    return Card(
                      child: SwitchListTile(
                        value: available,
                        onChanged: (value) => _toggle(p, value),
                        activeThumbColor: _flame600,
                        secondary: const CircleAvatar(
                          backgroundColor: _leaf100,
                          child: Icon(Icons.restaurant_menu, color: _leaf700),
                        ),
                        title: Text(
                          p['nom'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${_money(p['prix'])} F · ${available ? 'Disponible' : 'Rupture'}',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class SellerAccountScreen extends StatefulWidget {
  const SellerAccountScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<SellerAccountScreen> createState() => _SellerAccountScreenState();
}

class _SellerAccountScreenState extends State<SellerAccountScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/vendeur/profile',
    ).then((v) => v as Map<String, dynamic>);
  }

  Future<void> _logout() async {
    try {
      await ClientApi.request('POST', '/logout');
    } catch (_) {}
    await ClientApi.storage.delete(key: 'auth_token');
    widget.onLogout();
  }

  Future<void> _edit(
    Map<String, dynamic> user,
    Map<String, dynamic> seller,
  ) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: user['name']?.toString());
    final shop = TextEditingController(
      text: seller['nom_boutique']?.toString(),
    );
    final email = TextEditingController(text: user['email']?.toString());
    final phone = TextEditingController(text: user['telephone']?.toString());
    final description = TextEditingController(
      text: seller['description']?.toString(),
    );
    final address = TextEditingController(
      text: seller['adresse_texte']?.toString(),
    );
    var latitude = double.tryParse(seller['latitude']?.toString() ?? '');
    var longitude = double.tryParse(seller['longitude']?.toString() ?? '');
    bool locating = false;
    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Modifier la boutique'),
          content: SizedBox(
            width: 520,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sellerRequired(shop, 'Nom de la boutique'),
                    _sellerRequired(name, 'Nom du responsable'),
                    _sellerRequired(email, 'Email'),
                    _sellerRequired(phone, 'Téléphone'),
                    TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    _sellerRequired(address, 'Adresse'),
                    OutlinedButton.icon(
                      onPressed: locating
                          ? null
                          : () async {
                              update(() => locating = true);
                              try {
                                var permission =
                                    await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission =
                                      await Geolocator.requestPermission();
                                }
                                if (permission == LocationPermission.denied ||
                                    permission ==
                                        LocationPermission.deniedForever) {
                                  throw Exception('Permission refusée.');
                                }
                                final pos =
                                    await Geolocator.getCurrentPosition();
                                final places = await placemarkFromCoordinates(
                                  pos.latitude,
                                  pos.longitude,
                                );
                                final p = places.isEmpty ? null : places.first;
                                update(() {
                                  latitude = pos.latitude;
                                  longitude = pos.longitude;
                                  address.text =
                                      [
                                            p?.street,
                                            p?.subLocality,
                                            p?.locality,
                                            p?.administrativeArea,
                                          ]
                                          .whereType<String>()
                                          .where((e) => e.trim().isNotEmpty)
                                          .toSet()
                                          .join(', ');
                                  locating = false;
                                });
                              } catch (error) {
                                update(() => locating = false);
                                if (context.mounted) {
                                  await AppFeedback.error(
                                    context,
                                    message: error,
                                  );
                                }
                              }
                            },
                      icon: locating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: const Text('Mettre à jour ma position'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if ((form.currentState?.validate() ?? false) &&
                    latitude != null &&
                    longitude != null) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (save == true) {
      try {
        await ClientApi.request(
          'PUT',
          '/vendeur/profile',
          body: {
            'name': name.text.trim(),
            'nom_boutique': shop.text.trim(),
            'email': email.text.trim(),
            'telephone': phone.text.trim(),
            'description': description.text.trim(),
            'adresse_texte': address.text.trim(),
            'latitude': latitude,
            'longitude': longitude,
          },
        );
        if (mounted) {
          await AppFeedback.success(
            context,
            title: 'Boutique mise à jour',
            message: 'Les clients voient maintenant ces informations.',
          );
          setState(_reload);
        }
      } catch (error) {
        if (mounted) await AppFeedback.error(context, message: error);
      }
    }
    for (final c in [name, shop, email, phone, description, address]) {
      c.dispose();
    }
  }

  Future<void> _password() async {
    final form = GlobalKey<FormState>();
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le mot de passe'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sellerRequired(current, 'Mot de passe actuel', obscure: true),
              _sellerRequired(
                password,
                'Nouveau mot de passe',
                obscure: true,
                min: 8,
              ),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmation *'),
                validator: (v) => v != password.text
                    ? 'La confirmation ne correspond pas.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await ClientApi.request(
          'PUT',
          '/vendeur/profile',
          body: {
            'current_password': current.text,
            'password': password.text,
            'password_confirmation': confirmation.text,
          },
        );
        if (mounted) {
          await AppFeedback.success(
            context,
            title: 'Mot de passe modifié',
            message: 'Votre nouveau mot de passe est actif.',
          );
        }
      } catch (error) {
        if (mounted) await AppFeedback.error(context, message: error);
      }
    }
    current.dispose();
    password.dispose();
    confirmation.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _SellerAccountRecovery(
                  error: snapshot.error!,
                  retry: () => setState(_reload),
                  logout: _logout,
                )
              : const Center(
                  child: CircularProgressIndicator(color: _flame500),
                );
        }
        final seller = snapshot.data!['vendeur'] as Map<String, dynamic>;
        final user = snapshot.data!['user'] as Map<String, dynamic>;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_leaf700, _leaf900]),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('my_shop'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: _flame500,
                    child: Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    seller['nom_boutique'].toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    user['name'].toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _AccountTile(
                    icon: Icons.phone_outlined,
                    label: context.tr('phone'),
                    value: user['telephone']?.toString() ?? '—',
                  ),
                  _AccountTile(
                    icon: Icons.email_outlined,
                    label: context.tr('email'),
                    value: user['email'].toString(),
                  ),
                  _AccountTile(
                    icon: Icons.location_on_outlined,
                    label: context.tr('address'),
                    value: seller['adresse_texte']?.toString() ?? '—',
                  ),
                  _AccountTile(
                    icon: Icons.edit_outlined,
                    label: context.tr('shop'),
                    value: context.tr('edit_information'),
                    onTap: () => _edit(user, seller),
                  ),
                  _AccountTile(
                    icon: Icons.lock_outline,
                    label: context.tr('security'),
                    value: context.tr('change_password'),
                    onTap: _password,
                  ),
                  const SizedBox(height: 10),
                  const PreferencesCard(),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: Text(context.tr('logout')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
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

Widget _sellerRequired(
  TextEditingController c,
  String label, {
  bool obscure = false,
  int min = 1,
}) => TextFormField(
  controller: c,
  obscureText: obscure,
  decoration: InputDecoration(labelText: '$label *'),
  validator: (v) {
    if (v == null || v.trim().isEmpty) return '$label est obligatoire.';
    if (v.length < min) return '$label doit contenir au moins $min caractères.';
    return null;
  },
);

class _SellerStat extends StatelessWidget {
  const _SellerStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFE8E5E1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _flame600),
        const Spacer(),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(color: _inkSoft, fontSize: 10),
        ),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: _leaf900,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _SellerTitle extends StatelessWidget {
  const _SellerTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _leaf900,
      fontSize: 17,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Map<String, dynamic> review;
  @override
  Widget build(BuildContext context) {
    final order = review['commande'] as Map<String, dynamic>?;
    final client = order?['client'] as Map<String, dynamic>?;
    final user = client?['user'] as Map<String, dynamic>?;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _leaf100,
          child: Text(
            '${review['note']}★',
            style: const TextStyle(
              color: _flame600,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          user?['name']?.toString() ?? 'Client',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          review['commentaire']?.toString().trim().isNotEmpty == true
              ? review['commentaire'].toString()
              : 'Aucun commentaire.',
        ),
      ),
    );
  }
}

class _OrderStatus extends StatelessWidget {
  const _OrderStatus({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'livree' ? _leaf100 : const Color(0xFFF6D2BC),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _statusLabel(status),
      style: TextStyle(
        color: status == 'livree' ? _leaf700 : _flame600,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _leaf100,
        child: Icon(icon, color: _leaf700),
      ),
      title: Text(label, style: const TextStyle(color: _inkSoft, fontSize: 11)),
      subtitle: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    ),
  );
}

class _SellerEmpty extends StatelessWidget {
  const _SellerEmpty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _inkSoft),
      ),
    ),
  );
}

class _SellerError extends StatelessWidget {
  const _SellerError({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error.toString(), textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

class _SellerAccountRecovery extends StatelessWidget {
  const _SellerAccountRecovery({
    required this.error,
    required this.retry,
    required this.logout,
  });

  final Object error;
  final VoidCallback retry;
  final Future<void> Function() logout;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 48, color: _flame600),
          const SizedBox(height: 12),
          const Text(
            'Profil vendeur indisponible',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            label: const Text('Fermer cette session'),
          ),
          TextButton(onPressed: retry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

String _money(dynamic value) =>
    double.tryParse(value.toString())?.round().toString() ?? value.toString();
String _statusLabel(String status) =>
    {
      'toutes': 'Toutes',
      'en_attente_paiement': 'À payer',
      'recue': 'Reçue',
      'preparation': 'Préparation',
      'en_livraison': 'En livraison',
      'livree': 'Livrée',
      'annulee': 'Annulée',
    }[status] ??
    status;
String _availabilityLabel(String value) =>
    {
      'disponible': 'Votre boutique est visible et accepte les commandes.',
      'pause': 'Votre boutique est temporairement en pause.',
      'indisponible': 'Votre boutique est maintenant indisponible.',
    }[value] ??
    value;
