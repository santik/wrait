import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../domain/model/entry.dart';
import '../../l10n/app_localizations.dart';
import '../theme/design_tokens.dart';
import '../theme/wrait_colors.dart';
import 'entry_list_formatters.dart';

class EntryListRow extends StatefulWidget {
  const EntryListRow({
    required this.entry,
    required this.onTap,
    required this.onDeleteRequested,
    super.key,
    this.onRevealHaptic,
  });

  final Entry entry;
  final ValueChanged<int> onTap;
  final Future<void> Function(int entryId) onDeleteRequested;
  final Future<void> Function()? onRevealHaptic;

  @override
  State<EntryListRow> createState() => _EntryListRowState();
}

class _EntryListRowState extends State<EntryListRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  Completer<void>? _revealFlowCompleter;

  double get _revealWidth => WraitGestureTokens.swipeDeleteReveal;
  double get _revealOffset => _revealController.value * _revealWidth;
  bool get _isRevealFlowActive => _revealFlowCompleter != null;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: WraitAnimationTokens.swipeDeleteFling,
      value: 0,
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final semanticColors = theme.extension<WraitSemanticColors>()!;
    final timestamp = formatEntryListTimestamp(
      createdAt: widget.entry.createdAt,
      locale: Localizations.localeOf(context),
    );
    final isAudioDraft = entryListIsAudioOnlyDraft(widget.entry);
    final previewText = entryListPreviewText(widget.entry, l10n);
    final languageLabel = entryListLanguageLabel(widget.entry.language);
    final deleteAction = CustomSemanticsAction(
      label: l10n.entryListDeleteActionLabel,
    );

    return Semantics(
      button: true,
      enabled: !isAudioDraft,
      label: l10n.entryListRowSemanticsLabel(
        timestamp.displayLabel,
        languageLabel,
      ),
      hint: isAudioDraft
          ? l10n.entryListRowSwipeHint
          : l10n.entryListRowOpenHint,
      value: isAudioDraft
          ? l10n.entryListRowAudioDraftValue(
              l10n.entryListAudioDraftStateDescription,
            )
          : (widget.entry.type == EntryType.draft
                ? l10n.entryListRowDraftValue
                : null),
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        deleteAction: () {
          unawaited(_handleRevealFlow());
        },
      },
      child: AnimatedBuilder(
        animation: _revealController,
        builder: (context, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: ValueKey('entryRowReveal-${widget.entry.id}'),
                    width: _revealWidth,
                    decoration: BoxDecoration(
                      color: semanticColors.error,
                      borderRadius: BorderRadius.circular(
                        WraitRadiusTokens.card,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: semanticColors.onSemantic,
                    ),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(_revealOffset, 0),
                child: GestureDetector(
                  onHorizontalDragUpdate: _isRevealFlowActive
                      ? null
                      : _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _isRevealFlowActive
                      ? null
                      : _handleHorizontalDragEnd,
                  child: Material(
                    key: ValueKey('entryCard-${widget.entry.id}'),
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(WraitRadiusTokens.card),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        WraitRadiusTokens.card,
                      ),
                      onTap: _isRevealFlowActive
                          ? null
                          : isAudioDraft
                          ? null
                          : () => widget.onTap(widget.entry.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: WraitSpacingTokens.md,
                          vertical: WraitSpacingTokens.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    timestamp.displayLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                                if (widget.entry.type == EntryType.draft)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: WraitSpacingTokens.sm,
                                      vertical: WraitSpacingTokens.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: semanticColors.warningContainer,
                                      borderRadius: BorderRadius.circular(
                                        WraitRadiusTokens.small,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.entryListRowDraftBadge,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: semanticColors.warning,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: WraitSpacingTokens.sm),
                            Text(
                              previewText,
                              key: ValueKey('entryPreview-${widget.entry.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: WraitSpacingTokens.xs),
                            Text(
                              languageLabel,
                              key: ValueKey('entryLanguage-${widget.entry.id}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            if (widget.entry.tags.isNotEmpty) ...[
                              const SizedBox(height: WraitSpacingTokens.xs),
                              Wrap(
                                spacing: WraitSpacingTokens.xs,
                                runSpacing: WraitSpacingTokens.xs,
                                children: widget.entry.tags
                                    .map(
                                      (tag) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: WraitSpacingTokens.sm,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            WraitRadiusTokens.small,
                                          ),
                                        ),
                                        child: Text(
                                          tag.name,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isRevealFlowActive) {
      return;
    }

    final nextValue =
        _revealController.value + (details.delta.dx / _revealWidth);
    _revealController.value = nextValue.clamp(0.0, 1.0);
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails details) async {
    if (_isRevealFlowActive) {
      return;
    }

    if (_revealController.value >= 0.5) {
      await _handleRevealFlow();
      return;
    }

    await _revealController.animateTo(0);
  }

  Future<void> _handleRevealFlow() async {
    final existingOperation = _revealFlowCompleter;
    if (existingOperation != null) {
      return existingOperation.future;
    }

    final completer = Completer<void>();
    setState(() {
      _revealFlowCompleter = completer;
    });

    try {
      await _revealController.animateTo(1);
      unawaited(widget.onRevealHaptic?.call() ?? HapticFeedback.lightImpact());
      await widget.onDeleteRequested(widget.entry.id);
    } finally {
      if (mounted) {
        await _revealController.animateTo(0);
        setState(() {
          _revealFlowCompleter = null;
        });
      } else {
        _revealFlowCompleter = null;
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }
}
