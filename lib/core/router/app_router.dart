import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/entries/entry_detail_screen.dart';
import '../../presentation/entries/entry_list_screen.dart';
import '../../presentation/main/main_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/tags/manage_tags_screen.dart';

GoRouter buildAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: _resolveInitialLocation(initialLocation),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          focusTranscriptionLanguage:
              state.uri.queryParameters['section'] == 'transcription-language',
        ),
      ),
      GoRoute(
        path: '/entries',
        builder: (context, state) => const EntryListScreen(),
      ),
      GoRoute(
        path: '/entry/:id',
        redirect: (context, state) {
          return _parseEntryId(state) == null ? '/entries' : null;
        },
        builder: (context, state) {
          final entryId = _parseEntryId(state);
          if (entryId == null) {
            return const EntryListScreen();
          }

          return EntryDetailScreen(entryId: entryId);
        },
      ),
      GoRoute(
        path: '/tags',
        builder: (context, state) => const ManageTagsScreen(),
      ),
    ],
  );
}

String _resolveInitialLocation(String? initialLocation) {
  if (initialLocation case final explicitLocation?) {
    return explicitLocation;
  }

  final platformRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (platformRoute.isNotEmpty && platformRoute != Navigator.defaultRouteName) {
    return platformRoute;
  }

  return '/';
}

int? _parseEntryId(GoRouterState state) {
  final rawEntryId = state.pathParameters['id']?.trim() ?? '';
  if (rawEntryId.isEmpty) {
    return null;
  }

  final parsedEntryId = int.tryParse(rawEntryId);
  if (parsedEntryId == null || parsedEntryId <= 0) {
    return null;
  }

  return parsedEntryId;
}
