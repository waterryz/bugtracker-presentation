import 'dart:io';
import 'dart:ui' as ui;

import 'package:bug_tracker/data/tracker_store.dart';
import 'package:bug_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _captureKey = ValueKey('qa-capture');
final _qaDirectory = Platform.environment['BUGTRACKER_QA_DIR'];
bool _fontsLoaded = false;

Future<TrackerStore> _prepare(
  WidgetTester tester,
  Size size, {
  bool demo = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  late TrackerStore store;
  late Directory directory;
  await tester.runAsync(() async {
    if (!_fontsLoaded) {
      final windows = Platform.environment['WINDIR'] ?? r'C:\Windows';
      final font = File(p.join(windows, 'Fonts', 'segoeui.ttf'));
      if (await font.exists()) {
        final loader = FontLoader('Segoe UI');
        loader.addFont(
          font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        final bold = File(p.join(windows, 'Fonts', 'segoeuib.ttf'));
        if (await bold.exists()) {
          loader.addFont(
            bold.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        }
        await loader.load();
      }
      final material = FontLoader('MaterialIcons');
      material.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await material.load();
      _fontsLoaded = true;
    }
    directory = await Directory.systemTemp.createTemp('bugtracker_ui_');
    store = await TrackerStore.open(
      databasePath: p.join(directory.path, 'tracker.sqlite'),
    );
    if (demo) await store.seedDemo();
  });
  addTearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: BugTrackerApp(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

Future<void> _drainDatabase(WidgetTester tester) async {
  // SQLite FFI and its isolate must receive real event-loop time.
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _waitUntil(WidgetTester tester, bool Function() done) async {
  for (var attempt = 0; attempt < 200 && !done(); attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
  }
  expect(done(), isTrue, reason: 'Database operation should complete');
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_qaDirectory == null) return;
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(_qaDirectory!);
    await folder.create(recursive: true);
    await File(p.join(folder.path, '$name.png'))
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Finder _field({String? label, String? hint}) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (label == null || widget.decoration?.labelText == label) &&
      (hint == null || widget.decoration?.hintText == hint),
);

void _noErrors(WidgetTester tester, String screen) {
  expect(
    tester.takeException(),
    isNull,
    reason: '$screen must lay out and render without exceptions',
  );
}

Future<void> _navigate(
  WidgetTester tester,
  String label, {
  bool mobile = false,
}) async {
  final target = mobile
      ? find
            .descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            )
            .last
      : find.text(label).first;
  await tester.tap(target);
  await tester.pumpAndSettle();
  _noErrors(tester, label);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('registration and login work from responsive auth screen', (
    tester,
  ) async {
    final store = await _prepare(tester, const Size(1440, 1000), demo: false);
    _noErrors(tester, 'desktop login');
    await _capture(tester, 'desktop-login');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    _noErrors(tester, 'mobile login');
    await _capture(tester, 'mobile-login');
    await tester.ensureVisible(find.text('Создать аккаунт'));
    await tester.tap(find.text('Создать аккаунт'));
    await tester.pumpAndSettle();
    _noErrors(tester, 'mobile registration');
    await tester.enterText(_field(hint: 'Александр Иванов'), 'Тестировщик QA');
    await tester.enterText(_field(hint: 'you@example.com'), 'qa@example.com');
    await tester.enterText(
      _field(hint: 'Не менее 8 символов'),
      'Password-QA-2026',
    );
    await tester.enterText(
      _field(hint: 'Ещё раз тот же пароль'),
      'Password-QA-2026',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    _noErrors(tester, 'registration with keyboard');
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Создать аккаунт'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать аккаунт'));
    await _waitUntil(tester, () => store.currentUser != null);
    expect(store.currentUser!.email, 'qa@example.com');
    expect(store.issues, isEmpty);
    _noErrors(tester, 'empty new account overview');
    await _navigate(tester, 'Профиль', mobile: true);
    await tester.ensureVisible(find.text('Выйти из аккаунта'));
    await tester.tap(find.text('Выйти из аккаунта'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Выйти'));
    await _waitUntil(tester, () => store.currentUser == null);
    await tester.enterText(_field(hint: 'you@example.com'), 'qa@example.com');
    await tester.enterText(_field(hint: 'Введите пароль'), 'Password-QA-2026');
    await tester.ensureVisible(find.text('Войти в аккаунт'));
    await tester.tap(find.text('Войти в аккаунт'));
    await _waitUntil(tester, () => store.currentUser != null);
    expect(store.currentUser!.name, 'Тестировщик QA');
    _noErrors(tester, 'login restores account');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'desktop workflow persists create, edit, status, comment and project changes',
    (tester) async {
      final store = await _prepare(tester, const Size(1440, 1000));
      _noErrors(tester, 'desktop overview');
      expect(find.text('Всё под контролем'), findsOneWidget);
      await _capture(tester, 'desktop-overview');

      await _navigate(tester, 'Дефекты');
      final initialCount = store.issues.length;
      final existingTitle = store.issues.first.title;
      await tester.enterText(
        _field(hint: 'Название, описание или BUG-001'),
        'запрос-без-совпадений',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ничего не найдено'), findsOneWidget);
      await tester.enterText(
        _field(hint: 'Название, описание или BUG-001'),
        existingTitle,
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == existingTitle,
        ),
        findsOneWidget,
      );
      await tester.enterText(
        _field(hint: 'Название, описание или BUG-001'),
        '',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Доска'));
      await tester.pumpAndSettle();
      _noErrors(tester, 'desktop kanban');
      await _capture(tester, 'desktop-kanban');
      await tester.tap(find.byTooltip('Список'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Новый дефект'));
      await tester.pumpAndSettle();
      expect(find.text('Сообщить об ошибке'), findsOneWidget);
      await tester.tap(find.text('Создать ошибку'));
      await tester.pumpAndSettle();
      expect(find.text('Введите название ошибки'), findsOneWidget);
      await tester.enterText(
        _field(label: 'Название ошибки *'),
        'QA: изменения профиля не сохраняются',
      );
      await tester.enterText(
        _field(label: 'Описание'),
        'Проверка сохранения в настоящей локальной SQLite.',
      );
      await tester.tap(find.text('Создать ошибку'));
      await _drainDatabase(tester);
      expect(store.issues.length, initialCount + 1);
      final issue = store.issues.singleWhere((i) => i.title.startsWith('QA:'));
      expect(issue.description, contains('SQLite'));
      expect(find.text('Сообщить об ошибке'), findsNothing);
      _noErrors(tester, 'saved editor');

      await tester.tap(find.text(issue.title));
      await _drainDatabase(tester);
      expect(find.text('Изменить статус'), findsOneWidget);
      await _capture(tester, 'desktop-issue-details');
      await tester.tap(find.text('Комментарии'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _field(hint: 'Напишите комментарий…'),
        'Воспроизводится на Windows. Исправление проверено.',
      );
      await tester.pump();
      await tester.tap(find.text('Отправить'));
      await _drainDatabase(tester);
      expect(
        find.text('Воспроизводится на Windows. Исправление проверено.'),
        findsOneWidget,
      );
      final comments = await tester.runAsync(() => store.commentsFor(issue.id));
      expect(comments!.last.text, contains('Windows'));

      await tester.tap(
        find.ancestor(
          of: find.text('Изменить статус'),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('В работе').last);
      await _drainDatabase(tester);
      expect(store.issueById(issue.id)!.status, 'В работе');

      await tester.tap(find.text('Редактировать'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _field(label: 'Название ошибки *'),
        'QA: исправлено сохранение профиля',
      );
      await tester.tap(find.text('Сохранить'));
      await _drainDatabase(tester);
      expect(
        store.issueById(issue.id)!.title,
        'QA: исправлено сохранение профиля',
      );
      await tester.tap(find.text('История'));
      await _drainDatabase(tester);
      expect(find.textContaining('В работе'), findsWidgets);
      _noErrors(tester, 'detail edit, comment and history');
      await tester.tap(find.byTooltip('Закрыть').last);
      await tester.pumpAndSettle();

      await _navigate(tester, 'Проекты');
      await tester.tap(find.text('Создать проект').last);
      await tester.pumpAndSettle();
      await tester.enterText(_field(label: 'Название проекта'), 'QA Workspace');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Создать проект').last,
      );
      await _drainDatabase(tester);
      expect(
        store.projects.any((project) => project.name == 'QA Workspace'),
        isTrue,
      );
      _noErrors(tester, 'project creation');

      await _navigate(tester, 'Профиль');
      expect(find.text('Мой профиль'), findsOneWidget);
      await tester.enterText(_field(hint: 'Ваше имя'), 'Александр QA');
      await tester.tap(find.text('Сохранить изменения'));
      await _drainDatabase(tester);
      expect(store.currentUser!.name, 'Александр QA');
      _noErrors(tester, 'profile save');
      await _capture(tester, 'desktop-profile');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  for (final size in [const Size(390, 844), const Size(390, 600)]) {
    testWidgets(
      'mobile ${size.width.toInt()}x${size.height.toInt()} screens and issue dialogs fit',
      (tester) async {
        final store = await _prepare(tester, size);
        _noErrors(tester, 'mobile overview ${size.height}');
        if (size.height == 844) await _capture(tester, 'mobile-overview');
        await _navigate(tester, 'Проекты', mobile: true);
        await _navigate(tester, 'Профиль', mobile: true);
        await _navigate(tester, 'Дефекты', mobile: true);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        _noErrors(tester, 'mobile search with keyboard ${size.height}');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        if (size.height == 844) await _capture(tester, 'mobile-issues');
        await tester.tap(find.text('Новый дефект'));
        await tester.pumpAndSettle();
        _noErrors(tester, 'mobile editor ${size.height}');
        expect(find.text('Создать ошибку'), findsOneWidget);
        await tester.enterText(
          _field(label: 'Название ошибки *'),
          'Мобильная ошибка ${size.height}',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        _noErrors(tester, 'mobile editor with keyboard ${size.height}');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Создать ошибку'));
        await _drainDatabase(tester);
        final created = store.issues.singleWhere(
          (i) => i.title == 'Мобильная ошибка ${size.height}',
        );
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -320),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(created.title));
        await tester.pumpAndSettle();
        await tester.tap(find.text(created.title));
        await _drainDatabase(tester);
        _noErrors(tester, 'mobile detail ${size.height}');
        if (size.height == 600) await _capture(tester, 'mobile-small-detail');
        await tester.tap(find.text('Комментарии'));
        await tester.pumpAndSettle();
        _noErrors(tester, 'mobile comments ${size.height}');
        await tester.enterText(
          _field(hint: 'Напишите комментарий…'),
          'Мобильная проверка',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        _noErrors(tester, 'mobile comments with keyboard ${size.height}');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        _noErrors(
          tester,
          'mobile comments after keyboard closes ${size.height}',
        );
        await tester.tap(find.byTooltip('Закрыть').last);
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
