import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import '../../features/notifications/data/notifications_repository.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart' as plat;

typedef PushDeepLinkHandler = void Function(Map<String, dynamic> data);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.messageId}');
}

/// FCM with config guard. Builds and runs without Firebase project files.
class PushMessagingService {
  PushMessagingService(this._repo);
  final NotificationsRepository _repo;
  String? _token;
  PushDeepLinkHandler? onDeepLink;
  bool enabled = false;

  Future<void> init({PushDeepLinkHandler? deepLink}) async {
    onDeepLink = deepLink;
    if (!isFirebaseConfigured) {
      debugPrint('PushMessagingService: Firebase not configured — push disabled');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission denied');
        return;
      }

      if (!kIsWeb && plat.isIosPlatform) {
        await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      }

      _token = await messaging.getToken();
      enabled = _token != null;
      messaging.onTokenRefresh.listen((t) async {
        _token = t;
        await registerIfPossible();
      });

      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('FCM foreground: ${msg.notification?.title}');
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleOpen(initial);

      await registerIfPossible();
    } catch (e) {
      debugPrint('PushMessagingService init failed (push disabled): $e');
      enabled = false;
    }
  }

  void _handleOpen(RemoteMessage message) {
    onDeepLink?.call(Map<String, dynamic>.from(message.data));
  }

  Future<void> registerIfPossible() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repo.registerDevice(token, plat.detectPlatform());
    } catch (e) {
      debugPrint('device register skipped: $e');
    }
  }

  Future<void> unregister() async {
    final token = _token;
    if (token == null) return;
    try {
      await _repo.unregisterDevice(token);
    } catch (_) {}
  }
}
