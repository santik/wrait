import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/tag_repository.dart';
import 'entry_providers.dart';
import 'tag_repository_impl.dart';

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepositoryImpl(
    tagDao: ref.watch(localEntryDatabaseProvider).tagDao,
  ),
);
