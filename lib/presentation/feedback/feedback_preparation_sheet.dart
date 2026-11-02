import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../presentation/theme/design_tokens.dart';
import 'feedback_model.dart';

const feedbackContactFieldKey = ValueKey<String>('feedbackContactField');
const feedbackMessageFieldKey = ValueKey<String>('feedbackMessageField');
const feedbackPrivacyCopyKey = ValueKey<String>('feedbackPrivacyCopy');
const feedbackSubmitButtonKey = ValueKey<String>('feedbackSubmitButton');
const feedbackPreparationPanelKey = ValueKey<String>(
  'feedbackPreparationPanel',
);

Future<FeedbackDraft?> showFeedbackPreparationDialog(
  BuildContext context, {
  FeedbackDraft? initialDraft,
}) {
  final l10n = AppLocalizations.of(context);
  return showGeneralDialog<FeedbackDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l10n.feedbackDismissLabel,
    pageBuilder: (context, animation, secondaryAnimation) {
      final mediaQuery = MediaQuery.of(context);
      final maxHeight = (mediaQuery.size.height - mediaQuery.padding.top)
          .clamp(0.0, double.infinity)
          .toDouble();

      return _FeedbackPreparationDialog(
        initialDraft: initialDraft,
        maxHeight: maxHeight,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation);
      return SlideTransition(position: offset, child: child);
    },
  );
}

class _FeedbackPreparationDialog extends StatefulWidget {
  const _FeedbackPreparationDialog({
    required this.initialDraft,
    required this.maxHeight,
  });

  final FeedbackDraft? initialDraft;
  final double maxHeight;

  @override
  State<_FeedbackPreparationDialog> createState() =>
      _FeedbackPreparationDialogState();
}

class _FeedbackPreparationDialogState
    extends State<_FeedbackPreparationDialog> {
  final _panelKey = GlobalKey();
  late final double _maxHeight;
  double? _initialPanelHeight;

  @override
  void initState() {
    super.initState();
    _maxHeight = widget.maxHeight;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialPanelHeight != null) {
        return;
      }

      final renderObject = _panelKey.currentContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        setState(() => _initialPanelHeight = renderObject.size.height);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardAvailableHeight = (_maxHeight - mediaQuery.viewInsets.bottom)
        .clamp(0.0, double.infinity)
        .toDouble();
    final preparationSheet = FeedbackPreparationSheet(
      initialDraft: widget.initialDraft,
      keyboardInset: _initialPanelHeight == null
          ? 0
          : mediaQuery.viewInsets.bottom,
      keyboardAvailableHeight: keyboardAvailableHeight,
    );
    final panelHeight = _initialPanelHeight;
    final panelContent = panelHeight == null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _maxHeight),
            child: preparationSheet,
          )
        : SizedBox(height: panelHeight, child: preparationSheet);

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: double.infinity,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: KeyedSubtree(
                key: feedbackPreparationPanelKey,
                child: Material(
                  key: _panelKey,
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(WraitRadiusTokens.card),
                  ),
                  child: panelContent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeedbackPreparationSheet extends StatefulWidget {
  const FeedbackPreparationSheet({
    this.initialDraft,
    this.keyboardInset = 0,
    this.keyboardAvailableHeight,
    super.key,
  });

  final FeedbackDraft? initialDraft;
  final double keyboardInset;
  final double? keyboardAvailableHeight;

  @override
  State<FeedbackPreparationSheet> createState() =>
      _FeedbackPreparationSheetState();
}

class _FeedbackPreparationSheetState extends State<FeedbackPreparationSheet> {
  late final TextEditingController _contactController;
  late final TextEditingController _messageController;
  late final FocusNode _contactFocusNode;
  late final FocusNode _messageFocusNode;
  FeedbackCategory? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.initialDraft?.category;
    _contactController = TextEditingController(
      text: widget.initialDraft?.replyContact ?? '',
    );
    _contactFocusNode = FocusNode();
    _messageController = TextEditingController(
      text: widget.initialDraft?.message ?? '',
    )..addListener(_handleMessageChanged);
    _messageFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageChanged);
    _messageController.dispose();
    _contactController.dispose();
    _messageFocusNode.dispose();
    _contactFocusNode.dispose();
    super.dispose();
  }

  void _handleMessageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final category = _category;
    final canSubmit =
        category != null && _messageController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        WraitSpacingTokens.lg,
        WraitSpacingTokens.md,
        WraitSpacingTokens.lg,
        WraitSpacingTokens.xs,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollView = SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.feedbackTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: WraitSpacingTokens.sm),
                Text(l10n.feedbackPrompt, style: theme.textTheme.bodyMedium),
                const SizedBox(height: WraitSpacingTokens.sm),
                Wrap(
                  spacing: WraitSpacingTokens.sm,
                  runSpacing: WraitSpacingTokens.sm,
                  children: [
                    for (final option in FeedbackCategory.values)
                      ChoiceChip(
                        label: Text(option.localizedLabel(l10n)),
                        selected: category == option,
                        onSelected: (_) => setState(() => _category = option),
                      ),
                  ],
                ),
                const SizedBox(height: WraitSpacingTokens.sm),
                TextField(
                  key: feedbackContactFieldKey,
                  controller: _contactController,
                  focusNode: _contactFocusNode,
                  maxLines: 1,
                  scrollPadding: EdgeInsets.zero,
                  decoration: InputDecoration(
                    labelText: l10n.feedbackContactLabel,
                    hintText: l10n.feedbackContactHint,
                  ),
                ),
                const SizedBox(height: WraitSpacingTokens.sm),
                TextField(
                  key: feedbackMessageFieldKey,
                  controller: _messageController,
                  focusNode: _messageFocusNode,
                  keyboardType: TextInputType.multiline,
                  minLines: 3,
                  maxLines: 10,
                  maxLength: 2048,
                  scrollPadding: EdgeInsets.zero,
                  decoration: InputDecoration(
                    labelText: l10n.feedbackMessageLabel,
                    hintText: l10n.feedbackMessageHint,
                  ),
                ),
                const SizedBox(height: WraitSpacingTokens.md),
                Text(
                  l10n.feedbackPrivacyCopy,
                  key: feedbackPrivacyCopyKey,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: WraitSpacingTokens.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.feedbackCancel),
                    ),
                    const SizedBox(width: WraitSpacingTokens.sm),
                    FilledButton(
                      key: feedbackSubmitButtonKey,
                      onPressed: canSubmit
                          ? () {
                              Navigator.of(context).pop(
                                FeedbackDraft(
                                  category: category,
                                  replyContact: _contactController.text,
                                  message: _messageController.text.trim(),
                                ),
                              );
                            }
                          : null,
                      child: Text(l10n.feedbackSubmit),
                    ),
                  ],
                ),
              ],
            ),
          );

          final keyboardAvailableHeight = widget.keyboardAvailableHeight;
          final visibleHeight =
              widget.keyboardInset > 0 &&
                  keyboardAvailableHeight != null &&
                  constraints.maxHeight.isFinite
              ? () {
                  final availableContentHeight =
                      (keyboardAvailableHeight -
                              WraitSpacingTokens.md -
                              WraitSpacingTokens.xs)
                          .clamp(0.0, double.infinity)
                          .toDouble();
                  return availableContentHeight < constraints.maxHeight
                      ? availableContentHeight
                      : null;
                }()
              : null;
          // Keep the wrapper stable across inset changes so the focused
          // EditableText is not detached when the keyboard opens.
          return Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: SizedBox(height: visibleHeight, child: scrollView),
          );
        },
      ),
    );
  }
}
