import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart' as sql;

import 'models.dart';
import 'platform_storage.dart';
import 'platform_storage_native.dart'
    if (dart.library.js_interop) 'platform_storage_web.dart'
    as platform;

const _passwordIterations = 600000;

Future<String> _derivePassword(Map<String, Object> input) async {
  final algorithm = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: input['iterations'] as int,
    bits: 256,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKey(utf8.encode(input['password'] as String)),
    nonce: base64Decode(input['salt'] as String),
  );
  return base64Encode(await key.extractBytes());
}

/// Local, account-scoped SQLite workspace. No data leaves this device.
class TrackerStore extends ChangeNotifier {
  TrackerStore._(this._db, this._storage);

  final sql.Database _db;
  final PlatformStorage _storage;
  String get databasePath => _storage.databaseDescription;
  AppUser? _currentUser;
  List<AppUser> _users = const [];
  List<Project> _projects = const [];
  List<Issue> _issues = const [];
  bool _closed = false;
  int _sessionGeneration = 0;
  int _reloadGeneration = 0;

  AppUser? get currentUser => _currentUser;
  List<AppUser> get users => List.unmodifiable(_users);
  List<Project> get projects => List.unmodifiable(_projects);
  List<Issue> get issues => List.unmodifiable(_issues);

  static Future<TrackerStore> open({String? databasePath}) async {
    final storage = await platform.openStorage(databasePath);
    final db = await storage.databaseFactory.openDatabase(
      storage.databaseName,
      options: sql.OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          // Android treats this PRAGMA as a row-returning query.
          await db.rawQuery('PRAGMA busy_timeout = 5000');
        },
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
            role TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '',
            password_hash TEXT NOT NULL, password_salt TEXT NOT NULL,
            password_iterations INTEGER NOT NULL,
            is_demo INTEGER NOT NULL DEFAULT 0
          )''');
          await db.execute('''CREATE TABLE settings (
            key TEXT PRIMARY KEY, value TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
            color TEXT NOT NULL, created_at TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE issues (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
            steps TEXT NOT NULL DEFAULT '', expected TEXT NOT NULL DEFAULT '',
            actual TEXT NOT NULL DEFAULT '', status TEXT NOT NULL,
            priority TEXT NOT NULL, severity TEXT NOT NULL,
            environment TEXT NOT NULL DEFAULT '',
            assignee_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
            created_by INTEGER NOT NULL REFERENCES users(id),
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE comments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id),
            text TEXT NOT NULL, created_at TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE activity (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
            text TEXT NOT NULL, created_at TEXT NOT NULL
          )''');
          await db.execute('''CREATE TABLE attachments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue_id INTEGER NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
            name TEXT NOT NULL, path TEXT NOT NULL, content BLOB
          )''');
          await db.execute('CREATE INDEX projects_owner ON projects(owner_id)');
          await db.execute('CREATE INDEX issues_project ON issues(project_id)');
          await db.execute('CREATE INDEX comments_issue ON comments(issue_id)');
          await db.execute('CREATE INDEX activity_issue ON activity(issue_id)');
          await db.execute(
            'CREATE INDEX attachments_issue ON attachments(issue_id)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE attachments ADD COLUMN content BLOB');
          }
        },
      ),
    );
    final store = TrackerStore._(db, storage);
    final session = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['current_user'],
    );
    if (session.isNotEmpty) {
      final id = int.tryParse(session.first['value'] as String);
      if (id != null) {
        final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
        if (rows.isNotEmpty) store._currentUser = AppUser.fromMap(rows.first);
      }
    }
    await store._cleanupOrphanedAttachments();
    await store._reload();
    return store;
  }

  Future<void> _reload() async {
    final user = _currentUser;
    final sessionGeneration = _sessionGeneration;
    final reloadGeneration = ++_reloadGeneration;
    if (user == null) {
      _users = const [];
      _projects = const [];
      _issues = const [];
    } else {
      final ownUser = await _db.query(
        'users',
        where: 'id = ?',
        whereArgs: [user.id],
      );
      final projects = (await _db.query(
        'projects',
        where: 'owner_id = ?',
        whereArgs: [user.id],
        orderBy: 'created_at DESC, id DESC',
      )).map(Project.fromMap).toList();
      final issues = (await _db.rawQuery(
        '''SELECT i.* FROM issues i
        INNER JOIN projects p ON p.id = i.project_id WHERE p.owner_id = ?
        ORDER BY i.updated_at DESC, i.id DESC''',
        [user.id],
      )).map(Issue.fromMap).toList();
      // A slow refresh must never restore an account after logout or publish
      // results from an older mutation over a newer refresh.
      if (_closed ||
          sessionGeneration != _sessionGeneration ||
          reloadGeneration != _reloadGeneration) {
        return;
      }
      _currentUser = AppUser.fromMap(ownUser.single);
      _users = [_currentUser!];
      _projects = projects;
      _issues = issues;
    }
    if (!_closed) notifyListeners();
  }

  void _setSession(AppUser? user) {
    _sessionGeneration++;
    _currentUser = user;
    _users = const [];
    _projects = const [];
    _issues = const [];
  }

  void _checkSession(int generation) {
    if (_closed || generation != _sessionGeneration || _currentUser == null) {
      throw StateError('Сеанс завершён. Войдите в учётную запись снова.');
    }
  }

  AppUser _requireUser() =>
      _currentUser ?? (throw StateError('Войдите в учётную запись.'));

  Project _requireProject(int id) =>
      projectById(id) ?? (throw StateError('Проект не найден или недоступен.'));

  Issue _requireIssue(int id) =>
      issueById(id) ?? (throw StateError('Задача не найдена или недоступна.'));

  Issue? issueById(int id) {
    for (final issue in _issues) {
      if (issue.id == id) return issue;
    }
    return null;
  }

  Project? projectById(int id) {
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  AppUser? userById(int id) {
    for (final user in _users) {
      if (user.id == id) return user;
    }
    return null;
  }

  static void _validateText(String value, String label, {int max = 200}) {
    if (value.trim().isEmpty) throw StateError('Заполните поле «$label».');
    if (value.trim().length > max) {
      throw StateError('Поле «$label»: не более $max символов.');
    }
  }

  static void _validateRole(String role) {
    if (!userRoles.contains(role)) throw StateError('Выберите роль из списка.');
  }

  static String _salt() =>
      base64Encode(List<int>.generate(24, (_) => Random.secure().nextInt(256)));

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phone,
  }) async {
    _validateText(name, 'Имя', max: 80);
    _validateRole(role);
    final normalizedEmail = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
      throw StateError('Введите корректный адрес электронной почты.');
    }
    if (normalizedEmail == 'demo@flowtrack.local') {
      throw StateError('Этот адрес зарезервирован для демо-режима.');
    }
    if (password.length < 8 || password.length > 128) {
      throw StateError('Пароль должен содержать от 8 до 128 символов.');
    }
    final salt = _salt();
    final hash = await compute(_derivePassword, <String, Object>{
      'password': password,
      'salt': salt,
      'iterations': _passwordIterations,
    });
    final int id;
    try {
      id = await _db.transaction((tx) async {
        final id = await tx.insert('users', {
          'name': name.trim(),
          'email': normalizedEmail,
          'role': role,
          'phone': phone.trim(),
          'password_hash': hash,
          'password_salt': salt,
          'password_iterations': _passwordIterations,
        });
        await _writeSession(tx, id);
        return id;
      });
    } on sql.DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) {
        throw StateError('Учётная запись с такой почтой уже существует.');
      }
      rethrow;
    }
    _setSession(
      AppUser(
        id: id,
        name: name.trim(),
        email: normalizedEmail,
        role: role,
        phone: phone.trim(),
      ),
    );
    await _reload();
  }

  static Future<void> _writeSession(sql.DatabaseExecutor tx, int id) => tx
      .insert('settings', {
        'key': 'current_user',
        'value': '$id',
      }, conflictAlgorithm: sql.ConflictAlgorithm.replace)
      .then((_) {});

  Future<void> login(String email, String password) async {
    final rows = await _db.query(
      'users',
      where: 'email = ? AND is_demo = 0',
      whereArgs: [email.trim().toLowerCase()],
    );
    if (rows.isEmpty) throw StateError('Неверная почта или пароль.');
    final row = rows.single;
    final actual = await compute(_derivePassword, <String, Object>{
      'password': password,
      'salt': row['password_salt'] as String,
      'iterations': row['password_iterations'] as int,
    });
    final expectedBytes = base64Decode(row['password_hash'] as String);
    final actualBytes = base64Decode(actual);
    var difference = expectedBytes.length ^ actualBytes.length;
    for (var i = 0; i < expectedBytes.length && i < actualBytes.length; i++) {
      difference |= expectedBytes[i] ^ actualBytes[i];
    }
    if (difference != 0) throw StateError('Неверная почта или пароль.');
    await _writeSession(_db, row['id'] as int);
    _setSession(AppUser.fromMap(row));
    await _reload();
  }

  Future<void> logout() async {
    await _db.delete('settings', where: 'key = ?', whereArgs: ['current_user']);
    _setSession(null);
    await _reload();
  }

  Future<void> updateProfile({
    required String name,
    required String role,
    required String phone,
  }) async {
    final user = _requireUser();
    _validateText(name, 'Имя', max: 80);
    _validateRole(role);
    await _db.update(
      'users',
      {'name': name.trim(), 'role': role, 'phone': phone.trim()},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    await _reload();
  }

  Future<void> createProject({
    required String name,
    required String description,
    required String color,
  }) async {
    final user = _requireUser();
    _validateText(name, 'Название проекта', max: 100);
    await _db.insert('projects', {
      'owner_id': user.id,
      'name': name.trim(),
      'description': description.trim(),
      'color': color,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _reload();
  }

  Future<void> updateProject(
    Project project, {
    required String name,
    required String description,
    required String color,
  }) async {
    final user = _requireUser();
    _requireProject(project.id);
    _validateText(name, 'Название проекта', max: 100);
    await _db.update(
      'projects',
      {'name': name.trim(), 'description': description.trim(), 'color': color},
      where: 'id = ? AND owner_id = ?',
      whereArgs: [project.id, user.id],
    );
    await _reload();
  }

  Future<void> deleteProject(int id) async {
    final user = _requireUser();
    _requireProject(id);
    final paths = await _db.rawQuery(
      '''SELECT a.path FROM attachments a
      JOIN issues i ON i.id = a.issue_id WHERE i.project_id = ?''',
      [id],
    );
    await _db.delete(
      'projects',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, user.id],
    );
    await _removeFiles(paths);
    await _reload();
  }

  Future<void> _addActivity(
    sql.DatabaseExecutor tx,
    int issueId,
    String text, {
    DateTime? at,
  }) async {
    await tx.insert('activity', {
      'issue_id': issueId,
      'text': text,
      'created_at': (at ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<int> saveIssue({
    int? id,
    required int projectId,
    required String title,
    required String description,
    required String steps,
    required String expected,
    required String actual,
    required String status,
    required String priority,
    required String severity,
    required String environment,
    int? assigneeId,
  }) async {
    final user = _requireUser();
    _requireProject(projectId);
    final previous = id == null ? null : _requireIssue(id);
    _validateText(title, 'Название задачи', max: 160);
    if (!issueStatuses.contains(status)) {
      throw StateError('Неизвестный статус.');
    }
    if (!issuePriorities.contains(priority)) {
      throw StateError('Неизвестный приоритет.');
    }
    if (assigneeId != null && userById(assigneeId) == null) {
      throw StateError('Исполнитель недоступен в вашем рабочем пространстве.');
    }
    final now = DateTime.now();
    final values = <String, Object?>{
      'project_id': projectId,
      'title': title.trim(),
      'description': description.trim(),
      'steps': steps.trim(),
      'expected': expected.trim(),
      'actual': actual.trim(),
      'status': status,
      'priority': priority,
      'severity': severity,
      'environment': environment.trim(),
      'assignee_id': assigneeId,
      'updated_at': now.toIso8601String(),
    };
    final savedId = await _db.transaction((tx) async {
      if (previous == null) {
        values['created_by'] = user.id;
        values['created_at'] = now.toIso8601String();
        final createdId = await tx.insert('issues', values);
        await _addActivity(
          tx,
          createdId,
          '${user.name} создал(а) задачу',
          at: now,
        );
        return createdId;
      }
      await tx.update(
        'issues',
        values,
        where: 'id = ?',
        whereArgs: [previous.id],
      );
      await _addActivity(
        tx,
        previous.id,
        previous.status == status
            ? '${user.name} обновил(а) задачу'
            : '${user.name}: ${previous.status} → $status',
        at: now,
      );
      return previous.id;
    });
    await _reload();
    return savedId;
  }

  Future<void> deleteIssue(int id) async {
    _requireUser();
    _requireIssue(id);
    final paths = await _db.query(
      'attachments',
      columns: ['path'],
      where: 'issue_id = ?',
      whereArgs: [id],
    );
    await _db.delete('issues', where: 'id = ?', whereArgs: [id]);
    await _removeFiles(paths);
    await _reload();
  }

  Future<void> changeStatus(int id, String status) async {
    final user = _requireUser();
    final issue = _requireIssue(id);
    if (!issueStatuses.contains(status)) {
      throw StateError('Неизвестный статус.');
    }
    if (issue.status == status) return;
    await _db.transaction((tx) async {
      await tx.update(
        'issues',
        {'status': status, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _addActivity(tx, id, '${user.name}: ${issue.status} → $status');
    });
    await _reload();
  }

  Future<List<IssueComment>> commentsFor(int issueId) async {
    _requireIssue(issueId);
    final generation = _sessionGeneration;
    final rows = await _db.query(
      'comments',
      where: 'issue_id = ?',
      whereArgs: [issueId],
      orderBy: 'created_at ASC, id ASC',
    );
    _checkSession(generation);
    return rows.map(IssueComment.fromMap).toList();
  }

  Future<List<IssueActivity>> activityFor(int issueId) async {
    _requireIssue(issueId);
    final generation = _sessionGeneration;
    final rows = await _db.query(
      'activity',
      where: 'issue_id = ?',
      whereArgs: [issueId],
      orderBy: 'created_at DESC, id DESC',
    );
    _checkSession(generation);
    return rows.map(IssueActivity.fromMap).toList();
  }

  Future<List<IssueAttachment>> attachmentsFor(int issueId) async {
    _requireIssue(issueId);
    final generation = _sessionGeneration;
    final rows = await _db.query(
      'attachments',
      columns: ['id', 'issue_id', 'name', 'path'],
      where: 'issue_id = ?',
      whereArgs: [issueId],
      orderBy: 'id ASC',
    );
    _checkSession(generation);
    return rows.map(IssueAttachment.fromMap).toList();
  }

  Future<void> addComment(int issueId, String text) async {
    final user = _requireUser();
    _requireIssue(issueId);
    _validateText(text, 'Комментарий', max: 10000);
    final now = DateTime.now().toIso8601String();
    await _db.transaction((tx) async {
      await tx.insert('comments', {
        'issue_id': issueId,
        'user_id': user.id,
        'text': text.trim(),
        'created_at': now,
      });
      await tx.update(
        'issues',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [issueId],
      );
      await _addActivity(tx, issueId, '${user.name} добавил(а) комментарий');
    });
    await _reload();
  }

  Future<void> addAttachment(int issueId, String sourcePath) async {
    _requireUser();
    final generation = _sessionGeneration;
    _requireIssue(issueId);
    final bytes = await _storage.readSource(sourcePath);
    _checkSession(generation);
    await addAttachmentBytes(issueId, p.basename(sourcePath), bytes);
  }

  Future<void> addAttachmentBytes(
    int issueId,
    String name,
    Uint8List bytes,
  ) async {
    final user = _requireUser();
    final generation = _sessionGeneration;
    _requireIssue(issueId);
    _validateText(name, 'Имя файла', max: 255);
    if (bytes.length > 25 * 1024 * 1024) {
      throw StateError('Размер вложения не должен превышать 25 МБ.');
    }
    final safeName = p.basename(name.replaceAll('\\', '/'));
    final content = Uint8List.fromList(bytes);
    String? savedPath;
    try {
      if (!_storage.storesAttachmentBlobs) {
        savedPath = await _storage.writeAttachment(user.id, safeName, content);
      }
      _checkSession(generation);
      await _db.transaction((tx) async {
        _checkSession(generation);
        await tx.insert('attachments', {
          'issue_id': issueId,
          'name': safeName,
          'path': savedPath ?? 'indexeddb:attachment',
          'content': _storage.storesAttachmentBlobs ? content : null,
        });
        await _addActivity(
          tx,
          issueId,
          '${user.name} прикрепил(а) файл «$safeName»',
        );
      });
    } catch (_) {
      if (savedPath != null) await _storage.removeAttachments([savedPath]);
      rethrow;
    }
    await _reload();
  }

  Future<Uint8List> attachmentBytes(int attachmentId) async {
    final user = _requireUser();
    final generation = _sessionGeneration;
    final rows = await _db.rawQuery(
      '''SELECT a.* FROM attachments a
      JOIN issues i ON i.id = a.issue_id JOIN projects p ON p.id = i.project_id
      WHERE a.id = ? AND p.owner_id = ?''',
      [attachmentId, user.id],
    );
    _checkSession(generation);
    if (rows.isEmpty) throw StateError('Вложение не найдено или недоступно.');
    final bytes = await _attachmentContent(rows.single);
    _checkSession(generation);
    return bytes;
  }

  Future<Uint8List> _attachmentContent(Map<String, Object?> row) async {
    final content = row['content'];
    if (content is List<int>) return Uint8List.fromList(content);
    try {
      return await _storage.readAttachment(row['path'] as String);
    } on StateError {
      throw StateError(
        'Вложение «${row['name']}» не найдено. '
        'Прикрепите файл заново или удалите запись перед экспортом.',
      );
    }
  }

  Future<void> deleteAttachment(int id) async {
    final user = _requireUser();
    final rows = await _db.rawQuery(
      '''SELECT a.* FROM attachments a
      JOIN issues i ON i.id = a.issue_id JOIN projects p ON p.id = i.project_id
      WHERE a.id = ? AND p.owner_id = ?''',
      [id, user.id],
    );
    if (rows.isEmpty) throw StateError('Вложение не найдено или недоступно.');
    final row = rows.single;
    await _db.transaction((tx) async {
      await tx.delete('attachments', where: 'id = ?', whereArgs: [id]);
      await _addActivity(
        tx,
        row['issue_id'] as int,
        '${user.name} удалил(а) вложение «${row['name']}»',
      );
    });
    await _removeFiles(rows);
    await _reload();
  }

  Future<void> _removeFiles(List<Map<String, Object?>> rows) async {
    await _storage.removeAttachments(rows.map((row) => row['path'] as String));
  }

  Future<void> _cleanupOrphanedAttachments() async {
    if (_storage.storesAttachmentBlobs) return;
    final rows = await _db.query('attachments', columns: ['path']);
    await _storage.cleanupAttachments(rows.map((row) => row['path'] as String));
  }

  Future<String> exportBackup() async {
    final user = _requireUser();
    final generation = _sessionGeneration;
    final bytes = await exportJsonBytes();
    _checkSession(generation);
    return _storage.writeExport(user.id, bytes);
  }

  Future<Uint8List> exportJsonBytes() async {
    final user = _requireUser();
    final generation = _sessionGeneration;
    final data = await _db.transaction((tx) async {
      final projects = await tx.query(
        'projects',
        where: 'owner_id = ?',
        whereArgs: [user.id],
      );
      final issues = await tx.rawQuery(
        '''SELECT i.* FROM issues i
        JOIN projects p ON p.id = i.project_id WHERE p.owner_id = ?''',
        [user.id],
      );
      Future<List<Map<String, Object?>>> children(String table) => tx.rawQuery(
        '''
        SELECT child.* FROM $table child
        JOIN issues i ON i.id = child.issue_id JOIN projects p ON p.id = i.project_id
        WHERE p.owner_id = ?''',
        [user.id],
      );
      return <String, Object?>{
        'format': 'bugtracker-export',
        'version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user': user.toMap(),
        'projects': projects,
        'issues': issues,
        'comments': await children('comments'),
        'activity': await children('activity'),
        'attachments': await children('attachments'),
      };
    });
    final attachments = data['attachments'] as List<Map<String, Object?>>;
    final exportedAttachments = <Map<String, Object?>>[];
    for (final attachment in attachments) {
      _checkSession(generation);
      exportedAttachments.add({
        'id': attachment['id'],
        'issue_id': attachment['issue_id'],
        'name': attachment['name'],
        'content_base64': base64Encode(await _attachmentContent(attachment)),
      });
    }
    data['attachments'] = exportedAttachments;
    _checkSession(generation);
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
  }

  /// Demo is an explicitly selected, separate account; existing work is untouched.
  Future<void> seedDemo() async {
    final existing = await _db.query('users', where: 'is_demo = 1', limit: 1);
    final int userId;
    if (existing.isNotEmpty) {
      userId = existing.single['id'] as int;
      await _writeSession(_db, userId);
    } else {
      final salt = _salt();
      final password = _salt();
      final hash = await compute(_derivePassword, <String, Object>{
        'password': password,
        'salt': salt,
        'iterations': _passwordIterations,
      });
      userId = await _db.transaction((tx) async {
        final id = await tx.insert('users', {
          'name': 'Александр',
          'email': 'demo@flowtrack.local',
          'role': 'Менеджер',
          'phone': '',
          'password_hash': hash,
          'password_salt': salt,
          'password_iterations': _passwordIterations,
          'is_demo': 1,
        });
        final now = DateTime.now();
        final projectIds = <int>[];
        for (final project in [
          [
            'Atlas Mobile',
            'Мобильное приложение: авторизация, каталог и оплата',
            '#6C5CE7',
          ],
          ['Workspace', 'Кабинет команды и управление проектами', '#16A394'],
          ['Design System', 'Компоненты интерфейса и доступность', '#E69739'],
        ]) {
          projectIds.add(
            await tx.insert('projects', {
              'owner_id': id,
              'name': project[0],
              'description': project[1],
              'color': project[2],
              'created_at': now
                  .subtract(const Duration(days: 12))
                  .toIso8601String(),
            }),
          );
        }
        final demo = [
          [
            'Не приходит код подтверждения',
            0,
            'В работе',
            'Критический',
            'При повторной отправке кода экран остаётся в состоянии загрузки.',
          ],
          [
            'Фильтр каталога сбрасывается после возврата',
            0,
            'Новый',
            'Высокий',
            'Выбранная категория не сохраняется при переходе из карточки товара.',
          ],
          [
            'Тёмная тема: низкий контраст подписи',
            2,
            'На проверке',
            'Средний',
            'Вторичный текст недостаточно контрастен на тёмном фоне.',
          ],
          [
            'Пустое состояние списка участников',
            1,
            'Исправлен',
            'Низкий',
            'Нужно показать подсказку и действие для приглашения первого участника.',
          ],
          [
            'Двойная отправка формы оплаты',
            0,
            'В работе',
            'Высокий',
            'Повторное нажатие создаёт второй запрос до завершения первого.',
          ],
          [
            'Таблица задач обрезается на узком экране',
            1,
            'Новый',
            'Средний',
            'На экране шириной 800 px последний столбец недоступен.',
          ],
          [
            'Кнопка без подписи для скринридера',
            2,
            'Закрыт',
            'Средний',
            'Для кнопки закрытия модального окна добавлена семантическая подпись.',
          ],
          [
            'Поиск не учитывает регистр',
            1,
            'Переоткрыт',
            'Высокий',
            'Поиск кириллицей в верхнем регистре снова не находит результаты.',
          ],
          [
            'Отступы в карточке проекта',
            2,
            'Новый',
            'Низкий',
            'Внутренние отступы не совпадают со шкалой компонентов.',
          ],
        ];
        for (var index = 0; index < demo.length; index++) {
          final item = demo[index];
          final created = now.subtract(Duration(days: 9 - index));
          final issueId = await tx.insert('issues', {
            'project_id': projectIds[item[1] as int],
            'title': item[0],
            'description': item[4],
            'steps': '1. Откройте соответствующий экран.\n2. Выполните описанное действие.\n3. Проверьте результат.',
            'expected':
                'Интерфейс корректно обрабатывает действие пользователя.',
            'actual': item[4],
            'status': item[2],
            'priority': item[3],
            'severity': index == 0 ? 'Блокирующая' : 'Значительная',
            'environment': item[1] == 0
                ? 'Android 14 · Pixel 7'
                : 'Windows 11 · Desktop',
            'assignee_id': index % 3 == 1 ? null : id,
            'created_by': id,
            'created_at': created.toIso8601String(),
            'updated_at': created
                .add(const Duration(hours: 2))
                .toIso8601String(),
          });
          await _addActivity(
            tx,
            issueId,
            'Александр создал(а) задачу',
            at: created,
          );
          if (index == 0) {
            await tx.insert('comments', {
              'issue_id': issueId,
              'user_id': id,
              'text': 'Воспроизводится после третьей повторной отправки. Проверяем обработку тайм-аута.',
              'created_at': created
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
            });
            await _addActivity(
              tx,
              issueId,
              'Александр: Новый → В работе',
              at: created.add(const Duration(hours: 2)),
            );
          }
        }
        await _writeSession(tx, id);
        return id;
      });
    }
    final row = (await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    )).single;
    _setSession(AppUser.fromMap(row));
    await _reload();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _db.close();
    dispose();
  }
}
