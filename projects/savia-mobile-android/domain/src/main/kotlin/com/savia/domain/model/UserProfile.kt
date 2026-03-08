package com.savia.domain.model

/**
 * User profile combining Google Auth data and PM-Workspace role.
 *
 * Represents the authenticated user with both identity information from Google Sign-In
 * and role/team data from PM-Workspace.
 *
 * @property name Display name of the user
 * @property email Email address from Google account
 * @property photoUrl URL of user's profile photo (may be null)
 * @property role Role in the workspace (e.g., "PM", "Developer", "QA")
 * @property organization Name of the organization/company
 * @property activeProjects Number of projects the user is actively involved in
 * @property stats Optional detailed user statistics
 */
data class UserProfile(
    val name: String,
    val email: String,
    val photoUrl: String?,
    val role: String,
    val organization: String,
    val activeProjects: Int,
    val stats: UserStats?
)

/**
 * Detailed statistics about a user's activity and contribution.
 *
 * Tracks user engagement metrics within the workspace.
 *
 * @property sprintsManaged Number of sprints this user has managed
 * @property pbisCompleted Number of product backlog items completed
 * @property hoursLogged Total hours of work logged by this user
 */
data class UserStats(
    val sprintsManaged: Int,
    val pbisCompleted: Int,
    val hoursLogged: Float
)
