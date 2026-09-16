import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'client_screens.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  static Future<void> initializeSafely() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      if (_initialized) return;
      _initialized = true;

      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;
        LocalNotificationService.show(
          title: notification.title ?? 'Hot Koki',
          body: notification.body ?? 'Une nouvelle information est disponible.',
          payload: message.data['type']?.toString(),
        );
      });

      FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => registerAuthenticatedDevice(),
      );

      if (await ClientApi.storage.read(key: 'auth_token') != null) {
        await registerAuthenticatedDevice();
      }
    } catch (_) {
      // Firebase ne doit jamais bloquer l'accès à l'application.
    }
  }

  static Future<void> registerAuthenticatedDevice() async {
    try {
      await initializeSafely();
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await ClientApi.request(
        'POST',
        '/notifications/appareil',
        body: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
      );

      final confirmationShown = await ClientApi.storage.read(
        key: 'push_confirmation_shown',
      );
      if (confirmationShown != 'true') {
        await LocalNotificationService.show(
          title: 'Notifications activées',
          body:
              'Vous recevrez ici le suivi de vos commandes et paiements Hot Koki.',
          payload: 'notifications_activees',
        );
        await ClientApi.storage.write(
          key: 'push_confirmation_shown',
          value: 'true',
        );
      }
    } catch (_) {
      // L'enregistrement sera retenté à la prochaine ouverture/session.
    }
  }
}
