import 'package:flutter/material.dart';

import '../theme/adaptive_button_size.dart';
import '../theme/design_tokens.dart';

class ShellPlaceholderScreen extends StatelessWidget {
  const ShellPlaceholderScreen({
    required this.title,
    required this.description,
    super.key,
    this.entryId,
  });

  final String title;
  final String description;
  final String? entryId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              Color.alphaBlend(
                colorScheme.primary.withValues(alpha: 0.06),
                colorScheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: WraitDesignTokens.screenPadding,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonSize = AdaptiveButtonSize.forWidth(
                      constraints.maxWidth,
                    );

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wrait',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(height: WraitSpacingTokens.sm),
                          Text(
                            title,
                            key: const ValueKey('shellTitle'),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: WraitSpacingTokens.sm),
                          Text(description, style: theme.textTheme.bodyLarge),
                          if (entryId case final id?)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: WraitSpacingTokens.md,
                              ),
                              child: _InfoBadge(
                                label: 'Entry ID',
                                value: id,
                                valueKey: const ValueKey('entryIdValue'),
                              ),
                            ),
                          const SizedBox(
                            height: WraitStatusLineTokens.gapAbove,
                          ),
                          _SectionCard(
                            title: 'Reserved layout',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _ReservedLine(
                                  label: 'Status',
                                  slotKey: ValueKey('statusLineSlot'),
                                  reservedHeight:
                                      WraitStatusLineTokens.reservedHeight,
                                ),
                                SizedBox(height: WraitQuotaLineTokens.gapBelow),
                                _ReservedLine(
                                  label: 'Quota',
                                  slotKey: ValueKey('quotaLineSlot'),
                                  reservedHeight:
                                      WraitQuotaLineTokens.reservedHeight,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: WraitSpacingTokens.lg),
                          _SectionCard(
                            title: 'Adaptive button preview',
                            child: Semantics(
                              container: true,
                              label:
                                  'Adaptive button preview. Computed size ${buttonSize.toStringAsFixed(0)} density-independent pixels.',
                              child: Center(
                                child: Column(
                                  children: [
                                    ExcludeSemantics(
                                      child: SizedBox(
                                        width:
                                            buttonSize *
                                            WraitButtonTokens.pulseScaleMax,
                                        height:
                                            buttonSize *
                                            WraitButtonTokens.pulseScaleMax,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.08),
                                          ),
                                          child: Center(
                                            child: Container(
                                              key: const ValueKey(
                                                'adaptiveButtonPreview',
                                              ),
                                              width: buttonSize,
                                              height: buttonSize,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colorScheme.primary,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.mic_none_rounded,
                                                size: buttonSize * 0.32,
                                                color: colorScheme.onPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: WraitSpacingTokens.md,
                                    ),
                                    Text(
                                      '${buttonSize.toStringAsFixed(0)} dp',
                                      key: const ValueKey(
                                        'adaptiveButtonSizeLabel',
                                      ),
                                      style: theme.textTheme.labelLarge,
                                    ),
                                    const SizedBox(
                                      height: WraitSpacingTokens.xs,
                                    ),
                                    Text(
                                      'Scales with width, then clamps to the approved min and max bounds.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.secondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: WraitDesignTokens.sectionPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.secondary,
              ),
            ),
            const SizedBox(height: WraitSpacingTokens.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReservedLine extends StatelessWidget {
  const _ReservedLine({
    required this.label,
    required this.slotKey,
    required this.reservedHeight,
  });

  final String label;
  final Key slotKey;
  final double reservedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: WraitSpacingTokens.sm),
        Semantics(
          container: true,
          label: '$label message area reserved for future status text.',
          child: Container(
            key: slotKey,
            height: reservedHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(WraitRadiusTokens.card),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.35),
              ),
              color: colorScheme.surface.withValues(alpha: 0.7),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: WraitSpacingTokens.md,
            ),
            child: Text('', style: theme.textTheme.bodyLarge),
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: '$label $value',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: WraitSpacingTokens.sm,
          vertical: WraitSpacingTokens.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(WraitRadiusTokens.small),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
        ),
        child: ExcludeSemantics(
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
            key: valueKey,
          ),
        ),
      ),
    );
  }
}
