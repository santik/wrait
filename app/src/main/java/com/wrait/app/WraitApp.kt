package com.wrait.app

import android.app.Application
import com.google.crypto.tink.aead.AeadConfig
import dagger.hilt.android.HiltAndroidApp

@HiltAndroidApp
class WraitApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AeadConfig.register()
    }
}
