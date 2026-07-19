import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

const _prefsEnabledKey = 'web_push_reminders_enabled';

String _vapidPublicKey = '';
String _apiBaseUrl = '';
String _appUrl = 'https://eli2109.github.io/sagesse-bitachon/';
String? _lastStatusMessage;
bool _remindersEnabled = false;

Future<void> loadConfig() async {
  try {
    final raw = await rootBundle.loadString('assets/push_config.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    _vapidPublicKey = (map['vapidPublicKey'] as String?)?.trim() ?? '';
    _apiBaseUrl = (map['apiBaseUrl'] as String?)?.trim() ?? '';
    _appUrl = (map['appUrl'] as String?)?.trim() ?? _appUrl;
  } catch (_) {
    _lastStatusMessage = 'Config push introuvable (assets/push_config.json).';
  }

  final prefs = await SharedPreferences.getInstance();
  _remindersEnabled = prefs.getBool(_prefsEnabledKey) ?? false;
}

bool get isWebPlatform => true;

bool get isPushSupported {
  try {
    final hasNotification =
        web.window.hasProperty('Notification'.toJS).toDart;
    final hasServiceWorker = web.window.navigator.serviceWorker.isDefinedAndNotNull;
    return hasNotification && hasServiceWorker;
  } catch (_) {
    return false;
  }
}

bool get isStandaloneMode {
  try {
    if (web.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    // iOS Safari: navigator.standalone
    final standalone = web.window.navigator.getProperty('standalone'.toJS);
    if (standalone != null && standalone.isA<JSBoolean>()) {
      return (standalone as JSBoolean).toDart;
    }
  } catch (_) {}
  return false;
}

bool get isIosDevice {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      (ua.contains('mac') && web.window.navigator.maxTouchPoints > 1);
}

bool get hasPushApi => _apiBaseUrl.isNotEmpty;
bool get remindersEnabled => _remindersEnabled;

String get notificationPermission {
  try {
    return web.Notification.permission;
  } catch (_) {
    return 'unsupported';
  }
}

String? get lastStatusMessage => _lastStatusMessage;
String? get configuredApiBaseUrl => _apiBaseUrl.isEmpty ? null : _apiBaseUrl;

Uint8List _urlBase64ToBytes(String base64String) {
  final padding = '=' * ((4 - base64String.length % 4) % 4);
  final normalized =
      (base64String + padding).replaceAll('-', '+').replaceAll('_', '/');
  return Uint8List.fromList(base64Decode(normalized));
}

JSAny _applicationServerKey() {
  final bytes = _urlBase64ToBytes(_vapidPublicKey);
  return bytes.buffer.toJS;
}

Future<web.ServiceWorkerRegistration> _registration() async {
  return web.window.navigator.serviceWorker.ready.toDart;
}

String _encodeKey(web.PushSubscription sub, String name) {
  final buffer = sub.getKey(name);
  if (buffer == null) return '';
  final bytes = buffer.toDart.asUint8List();
  return base64Url.encode(bytes).replaceAll('=', '');
}

Map<String, dynamic> _subscriptionToMap(web.PushSubscription sub) {
  return {
    'endpoint': sub.endpoint,
    'keys': {
      'p256dh': _encodeKey(sub, 'p256dh'),
      'auth': _encodeKey(sub, 'auth'),
    },
  };
}

Future<bool> enableReminders() async {
  _lastStatusMessage = null;

  if (!isPushSupported) {
    _lastStatusMessage =
        'Les notifications web ne sont pas supportées sur ce navigateur.';
    return false;
  }

  if (_vapidPublicKey.isEmpty) {
    _lastStatusMessage = 'Clé VAPID manquante dans la configuration.';
    return false;
  }

  if (isIosDevice && !isStandaloneMode) {
    _lastStatusMessage =
        'Sur iPhone : ajoutez d’abord l’app à l’écran d’accueil '
        '(Partager → Sur l’écran d’accueil), puis rouvrez-la depuis l’icône '
        'avant d’activer les rappels.';
    return false;
  }

  if (!hasPushApi) {
    _lastStatusMessage =
        'Le serveur de rappels n’est pas encore configuré (apiBaseUrl vide). '
        'Déployez le dossier push-server (Cloudflare Worker), puis mettez '
        'l’URL dans assets/push_config.json.';
    return false;
  }

  try {
    final permission =
        (await web.Notification.requestPermission().toDart).toDart;
    if (permission != 'granted') {
      _lastStatusMessage =
          'Permission refusée. Autorisez les notifications dans Réglages.';
      return false;
    }

    final reg = await _registration();
    web.PushSubscription? existing;
    try {
      existing = await reg.pushManager.getSubscription().toDart;
    } catch (_) {}

    final web.PushSubscription subscription;
    if (existing != null) {
      subscription = existing;
    } else {
      final options = web.PushSubscriptionOptionsInit(
        userVisibleOnly: true,
        applicationServerKey: _applicationServerKey(),
      );
      subscription = await reg.pushManager.subscribe(options).toDart;
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/subscribe'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'subscription': _subscriptionToMap(subscription)}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _lastStatusMessage =
          'Échec d’enregistrement côté serveur (${response.statusCode}). '
          '${response.body}';
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsEnabledKey, true);
    _remindersEnabled = true;
    _lastStatusMessage =
        'Rappels activés. Une notification arrivera toutes les 3 heures '
        '(même si l’app est fermée).';

    // Immediate feedback on platforms that allow local Notification API.
    try {
      web.Notification(
        'Sagesse du Bitachon',
        web.NotificationOptions(
          body: 'Rappels activés. Prochain rappel automatique sous 3 heures.',
          icon: 'icons/Icon-192.png',
          tag: 'bitachon-enabled',
        ),
      );
    } catch (_) {}

    return true;
  } catch (e) {
    _lastStatusMessage = 'Impossible d’activer les rappels : $e';
    return false;
  }
}

Future<void> disableReminders() async {
  _lastStatusMessage = null;
  try {
    final reg = await _registration();
    final sub = await reg.pushManager.getSubscription().toDart;
    if (sub != null) {
      if (hasPushApi) {
        try {
          await http.post(
            Uri.parse('$_apiBaseUrl/unsubscribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'subscription': _subscriptionToMap(sub)}),
          );
        } catch (_) {}
      }
      await sub.unsubscribe().toDart;
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_prefsEnabledKey, false);
  _remindersEnabled = false;
  _lastStatusMessage = 'Rappels désactivés.';
}

Future<bool> sendTestNotification() async {
  try {
    if (web.Notification.permission != 'granted') {
      _lastStatusMessage = 'Permission notifications non accordée.';
      return false;
    }
    web.Notification(
      'Sagesse du Bitachon',
      web.NotificationOptions(
        body: 'Notification de test — les rappels 3 h viennent du serveur.',
        icon: 'icons/Icon-192.png',
        tag: 'bitachon-test',
      ),
    );
    _lastStatusMessage = 'Notification de test affichée.';
    return true;
  } catch (e) {
    _lastStatusMessage = 'Test impossible : $e';
    return false;
  }
}
