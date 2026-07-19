import 'web_push_service_stub.dart'
    if (dart.library.html) 'web_push_service_web.dart' as impl;

/// Web Push (PWA) — iOS Home Screen / navigateur compatible.
class WebPushService {
  WebPushService._();
  static final WebPushService instance = WebPushService._();

  Future<void> loadConfig() => impl.loadConfig();

  bool get isWeb => impl.isWebPlatform;
  bool get isSupported => impl.isPushSupported;
  bool get isStandalone => impl.isStandaloneMode;
  bool get isIos => impl.isIosDevice;
  bool get hasApi => impl.hasPushApi;
  bool get isEnabled => impl.remindersEnabled;

  String get permission => impl.notificationPermission;
  String? get statusMessage => impl.lastStatusMessage;
  String? get apiBaseUrl => impl.configuredApiBaseUrl;

  Future<bool> enableReminders() => impl.enableReminders();
  Future<void> disableReminders() => impl.disableReminders();
  Future<bool> sendTestNotification() => impl.sendTestNotification();
}
