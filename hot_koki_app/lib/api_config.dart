import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String apiResourceId(Map<dynamic, dynamic> resource) =>
    (resource['public_id'] ?? resource['id']).toString();

String formatDistanceKm(dynamic value) {
  final distance = double.tryParse(value?.toString() ?? '');
  if (distance == null) return 'Distance indisponible';
  final decimals = (distance - 3).abs() < .01 ? 3 : 2;
  return '${distance.toStringAsFixed(decimals)} km';
}

String deliveryFeeText(dynamic value) {
  final fee = double.tryParse(value?.toString() ?? '') ?? 0;
  return 'Frais de livraison : ${fee.round()} FCFA';
}

class ApiConfig {
  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      _validate(_definedBaseUrl);
      return _definedBaseUrl;
    }
    if (appFlavor == null || appFlavor == 'development') {
      return 'http://10.0.2.2:8000/api';
    }
    throw StateError('API_BASE_URL est obligatoire pour un build $appFlavor.');
  }

  static void _validate(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.path.endsWith('/api')) {
      throw StateError('API_BASE_URL doit être une URL terminée par /api.');
    }
    if ((kReleaseMode || appFlavor != 'development') && uri.scheme != 'https') {
      throw StateError('Staging et production exigent une API HTTPS.');
    }
  }

  static String resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = baseUrl.replaceFirst(RegExp(r'/api$'), '');
    return '$root/${path.replaceFirst(RegExp(r'^/'), '')}';
  }
}
