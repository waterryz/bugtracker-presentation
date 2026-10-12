import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';
import 'issue_dialogs.dart';
import 'projects_screen.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.store,
    required this.onCreate,
    required this.onIssues,
    required this.onProject,
  });
  final TrackerStore store;
  final VoidCallback onCreate;
  final void Function(String? status) onIssues;
  final ValueChanged<int> onProject;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      final padding = constraints.maxWidth < 600 ? 18.0 : 32.0;
      final closed = store.issues.where((e) => e.status == 'Закрыт').length;
      final opened = store.issues.length - closed;
      final critical = store.issues
          .where((e) => e.priority == 'Критический' && e.status != 'Закрыт')
          .length;
      final review = store.issues
          .where((e) => e.status == 'На проверке')
          .length;
      final recent = [...store.issues]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return ListView(
        padding: EdgeInsets.all(padding),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Всё под контролем',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Здравствуйте, ${store.currentUser!.name.split(' ').first}. Вот что происходит в проектах.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Новый дефект'),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _hero(context, closed, opened),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth >= 700 ? 4 : 2;
              final width = (c.maxWidth - (columns - 1) * 14) / columns;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  _metric(
                    width,
                    'Всего дефектов',
                    store.issues.length,
                    Icons.layers_outlined,
                    AppColors.accent,
                    'Во всех проектах',
                    () => onIssues(null),
                  ),
                  _metric(
                    width,
                    'Открытые',
                    opened,
                    Icons.adjust_rounded,
                    const Color(0xFF5D83CD),
                    'Ждут решения',
                    () => onIssues('Открытые'),
                  ),
                  _metric(
                    width,
                    'Критические',
                    critical,
                    Icons.priority_high_rounded,
                    const Color(0xFFD96B78),
                    'Требуют внимания',
                    () => onIssues('Критические'),
                  ),
                  _metric(
                    width,
                    'На проверке',
                    review,
                    Icons.fact_check_outlined,
                    const Color(0xFFBD944C),
                    'Можно протестировать',
                    () => onIssues('На проверке'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _recent(context, recent)),
                const SizedBox(width: 22),
                Expanded(flex: 4, child: _status(context)),
              ],
            )
          else ...[
            _recent(context, recent),
            const SizedBox(height: 20),
            _status(context),
          ],
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Ваши проекты',
            subtitle: 'От первой ошибки до стабильного релиза',
            trailing: TextButton.icon(
              onPressed: () => showProjectEditor(context, store),
              icon: const Icon(Icons.add, size: 17),
              label: const Text('Создать'),
            ),
          ),
          const SizedBox(height: 16),
          if (store.projects.isEmpty)
            SurfaceCard(
              child: EmptyState(
                title: 'Начните с первого проекта',
                message: 'Соберите дефекты приложения в одном месте.',
                icon: Icons.folder_open_rounded,
                action: FilledButton.icon(
                  onPressed: () => showProjectEditor(context, store),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Создать проект'),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final cols = c.maxWidth > 950
                    ? 3
                    : c.maxWidth > 600
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: store.projects
                      .take(6)
                      .map(
                        (p) => SizedBox(
                          width: (c.maxWidth - 16 * (cols - 1)) / cols,
                          child: ProjectSummary(
                            project: p,
                            issues: store.issues
                                .where((i) => i.projectId == p.id)
                                .toList(),
                            onTap: () => onProject(p.id),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: AppColors.muted,
              ),
              SizedBox(width: 6),
              Text(
                'Сохраняется локально · Доступно без интернета',
                style: TextStyle(color: AppColors.muted, fontSize: 10),
              ),
            ],
          ),
        ],
      );
    },
  );

  Widget _hero(BuildContext context, int closed, int open) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6554BA), Color(0xFF8070CC)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -32,
          top: -110,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .07),
                width: 48,
              ),
            ),
          ),
        ),
        Positioned(
          right: 110,
          bottom: -170,
          child: Container(
            width: 290,
            height: 290,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: .06),
                width: 36,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: LayoutBuilder(
            builder: (context, c) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: Color(0xFFDFD9FF),
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ШАГ ЗА ШАГОМ К ЛУЧШЕМУ ПРОДУКТУ',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFE2DCFF),
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        store.issues.isEmpty
                            ? 'Хорошие релизы начинаются здесь.'
                            : open == 0
                            ? 'Все дефекты закрыты. Отличная работа!'
                            : 'Меньше ошибок. Больше уверенности.',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.3,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        store.issues.isEmpty
                            ? 'Создайте проект и зафиксируйте первый дефект.'
                            : 'Закрыто $closed из ${store.issues.length} дефектов. Каждый шаг делает продукт лучше.',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Color(0xFFE4DFF9),
                        ),
                      ),
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => onIssues('Открытые'),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Перейти к дефектам',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (c.maxWidth > 600) ...[
                  const SizedBox(width: 22),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: CircularProgressIndicator(
                            value: store.issues.isEmpty
                                ? 0
                                : closed / store.issues.length,
                            strokeWidth: 6,
                            backgroundColor: Colors.white.withValues(
                              alpha: .17,
                            ),
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${store.issues.isEmpty ? 0 : (closed / store.issues.length * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Text(
                              'закрыто',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE2DCFF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _metric(
    double width,
    String title,
    int value,
    IconData icon,
    Color color,
    String note,
    VoidCallback onTap,
  ) => SizedBox(
    width: width,
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(19),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                ],
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                note,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _recent(BuildContext context, List<Issue> recent) => SurfaceCard(
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          title: 'Последние обновления',
          subtitle: 'То, над чем вы работали недавно',
          trailing: IconButton(
            tooltip: 'Все дефекты',
            onPressed: () => onIssues(null),
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 18),
        if (recent.isEmpty)
          const EmptyState(
            title: 'Здесь появятся ваши дефекты',
            message: 'Добавьте первый, чтобы начать работу.',
          )
        else
          ...recent
              .take(5)
              .map(
                (issue) => InkWell(
                  onTap: () => showIssueDetails(context, store, issue.id),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 2,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: priorityColor(issue.priority)
                                .withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.bug_report_outlined,
                            size: 17,
                            color: priorityColor(issue.priority),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'BUG-${issue.id.toString().padLeft(3, '0')}  ·  ${store.projectById(issue.projectId)?.name ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusPill(status: issue.status),
                      ],
                    ),
                  ),
                ),
              ),
      ],
    ),
  );

  Widget _status(BuildContext context) {
    final counts = {
      for (final status in issueStatuses)
        status: store.issues.where((i) => i.status == status).length,
    };
    final total = store.issues.length;
    return SurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Пульс проектов', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          const Text(
            'Распределение по статусам',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 130,
              height: 130,
              child: CustomPaint(
                painter: _DonutPainter(counts),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$total',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'дефектов',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          ...counts.entries.map(
            (entry) => InkWell(
              onTap: () => onIssues(entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor(entry.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.counts);
  final Map<String, int> counts;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    final rect = Rect.fromLTWH(9, 9, size.width - 18, size.height - 18);
    paint.color = AppColors.background;
    canvas.drawOval(rect, paint);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;
    var start = -math.pi / 2;
    for (final entry in counts.entries) {
      if (entry.value == 0) continue;
      final angle = entry.value / total * math.pi * 2;
      paint.color = statusColor(entry.key);
      canvas.drawArc(
        rect,
        start + .015,
        math.max(0.0, angle - .03),
        false,
        paint,
      );
      start += angle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}
