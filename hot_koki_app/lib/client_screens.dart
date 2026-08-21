import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'app_feedback.dart';
import 'app_preferences.dart';
import 'app_states.dart';
import 'delivery_fee_info.dart';
import 'payment_method_card.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf700 = Color(0xFF2E4E36);
const _leaf100 = Color(0xFFE7EEE4);
const _cream = Color(0xFFF4F3F1);
const _flame600 = Color(0xFFD94B16);
const _flame500 = Color(0xFFF06424);
const _inkSoft = Color(0xFF6B6864);

class ApiException implements Exception {
  const ApiException(this.message, [this.fields = const {}]);
  final String message;
  final Map<String, String> fields;
  @override
  String toString() => message;
}

class ClientApi {
  static const storage = FlutterSecureStorage();

  static Future<Map<String, String>> headers() async => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (await storage.read(key: 'auth_token') case final token?)
      'Authorization': 'Bearer $token',
  };

  static Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headersValue = await headers();
    final encoded = body == null ? null : jsonEncode(body);
    final request = switch (method) {
      'POST' => http.post(uri, headers: headersValue, body: encoded),
      'PUT' => http.put(uri, headers: headersValue, body: encoded),
      'PATCH' => http.patch(uri, headers: headersValue, body: encoded),
      'DELETE' => http.delete(uri, headers: headersValue, body: encoded),
      _ => http.get(uri, headers: headersValue),
    };
    final response = await request.timeout(const Duration(seconds: 20));
    return _decodeResponse(response);
  }

  static Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    String? filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    );
    request.headers['Accept'] = 'application/json';
    if (await storage.read(key: 'auth_token') case final token?) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (filePath != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    }
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    return _decodeResponse(await http.Response.fromStream(streamed));
  }

  static dynamic _decodeResponse(http.Response response) {
    final data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? data['message'] : null;
      final errors = data is Map ? data['errors'] : null;
      final fieldErrors = <String, String>{};
      if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          fieldErrors[entry.key.toString()] = value is List && value.isNotEmpty
              ? value.first.toString()
              : value.toString();
        }
      }
      throw ApiException(
        message?.toString() ??
            _firstError(errors) ??
            'Impossible de terminer l’opération.',
        fieldErrors,
      );
    }
    return data;
  }

  static String? _firstError(dynamic errors) {
    if (errors is! Map || errors.isEmpty) return null;
    final value = errors.values.first;
    return value is List && value.isNotEmpty
        ? value.first.toString()
        : value.toString();
  }
}

class ClientOrdersScreen extends StatefulWidget {
  const ClientOrdersScreen({super.key});
  @override
  State<ClientOrdersScreen> createState() => _ClientOrdersScreenState();
}

class _ClientOrdersScreenState extends State<ClientOrdersScreen> {
  late Future<List<dynamic>> _orders;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _orders = ClientApi.request(
    'GET',
    '/commandes',
  ).then((data) => data as List<dynamic>);

