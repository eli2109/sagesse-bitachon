import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/font_size_service.dart';
import 'services/notification_service.dart';
import 'services/phrase_service.dart';
import 'services/web_push_service.dart';
import 'widgets/phrase_display.dart';
import 'widgets/reminder_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  if (kIsWeb) {
    await WebPushService.instance.loadConfig();
  }
  runApp(const SagesseBitachonApp());
}

class SagesseBitachonApp extends StatelessWidget {
  const SagesseBitachonApp({super.key});

  static ThemeData _theme(Brightness brightness, Color seed) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    );
    return base.copyWith(
      // Large touch targets for phones (thumb-friendly).
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(56, 56),
          maximumSize: const Size(64, 64),
          iconSize: 34,
          padding: const EdgeInsets.all(12),
          visualDensity: VisualDensity.standard,
          foregroundColor: base.colorScheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        toolbarHeight: 68,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: base.colorScheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 68),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          textStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sagesse du Bitachon',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light, const Color(0xFF1E5A8E)),
      darkTheme: _theme(Brightness.dark, const Color(0xFF5B9BD5)),
      themeMode: ThemeMode.system,
      home: const ReadingScreen(),
    );
  }
}

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  final PhraseService _service = PhraseService();
  final FontSizeService _fontSizeService = FontSizeService();
  bool _isLoading = true;
  bool _isAdvancing = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _service.initialize(),
      _fontSizeService.load(),
      NotificationService.instance.scheduleReminders(),
    ]);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (await _service.shouldShowWelcome()) {
      await _showWelcomeDialog();
      await _service.markWelcomeShown();
    }
  }

  Future<void> _showWelcomeDialog() async {
    if (!mounted) return;

    final String reminderLine;
    if (NotificationService.instance.isSupported) {
      reminderLine =
          '\n\nUn rappel local vous sera envoyé toutes les 3 heures (Android).';
    } else if (kIsWeb) {
      reminderLine =
          '\n\nVotre progression est mémorisée dans ce navigateur.\n\n'
          'Pour des rappels sur iPhone : ajoutez l’app à l’écran d’accueil, '
          'puis activez les notifications via l’icône cloche.';
    } else {
      reminderLine = '\n\nVotre progression est sauvegardée localement.';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bienvenue'),
        content: Text(
          'Cette application vous propose des phrases et idées du Shaar HaBitachon, '
          'une à la fois, dans un ordre mélangé.\n\n'
          'Appuyez sur « Suivant » pour avancer. Votre progression est sauvegardée '
          'automatiquement.'
          '$reminderLine',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToNext() async {
    if (_isAdvancing || _service.cycleLength == 0) return;

    setState(() => _isAdvancing = true);
    await _service.nextPhrase();
    if (!mounted) return;
    setState(() => _isAdvancing = false);
  }

  Future<void> _startNewCycle() async {
    if (_service.phrases.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau cycle'),
        content: const Text(
          'Mélanger à nouveau toutes les phrases et recommencer au début ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _service.startNewCycle();
    if (!mounted) return;
    setState(() {});
  }

  void _copyCurrentPhrase() {
    final phrase = _service.currentPhrase;
    if (phrase == null || phrase.isEmpty) return;
    copyPhraseToClipboard(context, phrase);
  }

  Future<void> _increaseFontSize() async {
    await _fontSizeService.increase();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _decreaseFontSize() async {
    await _fontSizeService.decrease();
    if (!mounted) return;
    setState(() {});
  }

  /// Max content width so buttons stay proportional on phones & desktops.
  static const double _contentMaxWidth = 420;

  Widget _toolbarIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
    bool emphasized = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(56, 56),
        iconSize: 34,
        foregroundColor: emphasized
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: onPressed == null ? 0.35 : 0.95),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhrases = _service.cycleLength > 0;
    final currentPhrase = _service.currentPhrase;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sagesse du Bitachon'),
        centerTitle: true,
        actions: [
          if (kIsWeb)
            _toolbarIcon(
              tooltip: 'Rappels / notifications',
              onPressed: () => showReminderSheet(context),
              emphasized: WebPushService.instance.isEnabled,
              icon: WebPushService.instance.isEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_none_outlined,
            ),
          _toolbarIcon(
            tooltip: 'Réduire la police',
            onPressed: _fontSizeService.canDecrease ? _decreaseFontSize : null,
            icon: Icons.text_decrease,
          ),
          _toolbarIcon(
            tooltip: 'Augmenter la police',
            onPressed: _fontSizeService.canIncrease ? _increaseFontSize : null,
            icon: Icons.text_increase,
          ),
          if (hasPhrases)
            _toolbarIcon(
              tooltip: 'Copier la phrase',
              onPressed: _copyCurrentPhrase,
              icon: Icons.copy_rounded,
            ),
          if (hasPhrases)
            _toolbarIcon(
              tooltip: 'Nouveau cycle',
              onPressed: _startNewCycle,
              icon: Icons.shuffle_rounded,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth + 48),
                child: Column(
                  children: [
                    Expanded(
                      child: PhraseDisplay(
                        phrase: currentPhrase,
                        isEmpty: !hasPhrases,
                        onCopy: _copyCurrentPhrase,
                        fontSize: _fontSizeService.fontSize,
                      ),
                    ),
                    SafeArea(
                      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        children: [
                          if (hasPhrases)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Text(
                                'Phrase ${_service.displayPosition} / ${_service.cycleLength} dans ce cycle',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: _contentMaxWidth,
                                minWidth: 260,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 68,
                                child: FilledButton(
                                  onPressed: hasPhrases && !_isAdvancing
                                      ? _goToNext
                                      : null,
                                  child: _isAdvancing
                                      ? SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: scheme.onPrimary,
                                          ),
                                        )
                                      : const Text('Suivant'),
                                ),
                              ),
                            ),
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
}