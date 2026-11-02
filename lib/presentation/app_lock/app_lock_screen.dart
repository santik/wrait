import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_lock_controller.dart';
import 'app_lock_test_keys.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({
    required this.state,
    required this.onUnlock,
    required this.onOpenSettings,
    required this.onContinueWithoutLock,
    super.key,
  });

  final AppLockState state;
  final VoidCallback onUnlock;
  final VoidCallback onOpenSettings;
  final VoidCallback onContinueWithoutLock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.84),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Semantics(
              container: true,
              label: l10n.appLockSemanticsLabel,
              hint: _semanticsHintFor(state, l10n),
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.appLockTitle,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _messageFor(state.status, l10n),
                    key: appLockMessageKey,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: appLockUnlockButtonKey,
                    onPressed: state.isPromptPending ? null : onUnlock,
                    child: Text(l10n.appLockUnlock),
                  ),
                  if (state.isPromptPending) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      key: appLockProgressKey,
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                  if (state.canOpenSettings) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: appLockSettingsButtonKey,
                      onPressed: onOpenSettings,
                      child: Text(l10n.appLockOpenSettings),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appLockSettingsWarning,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: appLockBypassButtonKey,
                      onPressed: onContinueWithoutLock,
                      child: Text(l10n.appLockContinueWithout),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _messageFor(AppLockStatus status, AppLocalizations l10n) {
    return switch (status) {
      AppLockStatus.canceled => l10n.appLockStillLocked,
      AppLockStatus.noSecurity => l10n.appLockSetUpSecurity,
      AppLockStatus.temporarilyUnavailable ||
      AppLockStatus.unavailable => l10n.appLockUnavailableTryAgain,
      _ => l10n.appLockUnlockToContinue,
    };
  }

  String _semanticsHintFor(AppLockState state, AppLocalizations l10n) {
    if (state.canOpenSettings) {
      return l10n.appLockSemanticsHintSettings;
    }

    if (state.isPromptPending) {
      return l10n.appLockSemanticsHintAuthInProgress;
    }

    return l10n.appLockSemanticsHintUnlock;
  }
}
