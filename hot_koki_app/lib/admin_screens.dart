import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'app_feedback.dart';
import 'client_screens.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf700 = Color(0xFF2E4E36);
const _leaf100 = Color(0xFFE7EEE4);
const _flame600 = Color(0xFFC9491E);
const _flame500 = Color(0xFFE0672F);
const _inkSoft = Color(0xFF6B5F4E);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/admin/dashboard',
    ).then((value) => value as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _flame500),
          );
        }
        if (snapshot.hasError) {
          return _AdminError(
            error: snapshot.error!,
            retry: () => setState(_reload),
          );
        }
        final data = snapshot.data!;
        final stats = data['statistiques'] as Map<String, dynamic>;
        final vendors = data['vendeurs_recents'] as List<dynamic>;
        final orders = data['commandes_recentes'] as List<dynamic>;
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              const Text(
                'ADMINISTRATION',
                style: TextStyle(
                  color: _flame600,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tableau de bord',
                style: TextStyle(
                  color: _leaf900,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 17),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.4,
                children: [
                  _StatCard(
                    icon: Icons.storefront,
                    label: 'Vendeurs actifs',
                    value: '${stats['vendeurs_actifs']}',
                  ),
                  _StatCard(
                    icon: Icons.receipt_long,
                    label: 'Commandes du jour',
                    value: '${stats['commandes_du_jour']}',
                  ),
                  _StatCard(
                    icon: Icons.payments_outlined,
                    label: 'CA du jour',
                    value: '${_money(stats['chiffre_affaires_du_jour'])} F',
                  ),
                  _StatCard(
                    icon: Icons.people_outline,
                    label: 'Utilisateurs',
                    value: '${stats['utilisateurs']}',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _AdminSectionTitle('Vendeurs récents'),
              const SizedBox(height: 9),
              ...vendors.map(
                (raw) => _VendorSummary(vendor: raw as Map<String, dynamic>),
              ),
              const SizedBox(height: 22),
              const _AdminSectionTitle('Commandes récentes'),
              const SizedBox(height: 9),
              ...orders.map(
                (raw) => _OrderSummary(order: raw as Map<String, dynamic>),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AdminVendorsScreen extends StatefulWidget {
  const AdminVendorsScreen({super.key});
  @override
  State<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends State<AdminVendorsScreen> {
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
      '/admin/vendeurs',
    ).then((value) => value as List<dynamic>);
  }

  Future<void> _openForm([Map<String, dynamic>? vendor]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VendorForm(vendor: vendor),
    );
    if (changed == true && mounted) setState(_reload);
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Vendeurs',
                      style: TextStyle(
                        color: _leaf900,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _openForm,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Boutique, responsable ou téléphone…',
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
                    ? _AdminError(
                        error: snapshot.error!,
                        retry: () => setState(_reload),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _flame500),
                      );
              }
              final query = _search.text.trim().toLowerCase();
              final vendors = snapshot.data!.where((raw) {
                final vendor = raw as Map<String, dynamic>;
                final user = vendor['user'] as Map<String, dynamic>? ?? {};
                return query.isEmpty ||
                    [
                      vendor['nom_boutique'],
                      user['name'],
                      user['telephone'],
                    ].any(
                      (value) =>
                          value?.toString().toLowerCase().contains(query) ==
                          true,
                    );
              }).toList();
              if (vendors.isEmpty) {
                return const Center(child: Text('Aucun vendeur trouvé.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: vendors.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    final vendor = vendors[index] as Map<String, dynamic>;
                    final active = vendor['statut_compte'] == 'actif';
                    return Card(
                      child: ListTile(
                        onTap: () => _openForm(vendor),
                        leading: CircleAvatar(
                          backgroundColor: active
                              ? _leaf100
                              : Colors.red.shade50,
                          child: Icon(
                            Icons.storefront,
                            color: active ? _leaf700 : Colors.red,
                          ),
                        ),
                        title: Text(
                          vendor['nom_boutique'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${(vendor['user'] as Map?)?['name'] ?? 'Responsable'} · ${vendor['adresse_texte'] ?? 'Adresse non renseignée'}',
                        ),
                        trailing: _StatusPill(active: active),
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

class _VendorForm extends StatefulWidget {
  const _VendorForm({this.vendor});
  final Map<String, dynamic>? vendor;
  @override
  State<_VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<_VendorForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _shop;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _address;
  late final TextEditingController _description;
  double? _latitude;
  double? _longitude;
  bool _saving = false;
  bool _locating = false;
  late String _status;

  bool get editing => widget.vendor != null;
  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor ?? {};
    final user = vendor['user'] as Map<String, dynamic>? ?? {};
    _name = TextEditingController(text: user['name']?.toString());
    _shop = TextEditingController(text: vendor['nom_boutique']?.toString());
    _email = TextEditingController(text: user['email']?.toString());
    _phone = TextEditingController(text: user['telephone']?.toString());
    _password = TextEditingController();
    _address = TextEditingController(text: vendor['adresse_texte']?.toString());
    _description = TextEditingController(
      text: vendor['description']?.toString(),
    );
    _latitude = double.tryParse(vendor['latitude']?.toString() ?? '');
    _longitude = double.tryParse(vendor['longitude']?.toString() ?? '');
    _status = vendor['statut_compte']?.toString() ?? 'actif';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _shop,
      _email,
      _phone,
      _password,
      _address,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permission de localisation refusée.');
      }
      final position = await Geolocator.getCurrentPosition();
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = places.isEmpty ? null : places.first;
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address.text =
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
        _locating = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _locating = false);
        await AppFeedback.error(context, message: error);
      }
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_latitude == null || _longitude == null) {
      await AppFeedback.error(
        context,
        message: 'Définissez la position de la boutique.',
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'nom_boutique': _shop.text.trim(),
      'email': _email.text.trim(),
      'telephone': _phone.text.trim(),
      'adresse_texte': _address.text.trim(),
      'description': _description.text.trim(),
      'latitude': _latitude,
      'longitude': _longitude,
      if (editing) 'statut_compte': _status,
      if (!editing) ...{
        'password': _password.text,
        'password_confirmation': _password.text,
      },
    };
    try {
      await ClientApi.request(
        editing ? 'PUT' : 'POST',
        editing ? '/admin/vendeurs/${widget.vendor!['id']}' : '/admin/vendeurs',
        body: body,
      );
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: editing ? 'Vendeur modifié' : 'Vendeur créé',
        message: 'Les informations ont bien été enregistrées.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(editing ? 'Modifier le vendeur' : 'Nouveau vendeur'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _requiredField(_shop, 'Nom de la boutique'),
              _requiredField(_name, 'Nom du responsable'),
              _requiredField(
                _email,
                'Email',
                keyboard: TextInputType.emailAddress,
              ),
              _requiredField(
                _phone,
                'Téléphone',
                keyboard: TextInputType.phone,
              ),
              if (!editing)
                _requiredField(
                  _password,
                  'Mot de passe temporaire',
                  obscure: true,
                  min: 8,
                ),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              _requiredField(_address, 'Adresse de la boutique'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('Définir la position actuelle'),
              ),
              if (editing)
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Statut du compte',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'actif', child: Text('Actif')),
                    DropdownMenuItem(
                      value: 'suspendu',
                      child: Text('Suspendu'),
                    ),
                  ],
                  onChanged: (value) => _status = value!,
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
      ),
    ],
  );
}

class AdminCatalogueScreen extends StatefulWidget {
  const AdminCatalogueScreen({super.key});
  @override
  State<AdminCatalogueScreen> createState() => _AdminCatalogueScreenState();
}

class _AdminCatalogueScreenState extends State<AdminCatalogueScreen> {
  late Future<List<dynamic>> _products;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _products = ClientApi.request(
      'GET',
      '/admin/produits',
    ).then((v) => v as List<dynamic>);
  }

  Future<void> _form([Map<String, dynamic>? product]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ProductForm(product: product),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _addComplement() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau complément'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nom du complément'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Le nom est obligatoire.'
                : null,
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
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (save == true) {
      try {
        await ClientApi.request(
          'POST',
          '/admin/complements',
          body: {'nom': controller.text.trim()},
        );
        if (mounted) {
          await AppFeedback.success(
            context,
            title: 'Complément ajouté',
            message: '${controller.text.trim()} est maintenant disponible.',
          );
        }
      } catch (error) {
        if (mounted) await AppFeedback.error(context, message: error);
      }
    }
    controller.dispose();
  }

  Future<void> _delete(Map<String, dynamic> product) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text(product['nom'].toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ClientApi.request('DELETE', '/admin/produits/${product['id']}');
      if (mounted) {
        await AppFeedback.success(
          context,
          title: 'Produit supprimé',
          message: 'Le catalogue a été mis à jour.',
        );
        setState(_reload);
      }
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
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Catalogue',
                  style: TextStyle(
                    color: _leaf900,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Ajouter un complément',
                onPressed: _addComplement,
                icon: const Icon(Icons.playlist_add),
              ),
              const SizedBox(width: 7),
              FilledButton.icon(
                onPressed: _form,
                icon: const Icon(Icons.add),
                label: const Text('Produit'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _products,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? _AdminError(
                        error: snapshot.error!,
                        retry: () => setState(_reload),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _flame500),
                      );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: snapshot.data!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, index) {
                  final product = snapshot.data![index] as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      onTap: () => _form(product),
                      leading: CircleAvatar(
                        backgroundColor: _leaf100,
                        backgroundImage:
                            product['photo'] == null ||
                                product['photo'].toString().isEmpty
                            ? null
                            : NetworkImage(
                                ApiConfig.resolveMediaUrl(
                                  product['photo'].toString(),
                                ),
                              ),
                        child:
                            product['photo'] == null ||
                                product['photo'].toString().isEmpty
                            ? const Icon(Icons.restaurant_menu, color: _leaf700)
                            : null,
                      ),
                      title: Text(
                        product['nom'].toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${_money(product['prix'])} F · ${(product['complements'] as List?)?.length ?? 0} complément(s)',
                      ),
                      trailing: IconButton(
                        onPressed: () => _delete(product),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({this.product});
  final Map<String, dynamic>? product;
  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  XFile? _selectedImage;
  bool _removeExistingImage = false;
  bool _saving = false;
  late Future<List<dynamic>> _complements;
  late final Set<int> _selectedComplements;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?['nom']?.toString());
    _description = TextEditingController(
      text: widget.product?['description']?.toString(),
    );
    _price = TextEditingController(text: widget.product?['prix']?.toString());
    _complements = ClientApi.request(
      'GET',
      '/admin/complements',
    ).then((value) => value as List<dynamic>);
    _selectedComplements =
        (widget.product?['complements'] as List<dynamic>? ?? [])
            .map(
              (item) =>
                  int.parse((item as Map<String, dynamic>)['id'].toString()),
            )
            .toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final fields = <String, String>{
        'nom': _name.text.trim(),
        'description': _description.text.trim(),
        'prix': double.parse(_price.text.replaceAll(',', '.')).toString(),
        'synchroniser_complements': '1',
        if (widget.product != null) '_method': 'PUT',
        if (_removeExistingImage) 'supprimer_photo': '1',
      };
      for (var index = 0; index < _selectedComplements.length; index++) {
        fields['complements[$index]'] = _selectedComplements
            .elementAt(index)
            .toString();
      }
      await ClientApi.multipart(
        widget.product == null
            ? '/admin/produits'
            : '/admin/produits/${widget.product!['id']}',
        fields: fields,
        filePath: _selectedImage?.path,
      );
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: widget.product == null ? 'Produit créé' : 'Produit modifié',
        message: 'Le catalogue a bien été mis à jour.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1800,
      );
      if (image != null && mounted) {
        setState(() {
          _selectedImage = image;
          _removeExistingImage = false;
        });
      }
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.product == null ? 'Nouveau produit' : 'Modifier le produit',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProductImageField(
              selectedImage: _selectedImage,
              existingImage: _removeExistingImage
                  ? null
                  : widget.product?['photo']?.toString(),
              onPick: _pickImage,
              onRemove:
                  _selectedImage != null ||
                      (!_removeExistingImage &&
                          widget.product?['photo'] != null)
                  ? () => setState(() {
                      _selectedImage = null;
                      _removeExistingImage = true;
                    })
                  : null,
            ),
            const SizedBox(height: 12),
            _requiredField(_name, 'Nom du produit'),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Prix en F CFA'),
              validator: (value) =>
                  double.tryParse((value ?? '').replaceAll(',', '.')) == null
                  ? 'Renseignez un prix valide.'
                  : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Compléments proposés',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FutureBuilder<List<dynamic>>(
              future: _complements,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                return Wrap(
                  spacing: 7,
                  children: snapshot.data!.map((raw) {
                    final item = raw as Map<String, dynamic>;
                    final id = int.parse(item['id'].toString());
                    return FilterChip(
                      label: Text(item['nom'].toString()),
                      selected: _selectedComplements.contains(id),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _selectedComplements.add(id)
                            : _selectedComplements.remove(id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _ProductImageField extends StatelessWidget {
  const _ProductImageField({
    required this.selectedImage,
    required this.existingImage,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? selectedImage;
  final String? existingImage;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasExisting = existingImage != null && existingImage!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 155,
            color: _leaf100,
            child: selectedImage != null
                ? Image.file(File(selectedImage!.path), fit: BoxFit.cover)
                : hasExisting
                ? Image.network(
                    ApiConfig.resolveMediaUrl(existingImage!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  selectedImage != null || hasExisting
                      ? 'Changer l’image'
                      : 'Choisir une image',
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Retirer l’image',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ],
        ),
        const Text(
          'JPEG, PNG ou WebP · 5 Mo maximum',
          style: TextStyle(fontSize: 12, color: _inkSoft),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.image_outlined, size: 38, color: _leaf700),
        SizedBox(height: 6),
        Text('Photo du produit', style: TextStyle(color: _leaf700)),
      ],
    ),
  );
}

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late Future<List<dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/admin/commandes',
    ).then((v) => (v as Map<String, dynamic>)['data'] as List<dynamic>);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 14),
          child: Text(
            'Toutes les commandes',
            style: TextStyle(
              color: _leaf900,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? _AdminError(
                        error: snapshot.error!,
                        retry: () => setState(_reload),
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: _flame500),
                      );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) => _OrderSummary(
                    order: snapshot.data![index] as Map<String, dynamic>,
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

class AdminAccountScreen extends StatefulWidget {
  const AdminAccountScreen({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<AdminAccountScreen> createState() => _AdminAccountScreenState();
}

class _AdminAccountScreenState extends State<AdminAccountScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/admin/profile',
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
    Map<String, dynamic> admin,
  ) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: user['name']?.toString());
    final email = TextEditingController(text: user['email']?.toString());
    final phone = TextEditingController(text: user['telephone']?.toString());
    final lastName = TextEditingController(text: admin['nom']?.toString());
    final firstName = TextEditingController(text: admin['prenom']?.toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier mon compte'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _requiredField(name, 'Nom affiché'),
                _requiredField(
                  email,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                ),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Téléphone'),
                ),
                TextFormField(
                  controller: lastName,
                  decoration: const InputDecoration(
                    labelText: 'Nom administratif',
                  ),
                ),
                TextFormField(
                  controller: firstName,
                  decoration: const InputDecoration(
                    labelText: 'Prénom administratif',
                  ),
                ),
              ],
            ),
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
          '/admin/profile',
          body: {
            'name': name.text.trim(),
            'email': email.text.trim(),
            'telephone': phone.text.trim().isEmpty ? null : phone.text.trim(),
            'nom': lastName.text.trim(),
            'prenom': firstName.text.trim(),
          },
        );
        if (mounted) {
          await AppFeedback.success(
            context,
            title: 'Compte mis à jour',
            message: 'Vos informations administrateur ont été enregistrées.',
          );
          setState(_reload);
        }
      } catch (error) {
        if (mounted) await AppFeedback.error(context, message: error);
      }
    }
    name.dispose();
    email.dispose();
    phone.dispose();
    lastName.dispose();
    firstName.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? _AdminError(
                  error: snapshot.error!,
                  retry: () => setState(_reload),
                )
              : const Center(
                  child: CircularProgressIndicator(color: _flame500),
                );
        }
        final user = snapshot.data!['user'] as Map<String, dynamic>;
        final admin = snapshot.data!['admin'] as Map<String, dynamic>;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Compte administrateur',
              style: TextStyle(
                color: _leaf900,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 38,
              backgroundColor: _flame500,
              child: Text(
                user['name'].toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                user['name'].toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Center(
              child: Text(
                user['email'].toString(),
                style: const TextStyle(color: _inkSoft),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: _leaf700,
                ),
                title: const Text('Rôle'),
                subtitle: const Text('Administrateur'),
              ),
            ),
            Card(
              child: ListTile(
                onTap: () => _edit(user, admin),
                leading: const Icon(Icons.edit_outlined, color: _leaf700),
                title: const Text('Modifier mes informations'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _requiredField(
  TextEditingController controller,
  String label, {
  TextInputType? keyboard,
  bool obscure = false,
  int min = 1,
}) => TextFormField(
  controller: controller,
  keyboardType: keyboard,
  obscureText: obscure,
  decoration: InputDecoration(labelText: '$label *'),
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return '$label est obligatoire.';
    }
    if (value.length < min) {
      return '$label doit contenir au moins $min caractères.';
    }
    return null;
  },
);

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFECE7DA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _flame600, size: 20),
        const Spacer(),
        Text(label, style: const TextStyle(color: _inkSoft, fontSize: 11)),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            color: _leaf900,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _AdminSectionTitle extends StatelessWidget {
  const _AdminSectionTitle(this.text);
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

class _VendorSummary extends StatelessWidget {
  const _VendorSummary({required this.vendor});
  final Map<String, dynamic> vendor;
  @override
  Widget build(BuildContext context) {
    final active = vendor['statut_compte'] == 'actif';
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: _leaf100,
          child: Icon(Icons.storefront, color: _leaf700),
        ),
        title: Text(
          vendor['nom_boutique'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          vendor['adresse_texte']?.toString() ?? 'Adresse non renseignée',
        ),
        trailing: _StatusPill(active: active),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});
  final Map<String, dynamic> order;
  @override
  Widget build(BuildContext context) {
    final vendor = order['vendeur'] as Map<String, dynamic>?;
    final client = order['client'] as Map<String, dynamic>?;
    final user = client?['user'] as Map<String, dynamic>?;
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: _leaf100,
          child: Icon(Icons.receipt_long, color: _leaf700),
        ),
        title: Text(
          '#${order['id']} · ${vendor?['nom_boutique'] ?? 'Vendeur'}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${user?['name'] ?? 'Client'} · ${_money(order['total'])} F',
        ),
        trailing: Text(
          _statusLabel(order['statut'].toString()),
          style: const TextStyle(
            color: _flame600,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: active ? _leaf100 : Colors.red.shade50,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? 'Actif' : 'Suspendu',
      style: TextStyle(
        color: active ? _leaf700 : Colors.red,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _flame600, size: 42),
          const SizedBox(height: 8),
          Text(error.toString(), textAlign: TextAlign.center),
          TextButton(onPressed: retry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

String _money(dynamic value) =>
    double.tryParse(value.toString())?.round().toString() ?? value.toString();
String _statusLabel(String value) =>
    {
      'en_attente_paiement': 'À payer',
      'recue': 'Reçue',
      'preparation': 'Préparation',
      'en_livraison': 'Livraison',
      'livree': 'Livrée',
      'annulee': 'Annulée',
    }[value] ??
    value;
