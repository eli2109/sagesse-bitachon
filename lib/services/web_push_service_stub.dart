Future<void> loadConfig() async {}

bool get isWebPlatform => false;
bool get isPushSupported => false;
bool get isStandaloneMode => false;
bool get isIosDevice => false;
bool get hasPushApi => false;
bool get remindersEnabled => false;
String get notificationPermission => 'unsupported';
String? get lastStatusMessage => null;
String? get configuredApiBaseUrl => null;

Future<bool> enableReminders() async => false;
Future<void> disableReminders() async {}
Future<bool> sendTestNotification() async => false;
