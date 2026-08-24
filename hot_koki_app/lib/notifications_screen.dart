import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client_screens.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf100 = Color(0xFFE7EEE4);
const _flame600 = Color(0xFFD94B16);
const _flame100 = Color(0xFFFFF0E7);
const _inkSoft = Color(0xFF6B6864);

class NotificationStore {
  static final unread = ValueNotifier<int>(0);
  static bool _initialized = false;

  static void reset() {
    unread.value = 0;
    _initialized = false;
  }

  static Future<void> refresh() async {
    try {
      final data = await ClientApi.request('GET', '/notifications');
      final count = int.tryParse(data['non_lues'].toString()) ?? 0;
      if (_initialized && count > unread.value) {
        try {
          await SystemSound.play(SystemSoundType.alert);
          await HapticFeedback.mediumImpact();
        } catch (_) {
          // Le compteur reste fonctionnel si le son système est indisponible.
        }
      }
      unread.value = count;
      _initialized = true;
    } catch (_) {}
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<Map<String, dynamic>> _future;
  final _searchController = TextEditingController();
  String _status = 'toutes';
  String? _category;
  String? _period;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _path({int page = 1}) {
    final query = <String, String>{
      'statut': _status,
      'page': '$page',
      'categorie': ?_category,
      'periode': ?_period,
      if (_searchController.text.trim().isNotEmpty)
        'recherche': _searchController.text.trim(),
    };
    return Uri(path: '/notifications', queryParameters: query).toString();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      _path(),
    ).then((value) => value as Map<String, dynamic>);
    _future.then((data) {
      NotificationStore.unread.value =
          int.tryParse(data['non_lues'].toString()) ?? 0;
    });
  }

  void _applyFilters() => setState(_reload);

