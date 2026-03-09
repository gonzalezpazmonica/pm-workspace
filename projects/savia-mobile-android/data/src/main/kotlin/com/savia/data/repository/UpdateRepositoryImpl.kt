package com.savia.data.repository

import android.content.Context
import com.savia.data.api.SaviaBridgeService
import com.savia.domain.model.AppUpdate
import com.savia.domain.repository.SecurityRepository
import com.savia.domain.repository.UpdateRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import javax.inject.Inject
import javax.inject.Named

/**
 * Auto-update implementation using Bridge /update/check and /update/download endpoints.
 *
 * Manages the complete app update workflow:
 * - Checking for available updates from the Bridge server
 * - Downloading update APKs with progress tracking
 * - Managing downloaded APK files in cache storage
 *
 * **Architecture:** Data layer repository implementation. Abstracts OkHttp networking
 * and file I/O details from the domain layer.
 *
 * **Network Flow:**
 * 1. `checkForUpdate()` → GET `/update/check` (JSON response with version metadata)
 * 2. `downloadUpdate()` → GET `/update/download` (binary APK file, progress tracking)
 * 3. `getDownloadedApkPath()` → Read filesystem to locate cached APK
 *
 * **Storage:** Uses app cache directory (`context.cacheDir/updates/`) to store downloaded APKs.
 * Files may be deleted by the system if storage is needed, so APK must be installed
 * immediately after download or stored in app-specific external cache as needed.
 *
 * @property context Application context for cache directory access
 * @property bridgeClient OkHttpClient configured for Bridge communication
 * @property bridgeService Bridge service for accessing configuration and utilities
 * @property json Kotlinx serialization instance for JSON parsing
 *
 * @author Savia Mobile Team
 */
class UpdateRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    @Named("bridge") private val bridgeClient: OkHttpClient,
    private val bridgeService: SaviaBridgeService,
    private val securityRepository: SecurityRepository,
    private val json: Json
) : UpdateRepository {

    private val updateDir = File(context.cacheDir, "updates").apply { mkdirs() }

    /**
     * Check for available updates from the Bridge server.
     *
     * Performs a GET request to `/update/check` and parses the JSON response.
     * Compares the server's version code against the provided current version.
     *
     * **Response format (expected):**
     * ```json
     * {
     *   "version": "0.2.0",
     *   "versionCode": 2,
     *   "filename": "savia-mobile-0.2.0.apk",
     *   "size": 45678901,
     *   "sha256": "abc123...",
     *   "downloadUrl": "/update/download",
     *   "releaseNotes": "Bug fixes and UI improvements",
     *   "minAndroidSdk": 26
     * }
     * ```
     *
     * @param currentVersionCode The installed app's version code from PackageManager
     * @return AppUpdate if server has a newer version available, or null if up-to-date
     * @throws IllegalStateException if Bridge URL is not configured
     */
    override suspend fun checkForUpdate(currentVersionCode: Int): AppUpdate? {
        val bridgeUrl = securityRepository.getBridgeUrl() ?: return null
        val request = Request.Builder()
            .url("$bridgeUrl/update/check")
            .get()
            .build()

        return try {
            val response = bridgeClient.newCall(request).execute()
            if (!response.isSuccessful) return null

            val body = response.body?.string() ?: return null
            val jsonObj = json.parseToJsonElement(body).jsonObject

            val serverVersionCode = jsonObj["versionCode"]?.jsonPrimitive?.int ?: return null
            if (serverVersionCode <= currentVersionCode) return null

            AppUpdate(
                version = jsonObj["version"]?.jsonPrimitive?.content ?: "",
                versionCode = serverVersionCode,
                filename = jsonObj["filename"]?.jsonPrimitive?.content ?: "",
                size = jsonObj["size"]?.jsonPrimitive?.long ?: 0L,
                sha256 = jsonObj["sha256"]?.jsonPrimitive?.content ?: "",
                downloadUrl = jsonObj["downloadUrl"]?.jsonPrimitive?.content ?: "/update/download",
                releaseNotes = jsonObj["releaseNotes"]?.jsonPrimitive?.content ?: "",
                minAndroidSdk = jsonObj["minAndroidSdk"]?.jsonPrimitive?.int ?: 26
            )
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Download the update APK from the Bridge server.
     *
     * Performs a GET request to the download URL and streams the response body to disk.
     * Emits progress as Float values from 0.0 to 1.0 as the download progresses.
     *
     * **Progress emission semantics:**
     * - Progress is calculated as: `downloadedBytes / totalBytes`
     * - Progress is emitted after each chunk is written (granularity ~8KB)
     * - Final emission is 1.0f when download completes
     *
     * **Cancellation:** If the returned Flow is cancelled, the download stops and the
     * partially-downloaded file is left on disk (caller should clean up).
     *
     * **Threading:** Runs on Dispatchers.IO, safe to call from any coroutine context.
     *
     * @param update AppUpdate object containing filename, size, and downloadUrl
     * @return Flow<Float> emitting progress updates from 0.0 to 1.0
     * @throws RuntimeException if HTTP response is not successful (2xx) or body is empty
     */
    override fun downloadUpdate(update: AppUpdate): Flow<Float> = flow {
        val bridgeUrl = securityRepository.getBridgeUrl() ?: throw IllegalStateException("Bridge not configured")
        val request = Request.Builder()
            .url("$bridgeUrl${update.downloadUrl}")
            .get()
            .build()

        val response = bridgeClient.newCall(request).execute()
        if (!response.isSuccessful) throw RuntimeException("Download failed: ${response.code}")

        val body = response.body ?: throw RuntimeException("Empty response body")
        val totalBytes = update.size
        var downloadedBytes = 0L

        val file = File(updateDir, update.filename)
        file.outputStream().use { output ->
            body.byteStream().use { input ->
                val buffer = ByteArray(8192)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    downloadedBytes += bytesRead
                    if (totalBytes > 0) {
                        emit(downloadedBytes.toFloat() / totalBytes.toFloat())
                    }
                }
            }
        }
        emit(1.0f)
    }.flowOn(Dispatchers.IO)

    /**
     * Get the path to the most recently downloaded APK file.
     *
     * Searches the updates cache directory for APK files and returns the path
     * of the most recently modified one.
     *
     * **Important:** Files in cache directory may be deleted by the system if storage is needed.
     * The returned APK should be installed immediately to avoid loss.
     *
     * @return Absolute filesystem path to the downloaded APK, or null if no APK exists
     */
    override suspend fun getDownloadedApkPath(): String? {
        val files = updateDir.listFiles()?.filter { it.extension == "apk" }
        return files?.maxByOrNull { it.lastModified() }?.absolutePath
    }
}
