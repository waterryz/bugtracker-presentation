import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';
import 'issue_dialogs.dart';
import 'projects_screen.dart';

class IssueListScreen extends StatefulWidget {
  const IssueListScreen({
    super.key,
    required this.store,
    required this.query,
    required this.onCreate,
    required this.onClearSearch,
    this.projectId,
    this.initialStatus,
  });
  final TrackerStore store;
  final String query;
  final int? projectId;
  final String? initialStatus;
  final VoidCallback onCreate;
  final VoidCallback onClearSearch;
  @override
  State<IssueListScreen> createState() => _IssueListScreenState();
}

class _IssueListScreenState extends State<IssueListScreen> {
  final _search = TextEditingController();
  late int? _project = widget.projectId;
  late String? _status = widget.initialStatus == 'Критические'
      ? null
      : widget.initialStatus;
  late String? _priority = widget.initialStatus == 'Критические'
      ? 'Критический'
      : null;
  late bool _hideClosed = widget.initialStatus == 'Критические';
  int? _assignee;
  String _sort = 'Обновлённые';
  bool _board = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Issue> get _filtered {
    final query = '${widget.query} ${_search.text}'.trim().toLowerCase();
    final results = widget.store.issues.where((i) {
      if (_project != null && i.projectId != _project) return false;
      if (_status == 'Открытые' && i.status == 'Закрыт') return false;
      if (_status != null && _status != 'Открытые' && i.status != _status) {
        return false;
      }
      if (_priority != null && i.priority != _priority) return false;
      if (_hideClosed && i.status == 'Закрыт') return false;
      if (_assignee == -1 && i.assigneeId != null) return false;
      if (_assignee != null && _assignee != -1 && i.assigneeId != _assignee) {
        return false;
      }
      final searchable =
          'BUG-${i.id.toString().padLeft(3, '0')} ${i.title} ${i.description} ${i.steps} ${widget.store.projectById(i.projectId)?.name ?? ''}'
              .toLowerCase();
      return query.isEmpty ||
          query.split(RegExp(r'\s+')).every(searchable.contains);
    }).toList();
    results.sort(
      (a, b) => switch (_sort) {
        'Приоритет' =>
          issuePriorities
              .indexOf(b.priority)
              .compareTo(issuePriorities.indexOf(a.priority)),
        'Новые' => b.createdAt.compareTo(a.createdAt),
        'Старые' => a.createdAt.compareTo(b.createdAt),
        _ => b.updatedAt.compareTo(a.updatedAt),
      },
    );
    return results;
  }

  void _reset() => setState(() {
    _project = null;
    _status = null;
    _priority = null;
    _assignee = null;
    _hideClosed = false;
    _search.clear();
    widget.onClearSearch();
  });

