package com.wrait.app.analytics

import android.app.Application
import android.util.Log
import com.posthog.PersonProfiles
import com.posthog.android.PostHogAndroid
import com.posthog.android.PostHogAndroidConfig
import com.wrait.app.BuildConfig

object PostHogInitializer {
    private const val TAG = "PostHogInitializer"

    private val blockedPropertyKeys = setOf(
        "text",
        "transcript",
        "cleanedText",
        "audioPath",
        "entryId",
        "deviceId",
        "shareText",
        "filePath",
    )

    fun initialize(application: Application) {
        if (!shouldEnableAnalyticsSdk(
                enabled = BuildConfig.POSTHOG_ENABLED,
                apiKey = BuildConfig.POSTHOG_API_KEY,
                host = BuildConfig.POSTHOG_HOST,
            )
        ) {
            if (BuildConfig.POSTHOG_ENABLED &&
                BuildConfig.POSTHOG_API_KEY.isNotBlank() &&
                !isValidAnalyticsHost(BuildConfig.POSTHOG_HOST)
            ) {
                Log.w(TAG, "PostHog disabled due to invalid host: '${BuildConfig.POSTHOG_HOST}'")
            }
            AnalyticsSdkState.markUnavailable()
            return
        }

        runCatching {
            val config = PostHogAndroidConfig(
                apiKey = BuildConfig.POSTHOG_API_KEY,
                host = BuildConfig.POSTHOG_HOST,
            ).apply {
                debug = BuildConfig.DEV
                captureApplicationLifecycleEvents = false
                captureDeepLinks = false
                captureScreenViews = false
                preloadFeatureFlags = false
                sendFeatureFlagEvent = false
                sessionReplay = false
                personProfiles = PersonProfiles.IDENTIFIED_ONLY
                // On the currently shipped SDK, before-send filtering is the stable hook we can
                // rely on to strip blocked properties before dispatch.
                addBeforeSend { event ->
                    val properties = event.properties ?: emptyMap()
                    val removedKeys = blockedAnalyticsPropertyKeys(
                        propertyKeys = properties.keys,
                        blockedKeys = blockedPropertyKeys,
                    )
                    if (BuildConfig.DEV && removedKeys.isNotEmpty()) {
                        Log.w(TAG, "Blocked analytics properties: $removedKeys")
                    }

                    if (removedKeys.isEmpty()) {
                        event
                    } else {
                        val sanitizedProperties = properties.toMutableMap().apply {
                            removedKeys.forEach(::remove)
                        }
                        event.copy(properties = sanitizedProperties)
                    }
                }
            }

            PostHogAndroid.setup(application.applicationContext, config)
            AnalyticsSdkState.markReady()
            Log.i(TAG, "PostHog initialized")
        }.onFailure { error ->
            AnalyticsSdkState.markUnavailable()
            Log.w(TAG, "PostHog initialization failed; analytics disabled", error)
        }
    }
}
