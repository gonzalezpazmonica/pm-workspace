package com.savia.mobile.notification

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.savia.mobile.R
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Manages notification channels and sending notifications for Savia Mobile.
 *
 * Handles:
 * - Creating the notification channel (Android 8.0+)
 * - Checking POST_NOTIFICATIONS permission (Android 13+)
 * - Sending "response complete" notifications when app is backgrounded
 */
@Singleton
class SaviaNotificationManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        const val CHANNEL_ID = "savia_chat_responses"
        const val NOTIFICATION_ID_RESPONSE_COMPLETE = 1001
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_chat),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = context.getString(R.string.notification_channel_chat_desc)
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    /**
     * Whether the app has permission to post notifications.
     * Always true on Android < 13 (permission not required).
     */
    fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    /**
     * Whether the runtime permission dialog needs to be shown.
     * Only relevant on Android 13+ (API 33+).
     */
    fun needsPermissionRequest(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasNotificationPermission()
    }

    /**
     * Sends a notification that a Claude response has completed.
     * Only sends if the app has notification permission.
     */
    fun notifyResponseComplete(conversationTitle: String? = null) {
        if (!hasNotificationPermission()) return

        val title = context.getString(R.string.notification_response_ready)
        val text = conversationTitle
            ?: context.getString(R.string.notification_response_ready_desc)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context)
                .notify(NOTIFICATION_ID_RESPONSE_COMPLETE, notification)
        } catch (_: SecurityException) {
            // Permission revoked between check and send — ignore
        }
    }
}
