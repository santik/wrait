package com.wrait.app.test.fake

import com.wrait.app.domain.config.DevModeProvider

class FakeDevModeProvider(
    override val isDevMode: Boolean = true,
) : DevModeProvider
