package com.savia.domain.repository

import com.savia.domain.model.*
import kotlinx.coroutines.flow.Flow

/**
 * Repository for project, sprint, and workspace data from Bridge.
 *
 * Provides access to PM-Workspace data including projects, sprints, user profiles,
 * and board state. Implementations communicate with the Bridge server's project endpoints.
 *
 * All suspend functions run on IO dispatcher and are safe for UI thread invocation from
 * ViewModels and Compose state management.
 *
 * Clean Architecture role: Domain-layer abstraction for project management operations.
 * Implementations (in the data layer) handle Bridge API communication via OkHttp
 * and optional caching via Room or DataStore.
 *
 * @author Savia Mobile Team
 */
interface ProjectRepository {
    /**
     * Retrieve all projects the user has access to.
     *
     * Fetches the list of projects available in PM-Workspace for the authenticated user.
     * Projects include current sprint information and health metrics.
     *
     * @return List of Project objects, empty if no projects accessible
     * @throws IOException if Bridge cannot be reached
     */
    suspend fun getProjects(): List<Project>

    /**
     * Get the currently selected/active project.
     *
     * Returns the project that the user most recently selected or interacted with,
     * or null if no project has been selected yet (first-time user scenario).
     *
     * @return The selected Project, or null if none selected
     */
    suspend fun getSelectedProject(): Project?

    /**
     * Set the active project for the user.
     *
     * Updates the user's project selection, which persists across app sessions.
     * Subsequent calls to [getSelectedProject] will return the project set here.
     *
     * @param projectId The ID of the project to select
     * @throws IllegalArgumentException if projectId does not correspond to an accessible project
     */
    suspend fun setSelectedProject(projectId: String)

    /**
     * Get sprint dashboard summary for a project.
     *
     * Retrieves aggregated metrics for the current/active sprint in the given project.
     * Includes completion progress, blocked items, and velocity calculations.
     *
     * @param projectId The project to query
     * @return SprintSummary if an active sprint exists, or null if no sprint is active
     */
    suspend fun getSprintSummary(projectId: String): SprintSummary?

    /**
     * Get all available slash commands organized by family.
     *
     * Fetches the command families and commands available for execution via the Bridge.
     * Includes whether each command is enabled on mobile devices.
     *
     * @return List of CommandFamily objects, each containing related commands
     */
    suspend fun getCommands(): List<CommandFamily>

    /**
     * Get the authenticated user's profile.
     *
     * Returns profile information combining Google Sign-In identity with PM-Workspace role data.
     *
     * @return UserProfile with name, email, role, and optional stats, or null if not authenticated
     */
    suspend fun getUserProfile(): UserProfile?

    /**
     * Get the Kanban board state for a project.
     *
     * Retrieves the current board layout with all columns and work items.
     * Columns are ordered as configured in the project.
     *
     * @param projectId The project to query
     * @return List of BoardColumn objects representing the board state
     */
    suspend fun getBoard(projectId: String): List<BoardColumn>

    /**
     * Get pending approval requests in a project.
     *
     * Retrieves PRs, infrastructure changes, and deployment requests awaiting approval.
     *
     * @param projectId The project to query
     * @return List of ApprovalRequest objects sorted by creation date (newest first)
     */
    suspend fun getApprovals(projectId: String): List<ApprovalRequest>

    /**
     * Execute a slash command in the Bridge.
     *
     * Sends a command to the Bridge server and receives streaming responses.
     * Command names should not include the leading slash.
     *
     * **Example:** `executeCommand("sprint-status", "project-123")`
     *
     * @param command The command name (without leading slash)
     * @param projectId The project context for the command
     * @return Flow<String> emitting response chunks as they arrive from the Bridge
     *         Completes when the command execution finishes
     */
    suspend fun executeCommand(command: String, projectId: String): Flow<String>

    /**
     * Capture a new backlog item from user input.
     *
     * Creates a new PBI, Task, or Bug in the project backlog from user-provided content.
     * The Bridge may parse and structure the content automatically.
     *
     * @param content User-provided text describing the item
     * @param type Work item type: "PBI", "Task", or "Bug"
     * @param projectId The project where the item will be created
     * @return The ID of the newly created work item
     */
    suspend fun captureBacklogItem(content: String, type: String, projectId: String): String

    /**
     * Log time spent on a task.
     *
     * Records hours worked on a task for capacity planning and progress tracking.
     *
     * @param taskId The task/PBI to log time against
     * @param hours Hours spent (may be fractional, e.g., 2.5)
     * @param date Date in ISO 8601 format (YYYY-MM-DD)
     * @param note Optional note about the work completed
     * @return true if logging succeeded, false otherwise
     */
    suspend fun logTime(taskId: String, hours: Float, date: String, note: String?): Boolean

    /**
     * Get time entries for a specific date.
     *
     * Retrieves all time entries logged by the user on the given date,
     * useful for daily review and capacity validation.
     *
     * @param date Date in ISO 8601 format (YYYY-MM-DD)
     * @return List of TimeEntry objects for that date
     */
    suspend fun getTimeEntries(date: String): List<TimeEntry>

    /** Get git global configuration from Bridge. */
    suspend fun getGitConfig(): GitConfig?

    /** Update git global configuration via Bridge. */
    suspend fun updateGitConfig(config: GitConfig): Boolean

    /** Get team members from Bridge. */
    suspend fun getTeamMembers(): List<TeamMember>

    /** Add a new team member via Bridge. */
    suspend fun addTeamMember(slug: String, identity: Map<String, String>): Boolean

    /** Update an existing team member via Bridge. */
    suspend fun updateTeamMember(slug: String, identity: Map<String, String>): Boolean

    /** Remove a team member via Bridge. */
    suspend fun removeTeamMember(slug: String): Boolean

    /** Get company profile from Bridge. */
    suspend fun getCompanyProfile(): CompanyProfile?

    /** Update a company profile section via Bridge. */
    suspend fun updateCompanySection(section: String, fields: Map<String, String>, content: String = ""): Boolean

    /**
     * Get complete dashboard data from Bridge GET /dashboard endpoint.
     *
     * Returns all data needed for the Home screen in a single REST call.
     * The Bridge reads project data directly from disk (CLAUDE.md, mock JSON files),
     * making this fast and reliable - no dependency on Claude CLI.
     *
     * @return DashboardData with projects, sprint, tasks, and activity; or null if Bridge unavailable
     */
    suspend fun getDashboard(): DashboardData?
}
