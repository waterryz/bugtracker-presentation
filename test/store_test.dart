import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bug_tracker/data/models.dart';
import 'package:bug_tracker/data/tracker_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> register(
  TrackerStore store, {
  String email = 'alex@example.com',
}) => store.register(
  name: 'Александр',
  email: email,
  password: 'My-safe-password-42',
  role: 'Менеджер',
  phone: '+7 700 123 45 67',
);

Future<int> createIssue(
  TrackerStore store,
  int projectId, {
  int? id,
  String title = 'Ошибка входа',
  String status = 'Новый',
}) => store.saveIssue(
  id: id,
  projectId: projectId,
  title: title,
  description: 'Описание ошибки',
  steps: 'Открыть экран',
  expected: 'Успешный вход',
  actual: 'Ошибка',
  status: status,
  priority: 'Высокий',
  severity: 'Значительная',
  environment: 'Windows 11',
  assigneeId: store.currentUser!.id,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late TrackerStore store;
  late String databasePath;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flowtrack_test_');
    databasePath = p.join(directory.path, 'tracker.sqlite');
    store = await TrackerStore.open(databasePath: databasePath);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'registration, session restore, wrong password and profile persist',
    () async {
      expect(store.currentUser, isNull);
      var notifications = 0;
      store.addListener(() => notifications++);
      await register(store);
      expect(notifications, 1);
      final id = store.currentUser!.id;
      await store.updateProfile(
        name: 'Алексей',
        role: 'Разработчик',
        phone: '123',
      );
      await store.close();
      store = await TrackerStore.open(databasePath: databasePath);
      expect(store.currentUser!.id, id);
      expect(store.currentUser!.name, 'Алексей');
      expect(store.currentUser!.phone, '123');
      await store.logout();
      await store.close();
      store = await TrackerStore.open(databasePath: databasePath);
      expect(store.currentUser, isNull);
      await expectLater(
        store.login('alex@example.com', 'wrong-password'),
        throwsA(isA<StateError>()),
      );
      expect(store.currentUser, isNull);
      await store.login('  ALEX@EXAMPLE.COM ', 'My-safe-password-42');
      expect(store.currentUser!.id, id);
      expect(store.currentUser!.role, 'Разработчик');
      await store.close();
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      final row = (await db.query('users')).single;
      expect(row.containsKey('password'), isFalse);
      expect(row['password_hash'], isNot('My-safe-password-42'));
      expect(base64Decode(row['password_hash'] as String).length, 32);
      expect(base64Decode(row['password_salt'] as String).length, 24);
      expect(row['password_iterations'], greaterThanOrEqualTo(600000));
      await db.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'issue lifecycle, attachments and project cascade survive restart',
    () async {
      await register(store);
      await store.createProject(
        name: 'Мобильное приложение',
        description: 'Релиз',
        color: '#6C5CE7',
      );
      final project = store.projects.single;
      await store.updateProject(
        project,
        name: 'Atlas',
        description: 'Релиз 2',
        color: '#16A394',
      );
      final id = await createIssue(store, project.id);
      await store.addComment(id, '  Ошибка воспроизведена  ');
      await store.changeStatus(id, 'В работе');
      await createIssue(
        store,
        project.id,
        id: id,
        title: 'Ошибка подтверждения',
        status: 'Исправлен',
      );
      final source = File(p.join(directory.path, 'evidence.txt'));
      await source.writeAsString('Доказательство ошибки');
      await store.addAttachment(id, source.path);
      final attachment = (await store.attachmentsFor(id)).single;
      expect(attachment.path, isNot(source.path));
      await source.delete();
      expect(
        await File(attachment.path).readAsString(),
        'Доказательство ошибки',
      );
      final backup = jsonDecode(
        await File(await store.exportBackup()).readAsString(),
      ) as Map<String, dynamic>;
      expect(backup.toString(), isNot(contains('password')));
      expect(
        utf8.decode(
          base64Decode(backup['attachments'][0]['content_base64'] as String),
        ),
        'Доказательство ошибки',
      );
      final orphan = File(p.join(p.dirname(attachment.path), 'old-orphan.txt'));
      await orphan.writeAsString('Interrupted attachment copy');
      await orphan.setLastModified(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      final pendingCopy = File(
        p.join(p.dirname(attachment.path), 'pending-copy.txt'),
      );
      await pendingCopy.writeAsString('A second instance may still be copying');
      await store.close();
      store = await TrackerStore.open(databasePath: databasePath);
      expect(await orphan.exists(), isFalse);
      expect(await pendingCopy.exists(), isTrue);
      expect(await File(attachment.path).exists(), isTrue);
      expect(store.projects.single.name, 'Atlas');
      expect(store.issueById(id)!.status, 'Исправлен');
      expect(store.issueById(id)!.title, 'Ошибка подтверждения');
      expect(
        (await store.commentsFor(id)).single.text,
        'Ошибка воспроизведена',
      );
      expect(await store.activityFor(id), hasLength(5));
      expect(await store.attachmentsFor(id), hasLength(1));
      await store.deleteProject(project.id);
      expect(store.issues, isEmpty);
      expect(store.projects, isEmpty);
      expect(await File(attachment.path).exists(), isFalse);
      await store.close();
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      for (final table in ['issues', 'comments', 'attachments', 'activity']) {
        expect(await db.query(table), isEmpty, reason: '$table should cascade');
      }
      await db.close();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'accounts cannot read, modify, attach or export each other’s data',
    () async {
      await register(store);
      final ownerId = store.currentUser!.id;
      await store.createProject(
        name: 'Секретный проект',
        description: '',
        color: '#000000',
      );
      final project = store.projects.single;
      final issueId = await createIssue(store, project.id);
      final source = File(p.join(directory.path, 'private.txt'));
      await source.writeAsString('private');
      await store.addAttachment(issueId, source.path);
      final attachmentId = (await store.attachmentsFor(issueId)).single.id;
      await store.logout();
      await register(store, email: 'second@example.com');
      expect(store.users.map((u) => u.id), isNot(contains(ownerId)));
      expect(store.projects, isEmpty);
      expect(store.issues, isEmpty);
      await expectLater(store.commentsFor(issueId), throwsA(isA<StateError>()));
      await expectLater(store.activityFor(issueId), throwsA(isA<StateError>()));
      await expectLater(
        store.attachmentsFor(issueId),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.changeStatus(issueId, 'Закрыт'),
        throwsA(isA<StateError>()),
      );
      await expectLater(store.deleteIssue(issueId), throwsA(isA<StateError>()));
      await expectLater(
        store.deleteAttachment(attachmentId),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.deleteProject(project.id),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        createIssue(store, project.id),
        throwsA(isA<StateError>()),
      );
      final backup = await File(await store.exportBackup()).readAsString();
      expect(backup, isNot(contains('Секретный проект')));
      expect(backup, isNot(contains('alex@example.com')));
      await store.login('alex@example.com', 'My-safe-password-42');
      expect(store.projects.single.id, project.id);
      expect(store.issueById(issueId)!.status, 'Новый');
      await store.deleteAttachment(attachmentId);
      expect(await store.attachmentsFor(issueId), isEmpty);
      await store.deleteIssue(issueId);
      expect(store.issues, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'demo is opt-in, account isolated and never overwrites existing edits',
    () async {
      await register(store);
      final originalId = store.currentUser!.id;
      await store.createProject(
        name: 'Мой проект',
        description: '',
        color: '#000000',
      );
      await store.seedDemo();
      final demoId = store.currentUser!.id;
      expect(demoId, isNot(originalId));
      expect(store.projects, hasLength(3));
      expect(store.issues, hasLength(9));
      expect(
        store.issues.every((i) => issueStatuses.contains(i.status)),
        isTrue,
      );
      final issueId = store.issues.first.id;
      await store.changeStatus(issueId, 'Закрыт');
      await store.logout();
      await store.seedDemo();
      expect(store.currentUser!.id, demoId);
      expect(store.issues, hasLength(9));
      expect(store.issueById(issueId)!.status, 'Закрыт');
      await store.login('alex@example.com', 'My-safe-password-42');
      expect(store.projects.single.name, 'Мой проект');
      expect(store.issues, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'validation and duplicate registration leave persisted state unchanged',
    () async {
      await expectLater(
        store.register(
          name: '',
          email: 'invalid',
          password: '123',
          role: 'Менеджер',
          phone: '',
        ),
        throwsA(isA<StateError>()),
      );
      expect(store.currentUser, isNull);
      await register(store);
      final userId = store.currentUser!.id;
      await expectLater(
        register(store, email: 'ALEX@example.com'),
        throwsA(isA<StateError>()),
      );
      expect(store.currentUser!.id, userId);
      await store.createProject(
        name: 'Проект',
        description: '',
        color: '#000000',
      );
      final id = await createIssue(store, store.projects.single.id);
      await expectLater(
        store.changeStatus(id, 'Удалён'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        store.addComment(id, '   '),
        throwsA(isA<StateError>()),
      );
      expect(store.issueById(id)!.status, 'Новый');
      expect(await store.commentsFor(id), isEmpty);
      final source = File(p.join(directory.path, 'missing-evidence.txt'));
      await source.writeAsString('Evidence');
      await store.addAttachment(id, source.path);
      final attachment = (await store.attachmentsFor(id)).single;
      await File(attachment.path).delete();
      await expectLater(store.exportBackup(), throwsA(isA<StateError>()));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('an in-flight refresh cannot restore a logged-out account', () async {
    await register(store);
    await store.createProject(
      name: 'Private project',
      description: '',
      color: '#000000',
    );
    await createIssue(store, store.projects.single.id);
    await Future.wait([
      store.updateProfile(name: 'Updated name', role: 'Менеджер', phone: ''),
      store.logout(),
    ]);
    expect(store.currentUser, isNull);
    expect(store.users, isEmpty);
    expect(store.projects, isEmpty);
    expect(store.issues, isEmpty);
    await store.close();
    store = await TrackerStore.open(databasePath: databasePath);
    expect(store.currentUser, isNull);
    expect(store.projects, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('v1 migration preserves account, issue and file attachments', () async {
    await register(store);
    final accountId = store.currentUser!.id;
    await store.createProject(
      name: 'Существующий проект',
      description: '',
      color: '#6C5CE7',
    );
    final issueId = await createIssue(store, store.projects.single.id);
    await store.addComment(issueId, 'Комментарий до обновления');
    final originalBytes = Uint8List.fromList(
      utf8.encode('Original attachment'),
    );
    await store.addAttachmentBytes(issueId, 'original.txt', originalBytes);
    final attachment = (await store.attachmentsFor(issueId)).single;
    await store.close();

    // Recreate the exact v1 attachment shape and schema version while keeping
    // real pre-upgrade account/project/issue/comment data and managed files.
    final oldDb = await databaseFactoryFfi.openDatabase(databasePath);
    await oldDb.execute('ALTER TABLE attachments DROP COLUMN content');
    await oldDb.setVersion(1);
    await oldDb.close();

    store = await TrackerStore.open(databasePath: databasePath);
    expect(store.currentUser!.id, accountId);
    expect(store.issueById(issueId)!.title, 'Ошибка входа');
    expect(
      (await store.commentsFor(issueId)).single.text,
      'Комментарий до обновления',
    );
    expect(await store.attachmentBytes(attachment.id), originalBytes);
    final newBytes = Uint8List.fromList([0, 1, 2, 128, 255]);
    await store.addAttachmentBytes(issueId, 'binary.dat', newBytes);
    final added = (await store.attachmentsFor(issueId)).last;
    expect(await store.attachmentBytes(added.id), newBytes);
    final exported = jsonDecode(
      utf8.decode(await store.exportJsonBytes()),
    ) as Map<String, dynamic>;
    expect(exported['attachments'], hasLength(2));
    expect(
      base64Decode(exported['attachments'][1]['content_base64'] as String),
      newBytes,
    );
    await store.close();
    final upgraded = await databaseFactoryFfi.openDatabase(databasePath);
    expect(await upgraded.getVersion(), 2);
    expect(
      (await upgraded.rawQuery('PRAGMA table_info(attachments)'))
          .map((column) => column['name']),
      contains('content'),
    );
    await upgraded.close();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
