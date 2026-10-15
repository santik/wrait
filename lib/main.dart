import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_core;

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/api/backend_providers.dart';
import 'data/entries/entry_providers.dart';
import 'data/launch/app_launch_providers.dart';
import 'data/entries/local_entry_database.dart';
import 'data/preferences/preferences_providers.dart';
import 'data/preferences/reminders_enabled_controller.dart';
import 'data/reminders/notification_scheduler.dart';
import 'data/reminders/reminder_providers.dart';
import 'presentation/theme/wrait_theme.dart';

const _captureValidationMode = bool.fromEnvironment(
  'CAPTURE_VALIDATION_MODE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_captureValidationMode) {
    runApp(const _CaptureValidationApp());
    return;
  }

  runApp(
    BootstrapApp(
      appConfig: AppConfig.fromEnvironment(),
      bootstrapRuntime: bootstrapAppRuntime,
    ),
  );
}

class AppBootstrapRuntime {
  AppBootstrapRuntime({required this.container, required this.dispose});

  final ProviderContainer container;
  final Future<void> Function() dispose;
}

Future<AppBootstrapRuntime> bootstrapAppRuntime(AppConfig appConfig) async {
  developer.log('Starting app bootstrap.', name: 'AppBootstrap');

  developer.log('Opening local entry database.', name: 'AppBootstrap');
  final entryDatabase = await bootstrapLocalEntryDatabase();
  developer.log('Local entry database ready.', name: 'AppBootstrap');

  developer.log('Loading shared preferences.', name: 'AppBootstrap');
  final sharedPreferences = await SharedPreferences.getInstance();
  developer.log('Shared preferences ready.', name: 'AppBootstrap');

  developer.log('Initializing notifications.', name: 'AppBootstrap');
  tz.initializeTimeZones();
  final timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz_core.setLocalLocation(tz_core.getLocation(timeZoneName));

  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: darwinSettings,
  );
  await notificationsPlugin.initialize(initSettings);
  developer.log('Notifications ready.', name: 'AppBootstrap');

  final appContainer = createAppContainer(
    appConfig: appConfig,
    entryDatabase: entryDatabase,
    sharedPreferences: sharedPreferences,
    notificationsPlugin: notificationsPlugin,
  );
  developer.log('Provider container ready.', name: 'AppBootstrap');
  startAppLaunchWork(appContainer);
  developer.log('Launch registration started.', name: 'AppBootstrap');
  _scheduleRemindersOnLaunch(appContainer);
  startQuotaReminderSync(appContainer);

  return AppBootstrapRuntime(
    container: appContainer,
    dispose: () async {
      appContainer.dispose();
      await entryDatabase.close();
    },
  );
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    required this.appConfig,
    required this.bootstrapRuntime,
    this.startupTimeout = const Duration(seconds: 15),
    super.key,
  });

  final AppConfig appConfig;
  final Future<AppBootstrapRuntime> Function(AppConfig appConfig)
  bootstrapRuntime;
  final Duration startupTimeout;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  Future<AppBootstrapRuntime>? _runtimeFuture;
  AppBootstrapRuntime? _activeRuntime;
  int _bootstrapRequestId = 0;
  bool _bootstrapInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_startBootstrap());
    });
  }

  @override
  void dispose() {
    unawaited(_disposeRuntimeSafely(_activeRuntime));
    super.dispose();
  }

  Future<AppBootstrapRuntime> _createRuntime(int requestId) async {
    try {
      final runtime = await widget
          .bootstrapRuntime(widget.appConfig)
          .timeout(widget.startupTimeout);
      if (!mounted || requestId != _bootstrapRequestId) {
        await runtime.dispose();
      } else {
        _activeRuntime = runtime;
      }
      return runtime;
    } catch (error, stackTrace) {
      developer.log(
        'App bootstrap failed.',
        name: 'AppBootstrap',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _startBootstrap({bool disposeActiveRuntime = false}) async {
    if (_bootstrapInFlight) {
      return;
    }

    _bootstrapInFlight = true;
    final requestId = ++_bootstrapRequestId;
    final previousRuntime = disposeActiveRuntime ? _activeRuntime : null;
    _activeRuntime = null;

    if (previousRuntime != null) {
      await _disposeRuntimeSafely(previousRuntime);
    }

    final runtimeFuture = Future<AppBootstrapRuntime>.sync(
      () => _createRuntime(requestId),
    );
    unawaited(runtimeFuture.then<void>((_) {}, onError: (_, _) {}));
    if (mounted) {
      setState(() {
        _runtimeFuture = runtimeFuture;
      });
    }

    try {
      await runtimeFuture;
    } catch (_) {
      // FutureBuilder owns the user-visible error state.
    } finally {
      if (_bootstrapRequestId == requestId) {
        if (mounted) {
          setState(() {
            _bootstrapInFlight = false;
          });
        } else {
          _bootstrapInFlight = false;
        }
      }
    }
  }

  Future<void> _disposeRuntimeSafely(AppBootstrapRuntime? runtime) async {
    if (runtime == null) {
      return;
    }

    try {
      await runtime.dispose();
    } catch (error, stackTrace) {
      developer.log(
        'App bootstrap runtime disposal failed.',
        name: 'AppBootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _retryBootstrap() {
    unawaited(_startBootstrap(disposeActiveRuntime: true));
  }

  @override
  Widget build(BuildContext context) {
    final runtimeFuture = _runtimeFuture;
    if (runtimeFuture == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: wraitLightTheme,
        darkTheme: wraitDarkTheme,
        themeMode: ThemeMode.system,
        home: const _BootstrapStatusScreen(
          title: 'opening wrait',
          subtitle: 'loading your local journal',
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    return FutureBuilder<AppBootstrapRuntime>(
      future: runtimeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return UncontrolledProviderScope(
            container: snapshot.data!.container,
            child: const WraitApp(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: wraitLightTheme,
            darkTheme: wraitDarkTheme,
            themeMode: ThemeMode.system,
            home: _BootstrapStatusScreen(
              title: 'could not open wrait',
              subtitle: 'try again',
              child: FilledButton(
                onPressed: _bootstrapInFlight ? null : _retryBootstrap,
                child: const Text('retry'),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: wraitLightTheme,
          darkTheme: wraitDarkTheme,
          themeMode: ThemeMode.system,
          home: const _BootstrapStatusScreen(
            title: 'opening wrait',
            subtitle: 'loading your local journal',
            child: CircularProgressIndicator.adaptive(),
          ),
        );
      },
    );
  }
}

class _BootstrapStatusScreen extends StatelessWidget {
  const _BootstrapStatusScreen({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ProviderContainer createAppContainer({
  required AppConfig appConfig,
  SharedPreferences? sharedPreferences,
  LocalEntryDatabase? entryDatabase,
  FlutterLocalNotificationsPlugin? notificationsPlugin,
  Iterable overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(appConfig),
      if (entryDatabase != null)
        localEntryDatabaseProvider.overrideWithValue(entryDatabase),
      if (sharedPreferences != null)
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      if (notificationsPlugin != null)
        notificationSchedulerProvider.overrideWithValue(
          PluginNotificationScheduler(notificationsPlugin),
        ),
      ...overrides,
    ],
  );
}

void startAppLaunchWork(ProviderContainer appContainer) {
  unawaited(appContainer.read(appLaunchWorkUseCaseProvider).call());
}

void _scheduleRemindersOnLaunch(ProviderContainer container) {
  unawaited(() async {
    try {
      final controller = container.read(
        remindersEnabledControllerProvider.notifier,
      );
      await controller.load();
      final state = container.read(remindersEnabledControllerProvider);
      if (state.enabled) {
        final scheduler = container.read(reminderSchedulerProvider);
        final quotaState = container.read(sessionRecordQuotaStateProvider);
        await scheduler.updateSchedule(enabled: true, quotaState: quotaState);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to schedule reminders on launch.',
        name: 'AppBootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }());
}

class _CaptureValidationApp extends StatelessWidget {
  const _CaptureValidationApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: wraitLightTheme,
      darkTheme: wraitDarkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_moon_outlined,
                size: 56,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              const SizedBox(height: 20),
              Text(
                'capture validation',
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'visible placeholder content for native privacy-cover checks',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
