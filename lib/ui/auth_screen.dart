import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/tracker_store.dart';
import 'design.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.store});

  final TrackerStore store;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _phone = TextEditingController();
  String _role = userRoles.first;
  bool _register = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_register) {
        await widget.store.register(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
          phone: _phone.text.trim(),
        );
      } else {
        await widget.store.login(_email.text.trim(), _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDemo() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.seedDemo();
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readableError(Object error) => error.toString().replaceFirst(
    RegExp(r'^(Exception|StateError|Bad state):\s*'),
    '',
  );

  void _toggleMode() {
    if (_busy) return;
    setState(() {
      _register = !_register;
      _error = null;
      _confirmation.clear();
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final form = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: _buildForm(wide),
            ),
          );
          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 5, child: _WelcomePanel()),
                Expanded(
                  flex: 6,
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 44,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 88).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: form,
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm(bool wide) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide) ...[const _Brand(), const SizedBox(height: 38)],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                _register ? 'НОВЫЙ АККАУНТ' : 'ВАШЕ РАБОЧЕЕ ПРОСТРАНСТВО',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _register ? 'Начнём с знакомства' : 'С возвращением!',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 32,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: -.9,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _register
                  ? 'Создайте профиль, чтобы собрать проекты и задачи в одном месте.'
                  : 'Войдите, чтобы продолжить работу над вашими проектами.',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            if (_register) ...[
              _fieldLabel('Ваше имя'),
              TextFormField(
                controller: _name,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _input('Александр Иванов', Icons.person_outline),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Введите имя — хотя бы 2 символа'
                    : null,
              ),
              const SizedBox(height: 17),
            ],
            _fieldLabel('Электронная почта'),
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: _input('you@example.com', Icons.alternate_email),
              validator: (value) {
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                    .hasMatch(value?.trim() ?? '')) {
                  return 'Введите корректный адрес электронной почты';
                }
                return null;
              },
            ),
            const SizedBox(height: 17),
            _fieldLabel('Пароль'),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: !_showPassword,
              textInputAction: _register
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: [
                _register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              onFieldSubmitted: (_) {
                if (!_register) _submit();
              },
              decoration:
                  _input(
                    _register ? 'Не менее 8 символов' : 'Введите пароль',
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _showPassword
                          ? 'Скрыть пароль'
                          : 'Показать пароль',
                      onPressed: _busy
                          ? null
                          : () =>
                                setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
              validator: (value) => (value?.length ?? 0) < 8
                  ? 'Пароль должен содержать не менее 8 символов'
                  : null,
            ),
            if (_register) ...[
              const SizedBox(height: 17),
              _fieldLabel('Повторите пароль'),
              TextFormField(
                controller: _confirmation,
                enabled: !_busy,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.next,
                decoration: _input('Ещё раз тот же пароль', Icons.lock_outline),
                validator: (value) =>
                    value != _password.text ? 'Пароли не совпадают' : null,
              ),
              const SizedBox(height: 17),
              _fieldLabel('Ваша роль'),
              DropdownButtonFormField<String>(
                initialValue: _role,
                isExpanded: true,
                decoration: _input('Выберите роль', Icons.work_outline),
                items: userRoles
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _role = value!),
              ),
              const SizedBox(height: 17),
              _fieldLabel('Телефон', optional: true),
              TextFormField(
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: _input('+7 700 123 45 67', Icons.phone_outlined),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  return digits.length < 7 || digits.length > 15
                      ? 'Введите корректный номер телефона'
                      : null;
                },
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB33444), height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 51,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _register ? 'Создать аккаунт' : 'Войти в аккаунт',
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _register ? 'Уже есть аккаунт?' : 'Впервые здесь?',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text(_register ? 'Войти' : 'Создать аккаунт'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            const Row(
              children: [
                Expanded(child: Divider(color: AppColors.border)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13),
                  child: Text(
                    'или познакомьтесь с приложением',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openDemo,
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: const Text('Посмотреть демо'),
              ),
            ),
            const SizedBox(height: 23),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storage_rounded, size: 16, color: AppColors.muted),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ваше пространство хранится локально на этом устройстве. '
                    'Демо добавит примеры проектов и задач.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, {bool optional = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: label,
        children: [
          if (optional)
            const TextSpan(
              text: ' · необязательно',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  InputDecoration _input(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA3A6B7), fontSize: 13),
    prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
    filled: true,
    fillColor: const Color(0xFFFAFAFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        height: 39,
        width: 39,
        decoration: BoxDecoration(
          color: light ? Colors.white.withValues(alpha: .17) : AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.bug_report_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'БагТрекер',
        style: TextStyle(
          color: light ? Colors.white : AppColors.ink,
          fontSize: 23,
          fontWeight: FontWeight.w800,
          letterSpacing: -.6,
        ),
      ),
    ],
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7463CE), Color(0xFF5541AC)],
      ),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(44),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 88).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _Brand(light: true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Меньше хаоса.\nЛучше релизы.',
                        style: TextStyle(
                          fontSize: 43,
                          height: 1.16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Все ошибки, проекты и решения —\nв одном понятном пространстве.',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Colors.white.withValues(alpha: .76),
                        ),
                      ),
                      const SizedBox(height: 34),
                      const _PreviewCard(),
                      const SizedBox(height: 27),
                      const Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          _FeatureChip(
                            Icons.view_kanban_outlined,
                            'Канбан-доска',
                          ),
                          _FeatureChip(
                            Icons.analytics_outlined,
                            'Всё под контролем',
                          ),
                          _FeatureChip(
                            Icons.cloud_off_outlined,
                            'Работает офлайн',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'Порядок в каждом релизе',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      border: Border.all(color: Colors.white.withValues(alpha: .15)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF342571).withValues(alpha: .24),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.circle, size: 7, color: Color(0xFF7B67CE)),
            SizedBox(width: 7),
            Text(
              'КАЖДАЯ ДЕТАЛЬ НА МЕСТЕ',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        const Text(
          'От ошибки до решения',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 16),
        const _PreviewStep(
          icon: Icons.add_rounded,
          title: 'Зафиксируйте проблему',
          subtitle: 'Описание, приоритет и исполнитель',
          color: AppColors.accent,
        ),
        const SizedBox(height: 15),
        const _PreviewStep(
          icon: Icons.sync_rounded,
          title: 'Следите за прогрессом',
          subtitle: 'Статусы задач всегда перед глазами',
          color: Color(0xFFE59A3E),
        ),
        const SizedBox(height: 15),
        const _PreviewStep(
          icon: Icons.check_rounded,
          title: 'Выпускайте с уверенностью',
          subtitle: 'История изменений и результат',
          color: Color(0xFF37A78C),
        ),
      ],
    ),
  );
}

class _PreviewStep extends StatelessWidget {
  const _PreviewStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 33,
        height: 33,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 9),
            ),
          ],
        ),
      ),
    ],
  );
}
