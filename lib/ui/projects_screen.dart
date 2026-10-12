import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';

Color projectColor(String value) => Color(
  int.tryParse(value.replaceAll('#', ''), radix: 16) == null
      ? 0xFF6554C0
      : (int.parse(value.replaceAll('#', ''), radix: 16) | 0xFF000000),
);

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key, required this.store, required this.onOpen});
  final TrackerStore store;
  final ValueChanged<int> onOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth < 600 ? 18.0 : 32.0;
      return ListView(
        padding: EdgeInsets.all(padding),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Проекты',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Отдельное пространство для каждого продукта',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => showProjectEditor(context, store),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Создать проект'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (store.projects.isEmpty)
            SurfaceCard(
              child: EmptyState(
                title: 'Здесь начинается ваш следующий релиз',
                message:
                    'Создайте проект, чтобы собирать и отслеживать дефекты.',
                icon: Icons.folder_open_rounded,
                action: FilledButton(
                  onPressed: () => showProjectEditor(context, store),
                  child: const Text('Первый проект'),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final columns = c.maxWidth > 1050
                    ? 3
                    : c.maxWidth > 620
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: store.projects
                      .map(
                        (project) => SizedBox(
                          width: (c.maxWidth - (columns - 1) * 18) / columns,
                          child: ProjectSummary(
                            project: project,
                            issues: store.issues
                                .where((e) => e.projectId == project.id)
                                .toList(),
                            onTap: () => onOpen(project.id),
                            menu: PopupMenuButton<String>(
                              tooltip: 'Действия с проектом',
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppColors.muted,
                              ),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await showProjectEditor(
                                    context,
                                    store,
                                    project: project,
                                  );
                                } else {
                                  await _deleteProject(context, project);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Редактировать'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Удалить проект',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      );
    },
  );

  Future<void> _deleteProject(BuildContext context, Project project) async {
    final count = store.issues.where((i) => i.projectId == project.id).length;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text(
          '«${project.name}» и все его дефекты ($count), комментарии и вложения будут удалены. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCA5769),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await store.deleteProject(project.id);
      if (context.mounted) showMessage(context, 'Проект удалён');
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }
}

class ProjectSummary extends StatelessWidget {
  const ProjectSummary({
    super.key,
    required this.project,
    required this.issues,
    required this.onTap,
    this.menu,
  });
  final Project project;
  final List<Issue> issues;
  final VoidCallback onTap;
  final Widget? menu;
  @override
  Widget build(BuildContext context) {
    final color = projectColor(project.color);
    final closed = issues.where((e) => e.status == 'Закрыт').length;
    final ratio = issues.isEmpty ? 0.0 : closed / issues.length;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.folder_outlined, color: color, size: 23),
                  ),
                  const Spacer(),
                  if (menu != null)
                    menu!
                  else
                    const Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: AppColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 34,
                child: Text(
                  project.description.isEmpty
                      ? 'Дефекты, задачи и качество продукта'
                      : project.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    '${issues.length} дефектов',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(ratio * 100).round()}% закрыто',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: .10),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${issues.length - closed} открытых',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'С ${shortDate(project.createdAt)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showProjectEditor(
  BuildContext context,
  TrackerStore store, {
  Project? project,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _ProjectEditor(store: store, project: project),
    ) ??
    false;

class _ProjectEditor extends StatefulWidget {
  const _ProjectEditor({required this.store, this.project});
  final TrackerStore store;
  final Project? project;
  @override
  State<_ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<_ProjectEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.project?.name);
  late final _description = TextEditingController(
    text: widget.project?.description,
  );
  late String _color = widget.project?.color ?? '#6554C0';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.project == null) {
        await widget.store.createProject(
          name: _name.text,
          description: _description.text,
          color: _color,
        );
      } else {
        await widget.store.updateProject(
          widget.project!,
          name: _name.text,
          description: _description.text,
          color: _color,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Bad state: ', '');
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.project == null ? 'Новый проект' : 'Редактировать проект',
    ),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Дайте продукту своё пространство.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Название проекта',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Введите хотя бы 2 символа'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Краткое описание',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Цвет проекта',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    [
                          '#6554C0',
                          '#4F87CA',
                          '#399C86',
                          '#C38B42',
                          '#CC6984',
                          '#718096',
                        ]
                        .map(
                          (color) => Semantics(
                            label: 'Цвет $color',
                            selected: _color == color,
                            button: true,
                            child: InkWell(
                              onTap: () => setState(() => _color = color),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: projectColor(color),
                                  shape: BoxShape.circle,
                                ),
                                child: _color == color
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 19,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(
          _saving
              ? 'Сохраняем…'
              : widget.project == null
              ? 'Создать проект'
              : 'Сохранить',
        ),
      ),
    ],
  );
}
