import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth/app_lock_providers.dart';
import '../../data/preferences/app_lock_preference_controller.dart';
import '../../l10n/app_localizations.dart';
import 'app_lock_controller.dart';
import 'app_lock_screen.dart';
import 'app_lock_test_keys.dart';

const double _lockedContentBlurSigma = 20;

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  int _foregroundExitGeneration = 0;
  int? _enableStartExitGeneration;
  bool _foregroundReadyScheduled = false;
  late AppLifecycleState _lifecycleState;

  bool _shouldLockForLifecycleExit(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
      AppLifecycleState.inactive || AppLifecycleState.resumed => false,
    };
  }

  @override
  void initState() {
    super.initState();
    _lifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _scheduleForegroundReady();
  }

  void _scheduleForegroundReady() {
    if (_foregroundReadyScheduled) {
      return;
    }
    _foregroundReadyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foregroundReadyScheduled = false;
      if (!mounted) {
        return;
      }
      unawaited(_handleForegroundReady());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (_shouldLockForLifecycleExit(state)) {
      _foregroundExitGeneration += 1;
    }

    if (!ref.read(appLockEnabledProvider)) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _scheduleForegroundReady();
      return;
    }

    if (_shouldLockForLifecycleExit(state)) {
      ref.read(appLockControllerProvider.notifier).lockForForegroundExit();
    }
  }

  Future<void> _handleForegroundReady() async {
    // Prompt whenever the app is in the foreground, not only when strictly
    // `resumed`. On iOS a cold launch can settle in `inactive` (a foreground,
    // visible state — same class `_shouldLockForLifecycleExit` already treats as
    // not-backgrounded) without ever emitting a `resumed` event, which would
    // otherwise leave the user stranded on the lock screen with no prompt.
    if (!mounted || _shouldLockForLifecycleExit(_lifecycleState)) {
      return;
    }
    if (!ref.read(appLockBuildEnabledProvider)) {
      return;
    }
    final preference = ref.read(appLockPreferenceControllerProvider);
    if (!preference.isReady || !preference.enabled) {
      return;
    }
    await ref.read(appLockControllerProvider.notifier).onForegroundReady();
  }

  void _handlePreferenceChange(
    AppLockPreferenceState? previous,
    AppLockPreferenceState next,
  ) {
    final beganEnable =
        next.isSaving &&
        next.requestedValue == true &&
        !(previous?.isSaving ?? false);
    if (beganEnable) {
      _enableStartExitGeneration = _foregroundExitGeneration;
    }

    if (!next.isReady) {
      return;
    }

    final controller = ref.read(appLockControllerProvider.notifier);
    if (previous == null || !previous.isReady) {
      if (next.enabled) {
        _scheduleForegroundReady();
      } else {
        controller.disableSession();
      }
      return;
    }
    if (previous.enabled == next.enabled) {
      return;
    }

    if (!next.enabled) {
      _enableStartExitGeneration = null;
      controller.disableSession();
      return;
    }

    final shouldLock =
        _enableStartExitGeneration != null &&
        _foregroundExitGeneration > _enableStartExitGeneration!;
    _enableStartExitGeneration = null;
    controller.startEnabledSession(shouldLock: shouldLock);
    if (shouldLock && _lifecycleState == AppLifecycleState.resumed) {
      _scheduleForegroundReady();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buildAllowsLock = ref.watch(appLockBuildEnabledProvider);
    final preference = buildAllowsLock
        ? ref.watch(appLockPreferenceControllerProvider)
        : const AppLockPreferenceState(
            status: AppLockPreferenceStatus.ready,
            enabled: false,
          );
    if (buildAllowsLock) {
      ref.listen<AppLockPreferenceState>(appLockPreferenceControllerProvider, (
        previous,
        next,
      ) {
        _handlePreferenceChange(previous, next);
      });
    }

    final isEnabled = ref.watch(appLockEnabledProvider);
    if (!isEnabled) {
      return widget.child;
    }

    if (!preference.isReady) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: true,
            child: ExcludeSemantics(child: IgnorePointer(child: widget.child)),
          ),
          _AppLockPreferenceCover(state: preference),
        ],
      );
    }

    final state = ref.watch(appLockControllerProvider);
    final child = state.isLocked
        ? ExcludeSemantics(
            child: IgnorePointer(
              child: ImageFiltered(
                key: appLockBlurKey,
                imageFilter: ImageFilter.blur(
                  sigmaX: _lockedContentBlurSigma,
                  sigmaY: _lockedContentBlurSigma,
                ),
                child: widget.child,
              ),
            ),
          )
        : widget.child;

    return Stack(
      children: [
        child,
        if (state.isLocked)
          Positioned.fill(
            child: AppLockScreen(
              key: appLockOverlayKey,
              state: state,
              onUnlock: () {
                unawaited(
                  ref.read(appLockControllerProvider.notifier).unlock(),
                );
              },
              onOpenSettings: () {
                unawaited(
                  ref
                      .read(appLockControllerProvider.notifier)
                      .openSecuritySettings(),
                );
              },
              onContinueWithoutLock: () {
                ref
                    .read(appLockControllerProvider.notifier)
                    .continueWithoutLock();
              },
            ),
          ),
      ],
    );
  }
}

class _AppLockPreferenceCover extends ConsumerWidget {
  const _AppLockPreferenceCover({required this.state});

  final AppLockPreferenceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failed = state.status == AppLockPreferenceStatus.loadFailure;
    return ColoredBox(
      key: appLockPreferenceCoverKey,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!failed) const CircularProgressIndicator.adaptive(),
                if (!failed) const SizedBox(height: 16),
                Text(
                  failed
                      ? l10n.appLockPreferenceLoadFailed
                      : l10n.appLockPreferenceLoading,
                  textAlign: TextAlign.center,
                ),
                if (failed) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    key: appLockPreferenceRetryKey,
                    onPressed: () {
                      unawaited(
                        ref
                            .read(appLockPreferenceControllerProvider.notifier)
                            .retryLoad(),
                      );
                    },
                    child: Text(l10n.appLockPreferenceRetry),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
