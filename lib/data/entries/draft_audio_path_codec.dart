import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Retryable draft audio is stored relative to the current app temp directory.
// The lowercase app-cache:// scheme is an explicit app-owned marker so stored
// values are portable across iOS and Android app-container path changes
// without falling back to stale or ambiguous absolute paths.
class DraftAudioPathCodec {
  static const String cacheScheme = 'app-cache://';

  static Future<String> store(String audioPath) async {
    final trimmedPath = audioPath.trim();
    if (trimmedPath.isEmpty) {
      throw ArgumentError.value(audioPath, 'audioPath', 'must not be blank');
    }

    final normalizedAudioPath = path.normalize(trimmedPath);
    if (!path.isAbsolute(normalizedAudioPath)) {
      throw ArgumentError.value(
        audioPath,
        'audioPath',
        'must be an absolute path inside the app temporary directory',
      );
    }

    final normalizedCachePath = await _cacheRootPath();

    if (!_isWithinDirectory(
      directoryPath: normalizedCachePath,
      filePath: normalizedAudioPath,
    )) {
      throw ArgumentError.value(
        audioPath,
        'audioPath',
        'must be located inside the app temporary directory',
      );
    }

    final relativePath = _validateRelativeReference(
      path.relative(normalizedAudioPath, from: normalizedCachePath),
    );
    return '$cacheScheme$relativePath';
  }

  static Future<String> resolve(String storedAudioPath) async {
    final trimmedPath = storedAudioPath.trim();
    if (trimmedPath.isEmpty) {
      throw const FormatException('Stored draft audio path must not be blank.');
    }

    if (!trimmedPath.startsWith(cacheScheme)) {
      throw FormatException(
        'Stored draft audio path must use the lowercase $cacheScheme scheme.',
        storedAudioPath,
      );
    }

    final relativePath = _validateRelativeReference(
      trimmedPath.substring(cacheScheme.length),
    );
    final normalizedCachePath = await _cacheRootPath();
    final resolvedPath = path.normalize(
      path.join(normalizedCachePath, relativePath),
    );

    if (!_isWithinDirectory(
      directoryPath: normalizedCachePath,
      filePath: resolvedPath,
    )) {
      throw FormatException(
        'Stored draft audio path resolves outside the app temporary directory.',
        storedAudioPath,
      );
    }

    return resolvedPath;
  }

  static Future<String> _cacheRootPath() async {
    final cacheDirectory = await getTemporaryDirectory();
    return path.normalize(cacheDirectory.path);
  }

  static String _validateRelativeReference(String relativePath) {
    final trimmedPath = relativePath.trim();
    if (trimmedPath.isEmpty) {
      throw const FormatException(
        'Stored draft audio reference payload must not be blank.',
      );
    }

    final normalizedPath = path.normalize(trimmedPath);
    if (normalizedPath.isEmpty || normalizedPath == '.') {
      throw FormatException(
        'Stored draft audio reference must identify a file.',
        relativePath,
      );
    }

    if (path.isAbsolute(normalizedPath)) {
      throw FormatException(
        'Stored draft audio reference must be relative to the app temporary directory.',
        relativePath,
      );
    }

    if (path.split(normalizedPath).any((segment) => segment == '..')) {
      throw FormatException(
        'Stored draft audio reference must not traverse outside the app temporary directory.',
        relativePath,
      );
    }

    return normalizedPath;
  }

  static bool _isWithinDirectory({
    required String directoryPath,
    required String filePath,
  }) {
    return path.equals(path.dirname(filePath), directoryPath) ||
        path.isWithin(directoryPath, filePath);
  }
}
