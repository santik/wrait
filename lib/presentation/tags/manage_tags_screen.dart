import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/model/tag.dart';
import '../../domain/repository/tag_repository.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import 'manage_tags_controller.dart';

class ManageTagsScreen extends ConsumerStatefulWidget {
  const ManageTagsScreen({super.key});

  @override
  ConsumerState<ManageTagsScreen> createState() => _ManageTagsScreenState();
}

class _ManageTagsScreenState extends ConsumerState<ManageTagsScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(manageTagsAllTagsProvider);
    final countsAsync = ref.watch(manageTagsCountsProvider);
    final controllerState = ref.watch(manageTagsControllerProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final tags = tagsAsync.value ?? const <Tag>[];
    final counts = countsAsync.value ?? const <int, int>{};
    final isAtLimit = tags.length >= TagRepository.maxTags;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: WraitDesignTokens.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('manageTagsBackButton'),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/entries');
                      }
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: l10n.entryListBack,
                  ),
                  const SizedBox(width: WraitSpacingTokens.sm),
                  Text(l10n.tagsTitle, style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: WraitSpacingTokens.md),

              // Add tag field
              if (!isAtLimit)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('manageTagsNameField'),
                        controller: _nameController,
                        maxLength: TagRepository.maxTagNameLength,
                        decoration: InputDecoration(
                          hintText: l10n.tagsAddHint,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _handleCreate(),
                      ),
                    ),
                    const SizedBox(width: WraitSpacingTokens.sm),
                    IconButton(
                      key: const ValueKey('manageTagsAddButton'),
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _handleCreate,
                      tooltip: l10n.tagsAdd,
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: WraitSpacingTokens.sm),
                  child: Text(
                    l10n.tagsLimitReached(TagRepository.maxTags),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),

              // Error message
              if (controllerState.error != null) ...[
                const SizedBox(height: WraitSpacingTokens.xs),
                Text(
                  controllerState.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],

              const SizedBox(height: WraitSpacingTokens.md),

              // Tags list
              Expanded(
                child: tags.isEmpty
                    ? Center(
                        child: Text(
                          l10n.tagsEmpty,
                          key: const ValueKey('manageTagsEmptyState'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: tags.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tag = tags[index];
                          final count = counts[tag.id] ?? 0;
                          return ListTile(
                            key: ValueKey('manageTag-${tag.id}'),
                            title: Text(tag.name),
                            subtitle: Text(l10n.tagsEntryCount(count)),
                            trailing: IconButton(
                              key: ValueKey('manageTagDelete-${tag.id}'),
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _confirmDelete(context, tag),
                              tooltip: l10n.tagsDeleteConfirm,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final success = await ref
        .read(manageTagsControllerProvider.notifier)
        .createTag(name);
    if (success) {
      _nameController.clear();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Tag tag) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.tagsDeleteConfirmTitle),
        content: Text(l10n.tagsDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.tagsDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.tagsDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(manageTagsControllerProvider.notifier).deleteTag(tag.id);
    }
  }
}
