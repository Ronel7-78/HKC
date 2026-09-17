import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'client_screens.dart';

/// Publie la position d'un vendeur ambulant uniquement pendant que
/// l'application est ouverte et que son profil est déclaré disponible.
class VendorLocationService {
  VendorLocationService._();

  static StreamSubscription<Position>? _subscription;
  static DateTime? _lastSentAt;
  static bool _starting = false;

  static Future<void> start() async {
    if (_starting || _subscription != null) return;
    _starting = true;
    try {
      final response =
          await ClientApi.request('GET', '/vendeur/profile')
              as Map<String, dynamic>;
      final vendor = response['vendeur'] as Map<String, dynamic>?;
      if (vendor == null ||
          vendor['type_vendeur']?.toString() == 'point_fixe' ||
          vendor['statut_dispo']?.toString() != 'disponible') {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      try {
        final initial = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        await _send(initial);
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) await _send(lastKnown);
      }

      _subscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 25,
        ),
      ).listen(_send, onError: (_) {});
    } catch (_) {
      // Une panne GPS ne doit jamais bloquer l'espace vendeur.
    } finally {
      _starting = false;
    }
  }

  static Future<void> restart() async {
    await stop();
    await start();
  }

  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _lastSentAt = null;
  }

  static Future<void> _send(Position position) async {
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!).inSeconds < 30) {
      return;
    }
    try {
      await ClientApi.request(
        'PATCH',
        '/vendeur/position',
        body: {'latitude': position.latitude, 'longitude': position.longitude},
      );
      _lastSentAt = now;
    } catch (_) {
      // La prochaine position retentera automatiquement l'envoi.
    }
  }
}
