import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/models.dart';
import '../../core/notifications/notification_providers.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';

const _toggles = [
  ('notif_habit_reminders', 'Habit reminders', 'At the time you set for each habit'),
  ('notif_missed_daily', 'Missed habits', 'If daily habits are still unfinished'),
  ('notif_app_open', 'Open the app', 'If you have not opened the app today'),
  ('notif_level_up', 'Level and rank ups', 'When you grow stronger'),
  ('notif_achievements', 'Achievements and rewards', 'When you earn something'),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(gameProvider).playerName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _export() async {
    final text = const JsonEncoder.withIndent('  ')
        .convert(ref.read(gameProvider).toJson());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _toast('Backup copied. Save it somewhere safe.');
            },
            child: const Text('Copy'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _import() async {
    final restored = await showDialog<GameState>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (restored != null && mounted) {
      ref.read(gameProvider.notifier).replaceState(restored);
      _toast('Backup restored');
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
            'All habits, progress, gold and heroes will be erased. Export a backup first if unsure.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Erase')),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(gameProvider.notifier).replaceState(const GameState());
      _toast('Progress reset');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final controller = ref.read(gameProvider.notifier);
    return Scaffold(
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              Text('Settings', style: AppText.heading(26)),
            ]),
            const SizedBox(height: 8),
            GamePanel(
              child: Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('name_field'),
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Your name'),
                  ),
                ),
                const SizedBox(width: 8),
                GameButton(
                  label: 'Save',
                  compact: true,
                  onPressed: () {
                    controller.setPlayerName(_name.text);
                    _toast('Name saved');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 16),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notifications', style: AppText.headingPlain(20)),
                    Text(
                        ref.watch(notificationServiceProvider).supported
                            ? 'Reminders are scheduled on your phone for the next two weeks and refreshed whenever you open the app.'
                            : 'Phone notifications work in the Android and iPhone apps. In the browser your choices are saved but nothing is delivered.',
                        style: AppText.body(12)),
                    if (ref.watch(notificationServiceProvider).supported)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          GameButton(
                            key: const Key('notif_enable'),
                            label: 'Allow notifications',
                            compact: true,
                            onPressed: () async {
                              final ok = await ref
                                  .read(notificationServiceProvider)
                                  .requestPermission();
                              _toast(ok
                                  ? 'Notifications allowed'
                                  : 'Permission not granted. You can enable it in the phone settings.');
                            },
                          ),
                          GameButton(
                            key: const Key('notif_test'),
                            label: 'Send a test',
                            style: GameButtonStyle.blue,
                            compact: true,
                            onPressed: () =>
                                ref.read(notificationServiceProvider).sendTest(),
                          ),
                        ]),
                      ),
                    for (final t in _toggles)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.$2, style: AppText.body(15)),
                        subtitle: Text(t.$3, style: AppText.body(12)),
                        value: s.setting(t.$1),
                        onChanged: (v) => controller.setSetting(t.$1, v),
                      ),
                  ]),
            ),
            const SizedBox(height: 16),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Backup', style: AppText.headingPlain(20)),
                    const SizedBox(height: 4),
                    Text(
                        'Your data lives on this device. Export a backup to keep it safe or move it to another device.',
                        style: AppText.body(12)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      GameButton(
                          label: 'Export',
                          icon: Icons.upload,
                          style: GameButtonStyle.blue,
                          onPressed: _export),
                      GameButton(
                          label: 'Restore',
                          icon: Icons.download,
                          style: GameButtonStyle.blue,
                          onPressed: _import),
                    ]),
                  ]),
            ),
            const SizedBox(height: 16),
            Center(
              child: GameButton(
                key: const Key('open_character_lab'),
                label: 'Character Lab (preview)',
                icon: Icons.person,
                style: GameButtonStyle.gold,
                onPressed: () => context.push('/character-lab'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GameButton(
                label: 'Reset progress',
                style: GameButtonStyle.danger,
                onPressed: _reset,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Owns its TextEditingController so it is disposed only after the dialog
/// has fully left the tree.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restore() {
    try {
      final decoded = jsonDecode(_controller.text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Not a backup file');
      }
      Navigator.pop(context, GameState.fromJson(decoded));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Restore backup'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Paste your backup. This replaces ALL current data.'),
        TextField(
          key: const Key('import_field'),
          controller: _controller,
          maxLines: 6,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        TextButton(onPressed: _restore, child: const Text('Restore')),
      ],
    );
  }
}
