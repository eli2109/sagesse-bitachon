import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhraseDisplay extends StatelessWidget {
  const PhraseDisplay({
    super.key,
    required this.phrase,
    required this.onCopy,
    this.isEmpty = false,
    this.fontSize = 26,
  });

  final String? phrase;
  final VoidCallback onCopy;
  final bool isEmpty;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final displayText = isEmpty
        ? 'Aucune phrase disponible.\nAjoutez des phrases dans assets/phrases.json.'
        : (phrase ?? '');

    return GestureDetector(
      onLongPress: phrase == null || phrase!.isEmpty ? null : onCopy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
                maxWidth: 480,
              ),
              child: Center(
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: fontSize,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    color: isEmpty
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

void copyPhraseToClipboard(BuildContext context, String phrase) {
  Clipboard.setData(ClipboardData(text: phrase));
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Phrase copiée dans le presse-papiers'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );
}