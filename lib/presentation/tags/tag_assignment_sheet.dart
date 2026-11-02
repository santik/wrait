import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repository/tag_repository.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import 'tag_assignment_controller.dart';

class TagAssignmentSheet extends ConsumerStatefulWidget {
  const TagAssignmentSheet({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<TagAssignmentSheet> createState() => _TagAssignmentSheetState();
}

class _TagAssignmentSheetState extends ConsumerState<TagAssignmentSheet> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignState = ref.watch(
      tagAssignmentControllerProvider(widget.entryId),
    );
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: WraitSpacingTokens.lg,
        right: WraitSpacingTokens.lg,
        top: WraitSpacingTokens.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            WraitSpacingTokens.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(l10n.tagsAssign, style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.tagsAssignDone),
              ),
            ],
          ),
          const SizedBox(height: WraitSpacingTokens.md),
          // Create tag field
          if (assignState.allTags.length < TagRepository.maxTags)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: TagRepository.maxTagNameLength,
                    decoration: InputDecoration(
                      hintText: l10n.tagsAddHint,
                      counterText: '',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _createTag(),
                  ),
                ),
                const SizedBox(width: WraitSpacingTokens.sm),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _createTag,
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
          if (assignState.error != null) ...[
            const SizedBox(height: WraitSpacingTokens.xs),
            Text(
              assignState.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: WraitSpacingTokens.sm),
          if (assignState.allTags.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: WraitSpacingTokens.lg,
              ),
              child: Text(
                l10n.tagsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Wrap(
              spacing: WraitSpacingTokens.sm,
              runSpacing: WraitSpacingTokens.sm,
              children: assignState.allTags.map((tag) {
                final isSelected = assignState.selectedTagIds.contains(tag.id);
                return FilterChip(
                  key: ValueKey('assignTag-${tag.id}'),
                  label: Text(tag.name),
                  selected: isSelected,
                  onSelected: (_) {
                    ref
                        .read(
                          tagAssignmentControllerProvider(widget.entryId)
                              .notifier,
                        )
                        .toggleTag(tag.id);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _createTag() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ref
        .read(tagAssignmentControllerProvider(widget.entryId).notifier)
        .createAndAssignTag(name);
    _nameController.clear();
  }
}
