import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../data/auth/app_lock_providers.dart';
import '../../data/api/backend_providers.dart';
import '../../data/audio/audio_recording_providers.dart';
import '../../data/display/display_awake_service.dart';
import '../../data/preferences/preferences_providers.dart';
import '../../data/preferences/transcription_language_controller.dart';
import '../../data/transcription/transcription_providers.dart';
import '../../domain/model/supported_language.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_controller.dart';
import '../feedback/feedback_providers.dart';
import '../feedback/feedback_service.dart';
import '../theme/design_tokens.dart';
import 'button_area.dart';
import 'main_recording_controller.dart';
import 'main_screen_stats.dart';
import 'main_screen_status.dart';
import 'main_screen_test_keys.dart';
import 'recording_display_awake_coordinator.dart';
import 'recording_state.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  late final RecordingDisplayAwakeCoordinator _displayAwakeCoordinator;
  final GlobalKey _buttonAreaKey = GlobalKey();
  Timer? _savedAutoClearTimer;
  Timer? _countdownTicker;
  final ValueNotifier<double?> _countdownProgress = ValueNotifier<double?>(
    null,
  );
  bool? _storedHasEverRecorded;
  bool _hasRecordedThisSession = false;
  int _statusLineGeneration = 0;
  int _savedAutoClearGeneration = 0;
  bool _pulseMeasurementPending = false;
  double? _measuredPulseDiameter;
  Size? _lastPulseViewportSize;
  EdgeInsets? _lastPulseViewPadding;
  bool _feedbackInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayAwakeCoordinator = RecordingDisplayAwakeCoordinator(
      service: ref.read(displayAwakeServiceProvider),
      recordingState: ref.read(mainRecordingControllerProvider).recordingState,
      lifecycleState:
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.inactive,
      appLockState: _readEffectiveAppLockState(),
    );
    _loadHasEverRecorded();
  }

  @override
  void dispose() {
    _displayAwakeCoordinator.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _savedAutoClearTimer?.cancel();
    _countdownTicker?.cancel();
    _countdownProgress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _displayAwakeCoordinator.updateLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      return;
    }

    unawaited(
      ref.read(mainRecordingControllerProvider.notifier).onAppResumed(),
    );
  }

  Future<void> _loadHasEverRecorded() async {
    try {
      final hasEverRecorded = await ref
          .read(preferencesRepositoryProvider)
          .getHasEverRecorded();
      if (!mounted) {
        return;
      }
      setState(() {
        _storedHasEverRecorded = hasEverRecorded;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load hasEverRecorded for MainScreen.',
        name: 'MainScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _storedHasEverRecorded = false;
      });
    }
  }

  Future<void> _openFeedback() async {
    if (_feedbackInFlight) {
      return;
    }

    setState(() {
      _feedbackInFlight = true;
    });

    final result = await ref
        .read(feedbackServiceProvider)
        .open(context, appArea: 'main');

    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackInFlight = false;
    });

    final l10n = AppLocalizations.of(context);
    final message = switch (result.status) {
      FeedbackLaunchStatus.submitted => l10n.mainFeedbackSent,
      FeedbackLaunchStatus.unavailable => l10n.mainFeedbackUnavailable,
      FeedbackLaunchStatus.failed => l10n.mainFeedbackFailed,
      FeedbackLaunchStatus.cancelled => null,
    };
    if (message == null) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RecordingControllerState>(mainRecordingControllerProvider, (
      previous,
      next,
    ) {
      _displayAwakeCoordinator.updateRecordingState(next.recordingState);
      _handleControllerTransition(
        previous?.recordingState,
        next.recordingState,
      );
    });
    ref.listen<bool>(appLockEnabledProvider, (previous, next) {
      _displayAwakeCoordinator.updateAppLockState(_readEffectiveAppLockState());
    });
    ref.listen<AppLockState>(appLockControllerProvider, (previous, next) {
      if (!ref.read(appLockEnabledProvider)) {
        return;
      }
      _displayAwakeCoordinator.updateAppLockState(next);
    });

    final controllerState = ref.watch(mainRecordingControllerProvider);
    final languagePreference = ref.watch(
      transcriptionLanguageControllerProvider,
    );
    final transcriptionActive = ref.watch(transcriptionActivityProvider);
    final settingsAvailable = !controllerState.isActive && !transcriptionActive;
    final quota = ref.watch(sessionRecordQuotaStateProvider);
    final stats =
        ref.watch(mainScreenStatsProvider).value ??
        const MainScreenStatsData(entryCount: 0, activeDays: 0);
    final l10n = AppLocalizations.of(context);
    final hasEverRecorded =
        _hasRecordedThisSession || (_storedHasEverRecorded ?? false);
    final status = resolveMainScreenStatus(
      controllerState: controllerState,
      hasEverRecorded: hasEverRecorded,
      l10n: l10n,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final mediaQuery = MediaQuery.of(context);
                  _schedulePulseMeasurement(
                    viewportSize: mediaQuery.size,
                    viewPadding: mediaQuery.padding,
                  );
                  final pulseDiameter =
                      _measuredPulseDiameter ??
                      _fallbackPulseDiameter(constraints.biggest);

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: WraitDesignTokens.screenPadding,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  key: const ValueKey('quotaLineSlot'),
                                  height: WraitQuotaLineTokens.reservedHeight,
                                  child: Center(
                                    child: quota == null
                                        ? const SizedBox.shrink()
                                        : Semantics(
                                            container: true,
                                            label: l10n.mainQuotaSemanticsLabel(
                                              quota.limit,
                                              quota.remaining,
                                            ),
                                            child: Text(
                                              l10n.mainQuotaText(
                                                quota.limit,
                                                quota.remaining,
                                              ),
                                              key: const ValueKey(
                                                'quotaLineText',
                                              ),
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme.secondary,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(
                                  height: WraitQuotaLineTokens.gapBelow,
                                ),
                                ValueListenableBuilder<double?>(
                                  valueListenable: _countdownProgress,
                                  builder: (context, countdownProgress, _) {
                                    return ButtonArea(
                                      key: _buttonAreaKey,
                                      recordingState:
                                          controllerState.recordingState,
                                      shakeErrorKey:
                                          controllerState.shakeErrorKey,
                                      buttonLabel: status.buttonLabel,
                                      countdownProgress: countdownProgress,
                                      pulseDiameter: pulseDiameter,
                                      onPressed: () {
                                        ref
                                            .read(
                                              mainRecordingControllerProvider
                                                  .notifier,
                                            )
                                            .onMainButtonTapped();
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(
                                  height: WraitStatusLineTokens.gapAbove,
                                ),
                                SizedBox(
                                  key: mainStatusLineSlotKey,
                                  height: WraitStatusLineTokens.reservedHeight,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: WraitAnimationTokens.fade,
                                      child: _StatusLine(
                                        key: ValueKey(
                                          '${status.statusText}-${status.action}-${status.savedEntryId}-$_statusLineGeneration',
                                        ),
                                        presentation: status,
                                        onTap: () =>
                                            _handleStatusAction(status),
                                      ),
                                    ),
                                  ),
                                ),
                                if (languagePreference.isReady &&
                                    languagePreference.language != null) ...[
                                  const SizedBox(height: WraitSpacingTokens.sm),
                                  Builder(
                                    builder: (context) {
                                      final displayName =
                                          supportedLanguageDisplayName(
                                            languagePreference.language,
                                          );
                                      return Semantics(
                                        button: true,
                                        enabled: settingsAvailable,
                                        label: l10n.mainLanguageSemanticsLabel(
                                          displayName ?? '',
                                        ),
                                        child: InkWell(
                                          key: mainTranscriptionLanguageKey,
                                          borderRadius: BorderRadius.circular(
                                            WraitRadiusTokens.card,
                                          ),
                                          onTap: settingsAvailable
                                              ? () => context.push(
                                                  '/settings?section=transcription-language',
                                                )
                                              : null,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: WraitSpacingTokens.md,
                                              vertical: WraitSpacingTokens.xs,
                                            ),
                                            child: Text(
                                              l10n.mainLanguageLabel(
                                                displayName ?? '',
                                              ),
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                    color: settingsAvailable
                                                        ? colorScheme.secondary
                                                        : colorScheme.outline,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ] else if (languagePreference.status ==
                                    TranscriptionLanguageStatus
                                        .loadFailure) ...[
                                  const SizedBox(height: WraitSpacingTokens.sm),
                                  TextButton(
                                    key: mainTranscriptionLanguageRetryKey,
                                    onPressed: () => unawaited(
                                      ref
                                          .read(
                                            transcriptionLanguageControllerProvider
                                                .notifier,
                                          )
                                          .retryLoad(),
                                    ),
                                    child: Text(l10n.mainLanguageUnavailable),
                                  ),
                                ],
                                const SizedBox(
                                  height: WraitStatsLineTokens.gapAbove,
                                ),
                                SizedBox(
                                  key: const ValueKey('statsLineSlot'),
                                  height: WraitStatsLineTokens.reservedHeight,
                                  child: Center(
                                    child: Semantics(
                                      button: true,
                                      label: l10n.statsSemanticsLabel(
                                        stats.displayText(l10n),
                                      ),
                                      child: InkWell(
                                        key: const ValueKey('statsLineButton'),
                                        borderRadius: BorderRadius.circular(
                                          WraitRadiusTokens.card,
                                        ),
                                        onTap: () => context.go('/entries'),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: WraitSpacingTokens.md,
                                            vertical: WraitSpacingTokens.sm,
                                          ),
                                          child: Text(
                                            stats.displayText(l10n),
                                            key: const ValueKey(
                                              'statsLineText',
                                            ),
                                            style: theme.textTheme.labelLarge,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: WraitSpacingTokens.xs,
                left: WraitSpacingTokens.sm,
                child: Semantics(
                  container: true,
                  button: true,
                  label: l10n.mainSettingsSemanticsLabel,
                  child: IconButton(
                    key: mainSettingsButtonKey,
                    tooltip: l10n.mainSettingsTooltip,
                    onPressed: settingsAvailable
                        ? () => context.push('/settings')
                        : null,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
              ),
              Positioned(
                top: WraitSpacingTokens.xs,
                right: WraitSpacingTokens.sm,
                child: Semantics(
                  container: true,
                  button: true,
                  label: l10n.mainFeedbackSemanticsLabel,
                  onTap: _feedbackInFlight ? null : _openFeedback,
                  child: IconButton(
                    key: mainFeedbackButtonKey,
                    tooltip: l10n.mainFeedbackTooltip,
                    onPressed: _feedbackInFlight ? null : _openFeedback,
                    icon: const Icon(Icons.feedback_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _fallbackPulseDiameter(Size viewportSize) {
    return math.max(viewportSize.width, viewportSize.height) +
        (WraitButtonTokens.pulseViewportOverscan * 2);
  }

  void _schedulePulseMeasurement({
    required Size viewportSize,
    required EdgeInsets viewPadding,
  }) {
    final needsMeasurement =
        _measuredPulseDiameter == null ||
        _lastPulseViewportSize != viewportSize ||
        _lastPulseViewPadding != viewPadding;
    if (!needsMeasurement || _pulseMeasurementPending) {
      return;
    }

    _pulseMeasurementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pulseMeasurementPending = false;
      if (!mounted) {
        return;
      }

      final buttonContext = _buttonAreaKey.currentContext;
      final renderObject = buttonContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        return;
      }

      final buttonCenter = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      final visibleRect = Rect.fromLTRB(
        viewPadding.left,
        viewPadding.top,
        viewportSize.width - viewPadding.right,
        viewportSize.height - viewPadding.bottom,
      );
      final furthestCornerDistance = <double>[
        (buttonCenter - visibleRect.topLeft).distance,
        (buttonCenter - visibleRect.topRight).distance,
        (buttonCenter - visibleRect.bottomLeft).distance,
        (buttonCenter - visibleRect.bottomRight).distance,
      ].reduce(math.max);
      final measuredPulseDiameter =
          (furthestCornerDistance * 2) +
          (WraitButtonTokens.pulseViewportOverscan * 2);

      if (!measuredPulseDiameter.isFinite || measuredPulseDiameter <= 0) {
        return;
      }

      _lastPulseViewportSize = viewportSize;
      _lastPulseViewPadding = viewPadding;
      if ((_measuredPulseDiameter ?? 0) == measuredPulseDiameter) {
        return;
      }

      setState(() {
        _measuredPulseDiameter = measuredPulseDiameter;
      });
    });
  }

  AppLockState _readEffectiveAppLockState() {
    if (!ref.read(appLockEnabledProvider)) {
      return const AppLockState.unlocked();
    }
    return ref.read(appLockControllerProvider);
  }

  void _handleControllerTransition(
    RecordingState? previous,
    RecordingState next,
  ) {
    if (previous != next &&
        (previous is RecordingErrorState || next is RecordingErrorState)) {
      _statusLineGeneration += 1;
    }

    if (next is RecordingSaved) {
      _hasRecordedThisSession = true;
      if (previous != next) {
        _savedAutoClearTimer?.cancel();
        _savedAutoClearGeneration += 1;
        final generation = _savedAutoClearGeneration;
        final delay = ref
            .read(recordingFeedbackDelaysProvider)
            .savedDisplayWindow;
        _savedAutoClearTimer = Timer(delay, () {
          if (!mounted || generation != _savedAutoClearGeneration) {
            return;
          }
          ref.read(mainRecordingControllerProvider.notifier).clearSaved();
        });
      }
    } else {
      _savedAutoClearTimer?.cancel();
      _savedAutoClearTimer = null;
      _savedAutoClearGeneration += 1;
    }

    if (next is RecordingListening) {
      _startCountdownTicker(next);
    } else {
      _stopCountdownTicker();
    }
  }

  void _startCountdownTicker(RecordingListening listeningState) {
    _countdownTicker?.cancel();
    _updateCountdownProgress(listeningState);
    _countdownTicker = Timer.periodic(WraitAnimationTokens.countdownRefresh, (
      _,
    ) {
      if (!mounted) {
        return;
      }
      final currentState = ref
          .read(mainRecordingControllerProvider)
          .recordingState;
      if (currentState case RecordingListening()) {
        _updateCountdownProgress(currentState);
        return;
      }
      _stopCountdownTicker();
    });
  }

  void _stopCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = null;
    if (_countdownProgress.value != null) {
      _countdownProgress.value = null;
    }
  }

  void _updateCountdownProgress(RecordingListening state) {
    final hardCapMs = ref.read(appConfigProvider).recordingHardCapMs;
    if (hardCapMs <= 0) {
      if (_countdownProgress.value != null) {
        _countdownProgress.value = null;
      }
      return;
    }
    final now = ref.read(monotonicClockProvider).now();
    final remaining = state.hardCapDeadlineElapsedRealtime - now;
    final clampedRemaining = remaining.clamp(0, hardCapMs);
    _countdownProgress.value = clampedRemaining / hardCapMs;
  }

  void _handleStatusAction(MainScreenStatusPresentation status) {
    switch (status.action) {
      case MainScreenStatusAction.startRecording:
        ref.read(mainRecordingControllerProvider.notifier).onMainButtonTapped();
        return;
      case MainScreenStatusAction.openSavedEntry:
        final entryId = status.savedEntryId;
        if (entryId == null) {
          return;
        }
        context.go('/entry/$entryId');
        return;
      case MainScreenStatusAction.openMicrophoneSettings:
        ref
            .read(mainRecordingControllerProvider.notifier)
            .openMicrophoneSettings();
        return;
      case null:
        return;
    }
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.presentation,
    required this.onTap,
    super.key,
  });

  final MainScreenStatusPresentation presentation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = ExcludeSemantics(
      child: Text(
        presentation.statusText,
        key: const ValueKey('statusLineText'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
    );
    final l10n = AppLocalizations.of(context);
    final semanticsLabel =
        presentation.semanticsLabel ??
        l10n.statusDefaultSemanticsLabel(presentation.statusText);

    if (!presentation.isStatusTappable) {
      return Semantics(
        container: true,
        label: semanticsLabel,
        hint: presentation.semanticsHint,
        child: text,
      );
    }

    return Semantics(
      button: true,
      label: semanticsLabel,
      hint: presentation.semanticsHint,
      child: InkWell(
        key: const ValueKey('statusLineButton'),
        borderRadius: BorderRadius.circular(WraitRadiusTokens.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WraitSpacingTokens.md,
            vertical: WraitSpacingTokens.sm,
          ),
          child: text,
        ),
      ),
    );
  }
}
