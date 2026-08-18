import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'client_screens.dart';

const _leaf900 = Color(0xFF1F3524);
const _leaf100 = Color(0xFFE7EEE4);
const _flame600 = Color(0xFFC9491E);
const _flame100 = Color(0xFFFFE8E5);
const _inkSoft = Color(0xFF6B5F4E);

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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ClientApi.request(
      'GET',
      '/notifications',
    ).then((value) => value as Map<String, dynamic>);
    _future.then((data) {
      NotificationStore.unread.value =
          int.tryParse(data['non_lues'].toString()) ?? 0;
    });
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
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) {
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
