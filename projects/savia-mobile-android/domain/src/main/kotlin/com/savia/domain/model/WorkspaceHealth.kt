package com.savia.domain.model

import kotlinx.serialization.Serializable

/**
 * Represents the health and status of the remote Savia Bridge workspace.
 *
 * This model aggregates multiple health dimensions (e.g., server availability, database status,
 * SSH connectivity) into a single overall score. It allows the mobile app to display workspace
 * status to the user and make decisions about operation availability.
 *
 * ## Role in Clean Architecture
 * [WorkspaceHealth] is a domain model for monitoring and reporting. It abstracts the various
 * ways health data can be obtained (API call, SSH check, cached value) and presents a unified
 * interface to use cases and UI layers.
 *
 * ## Scoring Rules
 * - Scores range from 0 (worst) to 100 (best)
 * - A score of -1 indicates data is unavailable (special sentinel value)
 * - Individual dimensions are weighted and combined into the overall score
 * - Negative scores should be treated as errors, not as valid health data
 *
 * ## Data Source
 * The [source] field indicates how fresh the data is:
 * - [DataSource.API]: Fetched directly from Bridge server (most recent)
 * - [DataSource.SSH]: Checked via SSH command execution (direct access)
 * - [DataSource.CACHE]: From local device storage (may be stale)
 *
 * UI should indicate source to user (e.g., "Status (cached)" vs "Status (live)")
 *
 * @property overallScore Aggregated health score (0-100), or -1 if unavailable
 * @property dimensions Breakdown of health metrics by category
 * @property timestamp When this health snapshot was captured
 * @property source Whether data came from API, SSH, or cache
 */
@Serializable
data class WorkspaceHealth(
    val overallScore: Int = 0,
    val dimensions: List<HealthDimension> = emptyList(),
    val timestamp: Long = System.currentTimeMillis(),
    val source: DataSource = DataSource.CACHE
) {
    companion object {
        /**
         * Sentinel value indicating workspace health data is unavailable.
         * Used when the app cannot reach the Bridge server to check status.
         */
        val UNAVAILABLE = WorkspaceHealth(overallScore = -1, source = DataSource.CACHE)
    }

    /**
     * Whether valid health data is available.
     *
     * Returns false when [overallScore] is negative (indicating an error or unavailable status).
     * Use this to determine if UI should display the score or show an unavailable state.
     *
     * @return true if [overallScore] >= 0, false otherwise
     */
    val isAvailable: Boolean
        get() = overallScore >= 0
}

/**
 * A single dimension of workspace health.
 *
 * Examples: "Server Availability", "Database Connection", "SSH Access", "API Response Time"
 *
 * Each dimension has a score (current value) and a max score (reference value for normalization).
 * A dimension with score = maxScore indicates perfect health for that metric.
 *
 * @property name Human-readable dimension name
 * @property score Current health value for this dimension
 * @property maxScore Maximum possible score (usually 100)
 * @property details Additional context or explanation (e.g., "API latency: 45ms")
 */
@Serializable
data class HealthDimension(
    val name: String,
    val score: Int,
    val maxScore: Int = 100,
    val details: String = ""
)

/**
 * Enumeration of data sources for workspace health information.
 *
 * Indicates how fresh and direct the health data is, helping the app decide
 * whether to refetch or trust the current value.
 *
 * @property API Health fetched directly from Bridge's HTTP API
 * @property SSH Health checked via direct SSH command execution
 * @property CACHE Health loaded from local device storage (may be stale)
 */
@Serializable
enum class DataSource {
    API,
    SSH,
    CACHE
}
