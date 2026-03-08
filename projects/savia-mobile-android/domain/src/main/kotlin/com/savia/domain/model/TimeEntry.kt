package com.savia.domain.model

import java.time.LocalDate

/**
 * A time tracking entry for a task.
 *
 * Records hours spent on a specific task on a given date,
 * useful for time tracking and capacity planning.
 *
 * @property id Unique identifier for this time entry
 * @property taskId Reference to the task/PBI being tracked
 * @property taskTitle Human-readable title of the task
 * @property hours Number of hours logged (may be fractional, e.g., 2.5)
 * @property date Date when these hours were logged
 * @property note Optional notes about the work done
 */
data class TimeEntry(
    val id: String,
    val taskId: String,
    val taskTitle: String,
    val hours: Float,
    val date: LocalDate,
    val note: String?
)
