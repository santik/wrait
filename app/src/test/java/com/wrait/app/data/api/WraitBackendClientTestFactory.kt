package com.wrait.app.data.api

import com.wrait.app.data.api.generated.api.DefaultApi
import kotlin.Function1

internal object WraitBackendClientTestFactory {
    fun create(
        api: DefaultApi,
        deviceId: String,
    ): WraitBackendClient {
        val constructor = WraitBackendClient::class.java.getDeclaredConstructor(
            DefaultApi::class.java,
            Function1::class.java,
        )
        constructor.isAccessible = true
        return constructor.newInstance(api, suspend { deviceId }) as WraitBackendClient
    }
}
