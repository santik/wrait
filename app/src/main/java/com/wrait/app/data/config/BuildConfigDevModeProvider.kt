package com.wrait.app.data.config

import com.wrait.app.BuildConfig
import com.wrait.app.domain.config.DevModeProvider
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BuildConfigDevModeProvider @Inject constructor() : DevModeProvider {
    override val isDevMode: Boolean = BuildConfig.DEV
}
