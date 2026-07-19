import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/web_push_service.dart';

/// Bottom sheet: PWA install tips (iOS) + Web Push enable/disable.
Future<void> showReminderSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _ReminderSheet(),
  );
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet();

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  final _push = WebPushService.instance;
  bool _busy = false;

  Future<void> _refresh(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeb = kIsWeb && _push.isWeb;
    final ios = _push.isIos;
    final standalone = _push.isStandalone;
    final enabled = _push.isEnabled;
    final hasApi = _push.hasApi;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Rappels toutes les 3 heures',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Sur iPhone, les notifications web ne marchent que si l’app '
                'est ajoutée à l’écran d’accueil (PWA), puis que vous autorisez '
                'les notifications.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              if (isWeb && ios && !standalone) ...[
                _InfoCard(
                  icon: Icons.add_to_home_screen,
                  title: 'Étape 1 — Ajouter à l’écran d’accueil',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1. Ouvrez ce site dans Safari (pas Chrome).\n'
                        '2. Appuyez sur le bouton Partager □↑\n'
                        '3. Choisissez « Sur l’écran d’accueil »\n'
                        '4. Validez, puis ouvrez l’app depuis l’icône.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lien à utiliser :\nhttps://eli2109.github.io/sagesse-bitachon/',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(
                              text:
                                  'https://eli2109.github.io/sagesse-bitachon/',
                            ),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lien copié'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copier le lien'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (isWeb && ios && standalone)
                _InfoCard(
                  icon: Icons.check_circle_outline,
                  title: 'Ouverte depuis l’écran d’accueil',
                  child: Text(
                    'Parfait. Vous pouvez activer les notifications ci-dessous '
                    '(iOS 16.4 ou plus récent).',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              if (isWeb && !hasApi) ...[
                const SizedBox(height: 12),
                _InfoCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Serveur de rappels à configurer',
                  child: Text(
                    'Les notifications planifiées nécessitent le petit serveur '
                    'Web Push (Cloudflare Worker dans push-server/). '
                    'Sans apiBaseUrl dans assets/push_config.json, '
                    'l’abonnement ne peut pas être enregistré.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_busy)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                FilledButton.icon(
                  onPressed: !isWeb
                      ? null
                      : () async {
                          await _refresh(() async {
                            if (enabled) {
                              await _push.disableReminders();
                            } else {
                              await _push.enableReminders();
                            }
                          });
                        },
                  icon: Icon(
                    enabled
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_active_outlined,
                  ),
                  label: Text(
                    enabled
                        ? 'Désactiver les rappels'
                        : 'Activer les rappels (toutes les 3 h)',
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _refresh(() async {
                        await _push.sendTestNotification();
                      });
                    },
                    icon: const Icon(Icons.notification_add_outlined),
                    label: const Text('Envoyer une notification de test'),
                  ),
                ],
              ],
              if (_push.statusMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _push.statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Permission : ${_push.permission}'
                '${hasApi ? '' : ' · API non configurée'}'
                '${enabled ? ' · rappels ON' : ''}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
