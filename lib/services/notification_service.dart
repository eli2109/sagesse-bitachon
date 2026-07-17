import 'package:flutter/foundation.dart';

import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart' as impl;

/// Rappels locaux (Android). Sur le web : no-op (pas de push navigateur).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initialize() => impl.initializeNotifications();

  Future<bool> scheduleReminders() => impl.scheduleReminders();

  /// True seulement sur les plateformes où les rappels locaux sont actifs.
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
