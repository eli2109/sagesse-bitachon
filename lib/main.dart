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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sagesse du Bitachon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E5A8E),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B9BD5),
          brightness: Brightness.dark,
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final hasPhrases = _service.cycleLength > 0;
    final currentPhrase = _service.currentPhrase;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sagesse du Bitachon'),
        centerTitle: true,
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'Rappels / notifications',
              onPressed: () => showReminderSheet(context),
              icon: Icon(
                WebPushService.instance.isEnabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
              ),
            ),
          IconButton(
            tooltip: 'Réduire la police',
            onPressed: _fontSizeService.canDecrease ? _decreaseFontSize : null,
            icon: const Icon(Icons.text_decrease_outlined),
          ),
          IconButton(
            tooltip: 'Augmenter la police',
            onPressed: _fontSizeService.canIncrease ? _increaseFontSize : null,
            icon: const Icon(Icons.text_increase_outlined),
          ),
          if (hasPhrases)
            IconButton(
              tooltip: 'Copier la phrase',
              onPressed: _copyCurrentPhrase,
              icon: const Icon(Icons.copy_outlined),
            ),
          if (hasPhrases)
            IconButton(
              tooltip: 'Nouveau cycle',
              onPressed: _startNewCycle,
              icon: const Icon(Icons.shuffle),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: PhraseDisplay(
                      phrase: currentPhrase,
                      isEmpty: !hasPhrases,
                      onCopy: _copyCurrentPhrase,
                      fontSize: _fontSizeService.fontSize,
                    ),
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      if (hasPhrases)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Phrase ${_service.displayPosition} / ${_service.cycleLength} dans ce cycle',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed:
                              hasPhrases && !_isAdvancing ? _goToNext : null,
                          child: _isAdvancing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Suivant'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}