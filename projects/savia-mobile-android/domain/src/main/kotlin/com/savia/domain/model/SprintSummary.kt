package com.savia.domain.model

/**
 * Sprint dashboard summary data.
 *
 * Aggregates sprint metrics for display on the sprint dashboard.
 * All progress metrics are normalized to 0.0-1.0 range where applicable.
 *
 * @property name Name or identifier of the sprint
 * @property progress Completion progress as a decimal (0.0 = 0%, 1.0 = 100%)
 * @property completedPoints Story points completed in this sprint
 * @property totalPoints Total story points planned for this sprint
 * @property blockedItems Number of items currently blocked or awaiting action
 * @property daysRemaining Number of calendar days remaining in the sprint
 * @property velocity Average story points per day (calculated over recent sprints)
 */
data class SprintSummary(
    val name: String,
    val progress: Float,  // 0.0 to 1.0
    val completedPoints: Int,
    val totalPoints: Int,
    val blockedItems: Int,
    val daysRemaining: Int,
    val velocity: Float
)
