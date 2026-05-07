package com.wrait.app.di

import com.wrait.app.BuildConfig
import com.wrait.app.analytics.AnalyticsTracker
import com.wrait.app.analytics.NoOpAnalyticsTracker
import com.wrait.app.analytics.PostHogAnalyticsTracker
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AnalyticsModule {
    @Provides
    @Singleton
    fun provideAnalyticsTracker(): AnalyticsTracker {
        if (!BuildConfig.POSTHOG_ENABLED) return NoOpAnalyticsTracker()
        if (BuildConfig.POSTHOG_API_KEY.isBlank()) return NoOpAnalyticsTracker()
        if (BuildConfig.POSTHOG_HOST.isBlank()) return NoOpAnalyticsTracker()
        return PostHogAnalyticsTracker()
    }
}
