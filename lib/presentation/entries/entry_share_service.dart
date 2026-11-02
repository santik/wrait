import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class EntryShareService {
  Future<void> shareText(String text);
}

final entryShareServiceProvider = Provider<EntryShareService>((ref) {
  return const PlatformEntryShareService();
});

class PlatformEntryShareService implements EntryShareService {
  const PlatformEntryShareService();

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
