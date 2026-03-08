package com.savia.domain.model

/**
 * Represents an available app update from the Bridge server.
 *
 * Contains all metadata needed to check update eligibility and download the APK.
 * Fields are populated from the Bridge `/update/check` endpoint response.
 *
 * @property version Semantic version string (e.g., "0.2.0")
 * @property versionCode Integer version code for comparison
 * @property filename Name of the APK file (e.g., "savia-mobile-0.2.0.apk")
 * @property size Size of APK in bytes
 * @property sha256 SHA256 hash for integrity verification
 * @property downloadUrl Relative or absolute URL for the `/update/download` endpoint
 * @property releaseNotes Human-readable changelog for this version
 * @property minAndroidSdk Minimum Android API level required by this version
 */
data class AppUpdate(
    val version: String,
    val versionCode: Int,
    val filename: String,
    val size: Long,
    val sha256: String,
    val downloadUrl: String,
    val releaseNotes: String,
    val minAndroidSdk: Int
)
