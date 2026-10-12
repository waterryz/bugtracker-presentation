import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store});

  final TrackerStore store;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late String _role;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final user = widget.store.currentUser;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _role = user?.role ?? userRoles.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.store.updateProfile(
        name: _name.text.trim(),
        role: _role,
        phone: _phone.text.trim(),
      );
      if (mounted) showMessage(context, 'Изменения профиля сохранены');
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorText(Object error) => error.toString().replaceFirst(
    RegExp(r'^(Exception|StateError|Bad state):\s*'),
    '',
  );

  Future<void> _copy(String value, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (mounted) showMessage(context, message);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Не удалось скопировать путь', error: true);
      }
    }
  }

  Future<void> _backup() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final exportBytes = await widget.store.exportJsonBytes();
      final target = await FilePicker.saveFile(
        dialogTitle: 'Экспорт данных',
        fileName:
            'bugtracker-export-${DateTime.now().millisecondsSinceEpoch}.json',
        bytes: exportBytes,
      );
      if (kIsWeb) {
        if (mounted) showMessage(context, 'JSON отправлен в загрузки браузера');
        return;
      }
      if (target == null) return;
      final path = target.toString();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          icon: const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFF37A78C),
            size: 38,
          ),
          title: const Text('Данные экспортированы'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Файл с данными сохранён на вашем устройстве:'),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SelectableText(
                    path,
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _copy(path, 'Путь к файлу скопирован'),
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Скопировать путь'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Готово'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Ваши проекты и задачи сохранятся на этом устройстве. '
          'Вы сможете вернуться в них после входа.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.store.logout();
    } catch (error) {
      if (mounted) showMessage(context, _errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser;
    if (user == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Мой профиль',
            subtitle: 'Личные данные и ваше рабочее пространство',
          ),
          const SizedBox(height: 26),
          SurfaceCard(
            child: LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 26,
                runSpacing: 24,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarBadge(name: user.name, size: 70),
                      const SizedBox(width: 20),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: (constraints.maxWidth - 90).clamp(
                            90.0,
                            400.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user.email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.role,
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 30,
                    runSpacing: 12,
                    children: [
                      _NumberStat(
                        value: '${widget.store.projects.length}',
                        label: 'Проектов в пространстве',
                        icon: Icons.folder_outlined,
                      ),
                      _NumberStat(
                        value: '${widget.store.issues.length}',
                        label: 'Задач в пространстве',
                        icon: Icons.task_alt_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 850) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _personalDetails(user.email)),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: _localData()),
                  ],
                );
              }
              return Column(
                children: [
                  _personalDetails(user.email),
                  const SizedBox(height: 24),
                  _localData(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _personalDetails(String email) => SurfaceCard(
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            icon: Icons.person_outline_rounded,
            title: 'Личные данные',
            subtitle: 'Так вас видят участники проектов',
          ),
          const SizedBox(height: 25),
          _label('Имя и фамилия'),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Ваше имя'),
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Введите имя — хотя бы 2 символа'
                : null,
          ),
          const SizedBox(height: 19),
          _label('Электронная почта'),
          TextFormField(
            initialValue: email,
            readOnly: true,
            decoration: const InputDecoration(
              suffixIcon: Tooltip(
                message: 'Адрес используется для входа',
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
              filled: true,
              fillColor: AppColors.background,
            ),
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 19),
          _label('Роль в команде'),
          DropdownButtonFormField<String>(
            initialValue: _role,
            isExpanded: true,
            items: userRoles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: _saving
                ? null
                : (value) => setState(() => _role = value!),
          ),
          const SizedBox(height: 19),
          _label('Телефон · необязательно'),
          TextFormField(
            controller: _phone,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: '+7 700 123 45 67'),
            onFieldSubmitted: (_) => _save(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final digits = value.replaceAll(RegExp(r'\D'), '');
              return digits.length < 7 || digits.length > 15
                  ? 'Введите корректный номер телефона'
                  : null;
            },
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? 'Сохраняем…' : 'Сохранить изменения'),
          ),
        ],
      ),
    ),
  );

  Widget _localData() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle(
              icon: Icons.storage_rounded,
              title: 'Локальная база данных',
              subtitle: 'Работайте даже без интернета',
            ),
            const SizedBox(height: 23),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8F4),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E967B),
                    size: 17,
                  ),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'SQLite · данные сохраняются автоматически',
                      style: TextStyle(
                        color: Color(0xFF2E967B),
                        fontSize: 11,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 21),
            const Text(
              kIsWeb
                  ? 'Данные хранятся в этом профиле браузера. Используйте тот же адрес приложения. Очистка данных сайта удалит локальные записи.'
                  : 'Проекты, задачи, комментарии и ваш профиль находятся в базе данных на этом устройстве.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.7,
              ),
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 20),
              _label('Расположение базы'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  widget.store.databasePath,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _copy(
                  widget.store.databasePath,
                  'Путь к базе данных скопирован',
                ),
                icon: const Icon(Icons.copy_outlined, size: 15),
                label: const Text('Скопировать путь'),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(color: AppColors.border),
            const SizedBox(height: 18),
            const Text(
              'Экспорт данных в JSON',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Сохраните проекты, дефекты, комментарии и вложения в файл. '
              'Пароли в экспорт не входят. Обратный импорт пока не поддерживается.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : _backup,
                icon: _exporting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(
                  _exporting ? 'Экспортируем…' : 'Экспортировать JSON',
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Завершить работу',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Выйдите из аккаунта, если устройством пользуется кто-то ещё.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 15),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFC75367),
              ),
              onPressed: _saving || _exporting ? null : _logout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Выйти из аккаунта'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.accent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _NumberStat extends StatelessWidget {
  const _NumberStat({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: AppColors.muted),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
    ],
  );
}