  Future<void> _refresh() async {
    setState(() {
      _reload();
    });
    await _orders;
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Text(
            'Mes commandes',
            style: TextStyle(
              color: _leaf900,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _orders,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingState(
                  label: 'Nous retrouvons vos commandes…',
                );
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  message: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  onRetry: () => setState(() {
                    _reload();
                  }),
                );
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return const AppEmptyState(
                  title: 'Aucune commande pour le moment',
                  message:
                      'Votre prochaine commande apparaîtra ici avec son suivi en temps réel.',
                  icon: Icons.receipt_long_outlined,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: orders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) => _OrderCard(
                    order: orders[index] as Map<String, dynamic>,
                    onChanged: _refresh,
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onChanged});
  final Map<String, dynamic> order;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final status = order['statut'].toString();
    final vendor = order['vendeur'] as Map<String, dynamic>?;
    final items = order['items'] as List<dynamic>? ?? [];
    final cancellable = status == 'en_attente_paiement' || status == 'recue';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status == 'livree' ? Colors.white : _leaf900,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMANDE #${order['id']}',
                      style: TextStyle(
                        fontSize: 10,
                        color: status == 'livree' ? _inkSoft : Colors.white60,
                      ),
                    ),
                    Text(
                      vendor?['nom_boutique']?.toString() ?? 'Vendeur',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: status == 'livree' ? _leaf900 : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            items
                .map((raw) {
                  final item = raw as Map<String, dynamic>;
                  final product = item['produit'] as Map<String, dynamic>?;
                  return '${item['quantite']}× ${product?['nom'] ?? 'Produit'}';
                })
                .join(' · '),
            style: TextStyle(
              color: status == 'livree' ? _inkSoft : Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          if (order['distance_km'] != null)
            Row(
              children: [
                Icon(
                  Icons.route_outlined,
                  size: 16,
                  color: status == 'livree' ? _leaf700 : Colors.white70,
                ),
                const SizedBox(width: 6),
                Text(
                  formatDistanceKm(order['distance_km']),
                  style: TextStyle(
                    color: status == 'livree' ? _inkSoft : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '·',
                  style: TextStyle(
                    color: status == 'livree' ? _inkSoft : Colors.white70,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: DeliveryFeeLabel(
                    fee: order['frais_livraison'],
                    color: status == 'livree' ? _inkSoft : Colors.white70,
                    fontSize: 11,
                    compact: true,
                  ),
                ),
              ],
            ),
          if (order['distance_km'] != null) const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${_money(order['total'])} F CFA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: status == 'livree' ? _flame600 : Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showDetails(context),
                child: const Text('Détails'),
              ),
              if (status == 'en_attente_paiement')
                FilledButton(
                  onPressed: () => _pay(context),
                  child: const Text('Payer'),
                )
              else if (cancellable)
                TextButton(
                  onPressed: () => _cancel(context),
                  child: const Text('Annuler'),
                )
              else if (status == 'livree')
                TextButton(
                  onPressed: () => _review(context),
                  child: Text(
                    order['avis'] == null
                        ? 'Donner un avis'
                        : 'Modifier l’avis',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) async {
    final details =
        await ClientApi.request('GET', '/commandes/${apiResourceId(order)}')
            as Map<String, dynamic>;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _OrderDetails(order: details, onChanged: onChanged),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la commande ?'),
        content: const Text('Cette action arrête définitivement la commande.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ClientApi.request(
        'PATCH',
        '/commandes/${apiResourceId(order)}/annuler',
      );
      await onChanged();
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }

  Future<void> _pay(BuildContext context) async {
    final phone = TextEditingController();
    final methodsRaw = await ClientApi.request('GET', '/paiements-moyens');
    if (!context.mounted) return;
    final methods = (methodsRaw as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    var provider = 'mtn_momo';
    final value = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir le paiement'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...methods.map((method) {
                    final available = method['disponible'] == true;
                    return PaymentMethodCard(
                      code: method['code'].toString(),
                      name: method['nom'].toString(),
                      selected: provider == method['code'],
                      available: available,
                      onTap: () => setDialogState(
                        () => provider = method['code'].toString(),
                      ),
                    );
                  }),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Numéro Mobile Money',
                      hintText: '6XXXXXXXX',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'telephone': phone.text.trim(),
                'fournisseur': provider,
              }),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
    // Laisse l'animation de fermeture retirer complètement le champ avant de
    // libérer son contrôleur. Sinon Flutter peut brièvement afficher son écran
    // d'erreur rouge pendant la transition.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    phone.dispose();
    if (value == null || value['telephone']?.isEmpty != false) return;
    try {
      final result =
          await ClientApi.request(
                'POST',
                '/commandes/${apiResourceId(order)}/paiements',
                body: {
                  'fournisseur': value['fournisseur'],
                  'telephone': value['telephone'],
                },
              )
              as Map<String, dynamic>;
      if (!context.mounted) return;
      final payment = result['paiement'] as Map<String, dynamic>;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(payment: payment),
        ),
      );
      await onChanged();
    } catch (error) {
      if (context.mounted) _snack(context, error);
    }
  }

  Future<void> _review(BuildContext context) async {
    final existing = order['avis'] as Map<String, dynamic>?;
    final comment = TextEditingController(
      text: existing?['commentaire']?.toString() ?? '',
    );
    var rating = int.tryParse(existing?['note']?.toString() ?? '') ?? 5;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Votre avis'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: comment,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Commentaire (facultatif)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
    if (save != true) {
      comment.dispose();
      return;
    }
    try {
      await ClientApi.request(
        'POST',
        '/commandes/${apiResourceId(order)}/avis',
        body: {'note': rating, 'commentaire': comment.text.trim()},
      );
      await onChanged();
      if (context.mounted) {
        await AppFeedback.success(
          context,
          title: 'Avis publié',
          message: 'Merci, votre avis a bien été enregistré.',
        );
      }
    } catch (error) {
      if (context.mounted) _snack(context, error);
    } finally {
      comment.dispose();
    }
  }
}

