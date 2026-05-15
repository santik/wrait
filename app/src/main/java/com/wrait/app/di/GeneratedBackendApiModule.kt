package com.wrait.app.di

import com.wrait.app.BuildConfig
import com.wrait.app.data.api.generated.api.DefaultApi
import com.wrait.app.data.api.generated.auth.ApiKeyAuth
import com.wrait.app.data.api.generated.infrastructure.ApiClient
import com.wrait.app.data.api.generated.infrastructure.Serializer
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import okhttp3.OkHttpClient
import okhttp3.MediaType.Companion.toMediaType
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import retrofit2.converter.scalars.ScalarsConverterFactory
import java.util.concurrent.TimeUnit
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object GeneratedBackendApiModule {
    /**
     * Wires the build-generated OpenAPI client used for register/cleanup.
     *
     * To regenerate the client:
     * - update `openapi/wrait-backend.yaml`
     * - run `./gradlew :app:openApiGenerate`
     *
     * The transcribe upload path is intentionally not generated because the current
     * Retrofit byte-array body generation was not reliable for this endpoint.
     */

    private const val REQUEST_TIMEOUT_MS = 60_000L
    private const val CONNECT_TIMEOUT_MS = 10_000L

    @Provides
    @Singleton
    fun provideBackendOkHttpClient(): OkHttpClient {
        return OkHttpClient.Builder()
            .callTimeout(REQUEST_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .connectTimeout(CONNECT_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .readTimeout(REQUEST_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .writeTimeout(REQUEST_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            .build()
    }

    @Provides
    @Singleton
    fun provideGeneratedApiClient(okHttpClient: OkHttpClient): ApiClient {
        return ApiClient(
            baseUrl = BuildConfig.BACKEND_URL,
            okHttpClientBuilder = okHttpClient.newBuilder(),
            converterFactories = listOf(
                ScalarsConverterFactory.create(),
                Serializer.kotlinxSerializationJson.asConverterFactory("application/json".toMediaType()),
            ),
        ).apply {
            addAuthorization(
                authName = "ProxySecretHeader",
                authorization = ApiKeyAuth(
                    location = "header",
                    paramName = "X-Proxy-Secret",
                    apiKey = BuildConfig.PROXY_SECRET,
                ),
            )
        }
    }

    @Provides
    @Singleton
    fun provideDefaultApi(apiClient: ApiClient): DefaultApi {
        return apiClient.createService(DefaultApi::class.java)
    }
}