  Future<void> _loadMore(Map<String, dynamic> current) async {
    final pagination = current['pagination'] as Map<String, dynamic>? ?? {};
    final page = int.tryParse(pagination['page'].toString()) ?? 1;
    final previousItems = List<dynamic>.from(
      current['notifications'] as List<dynamic>? ?? const [],
    );
    setState(() {
      _future = ClientApi.request('GET', _path(page: page + 1)).then((value) {
        final next = value as Map<String, dynamic>;
        next['notifications'] = [
          ...previousItems,
          ...List<dynamic>.from(next['notifications'] as List? ?? const []),
        ];
        return next;
      });
    });
    await _future;
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _read(Map<String, dynamic> notification) async {
    if (notification['read_at'] != null) return;
    await ClientApi.request(
      'PATCH',
      '/notifications/${notification['id']}/lire',
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _readAll() async {
    await ClientApi.request('PATCH', '/notifications/tout-lire');
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    color: _leaf900,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: NotificationStore.unread,
                builder: (_, count, _) => TextButton(
                  onPressed: count == 0 ? null : _readAll,
                  child: const Text('Tout lire'),
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) => _NotificationFilters(
            status: _status,
            category: _category,
            period: _period,
            categories:
                snapshot.data?['filtres']?['categories'] as List? ?? const [],
            searchController: _searchController,
            onStatusChanged: (value) {
              _status = value;
              _applyFilters();
            },
            onCategoryChanged: (value) {
              _category = value;
              _applyFilters();
            },
            onPeriodChanged: (value) {
              _period = value;
              _applyFilters();
            },
            onSearch: _applyFilters,
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return _NotificationError(onRetry: _refresh);
                }
                return const Center(
                  child: CircularProgressIndicator(color: _flame600),
                );
              }
              final items = snapshot.data!['notifications'] as List<dynamic>;
              if (items.isEmpty) return const _EmptyNotifications();
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount:
                      items.length +
                      ((snapshot.data?['pagination']?['a_plus'] == true)
                          ? 1
                          : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
                    if (index == items.length) {
                      return Center(
                        child: OutlinedButton.icon(
                          onPressed: () => _loadMore(snapshot.data!),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('Voir les anciennes'),
                        ),
                      );
                    }
                    final item = items[index] as Map<String, dynamic>;
                    return _NotificationCard(
                      notification: item,
                      onTap: () => _read(item),
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

class _NotificationFilters extends StatelessWidget {
  const _NotificationFilters({
    required this.status,
    required this.category,
    required this.period,
    required this.categories,
    required this.searchController,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onPeriodChanged,
    required this.onSearch,
  });

  final String status;
  final String? category;
  final String? period;
  final List<dynamic> categories;
  final TextEditingController searchController;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'toutes', label: Text('Toutes')),
                  ButtonSegment(value: 'non_lues', label: Text('Non lues')),
                  ButtonSegment(value: 'lues', label: Text('Lues')),
                ],
                selected: {status},
                showSelectedIcon: false,
                onSelectionChanged: (values) => onStatusChanged(values.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity(horizontal: -2, vertical: -2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Choisir une période',
              onPressed: () => _choosePeriod(context),
              icon: Badge(
                isLabelVisible: period != null,
                smallSize: 7,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _categoryChip(null, 'Tout', 0),
              for (final raw in categories)
                if (raw is Map)
                  _categoryChip(
                    raw['id']?.toString(),
                    _categoryLabel(raw['id']?.toString()),
                    int.tryParse(raw['non_lues'].toString()) ?? 0,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: 'Rechercher une commande, un paiement…',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    onPressed: () {
                      searchController.clear();
                      onSearch();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: _leaf100.withValues(alpha: .55),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoryChip(String? id, String label, int unread) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: ChoiceChip(
      selected: category == id,
      onSelected: (_) => onCategoryChanged(id),
      label: Text(unread > 0 ? '$label  $unread' : label),
      avatar: unread > 0 && category != id
          ? const CircleAvatar(radius: 3, backgroundColor: _flame600)
          : null,
      showCheckmark: false,
      selectedColor: _leaf900,
      labelStyle: TextStyle(
        color: category == id ? Colors.white : _leaf900,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: BorderSide.none,
      backgroundColor: _leaf100,
      visualDensity: VisualDensity.compact,
    ),
  );

  Future<void> _choosePeriod(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Afficher la période',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              for (final option in const <String?, String>{
                null: 'Toutes les dates',
                'aujourdhui': "Aujourd’hui",
                '7j': '7 derniers jours',
                '30j': '30 derniers jours',
                'archives': 'Archives (+ de 30 jours)',
              }.entries)
                ListTile(
                  title: Text(option.value),
                  trailing: option.key == period
                      ? const Icon(Icons.check_circle, color: _flame600)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onTap: () => Navigator.pop(context, option.key ?? ''),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onPeriodChanged(selected.isEmpty ? null : selected);
  }

  static String _categoryLabel(String? id) => switch (id) {
    'commandes' => 'Commandes',
    'paiements' => 'Paiements',
    'avis' => 'Avis',
    'compte' => 'Compte',
    'systeme' => 'Système',
    _ => 'Autres',
  };
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = notification['data'] as Map<String, dynamic>;
    final unread = notification['read_at'] == null;
    return Material(
      color: unread ? _flame100 : Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: unread ? _flame600 : _leaf100,
                foregroundColor: unread ? Colors.white : _leaf900,
                child: Icon(_icon(data['type']?.toString())),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['titre']?.toString() ?? 'Notification',
                            style: TextStyle(
                              color: _leaf900,
                              fontWeight: unread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: _flame600,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['message']?.toString() ?? '',
                      style: const TextStyle(color: _inkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _date(notification['created_at']?.toString()),
                      style: const TextStyle(color: _inkSoft, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _icon(String? type) {
    if (type?.contains('paiement') == true) return Icons.payments_outlined;
    if (type?.contains('avis') == true) return Icons.star_rounded;
    if (type?.contains('compte') == true) return Icons.storefront_rounded;
    return Icons.receipt_long_rounded;
  }

  static String _date(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'À l’instant';
    if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 60, color: _leaf900),
          SizedBox(height: 12),
          Text(
            'Aucune notification pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          SizedBox(height: 6),
          Text(
            'Les informations importantes apparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _inkSoft),
          ),
        ],
      ),
    ),
  );
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Réessayer'),
    ),
  );
}
