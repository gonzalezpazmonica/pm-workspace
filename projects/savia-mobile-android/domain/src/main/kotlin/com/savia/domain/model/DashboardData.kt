package com.savia.domain.model

/**
 * Complete dashboard data returned by Bridge GET /dashboard endpoint.
 *
 * This is the primary data source for the Home screen. The Bridge reads
 * project data directly from disk (CLAUDE.md, mock JSON files) rather
 * than going through Claude CLI, making it fast and reliable.
 *
 * @property greeting Localized greeting for the user
 * @property projects List of all available projects
 * @property selectedProjectId ID of the currently selected project
 * @property sprint Sprint summary for the selected project (null if no sprint data)
 * @property myTasks Active tasks assigned to the current user
 * @property recentActivity Recent activity strings for display
 * @property blockedItems Number of blocked items
 * @property hoursToday Hours logged today
 */
data class DashboardData(
    val greeting: String,
    val projects: List<Project>,
    val selectedProjectId: String?,
    val sprint: SprintSummary?,
    val myTasks: List<BoardItem>,
    val recentActivity: List<String>,
    val blockedItems: Int,
    val hoursToday: Float
)
