package com.savia.mobile

import android.app.Application
import android.util.Log
import dagger.hilt.android.HiltAndroidApp
import java.io.PrintWriter
import java.io.StringWriter

@HiltAndroidApp
class SaviaApp : Application() {

    companion object {
        private const val TAG = "SaviaApp"
    }

    override fun onCreate() {
        super.onCreate()
        installCrashHandler()
    }

    private fun installCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val stackTrace = sw.toString()

                Log.e(TAG, "=== SAVIA UNCAUGHT EXCEPTION ===")
                Log.e(TAG, "Thread: ${thread.name}")
                Log.e(TAG, "Exception: ${throwable.javaClass.simpleName}: ${throwable.message}")
                Log.e(TAG, stackTrace)
                Log.e(TAG, "=== END SAVIA CRASH LOG ===")

                try {
                    val crashFile = java.io.File(filesDir, "last_crash.log")
                    crashFile.writeText(
                        "timestamp=${System.currentTimeMillis()}\n" +
                            "thread=${thread.name}\n" +
                            "exception=${throwable.javaClass.name}: ${throwable.message}\n" +
                            "stacktrace=\n$stackTrace"
                    )
                } catch (_: Exception) { }
            } catch (_: Exception) { }
            finally {
                defaultHandler?.uncaughtException(thread, throwable)
            }
        }
    }
}
