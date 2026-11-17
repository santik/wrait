import 'dart:developer' as developer;

import 'package:home_widget/home_widget.dart';

import 'widget_sync_payload.dart';

/// Shared-store key names, shared with the native Android/iOS widget code.
/// Keep in sync with `WraitWidgetProvider.kt` and the iOS widget's reads.
class WidgetSyncKeys {
  WidgetSyncKeys._();

  static const String entryCount = 'entryCount';
  static const String activeDays = 'activeDays';
  static const String quotaUsed = 'quotaUsed';
  static const String quotaLimit = 'quotaLimit';
  static const String quotaResetAtEpochMs = 'quotaResetAtEpochMs';
}

/// Android `AppWidgetProvider` class (receiver) simple name; must match the
/// manifest `<receiver android:name=".WraitWidgetProvider">`.
const String kWidgetAndroidName = 'WraitWidgetProvider';

/// Fully-qualified `AppWidgetProvider` class name. The provider class lives in
/// the `com.wrait.flutter` namespace, which differs from the `applicationId`
/// in the debug/profile flavors (`com.wrait.flutter.dev`). `home_widget`
/// resolves a non-qualified name against the applicationId, which would target
/// a non-existent `com.wrait.flutter.dev.WraitWidgetProvider` and silently fail
/// to refresh the widget — so always update by the qualified name.
const String kWidgetAndroidQualifiedName = 'com.wrait.flutter.WraitWidgetProvider';

/// iOS WidgetKit widget kind; must match the SwiftUI widget's `kind`.
const String kWidgetIOSName = 'WraitWidget';

/// iOS App Group id; must match both app and extension entitlements.
const String kWidgetAppGroupId = 'group.com.wrait.flutter';

/// Writes the widget payload into the platform-shared store and asks the OS to
/// reload the widget. This is the single writer of widget data (spec 055 plan
/// D-4). The widget itself never reads from the network or database.
///
/// The `home_widget` calls are injectable so the service is unit-testable
/// without the platform channel.
class WidgetSyncService {
  WidgetSyncService({
    Future<bool?> Function(String id, Object? data)? saveWidgetData,
    Future<bool?> Function()? updateWidget,
    Future<bool?> Function(String groupId)? setAppGroupId,
  }) : _saveWidgetData = saveWidgetData ?? _defaultSave,
       _updateWidget = updateWidget ?? _defaultUpdate,
       _setAppGroupId = setAppGroupId ?? HomeWidget.setAppGroupId;

  final Future<bool?> Function(String id, Object? data) _saveWidgetData;
  final Future<bool?> Function() _updateWidget;
  final Future<bool?> Function(String groupId) _setAppGroupId;

  // The App Group id only needs to be set once (iOS); it is idempotent but a
  // platform-channel round-trip, so avoid repeating it on every sync.
  bool _appGroupConfigured = false;

  static Future<bool?> _defaultSave(String id, Object? data) =>
      HomeWidget.saveWidgetData<Object?>(id, data);

  static Future<bool?> _defaultUpdate() => HomeWidget.updateWidget(
    qualifiedAndroidName: kWidgetAndroidQualifiedName,
    iOSName: kWidgetIOSName,
  );

  /// Writes the payload and reloads the widget.
  ///
  /// Entry stats are always written. The quota group is written only when it is
  /// present ([WidgetSyncPayload.hasQuota]); when absent (cold start before the
  /// first backend sync), the previously cached quota values are left untouched
  /// so the widget keeps showing the last known quota (spec 055 plan D-5).
  Future<void> sync(WidgetSyncPayload payload) async {
    if (!_appGroupConfigured) {
      await _setAppGroupId(kWidgetAppGroupId);
      _appGroupConfigured = true;
    }

    await _saveWidgetData(WidgetSyncKeys.entryCount, payload.entryCount);
    await _saveWidgetData(WidgetSyncKeys.activeDays, payload.activeDays);

    if (payload.hasQuota) {
      await _saveWidgetData(WidgetSyncKeys.quotaUsed, payload.quotaUsed);
      await _saveWidgetData(WidgetSyncKeys.quotaLimit, payload.quotaLimit);
      await _saveWidgetData(
        WidgetSyncKeys.quotaResetAtEpochMs,
        payload.quotaResetAtEpochMs,
      );
    }

    final updated = await _updateWidget();
    if (updated == false) {
      developer.log(
        'home_widget updateWidget reported no update.',
        name: 'WidgetSync',
      );
    }
  }
}
