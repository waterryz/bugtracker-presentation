import 'package:flutter/material.dart';

import '../data/tracker_store.dart';
import 'dashboard.dart';
import 'design.dart';
import 'issue_dialogs.dart';
import 'issue_list.dart';
import 'profile_screen.dart';
import 'projects_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.store});
  final TrackerStore store;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  int _page = 0;
  int? _projectId;
  String _query = '';
  String? _status;
  final _search = TextEditingController();
  static const _titles = ['Обзор', 'Дефекты', 'Проекты', 'Профиль'];
  static const _icons = [
    Icons.space_dashboard_outlined,
    Icons.bug_report_outlined,
    Icons.folder_outlined,
    Icons.person_outline_rounded,
  ];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _navigate(int page, {int? projectId, String? status}) {
    setState(() {
      _page = page;
      _projectId = projectId;
      _status = status;
      _query = '';
      _search.clear();
    });
  }

  Future<void> _createIssue() async {
    if (widget.store.projects.isEmpty) {
      final created = await showProjectEditor(context, widget.store);
      if (!mounted || !created) return;
    }
    if (!mounted) return;
    await showIssueEditor(context, widget.store, projectId: _projectId);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 1000;
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (desktop) _sidebar(),
              Expanded(
                child: Column(
                  children: [
                    _header(desktop),
                    Expanded(
                      child: switch (_page) {
                        0 => Dashboard(
                          store: widget.store,
                          onCreate: _createIssue,
                          onIssues: (status) => _navigate(1, status: status),
                          onProject: (id) => _navigate(1, projectId: id),
                        ),
                        1 => IssueListScreen(
                          key: ValueKey('$_projectId:$_status'),
                          store: widget.store,
                          query: _query,
                          projectId: _projectId,
                          initialStatus: _status,
                          onCreate: _createIssue,
                          onClearSearch: () => setState(() {
                            _query = '';
                            _search.clear();
                          }),
                        ),
                        2 => ProjectsScreen(
                          store: widget.store,
                          onOpen: (id) => _navigate(1, projectId: id),
                        ),
                        _ => ProfileScreen(store: widget.store),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: desktop
            ? null
            : NavigationBar(
                backgroundColor: Colors.white,
                elevation: 0,
                height: 70,
                selectedIndex: _page,
                onDestinationSelected: (value) => _navigate(value),
                destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _titles[i],
                  ),
                ),
              ),
      );
    },
  );

  Widget _header(bool desktop) => Container(
    padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 18, vertical: 17),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      children: [
        if (!desktop) ...[
          const Icon(
            Icons.bug_report_rounded,
            color: AppColors.accent,
            size: 26,
          ),
          const SizedBox(width: 10),
        ],
        if (desktop) ...[
          const Text(
            'Рабочее пространство',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.muted,
            ),
          ),
        ],
        Text(
          _titles[_page],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const Spacer(),
        if (desktop)
          SizedBox(
            width: 252,
            height: 40,
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() {
                _query = value;
                _page = 1;
              }),
              decoration: const InputDecoration(
                hintText: 'Найти дефект…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        if (desktop) const SizedBox(width: 24),
        if (desktop)
          const Tooltip(
            message: 'Все изменения сохраняются на этом устройстве',
            child: Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        const SizedBox(width: 18),
        InkWell(
          onTap: () => _navigate(3),
          borderRadius: BorderRadius.circular(12),
          child: AvatarBadge(name: widget.store.currentUser!.name, size: 36),
        ),
      ],
    ),
  );

  Widget _sidebar() => Material(
    color: Colors.white,
    child: SizedBox(
      width: 224,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 30, 16, 34),
            child: Row(
              children: [
                _BrandIcon(),
                SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'БагТрекер',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                    Text(
                      'КАЧЕСТВО В ДЕТАЛЯХ',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 26, bottom: 12),
            child: Text(
              'РАБОЧЕЕ ПРОСТРАНСТВО',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
              ),
            ),
          ),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              child: Material(
                color: _page == i && _projectId == null
                    ? const Color(0xFFEEEBF9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _navigate(i),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _icons[i],
                          size: 20,
                          color: _page == i
                              ? AppColors.accent
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            _titles[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _page == i
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _page == i
                                  ? AppColors.accent
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                        if (i == 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _page == 1
                                  ? Colors.white
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${widget.store.issues.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(26, 34, 20, 8),
            child: Text(
              'МОИ ПРОЕКТЫ',
              style: TextStyle(
                fontSize: 9,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                ...widget.store.projects.map(
                  (project) => ListTile(
                    dense: true,
                    selected: _projectId == project.id,
                    selectedColor: AppColors.accent,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 13),
                    leading: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: projectColor(project.color),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    minLeadingWidth: 8,
                    horizontalTitleGap: 12,
                    title: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _navigate(1, projectId: project.id),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showProjectEditor(context, widget.store),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Создать проект',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.offline_bolt_outlined,
                        size: 17,
                        color: AppColors.green,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Локальное пространство',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Данные на вашем устройстве.\nРаботает без интернета.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _navigate(3),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 18, 22),
              child: Row(
                children: [
                  AvatarBadge(name: widget.store.currentUser!.name, size: 33),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.store.currentUser!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.store.currentUser!.role,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.unfold_more_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon();
  @override
  Widget build(BuildContext context) => Container(
    width: 35,
    height: 39,
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Icon(Icons.bug_report_rounded, color: Colors.white, size: 24),
  );
}