class PaymentStatusScreen extends StatefulWidget {
  const PaymentStatusScreen({super.key, required this.payment});
  final Map<String, dynamic> payment;
  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  late Map<String, dynamic> _payment;
  Timer? _timer;
  bool _checking = false;
  bool _pollingStopped = false;
  String? _statusMessage;
  DateTime? _startedAt;
  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _sync());
  }

  bool get _terminal =>
      ['reussi', 'echoue', 'expire', 'annule'].contains(_payment['statut']);
  bool get _isOrange => _payment['fournisseur'] == 'orange_money';
  String get _operatorName => _isOrange ? 'Orange Money' : 'MTN MoMo';
  Future<void> _sync({bool relancer = false}) async {
    if (_checking || _terminal || _pollingStopped) return;
    _checking = true;
    try {
      final data = await ClientApi.request(
        'POST',
        '/paiements/${apiResourceId(_payment)}/synchroniser',
        body: relancer ? {'relancer': true} : null,
      );
      final response = data as Map<String, dynamic>;
      if (response['code'] == 'POLLING_TERMINE') {
        if (mounted) {
          setState(() {
            _pollingStopped = true;
            _statusMessage = response['message']?.toString();
          });
        }
        _timer?.cancel();
        return;
      }
      final payment = response['paiement'] is Map<String, dynamic>
          ? response['paiement'] as Map<String, dynamic>
          : response;
      if (mounted) {
        setState(() {
          _payment = payment;
          _statusMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(title: Text('Paiement $_operatorName')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _terminal
                  ? (_payment['statut'] == 'reussi'
                        ? Icons.check_circle
                        : Icons.error)
                  : Icons.phone_android,
              size: 72,
              color: _payment['statut'] == 'reussi' ? _leaf700 : _flame500,
            ),
            const SizedBox(height: 18),
            Text(
              _paymentLabel(_payment['statut'].toString()),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _leaf900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Référence ${_payment['reference_interne']}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _inkSoft),
            ),
            const SizedBox(height: 20),
            if (!_terminal)
              const AppLoadingState(
                label: 'Confirmation sécurisée en cours…',
                compact: true,
              ),
            if (!_terminal) ...[
              const SizedBox(height: 4),
              Text(
                _payment['mode_test'] == true
                    ? 'Mode Sandbox : aucun message réel n’est envoyé au téléphone. MTN simule le résultat.'
                    : 'Validez la demande reçue sur votre téléphone $_operatorName.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _inkSoft),
              ),
              if (_startedAt != null &&
                  DateTime.now().difference(_startedAt!).inSeconds >= 10) ...[
                const SizedBox(height: 8),
                const Text(
                  'La confirmation peut prendre quelques instants. Vous pouvez quitter cet écran : le suivi continuera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _inkSoft, fontSize: 12),
                ),
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _flame600, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_statusMessage != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _pollingStopped = false;
                          _statusMessage = null;
                        });
                        _sync(relancer: true);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Revérifier'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Revenir aux commandes'),
                  ),
                ],
              ),
            ],
            if (_terminal)
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour aux commandes'),
              ),
          ],
        ),
      ),
    ),
  );
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.order, required this.onChanged});
  final Map<String, dynamic> order;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List<dynamic>? ?? [];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commande #${order['id']}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _leaf900,
              ),
            ),
            Text(
              order['adresse_livraison'].toString(),
              style: const TextStyle(color: _inkSoft),
            ),
            const Divider(height: 28),
            ...items.map((raw) {
              final item = raw as Map<String, dynamic>;
              final product = item['produit'] as Map<String, dynamic>?;
              final complements = item['complements'] as List<dynamic>? ?? [];
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
            if (order['distance_km'] != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.route_outlined, color: _leaf700),
                title: const Text('Distance vendeur–livraison'),
                subtitle: Text(formatDistanceKm(order['distance_km'])),
              ),
              DeliveryFeeLabel(fee: order['frais_livraison'], color: _leaf900),
              const Divider(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${_money(order['total'])} F CFA',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _flame600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ClientAccountScreen extends StatefulWidget {
  const ClientAccountScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<ClientAccountScreen> createState() => _ClientAccountScreenState();
}

class _ClientAccountScreenState extends State<ClientAccountScreen> {
  late Future<Map<String, dynamic>> _profile;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _profile = ClientApi.request(
    'GET',
    '/client/profile',
  ).then((value) => value as Map<String, dynamic>);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _profile,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _ErrorState(
                  error: snapshot.error!,
                  retry: () => setState(() {
                    _reload();
                  }),
                )
              : const Center(
                  child: CircularProgressIndicator(color: _flame500),
                );
        }
        final user = snapshot.data!['user'] as Map<String, dynamic>;
        final client = snapshot.data!['client'] as Map<String, dynamic>;
        final name = user['name'].toString();
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('my_account'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _edit(user, client),
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: Text(
                          context.tr('edit'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: _flame500,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: context.tr('phone'),
                    value: user['telephone']?.toString() ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    label: context.tr('email'),
                    value: user['email'].toString(),
                  ),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: context.tr('delivery_address'),
                    value: client['adresse_texte']?.toString() ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.lock_outline,
                    label: context.tr('security'),
                    value: context.tr('change_password'),
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: 10),
                  const PreferencesCard(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: Text(context.tr('logout')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
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

  Future<void> _logout() async {
    try {
      await ClientApi.request('POST', '/logout');
    } catch (_) {}
    await ClientApi.storage.delete(key: 'auth_token');
    CartCleanup.clear();
    widget.onLogout();
  }

  Future<void> _edit(
    Map<String, dynamic> user,
    Map<String, dynamic> client,
  ) async {
    final name = TextEditingController(text: user['name']?.toString());
    final email = TextEditingController(text: user['email']?.toString());
    final phone = TextEditingController(text: user['telephone']?.toString());
    var address = client['adresse_texte']?.toString() ?? '';
    double? latitude = double.tryParse(client['latitude']?.toString() ?? '');
    double? longitude = double.tryParse(client['longitude']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    String? locationError;
    bool locating = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier mon profil'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nom *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Renseignez votre nom.'
                        : null,
                  ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email *'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Renseignez votre adresse email.';
                      }
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value.trim())) {
                        return 'Saisissez une adresse email valide.';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone *'),
                    validator: (value) {
                      final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
                      if (digits.isEmpty) {
                        return 'Renseignez votre numéro de téléphone.';
                      }
                      if (!RegExp(r'^(237)?6\d{8}$').hasMatch(digits)) {
                        return 'Saisissez un numéro camerounais valide.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on),
                    title: Text(
                      address.isEmpty ? 'Adresse non renseignée' : address,
                    ),
                    subtitle: const Text('Les coordonnées restent privées.'),
                    trailing: locating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(),
                          )
                        : null,
                  ),
                  if (locationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        locationError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: locating
                        ? null
                        : () async {
                            setDialogState(() => locating = true);
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
                                throw Exception(
                                  'Permission de localisation refusée.',
                                );
                              }
                              final position =
                                  await Geolocator.getCurrentPosition();
                              final places = await placemarkFromCoordinates(
                                position.latitude,
                                position.longitude,
                              );
                              final place = places.firstOrNull;
                              setDialogState(() {
                                latitude = position.latitude;
                                longitude = position.longitude;
                                address =
                                    [
                                          place?.street,
                                          place?.subLocality,
                                          place?.locality,
                                          place?.administrativeArea,
                                        ]
                                        .whereType<String>()
                                        .where((e) => e.trim().isNotEmpty)
                                        .toSet()
                                        .join(', ');
                                locating = false;
                                locationError = null;
                              });
                            } catch (error) {
                              setDialogState(() => locating = false);
                              if (context.mounted) _snack(context, error);
                            }
                          },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Utiliser ma position actuelle'),
                  ),
                ],
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
                final fieldsValid = formKey.currentState?.validate() ?? false;
                if (address.trim().isEmpty ||
                    latitude == null ||
                    longitude == null) {
                  setDialogState(
                    () => locationError =
                        'Utilisez votre position actuelle pour renseigner l’adresse.',
                  );
                  return;
                }
                if (fieldsValid) Navigator.pop(dialogContext, true);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await ClientApi.request(
        'PUT',
        '/client/profile',
        body: {
          'name': name.text.trim(),
          'nom': name.text.trim(),
          'email': email.text.trim(),
          'telephone': _normalizeCameroonPhone(phone.text),
          'adresse_texte': address,
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      setState(() {
        _reload();
      });
      if (mounted) {
        await _showFeedback(
          context,
          success: true,
          title: 'Profil mis à jour',
          message: 'Vos informations ont bien été enregistrées.',
        );
      }
    } catch (error) {
      if (mounted) {
        await _showFeedback(
          context,
          success: false,
          title: 'Modification impossible',
          message: error.toString().replaceFirst('ApiException: ', ''),
        );
      }
    }
    name.dispose();
    email.dispose();
    phone.dispose();
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le mot de passe'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel',
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Renseignez votre mot de passe actuel.'
                    : null,
              ),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Renseignez le nouveau mot de passe.';
                  }
                  if (value.length < 8) {
                    return 'Utilisez au moins 8 caractères.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmation'),
                validator: (value) => value != password.text
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
              if (formKey.currentState?.validate() ?? false) {
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
          '/client/profile',
          body: {
            'current_password': current.text,
            'password': password.text,
            'password_confirmation': confirmation.text,
          },
        );
        if (mounted) {
          await _showFeedback(
            context,
            success: true,
            title: 'Mot de passe modifié',
            message: 'Votre nouveau mot de passe est maintenant actif.',
          );
        }
      } catch (error) {
        if (mounted) {
          await _showFeedback(
            context,
            success: false,
            title: 'Modification impossible',
            message: error.toString(),
          );
        }
      }
    }
    current.dispose();
    password.dispose();
    confirmation.dispose();
  }
}

