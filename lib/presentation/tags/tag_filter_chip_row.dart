import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../entries/entry_list_controller.dart';
import '../theme/design_tokens.dart';

class TagFilterChipRow extends ConsumerWidget {
  const TagFilterChipRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(entryListAllTagsProvider);
    final selectedTagId = ref.watch(entryListTagFilterProvider);
    final l10n = AppLocalizations.of(context);

    final tags = tagsAsync.value ?? const [];
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WraitSpacingTokens.lg),
        itemCount: tags.length + 2, // "All" chip + tags + manage icon
        separatorBuilder: (_, _) =>
            const SizedBox(width: WraitSpacingTokens.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return FilterChip(
              key: const ValueKey('tagFilterAll'),
              label: Text(l10n.tagsFilterAll),
              selected: selectedTagId == null,
              onSelected: (_) {
                ref.read(entryListTagFilterProvider.notifier).clear();
              },
            );
          }
          if (index == tags.length + 1) {
            return IconButton(
              key: const ValueKey('tagFilterManage'),
              icon: const Icon(Icons.settings_outlined, size: 20),
              tooltip: l10n.tagsManage,
              onPressed: () => context.push('/tags'),
              visualDensity: VisualDensity.compact,
            );
          }
          final tag = tags[index - 1];
          return FilterChip(
            key: ValueKey('tagFilter-${tag.id}'),
            label: Text(tag.name),
            selected: selectedTagId == tag.id,
            onSelected: (_) {
              final notifier = ref.read(entryListTagFilterProvider.notifier);
              if (selectedTagId == tag.id) {
                notifier.clear();
              } else {
                notifier.select(tag.id);
              }
            },
          );
        },
      ),
    );
  }
}
