import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/auth/app_lock_providers.dart';
import '../../data/preferences/app_lock_preference_controller.dart';
import '../../data/preferences/reminders_enabled_controller.dart';
import '../../data/preferences/theme_mode_controller.dart';
import '../../data/preferences/transcription_language_controller.dart';
import '../../data/transcription/transcription_providers.dart';
import '../../domain/model/supported_language.dart';
import '../../l10n/app_localizations.dart';
import '../main/main_recording_controller.dart';
import '../theme/design_tokens.dart';
import 'settings_test_keys.dart';

const _automaticLanguageValue = '__automatic__';

String _toDropdownValue(String? language) =>
    language ?? _automaticLanguageValue;

String? _fromDropdownValue(String value) =>
    value == _automaticLanguageValue ? null : value;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.focusTranscriptionLanguage = false});

  final bool focusTranscriptionLanguage;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  final _languageSectionKey = GlobalKey();
  final _languageFocusNode = FocusNode();
  final _languageMenuController = MenuController();
  final _languageTextController = TextEditingController();
  bool _focusScheduled = false;
  bool _languageTextSyncScheduled = false;
  bool _remindersPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(remindersEnabledControllerProvider.notifier).load());
    _scheduleLanguageFocusIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.focusTranscriptionLanguage &&
        widget.focusTranscriptionLanguage) {
      _focusScheduled = false;
      _scheduleLanguageFocusIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _languageFocusNode.dispose();
    _languageTextController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _remindersPermissionDenied) {
      Permission.notification.status.then((status) {
        if (mounted && status.isGranted) {
          setState(() {
            _remindersPermissionDenied = false;
          });
        }
      });
    }
  }

  /// DropdownMenu writes the picked label into its text controller before
  /// onSelected runs, and does not reset it when the save is rejected. While no
  /// save is in flight, force the field back to the committed language.
  void _scheduleLanguageTextSync(String expectedLabel, bool isSaving) {
    if (isSaving ||
        _languageTextSyncScheduled ||
        _languageTextController.text == expectedLabel) {
      return;
    }
    _languageTextSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _languageTextSyncScheduled = false;
      if (!mounted) {
        return;
      }
      final current = ref.read(transcriptionLanguageControllerProvider);
      if (current.isSaving) {
        return;
      }
      final label = _languageLabel(current);
      if (_languageTextController.text != label) {
        _languageTextController.value = TextEditingValue(
          text: label,
          selection: TextSelection.collapsed(offset: label.length),
        );
      }
    });
  }

  Future<void> _handleRemindersToggle(bool value) async {
    var permissionDenied = false;
    if (value) {
      try {
        var status = await Permission.notification.status;
        if (!status.isGranted) {
          status = await Permission.notification.request();
        }
        permissionDenied = !status.isGranted;
      } catch (_) {
        // Permission lookup failed; the preference is still saved below.
        permissionDenied = false;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _remindersPermissionDenied = permissionDenied;
    });
    // The preference is saved regardless of permission status.
    await ref
        .read(remindersEnabledControllerProvider.notifier)
        .setEnabled(value);
  }

  String _languageLabel(TranscriptionLanguageState state) {
    if (!state.isReady) {
      return '';
    }
    final language = state.language;
    if (language == null) {
      return AppLocalizations.of(context).settingsAutomaticDetection;
    }
    return supportedLanguageDisplayName(language) ?? '';
  }

  void _scheduleLanguageFocusIfNeeded() {
    if (!widget.focusTranscriptionLanguage || _focusScheduled) {
      return;
    }
    final languageState = ref.read(transcriptionLanguageControllerProvider);
    if (!languageState.isReady) {
      return;
    }
    _focusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sectionContext = _languageSectionKey.currentContext;
      if (!mounted) {
        return;
      }
      if (sectionContext == null) {
        // Section not built yet; allow the next build to retry.
        _focusScheduled = false;
        return;
      }
      await Scrollable.ensureVisible(
        sectionContext,
        alignment: 0.1,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      if (mounted) {
        _languageFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preference = ref.watch(appLockPreferenceControllerProvider);
    final buildAllowsLock = ref.watch(appLockBuildEnabledProvider);
    final languagePreference = ref.watch(
      transcriptionLanguageControllerProvider,
    );
    final remindersState = ref.watch(remindersEnabledControllerProvider);
    final transcriptionActive = ref.watch(transcriptionActivityProvider);
    final recordingActive = ref.watch(
      mainRecordingControllerProvider.select((state) => state.isActive),
    );
    final activityActive = recordingActive || transcriptionActive;
    final canChange =
        buildAllowsLock &&
        preference.isReady &&
        !preference.isSaving &&
        !activityActive;
    final canChangeLanguage =
        languagePreference.isReady &&
        !languagePreference.isSaving &&
        !activityActive;
    _scheduleLanguageFocusIfNeeded();
    _scheduleLanguageTextSync(
      _languageLabel(languagePreference),
      languagePreference.isSaving,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: settingsBackButtonKey,
          tooltip: l10n.settingsBack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(l10n.settingsTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: WraitDesignTokens.screenPadding,
          children: [
            Text(
              l10n.settingsPrivacy,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: WraitSpacingTokens.sm),
            SwitchListTile.adaptive(
              key: appLockSwitchKey,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsAppLock),
              subtitle: Text(l10n.settingsAppLockDescription),
              value: preference.isReady && preference.enabled,
              onChanged: canChange
                  ? (value) {
                      unawaited(
                        ref
                            .read(appLockPreferenceControllerProvider.notifier)
                            .setEnabled(value),
                      );
                    }
                  : null,
            ),
            if (!buildAllowsLock)
              _Message(
                key: appLockPreferenceErrorKey,
                text: l10n.settingsAppLockUnavailable,
              )
            else if (preference.issue != null)
              _PreferenceIssue(issue: preference.issue!),
            const SizedBox(height: WraitSpacingTokens.lg),
            Text(
              l10n.settingsReminders,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: WraitSpacingTokens.sm),
            SwitchListTile.adaptive(
              key: remindersToggleKey,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsRemindersToggle),
              subtitle: Text(l10n.settingsRemindersDescription),
              value: remindersState.isReady && remindersState.enabled,
              onChanged:
                  remindersState.isReady &&
                      !remindersState.isSaving &&
                      !activityActive
                  ? (value) {
                      unawaited(_handleRemindersToggle(value));
                    }
                  : null,
            ),
            if (_remindersPermissionDenied && remindersState.enabled) ...[
              _Message(
                key: remindersPermissionDeniedKey,
                text: l10n.settingsRemindersPermissionDenied,
              ),
              const SizedBox(height: WraitSpacingTokens.sm),
              OutlinedButton(
                key: remindersOpenSettingsKey,
                onPressed: () {
                  unawaited(openAppSettings());
                },
                child: Text(l10n.settingsOpenDeviceSettings),
              ),
            ],
            const SizedBox(height: WraitSpacingTokens.lg),
            const _ThemeSection(),
            const SizedBox(height: WraitSpacingTokens.lg),
            KeyedSubtree(
              key: _languageSectionKey,
              child: const SizedBox(
                key: transcriptionLanguageSectionKey,
                height: 0,
              ),
            ),
            Text(
              l10n.settingsTranscriptionLanguage,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: WraitSpacingTokens.xs),
            Text(l10n.settingsTranscriptionLanguageDescription),
            const SizedBox(height: WraitSpacingTokens.sm),
            if (languagePreference.status ==
                TranscriptionLanguageStatus.loadFailure)
              _LanguageLoadFailure()
            else
              Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final menuItemStyle = MenuItemButton.styleFrom(
                    textStyle: theme.textTheme.bodyLarge,
                    padding: const EdgeInsets.symmetric(
                      horizontal: WraitSpacingTokens.md,
                    ),
                    minimumSize: const Size.fromHeight(
                      kMinInteractiveDimension,
                    ),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                  final dropdownEntries = <DropdownMenuEntry<String>>[
                    DropdownMenuEntry<String>(
                      value: _automaticLanguageValue,
                      label: l10n.settingsAutomaticDetection,
                      labelWidget: Text(
                        l10n.settingsAutomaticDetection,
                        key: transcriptionLanguageAutomaticKey,
                      ),
                      style: menuItemStyle,
                    ),
                    for (final language in supportedLanguages)
                      DropdownMenuEntry<String>(
                        value: language.code,
                        label: language.displayName,
                        labelWidget: Text(
                          language.displayName,
                          key: transcriptionLanguageOptionKey(language.code),
                        ),
                        style: menuItemStyle,
                      ),
                  ];

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return KeyedSubtree(
                        key: transcriptionLanguageFocusKey,
                        child: Focus(
                          focusNode: _languageFocusNode,
                          onKeyEvent: (_, event) {
                            if (!canChangeLanguage) {
                              return KeyEventResult.ignored;
                            }
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.space)) {
                              _languageMenuController.open();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: DropdownMenu<String>(
                            key: transcriptionLanguageDropdownKey,
                            width: constraints.maxWidth,
                            menuController: _languageMenuController,
                            controller: _languageTextController,
                            requestFocusOnTap: false,
                            enabled: canChangeLanguage,
                            initialSelection: languagePreference.isReady
                                ? _toDropdownValue(languagePreference.language)
                                : null,
                            hintText: l10n.settingsLoading,
                            label: Text(l10n.settingsTranscriptionLanguage),
                            textStyle: theme.textTheme.bodyLarge,
                            inputDecorationTheme:
                                const InputDecorationThemeData(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                            menuHeight: MediaQuery.sizeOf(context).height * 0.6,
                            enableFilter: false,
                            enableSearch: false,
                            selectOnly: true,
                            dropdownMenuEntries: dropdownEntries,
                            onSelected: canChangeLanguage
                                ? (value) {
                                    if (value == null) {
                                      return;
                                    }
                                    unawaited(
                                      ref
                                          .read(
                                            transcriptionLanguageControllerProvider
                                                .notifier,
                                          )
                                          .setLanguage(
                                            _fromDropdownValue(value),
                                          ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            if (languagePreference.isSaving) ...[
              const SizedBox(height: WraitSpacingTokens.sm),
              const LinearProgressIndicator(
                key: transcriptionLanguageSavingKey,
              ),
            ],
            if (languagePreference.saveFailed)
              _Message(
                key: transcriptionLanguageErrorKey,
                text: l10n.settingsTranscriptionLanguageSaveFailed,
              ),
            if (activityActive)
              _Message(
                key: const ValueKey<String>('settingsActivityMessage'),
                text: l10n.settingsActivityMessage,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageLoadFailure extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Message(
          key: transcriptionLanguageErrorKey,
          text: l10n.settingsTranscriptionLanguageLoadFailed,
        ),
        TextButton(
          key: transcriptionLanguageRetryKey,
          onPressed: () => unawaited(
            ref
                .read(transcriptionLanguageControllerProvider.notifier)
                .retryLoad(),
          ),
          child: Text(l10n.settingsTryAgain),
        ),
      ],
    );
  }
}

class _PreferenceIssue extends ConsumerWidget {
  const _PreferenceIssue({required this.issue});

  final AppLockPreferenceIssue issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final message = switch (issue) {
      AppLockPreferenceIssue.noSecurity => l10n.settingsAppLockNoSecurity,
      AppLockPreferenceIssue.temporarilyUnavailable =>
        l10n.settingsAppLockTemporarilyUnavailable,
      AppLockPreferenceIssue.unavailable =>
        l10n.settingsAppLockUnavailableDevice,
      AppLockPreferenceIssue.saveFailed => l10n.settingsAppLockSaveFailed,
      AppLockPreferenceIssue.settingsFailed =>
        l10n.settingsAppLockSettingsFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Message(key: appLockPreferenceErrorKey, text: message),
        if (issue == AppLockPreferenceIssue.noSecurity) ...[
          const SizedBox(height: WraitSpacingTokens.sm),
          OutlinedButton(
            key: appLockDeviceSettingsKey,
            onPressed: () {
              unawaited(
                ref
                    .read(appLockPreferenceControllerProvider.notifier)
                    .openDeviceSecuritySettings(),
              );
            },
            child: Text(l10n.settingsOpenDeviceSettings),
          ),
        ],
      ],
    );
  }
}

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeState = ref.watch(themeModeControllerProvider);
    final transcriptionActive = ref.watch(transcriptionActivityProvider);
    final recordingActive = ref.watch(
      mainRecordingControllerProvider.select((state) => state.isActive),
    );
    final activityActive = recordingActive || transcriptionActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settingsAppearance,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: WraitSpacingTokens.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ThemeMode>(
            key: themeSegmentedButtonKey,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.settingsThemeSystem,
                    key: themeSystemSegmentKey),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.settingsThemeLight,
                    key: themeLightSegmentKey),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.settingsThemeDark,
                    key: themeDarkSegmentKey),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {themeState.themeMode},
            onSelectionChanged: themeState.isSaving || activityActive
                ? null
                : (selected) {
                    unawaited(
                      ref
                          .read(themeModeControllerProvider.notifier)
                          .setThemeMode(selected.first),
                    );
                  },
          ),
        ),
        if (themeState.saveFailed)
          _Message(key: themeSaveFailedKey, text: l10n.settingsThemeSaveFailed),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: WraitSpacingTokens.md),
      child: Text(text),
    );
  }
}
