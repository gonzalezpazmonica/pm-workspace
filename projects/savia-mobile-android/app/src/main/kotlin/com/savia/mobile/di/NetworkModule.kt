package com.savia.mobile.di

import com.savia.data.api.ClaudeApiService
import com.savia.data.api.SaviaBridgeService
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.concurrent.TimeUnit
import javax.inject.Named
import javax.inject.Singleton
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

/**
 * Dependency injection module for network communication.
 *
 * Provides OkHttpClient instances for two distinct use cases:
 * - Anthropic Claude API: standard certificate validation
 * - Savia Bridge: self-signed certificate acceptance for local/VPN deployments
 *
 * Also provides Retrofit instances and API service interfaces for both channels.
 * The Bridge client has extended read timeout (300s) to accommodate Claude response streaming.
 *
 * @author Savia Mobile Team
 */
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {

    private const val DEFAULT_ANTHROPIC_URL = "https://api.anthropic.com/"

    /**
     * Provides kotlinx.serialization JSON configuration used by Retrofit and API clients.
     *
     * Configuration:
     * - ignoreUnknownKeys: true — forward compatibility with API responses
     * - isLenient: true — relaxed parsing of JSON structures
     * - encodeDefaults: true — always serialize default values
     *
     * @return configured Json instance for kotlinx.serialization
     */
    @Provides
    @Singleton
    fun provideJson(): Json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    /**
     * Standard OkHttpClient for Anthropic API (uses system CA certificates).
     */
    @Provides
    @Singleton
    fun provideOkHttpClient(): OkHttpClient =
        OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(120, TimeUnit.SECONDS)
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.HEADERS
                }
            )
            .build()

    /**
     * OkHttpClient that accepts the bridge's self-signed TLS certificate.
     * Used only for communication with the local Savia Bridge server.
     */
    @Provides
    @Singleton
    @Named("bridge")
    fun provideBridgeOkHttpClient(): OkHttpClient {
        // Trust all certificates for the bridge connection.
        // Security is ensured by: (1) VPN tunnel, (2) auth token, (3) local network only.
        // In future, certificate pinning by fingerprint can be added.
        val trustManager = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
        }

        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, arrayOf<TrustManager>(trustManager), SecureRandom())

        return OkHttpClient.Builder()
            .sslSocketFactory(sslContext.socketFactory, trustManager)
            .hostnameVerifier { _, _ -> true }
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(300, TimeUnit.SECONDS)  // Long timeout for Claude responses
            .writeTimeout(30, TimeUnit.SECONDS)
            .addInterceptor(
                HttpLoggingInterceptor().apply {
                    level = HttpLoggingInterceptor.Level.HEADERS
                }
            )
            .build()
    }

    /**
     * Provides Retrofit instance for Anthropic Claude API communication.
     *
     * Uses the standard OkHttpClient configured for system certificate validation.
     * Base URL points to Anthropic's official API endpoint.
     * Converter factory uses kotlinx.serialization for request/response serialization.
     *
     * @param client standard OkHttpClient with system certificates
     * @param json configured Json instance for serialization
     * @return Retrofit instance configured for Claude API
     */
    @Provides
    @Singleton
    fun provideRetrofit(client: OkHttpClient, json: Json): Retrofit =
        Retrofit.Builder()
            .baseUrl(DEFAULT_ANTHROPIC_URL)
            .client(client)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build()

    /**
     * Provides ClaudeApiService for direct Anthropic API calls.
     *
     * This service is used when the app is not connected to the Savia Bridge
     * and communicates directly with Anthropic's Claude API using an API key.
     *
     * @param retrofit configured Retrofit instance
     * @return ClaudeApiService proxy generated by Retrofit
     */
    @Provides
    @Singleton
    fun provideClaudeApiService(retrofit: Retrofit): ClaudeApiService =
        retrofit.create(ClaudeApiService::class.java)

    /**
     * Provides SaviaBridgeService for communication with the Savia Bridge.
     *
     * The Bridge is a local or VPN-connected service that proxies requests to Claude
     * and provides user profile/context injection. Uses self-signed certificate
     * validation via the bridge OkHttpClient.
     *
     * @param bridgeClient OkHttpClient configured to accept self-signed certificates
     * @param json configured Json instance for serialization
     * @return SaviaBridgeService instance
     */
    @Provides
    @Singleton
    fun provideSaviaBridgeService(
        @Named("bridge") bridgeClient: OkHttpClient,
        json: Json
    ): SaviaBridgeService =
        SaviaBridgeService(bridgeClient, json)
}