// Découple cet écran du panier tout en permettant au shell de fournir le nettoyage.
class CartCleanup {
  static VoidCallback clear = () {};
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
        style: const TextStyle(color: _leaf900, fontWeight: FontWeight.w700),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: _statusColor(status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _statusLabel(status),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
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
      'en_attente_paiement': 'À payer',
      'recue': 'Reçue',
      'preparation': 'Préparation',
      'en_livraison': 'En livraison',
      'livree': 'Livrée',
      'annulee': 'Annulée',
    }[status] ??
    status;
Color _statusColor(String status) =>
    {
      'livree': _leaf700,
      'annulee': Colors.red.shade700,
      'en_attente_paiement': _flame600,
    }[status] ??
    _flame500;
String _paymentLabel(String status) =>
    {
      'initie': 'Demande envoyée à MTN. Validation en cours…',
      'en_attente': 'Confirmation MTN MoMo en attente…',
      'reussi': 'Paiement confirmé',
      'echoue': 'Le paiement a échoué',
      'expire': 'La demande a expiré',
      'annule': 'Paiement annulé',
    }[status] ??
    status;
void _snack(BuildContext context, Object message) {
  final text = message.toString().replaceFirst('Exception: ', '');
  AppFeedback.error(context, message: text);
}

String _normalizeCameroonPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  return digits.startsWith('237') ? digits : '237$digits';
}

Future<void> _showFeedback(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    icon: Icon(
      success ? Icons.check_circle_rounded : Icons.error_rounded,
      color: success ? _leaf700 : Colors.red.shade700,
      size: 58,
    ),
    title: Text(title, textAlign: TextAlign.center),
    content: Text(message, textAlign: TextAlign.center),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        style: FilledButton.styleFrom(
          backgroundColor: success ? _leaf700 : Colors.red.shade700,
        ),
        child: const Text('D’accord'),
      ),
    ],
  ),
);
