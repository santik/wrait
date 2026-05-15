package com.wrait.app.data.api

import android.util.Log
import com.wrait.app.BuildConfig
import com.wrait.app.data.device.DeviceIdProvider
import com.wrait.app.di.IoDispatcher
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class OkHttpTranscribeUploadClient private constructor(
    private val okHttpClient: OkHttpClient,
    private val deviceIdProvider: DeviceIdProvider?,
    private val overrideDeviceId: String? = null,
    private val overrideBaseUrl: String? = null,
    private val overrideProxySecret: String? = null,
    private val ioDispatcher: CoroutineDispatcher,
) : TranscribeUploadClient {

    @Inject constructor(
        okHttpClient: OkHttpClient,
        deviceIdProvider: DeviceIdProvider,
        @IoDispatcher ioDispatcher: CoroutineDispatcher,
    ) : this(
        okHttpClient = okHttpClient,
        deviceIdProvider = deviceIdProvider,
        overrideDeviceId = null,
        overrideBaseUrl = null,
        overrideProxySecret = null,
        ioDispatcher = ioDispatcher,
    )

    internal constructor(
        okHttpClient: OkHttpClient,
        overrideDeviceId: String? = null,
        overrideBaseUrl: String? = null,
        overrideProxySecret: String? = null,
        ioDispatcher: CoroutineDispatcher,
    ) : this(
        okHttpClient = okHttpClient,
        deviceIdProvider = null,
        overrideDeviceId = overrideDeviceId,
        overrideBaseUrl = overrideBaseUrl,
        overrideProxySecret = overrideProxySecret,
        ioDispatcher = ioDispatcher,
    )

    override suspend fun transcribe(audioFile: File): TranscribeHttpResponse {
        val deviceId = resolveDeviceId()
        Log.d(TAG, "Transcribing ${audioFile.length()} bytes via handwritten OkHttp upload")
        return try {
            val request = Request.Builder()
                .url("${resolvedBaseUrl().trimEnd('/')}/api/transcribe")
                .addHeader("X-Device-Id", deviceId)
                .addHeader("X-Proxy-Secret", resolvedProxySecret())
                .post(audioFile.asRequestBody("audio/mp4".toMediaType()))
                .build()

            withContext(ioDispatcher) {
                okHttpClient.newCall(request).execute().use { response ->
                    TranscribeHttpResponse(
                        statusCode = response.code,
                        body = response.body?.string(),
                    )
                }
            }
        } catch (e: IOException) {
            Log.w(TAG, "Transcription request failed: ${e.javaClass.simpleName}: ${e.message}")
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "Transcription request failed: ${e.javaClass.simpleName}: ${e.message}")
            throw e
        }
    }

    private suspend fun resolveDeviceId(): String = withContext(ioDispatcher) {
        overrideDeviceId ?: deviceIdProvider?.getOrStore() ?: throw DeviceIdUnavailableException(
            "DeviceIdProvider not available for transcribe upload",
        )
    }

    private fun resolvedBaseUrl(): String = overrideBaseUrl ?: BuildConfig.BACKEND_URL

    private fun resolvedProxySecret(): String = overrideProxySecret ?: BuildConfig.PROXY_SECRET

    private companion object {
        const val TAG = "TranscribeUpload"
    }
}
