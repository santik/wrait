package com.wrait.flutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget for Wrait (spec 055).
 *
 * Reads aggregate values from the `home_widget` shared store (written by the
 * app's `WidgetSyncService`), applies the optimistic quota reset, and binds a
 * [RemoteViews]. Tapping anywhere launches the app to the main screen (ready to
 * record, no auto-start); the app's existing lock gate is not bypassed. The
 * widget performs no network or database work and shows no entry content.
 */
class WraitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val entryCount = widgetData.getInt(KEY_ENTRY_COUNT, 0)
            val activeDays = widgetData.getInt(KEY_ACTIVE_DAYS, 0)
            val views = RemoteViews(context.packageName, R.layout.wrait_widget).apply {
                setTextViewText(
                    R.id.wrait_widget_entry_count,
                    formatCount(context, R.plurals.wrait_widget_entries, entryCount),
                )
                setTextViewText(
                    R.id.wrait_widget_active_days,
                    formatCount(context, R.plurals.wrait_widget_days, activeDays),
                )

                // Quota line only when a complete quota group has been cached.
                if (widgetData.contains(KEY_QUOTA_USED) &&
                    widgetData.contains(KEY_QUOTA_LIMIT) &&
                    widgetData.contains(KEY_QUOTA_RESET_AT)
                ) {
                    val quota = WidgetQuotaDisplay.resolve(
                        used = widgetData.getInt(KEY_QUOTA_USED, 0),
                        limit = widgetData.getInt(KEY_QUOTA_LIMIT, 0),
                        resetAtMs = widgetData.getLong(KEY_QUOTA_RESET_AT, 0L),
                        nowMs = System.currentTimeMillis(),
                    )
                    setTextViewText(
                        R.id.wrait_widget_quota,
                        context.getString(
                            R.string.wrait_widget_quota,
                            quota.used,
                            quota.limit,
                        ),
                    )
                    setViewVisibility(R.id.wrait_widget_quota, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.wrait_widget_quota, View.GONE)
                }

                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                )
                setOnClickPendingIntent(R.id.wrait_widget_root, launchIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /**
     * Formats a localized "<n> entries/days" label, capping the number at
     * "[STAT_CAP]+" so large counts don't overflow the layout. Above the cap the
     * plural "other" form is used (quantity [STAT_CAP] + 1).
     */
    private fun formatCount(context: Context, pluralRes: Int, count: Int): CharSequence {
        if (count > STAT_CAP) {
            return context.resources
                .getQuantityString(pluralRes, STAT_CAP + 1)
                .replace("%1\$d", "$STAT_CAP+")
                .replace("%d", "$STAT_CAP+")
        }
        return context.resources.getQuantityString(pluralRes, count, count)
    }

    private companion object {
        const val STAT_CAP = 999
        const val KEY_ENTRY_COUNT = "entryCount"
        const val KEY_ACTIVE_DAYS = "activeDays"
        const val KEY_QUOTA_USED = "quotaUsed"
        const val KEY_QUOTA_LIMIT = "quotaLimit"
        const val KEY_QUOTA_RESET_AT = "quotaResetAtEpochMs"
    }
}
