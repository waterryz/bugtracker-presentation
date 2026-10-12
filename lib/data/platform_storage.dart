import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

/// Operating-system files stay in the native adapter. Browser attachments are
/// stored transactionally as SQLite BLOBs in the IndexedDB-backed database.
abstract class PlatformStorage {
  DatabaseFactory get databaseFactory;
  String get databaseName;
  String get databaseDescription;
  bool get storesAttachmentBlobs;
  Future<Uint8List> readSource(String path);
  Future<String> writeAttachment(int ownerId, String name, Uint8List bytes);
  Future<Uint8List> readAttachment(String path);
  Future<void> removeAttachments(Iterable<String> paths);
  Future<void> cleanupAttachments(Iterable<String> referencedPaths);
  Future<String> writeExport(int ownerId, Uint8List bytes);
}
