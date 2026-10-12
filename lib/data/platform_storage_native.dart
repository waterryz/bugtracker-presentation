import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'platform_storage.dart';

Future<PlatformStorage> openStorage(String? requestedPath) async {
  final Directory directory;
  if (requestedPath == null) {
    final support = await getApplicationSupportDirectory();
    directory = Directory(p.join(support.path, 'bugtracker'));
  } else {
    directory = Directory(p.dirname(p.absolute(requestedPath)));
  }
  await directory.create(recursive: true);
  final sql.DatabaseFactory factory;
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    ffi.sqfliteFfiInit();
    factory = ffi.databaseFactoryFfi;
  } else {
    factory = sql.databaseFactory;
  }
  return _NativeStorage(
    directory,
    factory,
    requestedPath ?? p.join(directory.path, 'tracker.sqlite'),
  );
}

class _NativeStorage implements PlatformStorage {
  _NativeStorage(this.directory, this.databaseFactory, this.databaseName);
  final Directory directory;
  @override
  final sql.DatabaseFactory databaseFactory;
  @override
  final String databaseName;
  @override
  String get databaseDescription => databaseName;
  @override
  bool get storesAttachmentBlobs => false;

  @override
  Future<Uint8List> readSource(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('Выбранный файл не найден.');
    if (await file.length() > 25 * 1024 * 1024) {
      throw StateError('Размер вложения не должен превышать 25 МБ.');
    }
    return file.readAsBytes();
  }

  @override
  Future<String> writeAttachment(
    int ownerId,
    String name,
    Uint8List bytes,
  ) async {
    final folder = Directory(p.join(directory.path, 'attachments', '$ownerId'));
    await folder.create(recursive: true);
    final unique =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';
    final target = File(p.join(folder.path, '$unique${p.extension(name)}'));
    try {
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
  }

  @override
  Future<Uint8List> readAttachment(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('Файл вложения не найден.');
    return file.readAsBytes();
  }

  @override
  Future<void> removeAttachments(Iterable<String> paths) async {
    final root = p.normalize(p.absolute(p.join(directory.path, 'attachments')));
    for (final path in paths) {
      final normalized = p.normalize(p.absolute(path));
      if (!p.isWithin(root, normalized)) continue;
      try {
        final file = File(normalized);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Locked orphans are retried when opening the application later.
      }
    }
  }

  @override
  Future<void> cleanupAttachments(Iterable<String> referencedPaths) async {
    final root = Directory(p.join(directory.path, 'attachments'));
    if (!await root.exists()) return;
    final referenced = referencedPaths
        .map((path) => p.normalize(p.absolute(path)))
        .toSet();
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    try {
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final normalized = p.normalize(p.absolute(entity.path));
        if (referenced.contains(normalized)) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // An inaccessible unused file must not prevent opening the database.
        }
      }
    } on FileSystemException {
      // Opening the workspace remains possible if orphan cleanup is unavailable.
    }
  }

  @override
  Future<String> writeExport(int ownerId, Uint8List bytes) async {
    final folder = Directory(p.join(directory.path, 'exports'));
    await folder.create(recursive: true);
    final target = File(
      p.join(
        folder.path,
        'bugtracker_${ownerId}_${DateTime.now().millisecondsSinceEpoch}.json',
      ),
    );
    final pending = File('${target.path}.tmp');
    await pending.writeAsBytes(bytes, flush: true);
    await pending.rename(target.path);
    return target.path;
  }
}
