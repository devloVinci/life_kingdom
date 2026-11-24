import 'package:flutter/material.dart';
import '../game/game_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'game_button.dart';
import 'game_panel.dart';

/// Shows the result of completing/undoing a habit: a snackbar for rewards,
/// and a celebration dialog for level-ups, rank-ups and streak milestones.
Future<void> showOutcomeFeedback(
    BuildContext context, CompletionOutcome o) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (o.status) {
    case CompletionStatus.done:
      if (o.xpGained > 0) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              duration: const Duration(seconds: 2),
              content: Text('+${o.xpGained} XP   +${o.goldGained} gold')));
      }
    case CompletionStatus.alreadyCompleted:
      messenger.showSnackBar(
          const SnackBar(content: Text('Already completed today')));
    case CompletionStatus.notDue:
      messenger.showSnackBar(
          const SnackBar(content: Text('This habit is not scheduled today')));
    case CompletionStatus.archived:
    case CompletionStatus.notFound:
    case CompletionStatus.notCompleted:
      break;
  }
  if (!context.mounted) return;
  await showEvents(context, o.events);
}

/// Celebration dialog for level-ups, rank-ups and streak milestones.
Future<void> showEvents(BuildContext context, List<GameEvent> events) async {
  if (events.isEmpty) return;
  final lines = <String>[];
  var title = 'Well done!';
  for (final e in events) {
    switch (e) {
      case LevelUp(:final level):
        title = 'LEVEL UP!';
        lines.add('You reached level $level');
      case RankUp(:final rank):
        title = 'NEW RANK!';
        lines.add('Rank $rank unlocked');
      case StreakMilestone(:final days):
        lines.add('$days-day streak reward');
    }
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: GamePanel(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: AppText.headingPlain(30, color: AppColors.panelPrimary)),
          const SizedBox(height: 12),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: AppText.body(16)),
            ),
          const SizedBox(height: 16),
          GameButton(label: 'Continue', onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}
