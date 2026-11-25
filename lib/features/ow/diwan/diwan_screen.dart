import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/world_engine.dart';
import '../ow_style.dart';

const _tierNames = ['خشبي', 'حديدي', 'ذهبي', 'ملكي'];

/// The royal register: chests, the weekly scout report, records, rest days.
class DiwanScreen extends ConsumerWidget {
  const DiwanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final game = ref.read(gameProvider.notifier);
    final chest = WorldEngine.pendingChest(s, now);
    final report = WorldEngine.pendingReport(s, now);
    final thisWeek = WorldEngine.weekScore(s, WorldEngine.weekStart(now));
    final tower = WorldEngine.towerLevel(s.world.bestWeek);
    final next = WorldEngine.nextTowerThreshold(s.world.bestWeek);
    final restToday = WorldEngine.isRestDay(s, now);
    final workedToday = WorldEngine.workedOn(s, dateKeyOf(now));

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 130, 14, 24),
      children: [
        Text('الديوان', style: Ow.title(24, color: Ow.gold)),
        const SizedBox(height: 12),

        // Weekly scout report.
        OwPanel(
          accent: report != null ? Ow.gold : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تقرير الكشّافة', style: Ow.title(18)),
              const SizedBox(height: 6),
              if (report == null)
                Text(
                    'يعود الكشّافة كل يوم اثنين بتقرير الأسبوع الماضي. '
                    'نقاط هذا الأسبوع حتى الآن: $thisWeek',
                    style: Ow.body(13, color: Ow.muted))
              else ...[
                Text(
                    'الأسبوع الماضي: ${report.score} نقطة · '
                    '${report.activeDays} أيام عمل · '
                    '${report.habitsDone} عادات · ${report.tasksDone} مهام',
                    style: Ow.body(14)),
                if (report.isRecord)
                  Text('رقم قياسي جديد!',
                      style: Ow.body(14, color: Ow.gold, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                    'صندوق ${_tierNames[report.tier]}: '
                    '+${report.reward.gold} ذهب، +${report.reward.gems} جواهر، '
                    '+${report.reward.supplies} إمدادات',
                    style: Ow.body(13, color: Ow.muted)),
                const SizedBox(height: 10),
                OwButton(
                  key: const Key('claim_report'),
                  label: 'استلام',
                  icon: Icons.inventory,
                  onPressed: () {
                    final r = game.claimReport();
                    if (r != null) owToast(context, 'استلمت صندوق الكشّافة');
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Daily chest.
        OwPanel(
          accent: chest != null ? Ow.gold : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('صندوق الإمدادات اليومي', style: Ow.title(18)),
              const SizedBox(height: 6),
              Text(
                  chest != null
                      ? 'صندوق الأمس جاهز: +${chest.gold} ذهب، +${chest.supplies} إمدادات'
                          '${chest.gems > 0 ? '، +${chest.gems} جوهرة' : ''}'
                      : 'ما تنجزه اليوم يملأ الصندوق عند البوابة، وتستلمه غداً.',
                  style: Ow.body(13, color: chest != null ? Ow.text : Ow.muted)),
              if (chest != null) ...[
                const SizedBox(height: 10),
                OwButton(
                  key: const Key('claim_chest'),
                  label: 'استلام',
                  onPressed: () {
                    if (game.claimChest() != null) {
                      owToast(context, 'استلمت صندوق الأمس');
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Record tower.
        OwPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('برج الأرقام القياسية', style: Ow.title(18)),
              const SizedBox(height: 6),
              Text(
                  'الطابق $tower من 8 · أفضل أسبوع: ${s.world.bestWeek} نقطة'
                  '${next != null ? ' · الطابق التالي عند $next' : ''}',
                  style: Ow.body(13)),
              const SizedBox(height: 4),
              Text('النقاط: السهلة 1، المتوسطة 2، الصعبة 3، الملحمية 4.',
                  style: Ow.body(12, color: Ow.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Fortifications.
        OwPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التحصينات وأيام الراحة', style: Ow.title(18)),
              const SizedBox(height: 6),
              Text(
                  'لديك ${s.streak.freezesHeld} من ${WorldConfig.maxFortifications}. '
                  'كل ${WorldConfig.fortifyEvery} أيام متصلة تأتيك قطعة '
                  '(${WorldEngine.fortifyProgress(s, now)} من ${WorldConfig.fortifyEvery}).',
                  style: Ow.body(13)),
              const SizedBox(height: 10),
              if (restToday)
                Text('اليوم يوم راحة. سلسلتك محفوظة.',
                    style: Ow.body(13, color: Ow.xp))
              else
                OwButton(
                  key: const Key('rest_day'),
                  label: 'اجعل اليوم يوم راحة',
                  color: Ow.xp,
                  icon: Icons.shield,
                  onPressed: s.streak.freezesHeld > 0 && !workedToday
                      ? () {
                          final st = game.declareRest();
                          owToast(
                              context,
                              switch (st) {
                                RestStatus.ok =>
                                  'أُغلقت البوابات. استرح، فمملكتك في أمان.',
                                RestStatus.tooManyInARow =>
                                  'لا يُتّخذ أكثر من يومي راحة متتاليين.',
                                RestStatus.alreadyCounted =>
                                  'هذا اليوم محسوب لك فعلاً.',
                                RestStatus.noFortification =>
                                  'لا تحصينات لديك.',
                              });
                        }
                      : null,
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: s.setting('auto_fortify', fallback: false),
                onChanged: (v) => game.setSetting('auto_fortify', v),
                title: Text('استعمل تحصيناً تلقائياً إن نسيت يوماً',
                    style: Ow.body(13)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (s.world.goblinLoot > 0) ...[
          OwPanel(
            accent: Ow.danger,
            child: Text(
                'غول أخذ ${s.world.goblinLoot} ذهباً من حصاد المنجم في يوم فاتك. '
                'أنجز شيئاً اليوم ثم المسه في المملكة لتسترد نصفه.',
                style: Ow.body(13)),
          ),
          const SizedBox(height: 12),
        ],

        OwPanel(
          child: Column(children: [
            _Link('التقويم والإحصائيات', Icons.calendar_month,
                () => context.push('/calendar')),
            _Link('الإعدادات والإشعارات والنسخ الاحتياطي', Icons.settings,
                () => context.push('/settings')),
            _Link('معرض الأست', Icons.grid_view,
                () => context.push('/gallery')),
          ]),
        ),
        const SizedBox(height: 8),
        Text('المستوى ${GameEngine.level(s)} · مجموع الإنجازات ${WorldEngine.totalWork(s)}',
            textAlign: TextAlign.center, style: Ow.body(12, color: Ow.muted)),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  const _Link(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Ow.gold),
        title: Text(label, style: Ow.body(14)),
        trailing: const Icon(Icons.chevron_left, color: Ow.muted),
        onTap: onTap,
      );
}