  Future<void> _createIssue() async {
    if (widget.store.projects.isEmpty) {
      widget.onCreate();
      return;
    }
    await showIssueEditor(context, widget.store, projectId: _project);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 700;
      final items = _filtered;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 32,
                28,
                compact ? 18 : 32,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _project == null
                                ? 'Дефекты'
                                : widget.store.projectById(_project!)?.name ??
                                      'Дефекты',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${widget.store.issues.length} в пространстве · ${items.length} в текущей выборке',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _createIssue,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Новый дефект'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Название, описание или BUG-001',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Очистить поиск',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(_search.clear),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.view_list_outlined, size: 20),
                            tooltip: 'Список',
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.view_kanban_outlined, size: 20),
                            tooltip: 'Доска',
                          ),
                        ],
                        showSelectedIcon: false,
                        selected: {_board},
                        onSelectionChanged: (value) =>
                            setState(() => _board = value.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _filter<String>(
                        label: 'Все статусы',
                        value: _status,
                        values: ['Открытые', ...issueStatuses],
                        text: (e) => e,
                        onChanged: (v) => setState(() => _status = v),
                      ),
                      _filter<String>(
                        label: 'Любой приоритет',
                        value: _priority,
                        values: issuePriorities,
                        text: (e) => e,
                        onChanged: (v) => setState(() => _priority = v),
                      ),
                      _filter<int>(
                        label: 'Все проекты',
                        value: widget.store.projectById(_project ?? -1) == null
                            ? null
                            : _project,
                        values: widget.store.projects.map((e) => e.id).toList(),
                        text: (id) => widget.store.projectById(id)!.name,
                        onChanged: (v) => setState(() => _project = v),
                      ),
                      _filter<int>(
                        label: 'Любой исполнитель',
                        value: _assignee,
                        values: [-1, ...widget.store.users.map((e) => e.id)],
                        text: (id) => id == -1
                            ? 'Не назначен'
                            : widget.store.userById(id)?.name ?? 'Пользователь',
                        onChanged: (v) => setState(() => _assignee = v),
                      ),
                      if (_status != null ||
                          _priority != null ||
                          _project != null ||
                          _assignee != null ||
                          _hideClosed)
                        TextButton.icon(
                          onPressed: _reset,
                          icon: const Icon(
                            Icons.filter_alt_off_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Сбросить',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        label: const Text(
                          'Назначены мне',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: _assignee == widget.store.currentUser!.id,
                        onSelected: (value) => setState(
                          () => _assignee = value
                              ? widget.store.currentUser!.id
                              : null,
                        ),
                        avatar: const Icon(
                          Icons.person_outline_rounded,
                          size: 15,
                        ),
                        showCheckmark: false,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      FilterChip(
                        label: const Text(
                          'Скрыть закрытые',
                          style: TextStyle(fontSize: 11),
                        ),
                        selected: _hideClosed,
                        onSelected: (value) =>
                            setState(() => _hideClosed = value),
                        showCheckmark: false,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Сортировка',
                        initialValue: _sort,
                        onSelected: (value) => setState(() => _sort = value),
                        itemBuilder: (_) =>
                            ['Обновлённые', 'Приоритет', 'Новые', 'Старые']
                                .map(
                                  (e) =>
                                      PopupMenuItem(value: e, child: Text(e)),
                                )
                                .toList(),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 17,
                                color: AppColors.muted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sort,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: items.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(
                      title: widget.store.issues.isEmpty
                          ? 'Первый дефект — первый шаг к качеству'
                          : 'Ничего не найдено',
                      message: widget.store.issues.isEmpty
                          ? 'Добавьте ошибку, описание и шаги воспроизведения.'
                          : 'Попробуйте изменить поисковый запрос или фильтры.',
                      action: widget.store.issues.isEmpty
                          ? FilledButton(
                              onPressed: _createIssue,
                              child: const Text('Добавить дефект'),
                            )
                          : TextButton(
                              onPressed: _reset,
                              child: const Text('Сбросить фильтры'),
                            ),
                    ),
                  )
                : _board
                ? _kanban(items)
                : _list(items, compact),
          ),
        ],
      );
    },
  );

  Widget _filter<T>({
    required String label,
    required T? value,
    required List<T> values,
    required String Function(T) text,
    required ValueChanged<T?> onChanged,
  }) => Container(
    height: 42,
    width: MediaQuery.sizeOf(context).width < 700 ? 170 : 185,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color: value == null
            ? AppColors.border
            : AppColors.accent.withValues(alpha: .35),
      ),
      borderRadius: BorderRadius.circular(9),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        style: const TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: 12,
          color: AppColors.ink,
        ),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 17,
          color: AppColors.muted,
        ),
        hint: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        items: [
          DropdownMenuItem<T>(value: null, child: Text(label)),
          ...values.map(
            (v) => DropdownMenuItem<T>(
              value: v,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  text(v),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    ),
  );

  Widget _list(List<Issue> items, bool compact) => ListView.separated(
    primary: false,
    padding: EdgeInsets.fromLTRB(compact ? 18 : 32, 0, compact ? 18 : 32, 24),
    itemCount: items.length,
    separatorBuilder: (_, index) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final issue = items[index];
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: () => showIssueDetails(context, widget.store, issue.id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'BUG-${issue.id.toString().padLeft(3, '0')}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                          const Spacer(),
                          StatusPill(status: issue.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        issue.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          PriorityPill(priority: issue.priority),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              widget.store.projectById(issue.projectId)?.name ??
                                  '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.bug_report_outlined,
                          color: priorityColor(issue.priority),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'BUG-${issue.id.toString().padLeft(3, '0')}  ·  ${widget.store.projectById(issue.projectId)?.name ?? ''}',
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
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 114,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: StatusPill(status: issue.status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 112,
                        child: PriorityPill(priority: issue.priority),
                      ),
                      Tooltip(
                        message: issue.assigneeId == null
                            ? 'Не назначен'
                            : widget.store.userById(issue.assigneeId!)?.name ??
                                  '',
                        child: issue.assigneeId == null
                            ? const CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.background,
                                child: Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: AppColors.muted,
                                ),
                              )
                            : AvatarBadge(
                                name:
                                    widget.store
                                        .userById(issue.assigneeId!)
                                        ?.name ??
                                    '?',
                                size: 28,
                              ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        shortDate(issue.updatedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    },
  );

  Widget _kanban(List<Issue> items) => Scrollbar(
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: issueStatuses.map((status) {
        final issues = items.where((i) => i.status == status).toList();
        return Container(
          width: 278,
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEFF5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 4, 3, 14),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      '${issues.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) =>
                      widget.store.issueById(details.data)?.status != status,
                  onAcceptWithDetails: (details) async {
                    try {
                      await widget.store.changeStatus(details.data, status);
                    } catch (e) {
                      if (mounted) {
                        showMessage(context, e.toString(), error: true);
                      }
                    }
                  },
                  builder: (context, candidate, rejected) => Container(
                    decoration: BoxDecoration(
                      color: candidate.isEmpty
                          ? Colors.transparent
                          : AppColors.accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: issues.isEmpty
                        ? const Center(
                            child: Text(
                              'Перетащите дефект сюда',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: issues.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final issue = issues[index];
                              final card = _boardCard(issue);
                              return LongPressDraggable<int>(
                                data: issue.id,
                                delay: const Duration(milliseconds: 250),
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: SizedBox(
                                    width: 250,
                                    child: _boardCard(issue),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: .3,
                                  child: card,
                                ),
                                child: card,
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );

  Widget _boardCard(Issue issue) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: () => showIssueDetails(context, widget.store, issue.id),
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BUG-${issue.id.toString().padLeft(3, '0')}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const Spacer(),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 15,
                  color: AppColors.muted.withValues(alpha: .5),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              issue.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: projectColor(
                      widget.store.projectById(issue.projectId)?.color ??
                          '#6554C0',
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.store.projectById(issue.projectId)?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AppColors.border),
            ),
            Row(
              children: [
                PriorityPill(priority: issue.priority),
                const Spacer(),
                if (issue.assigneeId != null)
                  AvatarBadge(
                    name: widget.store.userById(issue.assigneeId!)?.name ?? '?',
                    size: 24,
                  )
                else
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 19,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
