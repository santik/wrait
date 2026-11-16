import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../tags/tag_filter_chip_row.dart';
import '../theme/design_tokens.dart';
import 'entry_delete_confirmation.dart';
import 'entry_list_controller.dart';
import 'entry_list_row.dart';
import '../../domain/model/entry.dart';

class EntryListScreen extends ConsumerStatefulWidget {
  const EntryListScreen({super.key});

  @override
  ConsumerState<EntryListScreen> createState() => _EntryListScreenState();
}

class _EntryListScreenState extends ConsumerState<EntryListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = ref.watch(entryListEntriesProvider).value ?? const [];
    final filteredEntries = ref.watch(entryListFilteredEntriesProvider);
    final searchQuery = ref.watch(entryListSearchQueryProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final canPopRoute = Navigator.of(context).canPop();
    final hasActiveQuery = searchQuery.trim().isNotEmpty;

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _navigateBack(context);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: WraitSpacingTokens.lg,
                    left: WraitSpacingTokens.xs,
                    right: WraitSpacingTokens.xs,
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        button: true,
                        label: l10n.entryListBackSemanticsLabel,
                        child: IconButton(
                          key: const ValueKey('entryListBackButton'),
                          onPressed: () => _navigateBack(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: l10n.entryListBack,
                        ),
                      ),
                      const SizedBox(width: WraitSpacingTokens.xs),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('entryListSearchField'),
                          controller: _searchController,
                          autofocus: false,
                          onChanged: (query) {
                            ref
                                .read(entryListSearchQueryProvider.notifier)
                                .update(query);
                          },
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: l10n.entryListSearchLabel,
                            hintText: l10n.entryListSearchLabel,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchQuery.isEmpty
                                ? null
                                : Semantics(
                                    button: true,
                                    label: l10n.entryListClearSearch,
                                    child: IconButton(
                                      key: const ValueKey(
                                        'entryListClearSearchButton',
                                      ),
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: l10n.entryListClearSearch,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: WraitSpacingTokens.xs),
                      Semantics(
                        button: true,
                        label: l10n.entryListCalendarSemanticsLabel,
                        child: IconButton(
                          key: const ValueKey('entryListCalendarButton'),
                          onPressed: () => context.push('/calendar'),
                          icon: const Icon(Icons.calendar_month_outlined),
                          tooltip: l10n.entryListCalendar,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WraitSpacingTokens.sm),
                const TagFilterChipRow(),
                const SizedBox(height: WraitSpacingTokens.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      WraitSpacingTokens.lg,
                      0,
                      WraitSpacingTokens.lg,
                      WraitSpacingTokens.lg,
                    ),
                    child: _buildEntriesContent(
                      context,
                      theme: theme,
                      allEntries: allEntries,
                      filteredEntries: filteredEntries,
                      hasActiveQuery: hasActiveQuery,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntriesContent(
    BuildContext context, {
    required ThemeData theme,
    required List<Entry> allEntries,
    required List<Entry> filteredEntries,
    required bool hasActiveQuery,
  }) {
    final l10n = AppLocalizations.of(context);
    final selectedTagId = ref.watch(entryListTagFilterProvider);
    if (allEntries.isEmpty) {
      return _emptyState(
        theme: theme,
        text: l10n.entryListEmpty,
        textKey: const ValueKey('entryListEmptyState'),
      );
    }

    if (hasActiveQuery && filteredEntries.isEmpty) {
      return _emptyState(
        theme: theme,
        text: l10n.entryListNoResults,
        textKey: const ValueKey('entryListNoSearchResults'),
        action: TextButton(
          key: const ValueKey('entryListNoResultsClearButton'),
          onPressed: _clearSearch,
          child: Text(l10n.entryListClearSearch),
        ),
      );
    }

    if (selectedTagId != null && filteredEntries.isEmpty) {
      return _emptyState(
        theme: theme,
        text: l10n.tagsNoEntriesWithTag,
        textKey: const ValueKey('entryListNoTagResults'),
        action: TextButton(
          key: const ValueKey('entryListNoTagResultsClearButton'),
          onPressed: () =>
              ref.read(entryListTagFilterProvider.notifier).clear(),
          child: Text(l10n.tagsFilterClear),
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey('entryListView'),
      padding: const EdgeInsets.only(bottom: WraitSpacingTokens.md),
      itemCount: filteredEntries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: WraitSpacingTokens.sm),
      itemBuilder: (context, index) {
        final entry = filteredEntries[index];
        return EntryListRow(
          key: ValueKey('entryRow-${entry.id}'),
          entry: entry,
          onTap: (entryId) => context.push('/entry/$entryId'),
          onDeleteRequested: (entryId) => _confirmDelete(context, entryId),
        );
      },
    );
  }

  Widget _emptyState({
    required ThemeData theme,
    required String text,
    required ValueKey<String> textKey,
    Widget? action,
  }) {
    final label = Text(
      text,
      key: textKey,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
      ),
      textAlign: TextAlign.center,
    );

    return Center(
      child: action == null
          ? label
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                label,
                const SizedBox(height: WraitSpacingTokens.sm),
                action,
              ],
            ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(entryListSearchQueryProvider.notifier).clear();
  }

  void _navigateBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go('/');
  }

  Future<void> _confirmDelete(BuildContext context, int entryId) async {
    final shouldDelete = await showEntryDeleteConfirmationDialog(context);
    if (!shouldDelete) {
      return;
    }

    await ref.read(entryListControllerProvider.notifier).deleteEntry(entryId);
  }
}
