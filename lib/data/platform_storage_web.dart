import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'platform_storage.dart';

Future<PlatformStorage> openStorage(String? requestedPath) async =>
    _WebStorage(requestedPath ?? 'bugtracker.sqlite');

class _WebStorage implements PlatformStorage {
  _WebStorage(this.databaseName);
  @override
  final String databaseName;
  @override
  String get databaseDescription => 'В браузере · IndexedDB · $databaseName';
  @override
  DatabaseFactory get databaseFactory => databaseFactoryFfiWeb;
  @override
  bool get storesAttachmentBlobs => true;

  @override
  Future<Uint8List> readSource(String path) async =>
      throw StateError('Выберите файл через диалог браузера.');
  @override
  Future<String> writeAttachment(
    int ownerId,
    String name,
    Uint8List bytes,
  ) async => throw StateError(
    'Вложения браузера сохраняются в локальной базе данных.',
  );
  @override
  Future<Uint8List> readAttachment(String path) async =>
      throw StateError('Файл вложения не найден в базе данных браузера.');
  @override
  Future<void> removeAttachments(Iterable<String> paths) async {}
  @override
  Future<void> cleanupAttachments(Iterable<String> referencedPaths) async {}
  @override
  Future<String> writeExport(int ownerId, Uint8List bytes) async =>
      throw StateError('Используйте скачивание JSON через браузер.');
}
