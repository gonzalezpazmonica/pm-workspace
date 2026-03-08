package com.savia.mobile.update

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.savia.domain.model.AppUpdate
import com.savia.domain.repository.UpdateRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages app update lifecycle: check, download, install.
 *
 * Provides a unified state machine for the app update process:
 * 1. Check for updates via `checkForUpdate()`
 * 2. Download if update available via `downloadUpdate()`
 * 3. Install via `installUpdate()`
 *
 * Update status is exposed via `updateState` Flow for reactive UI binding.
 *
 * **Architecture:** Application-level singleton managing update coordination.
 * Uses UpdateRepository (domain layer) for network/file operations and maintains
 * update lifecycle state for consumption by SettingsViewModel or MainActivity.
 *
 * **Threading:** All public methods are suspend functions. Call from ViewModelScope
 * or other launch context that respects coroutine cancellation.
 *
 * **Installation:** Relies on PackageInstaller/ACTION_VIEW intent. Works on
 * Android 5.0+ (minSdk=26).
 *
 * @property context Application context for version code lookup and intent starting
 * @property updateRepository Repository for update network and file operations
 *
 * @author Savia Mobile Team
 */
@Singleton
class UpdateManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val updateRepository: UpdateRepository
) {
    /**
     * Mutable internal state for update status.
     */
    private val _updateState = MutableStateFlow<UpdateState>(UpdateState.Idle)

    /**
     * Observable state of the current update process.
     *
     * Reflects the lifecycle of the update:
     * - `Idle` → user hasn't checked for updates yet
     * - `Checking` → checking for updates in progress
     * - `UpToDate` → device is on latest version
     * - `Available(update)` → update available, ready for download
     * - `Downloading(progress)` → download in progress (0.0-1.0)
     * - `ReadyToInstall(apkPath)` → APK downloaded, ready to install
     * - `Error(message)` → error occurred during check/download
     *
     * Subscribe from UI for reactive updates:
     * ```kotlin
     * viewModel.updateManager.updateState.collectAsStateWithLifecycle()
     * ```
     */
    val updateState = _updateState.asStateFlow()

    /**
     * Check for available app updates from the Bridge server.
     *
     * Queries the Bridge `/update/check` endpoint with the device's current version code.
     * Updates state to either `Available` or `UpToDate`.
     *
     * On error, sets state to `Error` with a descriptive message.
     *
     * **State transitions:**
     * - `Any` → `Checking` (start)
     * - `Checking` → `Available(update)` (if update available)
     * - `Checking` → `UpToDate` (if already on latest)
     * - `Checking` → `Error(message)` (if network/parse error)
     */
    suspend fun checkForUpdate() {
        _updateState.value = UpdateState.Checking
        try {
            val currentVersionCode = getCurrentVersionCode()
            val update = updateRepository.checkForUpdate(currentVersionCode)
            _updateState.value = if (update != null) {
                UpdateState.Available(update)
            } else {
                UpdateState.UpToDate
            }
        } catch (e: Exception) {
            _updateState.value = UpdateState.Error(e.message ?: "Update check failed")
        }
    }

    /**
     * Download the available update APK.
     *
     * Triggers the download via UpdateRepository and updates state to `Downloading`
     * as progress is received.
     *
     * Returns a Flow of progress values (0.0-1.0) for UI binding:
     * ```kotlin
     * downloadUpdate(update).collect { progress ->
     *     updateProgressBar(progress)
     * }
     * ```
     *
     * **State transitions:**
     * - `Available(update)` → `Downloading(progress)` (for each progress emit)
     * - When complete, state remains `Downloading(1.0f)` until `installUpdate()` is called
     *
     * **Note:** State is updated to `Downloading` internally. Caller should subscribe
     * to the returned Flow for fine-grained progress updates.
     *
     * @param update AppUpdate metadata from `Available` state
     * @return Flow<Float> emitting progress from 0.0 to 1.0
     */
    fun downloadUpdate(update: AppUpdate): Flow<Float> {
        _updateState.value = UpdateState.Downloading(0f)
        return updateRepository.downloadUpdate(update)
    }

    /**
     * Install the downloaded APK using PackageInstaller.
     *
     * Retrieves the downloaded APK path and launches the system PackageInstaller
     * via ACTION_VIEW intent. The user is presented with the standard install confirmation dialog.
     *
     * **Permissions:** Requires `android.permission.REQUEST_INSTALL_PACKAGES` in manifest.
     *
     * **API Compatibility:**
     * - API 24+ (N): Uses FileProvider for URI security
     * - API <24: Uses Uri.fromFile (deprecated but needed for compatibility)
     *
     * **Post-installation:** After user confirms installation, the OS handles the rest.
     * The app is killed during upgrade (normal behavior) and relaunched afterward.
     *
     * @throws IllegalStateException if no downloaded APK is available
     */
    suspend fun installUpdate() {
        val apkPath = updateRepository.getDownloadedApkPath() ?: return
        val apkFile = File(apkPath)

        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", apkFile)
        } else {
            @Suppress("DEPRECATION")
            Uri.fromFile(apkFile)
        }

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        context.startActivity(intent)
    }

    /**
     * Get the device's current app version code.
     *
     * Queries PackageManager for the installed package's version code.
     * Returns 1 as fallback if package cannot be found (should not happen for the app itself).
     *
     * **Compatibility:**
     * - API 28+: Uses `pInfo.longVersionCode.toInt()`
     * - API <28: Uses deprecated `pInfo.versionCode`
     *
     * @return Current version code as Int (e.g., 1, 2, 3, ...)
     */
    private fun getCurrentVersionCode(): Int {
        return try {
            val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pInfo.longVersionCode.toInt()
            } else {
                @Suppress("DEPRECATION")
                pInfo.versionCode
            }
        } catch (e: PackageManager.NameNotFoundException) {
            1
        }
    }
}

/**
 * State machine for app update lifecycle.
 *
 * Represents all possible states during the update process.
 * Flows are reactive: UI observes state and updates accordingly.
 */
sealed class UpdateState {
    /**
     * Initial state: no update check has been performed.
     */
    data object Idle : UpdateState()

    /**
     * Update check in progress.
     */
    data object Checking : UpdateState()

    /**
     * Device is already on the latest version.
     */
    data object UpToDate : UpdateState()

    /**
     * An update is available from the Bridge server.
     *
     * @property update AppUpdate metadata with version, size, and download info
     */
    data class Available(val update: AppUpdate) : UpdateState()

    /**
     * Update download in progress.
     *
     * @property progress Completion percentage (0.0-1.0)
     */
    data class Downloading(val progress: Float) : UpdateState()

    /**
     * APK has been downloaded and is ready to install.
     *
     * @property apkPath Absolute filesystem path to the downloaded APK
     */
    data class ReadyToInstall(val apkPath: String) : UpdateState()

    /**
     * An error occurred during check or download.
     *
     * @property message Human-readable error description
     */
    data class Error(val message: String) : UpdateState()
}
