import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

const _channelId = 'bitachon_reminder';
const _channelName = 'Rappels';
const _channelDescription =
    'Rappels toutes les 3 heures pour ouvrir l\'application';
const _intervalHours = 3;
const _scheduledCount = 28;
const _notificationIdBase = 1000;

Future<void> initializeNotifications() async {
  if (_initialized) return;

  if (!Platform.isAndroid) {
    _initialized = true;
    return;
  }

  tz.initializeTimeZones();
  final timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName));

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);

  await _plugin.initialize(settings);

  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    ),
  );

  _initialized = true;
}

Future<bool> scheduleReminders() async {
  if (!_initialized) {
    await initializeNotifications();
  }

  if (!Platform.isAndroid) return false;

  final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  final permissionGranted =
      await androidPlugin?.requestNotificationsPermission();
  if (permissionGranted == false) {
    return false;
  }

  await _plugin.cancelAll();

  final now = tz.TZDateTime.now(tz.local);
  var nextTime = now.add(const Duration(hours: _intervalHours));

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  for (var i = 0; i < _scheduledCount; i++) {
    await _plugin.zonedSchedule(
      _notificationIdBase + i,
      'Sagesse du Bitachon',
      'Prenez un moment pour lire une phrase de sagesse.',
      nextTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    nextTime = nextTime.add(const Duration(hours: _intervalHours));
  }

  return true;
}
