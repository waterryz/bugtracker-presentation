import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';

Future<void> showIssueEditor(
  BuildContext context,
  TrackerStore store, {
  Issue? issue,
  int? projectId,
}) async {
  if (store.projects.isEmpty) {
    showMessage(context, 'Сначала создайте проект, чтобы добавить ошибку.');
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _IssueEditor(store: store, issue: issue, projectId: projectId),
  );
}

Future<void> showIssueDetails(
  BuildContext context,
  TrackerStore store,
  int issueId,
) => showDialog<void>(
  context: context,
  builder: (_) => _IssueDetails(store: store, issueId: issueId),
);

class _IssueEditor extends StatefulWidget {
  const _IssueEditor({required this.store, this.issue, this.projectId});
  final TrackerStore store;
  final Issue? issue;
  final int? projectId;

  @override
  State<_IssueEditor> createState() => _IssueEditorState();
}

class _IssueEditorState extends State<_IssueEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _steps;
  late final TextEditingController _expected;
  late final TextEditingController _actual;
  late final TextEditingController _environment;
  late int _projectId;
  late int _assigneeId;
  late String _status;
  late String _priority;
  late String _severity;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final issue = widget.issue;
    _title = TextEditingController(text: issue?.title);
    _description = TextEditingController(text: issue?.description);
    _steps = TextEditingController(text: issue?.steps);
    _expected = TextEditingController(text: issue?.expected);
    _actual = TextEditingController(text: issue?.actual);
    _environment = TextEditingController(
      text:
          issue?.environment ??
          (kIsWeb ? 'Браузер · веб-версия' : defaultTargetPlatform.name),
    );
    final requestedProject = issue?.projectId ?? widget.projectId;
    _projectId = widget.store.projects.any((p) => p.id == requestedProject)
        ? requestedProject!
        : widget.store.projects.first.id;
    _assigneeId = issue?.assigneeId ?? 0;
    _status = issue?.status ?? issueStatuses.first;
    _priority = issue?.priority ?? 'Средний';
    _severity = issue?.severity ?? 'Обычная';
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _description,
      _steps,
      _expected,
      _actual,
      _environment,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.saveIssue(
        id: widget.issue?.id,
        projectId: _projectId,
        title: _title.text.trim(),
        description: _description.text.trim(),
        steps: _steps.text.trim(),
        expected: _expected.text.trim(),
        actual: _actual.text.trim(),
        status: _status,
        priority: _priority,
        severity: _severity,
        environment: _environment.text.trim(),
        assigneeId: _assigneeId == 0 ? null : _assigneeId,
      );
      if (!mounted) return;
      showMessage(
        context,
        widget.issue == null
            ? 'Ошибка добавлена в проект'
            : 'Изменения сохранены',
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _errorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: EdgeInsets.all(size.width < 600 ? 12 : 32),
        clipBehavior: Clip.antiAlias,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: size.height * .91,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(
                eyebrow: widget.issue == null
                    ? 'НОВАЯ ЗАПИСЬ'
                    : _issueCode(widget.issue!.id),
                title: widget.issue == null
                    ? 'Сообщить об ошибке'
                    : 'Редактировать ошибку',
                onClose: _saving ? null : () => Navigator.pop(context),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(size.width < 600 ? 20 : 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Чем точнее описание, тем быстрее команда найдёт решение.',
                          style: TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _title,
                          autofocus: true,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 160,
                          decoration: const InputDecoration(
                            labelText: 'Название ошибки *',
                            hintText:
                                'Например, не сохраняются изменения в профиле',
                            counterText: '',
                          ),
                          validator: (value) {
                            final title = value?.trim() ?? '';
                            if (title.isEmpty) return 'Введите название ошибки';
                            if (title.length > 160) {
                              return 'Не более 160 символов';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _FieldPair(
                          first: DropdownButtonFormField<int>(
                            initialValue: _projectId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Проект *',
                              prefixIcon: Icon(Icons.folder_outlined, size: 20),
                            ),
                            items: widget.store.projects
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) =>
                                      setState(() => _projectId = value!),
                            validator: (value) =>
                                value == null ? 'Выберите проект' : null,
                          ),
                          second: DropdownButtonFormField<int>(
                            initialValue:
                                widget.store.users.any(
                                  (u) => u.id == _assigneeId,
                                )
                                ? _assigneeId
                                : 0,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Исполнитель',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 0,
                                child: Text('Не назначен'),
                              ),
                              ...widget.store.users.map(
                                (u) => DropdownMenuItem(
                                  value: u.id,
                                  child: Text(
                                    u.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) =>
                                      setState(() => _assigneeId = value!),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _FieldPair(
                          first: _dropdown(
                            'Статус',
                            _status,
                            issueStatuses,
                            (v) => _status = v,
                          ),
                          second: _dropdown(
                            'Приоритет',
                            _priority,
                            issuePriorities,
                            (v) => _priority = v,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _dropdown(
                          'Серьёзность',
                          _severity,
                          {
                            'Незначительная',
                            'Обычная',
                            'Серьёзная',
                            'Блокирующая',
                            _severity,
                          }.toList(),
                          (v) => _severity = v,
                        ),
                        const SizedBox(height: 28),
                        const _FormSection(
                          icon: Icons.subject_rounded,
                          title: 'Описание и воспроизведение',
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          _description,
                          'Описание',
                          'Что произошло и как это влияет на работу?',
                          lines: 3,
                        ),
                        const SizedBox(height: 18),
                        _textField(
                          _steps,
                          'Шаги воспроизведения',
                          '1. Откройте…\n2. Нажмите…\n3. Обратите внимание…',
                          lines: 4,
                        ),
                        const SizedBox(height: 18),
                        _FieldPair(
                          first: _textField(
                            _expected,
                            'Ожидаемый результат',
                            'Как должно работать',
                            lines: 3,
                          ),
                          second: _textField(
                            _actual,
                            'Фактический результат',
                            'Что происходит сейчас',
                            lines: 3,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _textField(
                          _environment,
                          'Окружение',
                          'ОС, браузер, версия приложения',
                          lines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 17,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Скриншоты и файлы можно прикрепить в карточке после сохранения.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 18),
                          _InlineError(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width < 600 ? 20 : 28,
                  vertical: 18,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              widget.issue == null
                                  ? Icons.add_rounded
                                  : Icons.check_rounded,
                              size: 19,
                            ),
                      label: Text(
                        _saving
                            ? 'Сохранение…'
                            : widget.issue == null
                            ? 'Создать ошибку'
                            : 'Сохранить',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: _saving ? null : (v) => setState(() => change(v!)),
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    int lines = 3,
  }) => TextFormField(
    controller: controller,
    enabled: !_saving,
    minLines: lines,
    maxLines: lines + 4,
    keyboardType: TextInputType.multiline,
    textCapitalization: TextCapitalization.sentences,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
    ),
  );
}

class _IssueDetails extends StatefulWidget {
  const _IssueDetails({required this.store, required this.issueId});
  final TrackerStore store;
  final int issueId;

  @override
  State<_IssueDetails> createState() => _IssueDetailsState();
}

class _IssueDetailsState extends State<_IssueDetails>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _comment = TextEditingController();
  List<IssueComment> _comments = [];
  List<IssueActivity> _activity = [];
  List<IssueAttachment> _attachments = [];
  final Map<int, Future<Uint8List>> _attachmentData = {};
  bool _loading = true;
  bool _busy = false;
  bool _sending = false;
  bool _attaching = false;
  String? _loadError;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    widget.store.addListener(_storeChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    widget.store.removeListener(_storeChanged);
    _tabs.dispose();
    _comment.dispose();
    super.dispose();
  }

  void _storeChanged() {
    if (!mounted) return;
    setState(() {});
    unawaited(_load());
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      final results = await Future.wait<Object>([
        widget.store.commentsFor(widget.issueId),
        widget.store.activityFor(widget.issueId),
        widget.store.attachmentsFor(widget.issueId),
      ]);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _comments = results[0] as List<IssueComment>;
        _activity = results[1] as List<IssueActivity>;
        _attachments = results[2] as List<IssueAttachment>;
        final attachmentIds = _attachments.map((item) => item.id).toSet();
        _attachmentData.removeWhere((id, _) => !attachmentIds.contains(id));
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loading = false;
        _loadError = _errorText(error);
      });
    }
  }

  Future<void> _changeStatus(String? value) async {
    if (value == null || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.changeStatus(widget.issueId, value);
      if (mounted) showMessage(context, 'Статус обновлён');
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendComment() async {
    if (_sending || _comment.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.store.addComment(widget.issueId, _comment.text.trim());
      if (!mounted) return;
      _comment.clear();
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    if (_attaching) return;
    setState(() => _attaching = true);
    try {
      final selection = await FilePicker.pickFiles(
        dialogTitle: 'Прикрепить файлы к ошибке',
      );
      if (selection.isEmpty || !mounted) return;
      var added = 0;
      for (final file in selection) {
        final length = await file.length();
        if (length != null && length > 25 * 1024 * 1024) {
          throw StateError('Размер вложения не должен превышать 25 МБ.');
        }
        await widget.store.addAttachmentBytes(
          widget.issueId,
          file.name,
          await file.readAsBytes(),
        );
        added++;
      }
      await _load();
      if (mounted && added > 0) {
        showMessage(context, 'Файлы прикреплены: $added');
      }
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Удалить ошибку?',
      body:
          'Ошибка ${_issueCode(widget.issueId)}, её комментарии, история и вложения будут удалены. Это действие нельзя отменить.',
      button: 'Удалить ошибку',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.deleteIssue(widget.issueId);
      if (!mounted) return;
      showMessage(context, 'Ошибка удалена');
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showMessage(context, _errorText(error), error: true);
      }
    }
  }

  Future<void> _removeAttachment(IssueAttachment attachment) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Удалить вложение?',
      body:
          'Файл «${attachment.name}» будет удалён из карточки. Исходный файл останется на вашем устройстве.',
      button: 'Удалить вложение',
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.store.deleteAttachment(attachment.id);
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    }
  }

  Future<void> _saveAttachment(IssueAttachment attachment) async {
    try {
      final bytes = await widget.store.attachmentBytes(attachment.id);
      final target = await FilePicker.saveFile(
        dialogTitle: 'Сохранить копию вложения',
        fileName: attachment.name,
        bytes: bytes,
      );
      if (target == null) return;
      if (mounted) {
        showMessage(
          context,
          kIsWeb ? 'Скачивание вложения началось' : 'Копия файла сохранена',
        );
      }
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.store.issueById(widget.issueId);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 650;
    final typing = compact && MediaQuery.viewInsetsOf(context).bottom > 0;
    if (issue == null) {
      return AlertDialog(
        title: const Text('Ошибка удалена'),
        content: const Text('Эта запись больше не существует.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }
    final project = widget.store.projectById(issue.projectId);
    return Dialog(
      insetAnimationDuration: Duration.zero,
      insetPadding: EdgeInsets.all(compact ? 12 : 32),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: 980,
        height: size.height * .9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (typing)
              Padding(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 8,
                  top: 4,
                  bottom: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_issueCode(issue.id)} · ${issue.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              )
            else ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 28,
                  22,
                  compact ? 12 : 20,
                  16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _issueCode(issue.id),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                ' / ',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  project?.name ?? 'Проект',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            issue.title,
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: compact ? 20 : 26,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (compact)
                      IconButton(
                        tooltip: 'Удалить ошибку',
                        visualDensity: VisualDensity.compact,
                        onPressed: _busy ? null : _delete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                    IconButton(
                      tooltip: 'Закрыть',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 28),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(status: issue.status),
                    PriorityPill(priority: issue.priority),
                    Text(
                      'Обновлено ${_formatDate(issue.updatedAt)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 28),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? 172 : 200,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(issue.status),
                        initialValue: issue.status,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Изменить статус',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          isDense: true,
                        ),
                        items: issueStatuses
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy ? null : _changeStatus,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => showIssueEditor(
                              context,
                              widget.store,
                              issue: issue,
                            ),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      label: Text(compact ? 'Изменить' : 'Редактировать'),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'Удалить ошибку',
                        onPressed: _busy ? null : _delete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            TabBar(
              controller: _tabs,
              isScrollable: compact,
              tabAlignment: compact ? TabAlignment.start : TabAlignment.fill,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.accent,
              tabs: [
                const Tab(text: 'Описание'),
                Tab(
                  text:
                      'Комментарии${_comments.isEmpty ? '' : ' · ${_comments.length}'}',
                ),
                const Tab(text: 'История'),
              ],
            ),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _InlineError(message: _loadError!, onRetry: _load),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _descriptionTab(issue, compact),
                  _commentsTab(compact),
                  _historyTab(compact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionTab(Issue issue, bool compact) {
    final author = widget.store.userById(issue.createdBy);
    final assignee = issue.assigneeId == null
        ? null
        : widget.store.userById(issue.assigneeId!);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailText(
          title: 'Описание',
          value: issue.description,
          empty: 'Автор ещё не добавил описание.',
        ),
        _DetailText(
          title: 'Шаги воспроизведения',
          value: issue.steps,
          empty: 'Шаги не указаны.',
        ),
        _DetailText(
          title: 'Ожидаемый результат',
          value: issue.expected,
          empty: 'Результат не указан.',
          accent: AppColors.green,
        ),
        _DetailText(
          title: 'Фактический результат',
          value: issue.actual,
          empty: 'Результат не указан.',
          accent: const Color(0xFFE37A59),
        ),
        _DetailText(
          title: 'Окружение',
          value: issue.environment,
          empty: 'Окружение не указано.',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Вложения',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.ink,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _attaching ? null : _attach,
              icon: _attaching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded, size: 17),
              label: Text(_attaching ? 'Добавление…' : 'Прикрепить'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (_attachments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.muted,
                  size: 28,
                ),
                SizedBox(height: 8),
                Text(
                  'Скриншоты, логи и другие файлы',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._attachments.map(_attachmentTile),
      ],
    );
    final metadata = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ДЕТАЛИ',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _person(
            'Исполнитель',
            assignee?.name ?? 'Не назначен',
            Icons.person_outline,
          ),
          const SizedBox(height: 20),
          _person('Автор', author?.name ?? 'Участник', Icons.person_outline),
          const SizedBox(height: 20),
          _meta('Серьёзность', issue.severity),
          const SizedBox(height: 20),
          _meta('Создано', _formatDate(issue.createdAt)),
          const SizedBox(height: 20),
          _meta('Обновлено', _formatDate(issue.updatedAt)),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  kIsWeb
                      ? 'Хранится в этом браузере'
                      : 'Хранится на устройстве',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 20 : 28),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [content, const SizedBox(height: 28), metadata],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: content),
                const SizedBox(width: 28),
                SizedBox(width: 235, child: metadata),
              ],
            ),
    );
  }

  Widget _commentsTab(bool compact) => Column(
    children: [
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _comments.isEmpty
            ? const _EmptyPanel(
                icon: Icons.forum_outlined,
                title: 'Обсудим решение?',
                subtitle: 'Оставьте первый комментарий, уточните детали\nили поделитесь результатом проверки.',
              )
            : ListView.separated(
                padding: EdgeInsets.all(compact ? 20 : 28),
                itemCount: _comments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 20),
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  final user = widget.store.userById(comment.userId);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AvatarBadge(name: user?.name ?? 'Участник', size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    user?.name ?? 'Участник',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(comment.createdAt),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                comment.text,
                                style: const TextStyle(
                                  height: 1.6,
                                  color: AppColors.ink,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
      const Divider(height: 1),
      Padding(
        padding: EdgeInsets.all(
          MediaQuery.viewInsetsOf(context).bottom > 0
              ? 10
              : compact
              ? 16
              : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _comment,
              enabled: !_sending,
              minLines: MediaQuery.viewInsetsOf(context).bottom > 0 ? 1 : 2,
              maxLines: 5,
              maxLength: 10000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Напишите комментарий…',
                counterText: '',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _comment,
              builder: (_, value, _) => FilledButton.icon(
                onPressed: _sending || value.text.trim().isEmpty
                    ? null
                    : _sendComment,
                icon: _sending
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_sending ? 'Отправка…' : 'Отправить'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _historyTab(bool compact) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_activity.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.history_rounded,
        title: 'История пока пуста',
        subtitle: 'Изменения ошибки будут появляться здесь.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(compact ? 20 : 28),
      itemCount: _activity.length,
      itemBuilder: (context, index) {
        final event = _activity[index];
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28,
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        color: AppColors.accent,
                        size: 15,
                      ),
                    ),
                    if (index < _activity.length - 1)
                      Expanded(
                        child: Container(width: 1, color: AppColors.border),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.text,
                        style: const TextStyle(
                          color: AppColors.ink,
                          height: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatDate(event.createdAt),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _attachmentTile(IssueAttachment attachment) {
    final image = RegExp(
      r'\.(png|jpe?g|gif|webp|bmp)$',
      caseSensitive: false,
    ).hasMatch(attachment.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: image
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _attachmentImage(attachment, thumbnail: true),
                )
              : const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.accent,
                ),
          title: Text(
            attachment.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            image ? 'Нажмите, чтобы посмотреть' : 'Локальное вложение',
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          onTap: image
              ? () => _previewImage(attachment)
              : () => _saveAttachment(attachment),
          trailing: PopupMenuButton<String>(
            tooltip: 'Действия с вложением',
            onSelected: (action) async {
              if (action == 'save') await _saveAttachment(attachment);
              if (action == 'remove') await _removeAttachment(attachment);
              if (action == 'path') {
                await Clipboard.setData(ClipboardData(text: attachment.path));
                if (mounted) showMessage(context, 'Путь к файлу скопирован');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'save',
                child: Text('Сохранить копию'),
              ),
              if (!kIsWeb && attachment.path.isNotEmpty)
                const PopupMenuItem(
                  value: 'path',
                  child: Text('Копировать путь'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'remove',
                child: Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentImage(
    IssueAttachment attachment, {
    bool thumbnail = false,
  }) => FutureBuilder<Uint8List>(
    future: _attachmentData.putIfAbsent(
      attachment.id,
      () => widget.store.attachmentBytes(attachment.id),
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return thumbnail
            ? const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.muted,
                ),
              )
            : const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Не удалось открыть изображение. Вложение могло быть удалено.',
                ),
              );
      }
      if (!snapshot.hasData) {
        return SizedBox(
          width: thumbnail ? 38 : 240,
          height: thumbnail ? 38 : 180,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return Image.memory(
        snapshot.data!,
        width: thumbnail ? 38 : null,
        height: thumbnail ? 38 : null,
        cacheWidth: thumbnail ? 114 : null,
        fit: thumbnail ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (_, _, _) => thumbnail
            ? const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.muted,
                ),
              )
            : const Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'Формат изображения не поддерживается или файл повреждён.',
                ),
              ),
      );
    },
  );

  Future<void> _previewImage(IssueAttachment attachment) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: .5,
                maxScale: 5,
                child: _attachmentImage(attachment),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  Widget _person(String label, String name, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 8),
      Row(
        children: [
          AvatarBadge(name: name, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _meta(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const SizedBox(height: 7),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.eyebrow,
    required this.title,
    this.onClose,
  });
  final String eyebrow, title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 16, 22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'Закрыть',
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.accent, size: 19),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    ],
  );
}

class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});
  final Widget first, second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) => constraints.maxWidth < 540
        ? Column(children: [first, const SizedBox(height: 18), second])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 16),
              Expanded(child: second),
            ],
          ),
  );
}

class _DetailText extends StatelessWidget {
  const _DetailText({
    required this.title,
    required this.value,
    required this.empty,
    this.accent,
  });
  final String title, value, empty;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 25),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (accent != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        SelectableText(
          value.trim().isEmpty ? empty : value,
          style: TextStyle(
            fontSize: 13,
            height: 1.7,
            color: value.trim().isEmpty ? AppColors.muted : AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: AppColors.accent, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFB93E39), size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFB93E39), fontSize: 12),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String body,
  required String button,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFC24640),
          size: 30,
        ),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(body, style: const TextStyle(height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC24640),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(button),
          ),
        ],
      ),
    ) ??
    false;

String _issueCode(int id) => 'BUG-${id.toString().padLeft(3, '0')}';

String _formatDate(DateTime date) {
  final local = date.toLocal();
  const months = [
    'янв',
    'фев',
    'мар',
    'апр',
    'мая',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _errorText(Object error) => error.toString().replaceFirst(
  RegExp(r'^(Exception|StateError|Bad state):\s*'),
  '',
);
