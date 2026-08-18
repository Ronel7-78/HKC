import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';
import 'app_feedback.dart';
import 'client_screens.dart';

const _flame600 = Color(0xFFC9491E);
const _cream = Color(0xFFFFF8EE);

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ClientApi.request(
    'GET',
    '/admin/annonces',
  ).then((value) => value as List<dynamic>);

  Future<void> _form([Map<String, dynamic>? announcement]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AnnouncementForm(announcement: announcement),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: Text(item['titre'].toString()),
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
    if (confirmed != true) return;
    try {
      await ClientApi.request('DELETE', '/admin/annonces/${item['id']}');
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: 'Annonce supprimée',
        message: 'Elle n’apparaît plus sur la page d’accueil.',
      );
      setState(_reload);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      title: const Text('Annonces d’accueil'),
      actions: [
        IconButton(
          onPressed: _form,
          tooltip: 'Nouvelle annonce',
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? Center(
                  child: TextButton(
                    onPressed: () => setState(_reload),
                    child: const Text('Impossible de charger · Réessayer'),
                  ),
                )
              : const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: _form,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Créer la première annonce'),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final item = items[index] as Map<String, dynamic>;
            final image = item['image']?.toString();
            final product = item['produit'] as Map<String, dynamic>?;
            final productImage = product?['photo']?.toString();
            final resolved = image?.isNotEmpty == true
                ? image
                : productImage?.isNotEmpty == true
                ? productImage
                : null;
            return Card(
              child: ListTile(
                onTap: () => _form(item),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFFFE8E5),
                  backgroundImage: resolved == null
                      ? null
                      : NetworkImage(ApiConfig.resolveMediaUrl(resolved)),
                  child: resolved == null
                      ? const Icon(Icons.campaign, color: _flame600)
                      : null,
                ),
                title: Text(
                  item['titre'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item['type'] == 'produit' ? 'Plat' : 'Promotion'} · ${item['active'] == true ? 'Visible' : 'Masquée'}',
                ),
                trailing: IconButton(
                  onPressed: () => _delete(item),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _form,
      icon: const Icon(Icons.add),
      label: const Text('Annonce'),
    ),
  );
}

class _AnnouncementForm extends StatefulWidget {
  const _AnnouncementForm({this.announcement});
  final Map<String, dynamic>? announcement;

  @override
  State<_AnnouncementForm> createState() => _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _order;
  late Future<List<dynamic>> _products;
  String _type = 'promotion';
  int? _productId;
  bool _active = true;
  bool _saving = false;
  XFile? _image;
  bool _removeImage = false;

  @override
  void initState() {
    super.initState();
    final item = widget.announcement;
    _label = TextEditingController(text: item?['etiquette']?.toString());
    _title = TextEditingController(text: item?['titre']?.toString());
    _description = TextEditingController(
      text: item?['description']?.toString(),
    );
    _order = TextEditingController(text: item?['ordre']?.toString() ?? '0');
    _type = item?['type']?.toString() ?? 'promotion';
    _productId = int.tryParse(item?['produit_id']?.toString() ?? '');
    _active = item?['active'] != false;
    _products = ClientApi.request(
      'GET',
      '/admin/produits',
    ).then((value) => value as List<dynamic>);
  }

  @override
  void dispose() {
    _label.dispose();
    _title.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image != null && mounted) {
      setState(() {
        _image = image;
        _removeImage = false;
      });
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final editing = widget.announcement != null;
    try {
      await ClientApi.multipart(
        editing
            ? '/admin/annonces/${widget.announcement!['id']}'
            : '/admin/annonces',
        fields: {
          if (editing) '_method': 'PUT',
          'type': _type,
          'etiquette': _label.text.trim(),
          'titre': _title.text.trim(),
          'description': _description.text.trim(),
          'active': _active ? '1' : '0',
          'ordre': _order.text.trim(),
          'produit_id': _productId?.toString() ?? '',
          if (_removeImage) 'supprimer_image': '1',
        },
        filePath: _image?.path,
      );
      if (!mounted) return;
      await AppFeedback.success(
        context,
        title: editing ? 'Annonce modifiée' : 'Annonce créée',
        message: _active
            ? 'Elle est visible sur l’accueil.'
            : 'Elle est enregistrée mais reste masquée.',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) await AppFeedback.error(context, message: error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _removeImage
        ? null
        : widget.announcement?['image']?.toString();
    return AlertDialog(
      title: Text(
        widget.announcement == null ? 'Nouvelle annonce' : 'Modifier l’annonce',
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 125,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E5),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _image != null
                      ? Image.file(File(_image!.path), fit: BoxFit.cover)
                      : existing?.isNotEmpty == true
                      ? Image.network(
                          ApiConfig.resolveMediaUrl(existing!),
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.campaign_outlined,
                          size: 42,
                          color: _flame600,
                        ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _pick,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Choisir une image'),
                    ),
                    if (_image != null || existing?.isNotEmpty == true)
                      IconButton(
                        onPressed: () => setState(() {
                          _image = null;
                          _removeImage = true;
                        }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'promotion',
                      child: Text('Promotion'),
                    ),
                    DropdownMenuItem(value: 'produit', child: Text('Plat')),
                  ],
                  onChanged: (value) => setState(() => _type = value!),
                ),
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'Étiquette (ex. NOUVEAUTÉ)',
                  ),
                ),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Titre *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Le titre est obligatoire.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                FutureBuilder<List<dynamic>>(
                  future: _products,
                  builder: (_, snapshot) => DropdownButtonFormField<int?>(
                    initialValue: _productId,
                    decoration: const InputDecoration(
                      labelText: 'Plat associé (facultatif)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Aucun'),
                      ),
                      ...(snapshot.data ?? []).map((raw) {
                        final item = raw as Map<String, dynamic>;
                        return DropdownMenuItem<int?>(
                          value: int.parse(item['id'].toString()),
                          child: Text(item['nom'].toString()),
                        );
                      }),
                    ],
                    onChanged: (value) => _productId = value,
                  ),
                ),
                TextFormField(
                  controller: _order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Ordre'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  title: const Text('Visible sur l’accueil'),
                  onChanged: (value) => setState(() => _active = value),
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
}
