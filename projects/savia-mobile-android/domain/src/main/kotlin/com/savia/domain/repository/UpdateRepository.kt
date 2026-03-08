package com.savia.domain.repository

import com.savia.domain.model.AppUpdate
import kotlinx.coroutines.flow.Flow

/**
 * Repository for app update operations via Bridge server.
 *
 * Abstracts all update-related network and file operations,
 * allowing the domain layer to remain independent of implementation details.
 * Implementations communicate with the Bridge `/update/check` and `/update/download` endpoints.
 *
 * Clean Architecture role: Provides a domain-level abstraction for app updates.
 * Implementations (in the data layer) handle OkHttp networking and file I/O.
 *
 * @author Savia Mobile Team
 */
interface UpdateRepository {
    /**
     * Check for available updates from the Bridge server.
     *
     * Compares the app's current version code against the latest version on the Bridge.
     * If an update is available and meets device requirements, returns the update metadata.
     * If the device is already on the latest version, returns null.
     *
     * This is a suspending function suitable for use in coroutines and ViewModels.
     *
     * @param currentVersionCode The installed app's version code (obtained from PackageManager)
     * @return AppUpdate metadata if an update is available and suitable for this device, or null
     *         if the device is up-to-date or if the Bridge cannot be reached
     * @throws IOException if network communication with Bridge fails unexpectedly
     */
    suspend fun checkForUpdate(currentVersionCode: Int): AppUpdate?

    /**
     * Download update APK, emitting progress updates.
     *
     * Downloads the APK file from the Bridge server and saves it to device cache storage.
     * Emits progress as a Flow of Float values representing completion percentage (0.0 to 1.0).
     *
     * This is a cold Flow — the download starts when the Flow is collected.
     * Cancelling the Flow will abort the download and clean up the partial file.
     *
     * Suitable for binding to a ProgressBar or displaying download speed in the UI.
     *
     * **Progress semantics:**
     * - 0.0 = download not started
     * - 0.0 < progress < 1.0 = download in progress
     * - 1.0 = download complete
     *
     * @param update The AppUpdate metadata containing filename and downloadUrl
     * @return Flow<Float> emitting progress updates from 0.0 to 1.0
     * @throws RuntimeException if the download fails or HTTP response is not 2xx
     */
    fun downloadUpdate(update: AppUpdate): Flow<Float>

    /**
     * Get the filesystem path to the most recently downloaded APK.
     *
     * Returns the absolute path to the APK file if one exists in cache storage,
     * or null if no APK has been downloaded yet.
     *
     * The APK at this path is ready for installation via PackageInstaller intent.
     * The path points to a cache directory and may be deleted by the system if storage is needed.
     *
     * @return Absolute filesystem path to the downloaded APK, or null if none exists
     */
    suspend fun getDownloadedApkPath(): String?
}
