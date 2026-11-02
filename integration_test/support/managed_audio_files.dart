import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<String> managedDraftAudioPath(String name) async {
  final directory = await getTemporaryDirectory();
  return path.join(directory.path, name);
}

Future<File> writeManagedDraftAudioFile({
  required List<File> managedFiles,
  required String name,
  String contents = 'audio',
}) async {
  final file = File(await managedDraftAudioPath(name));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
  managedFiles.add(file);
  return file;
}

Future<void> cleanupManagedDraftAudioFiles(List<File> managedFiles) async {
  for (final file in managedFiles) {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to delete managed audio test file ${file.path}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
