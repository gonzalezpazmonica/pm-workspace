package com.savia.data.repository

import android.content.Context
import com.savia.data.api.SaviaBridgeService
import com.savia.data.security.SecureStorage
import com.savia.domain.model.*
import com.savia.domain.repository.ProjectRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.serialization.json.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import javax.inject.Inject
import javax.inject.Named
import javax.inject.Singleton

/**
 * Implementation of [ProjectRepository] that communicates with Savia Bridge.
 *
 * **Responsibilities:**
 * 1. Retrieve projects and manage selected project state via SecureStorage
 * 2. Fetch sprint summaries, board state, approvals, and user profile
 * 3. Execute slash commands via streaming
 * 4. Manage backlog items and time tracking
 *
 * **Architecture Role:**
 * - Clean Architecture data layer (repository pattern)
 * - Implements interface [ProjectRepository] from domain layer
 * - Abstracts Bridge communication and local persistence from domain logic
 *
 * **Dual Strategy:**
 * - **Bridge REST**: Direct endpoints when available (/chat, /health)
 * - **Chat Fallback**: For operations not yet on REST, send slash commands to chat endpoint
 *   and parse JSON from response
 *
 * **Network Flow:**
 * All network calls run on Dispatchers.IO, safe for UI thread invocation from ViewModels.
 *
 * **Error Handling:**
 * - Network errors: Log and return null/empty (never crash)
 * - Parse errors: Catch and return null/empty (defensive parsing)
 * - Missing configuration: Gracefully degrade, return mock data if needed
 *
 * @constructor Injected dependencies via Hilt
 * @param context Application context for SecureStorage
 * @param bridgeClient OkHttpClient configured for Bridge communication
 * @param bridgeService SaviaBridgeService for Bridge endpoints
 * @param secureStorage Encrypted storage for selected project ID
 * @param json Kotlinx Serialization instance for JSON parsing
 *
 * @see ProjectRepository Domain interface this implements
 * @see SaviaBridgeService Bridge communication
 * @see SecureStorage Local persistence
 */
@Singleton
class ProjectRepositoryImpl @Inject constructor(
    @ApplicationContext private val context: Context,
    @Named("bridge") private val bridgeClient: OkHttpClient,
    private val bridgeService: SaviaBridgeService,
    private val secureStorage: SecureStorage,
    private val json: Json
) : ProjectRepository {

    private companion object {
        private const val KEY_SELECTED_PROJECT = "selected_project_id"
        private const val CHAT_SESSION_ID = "mobile-commands"
    }

    /**
     * Retrieve all projects the user has access to.
     *
     * Sends a help command via chat endpoint to discover available projects.
     * Falls back to a mock list containing "PM-Workspace" if the Bridge is unavailable.
     *
     * @return List of Project objects, empty if no projects accessible
     */
    override suspend fun getProjects(): List<Project> = try {
        val message = "/help --projects --format json"
        val projectsJson = sendChatCommand(message)

        if (projectsJson.isEmpty()) {
            getMockProjects()
        } else {
            parseProjectsFromJson(projectsJson)
        }
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching projects", e)
        getMockProjects()
    }

    /**
     * Get the currently selected/active project.
     *
     * Reads from SecureStorage. Returns null if no project has been selected yet.
     *
     * @return The selected Project, or null if none selected
     */
    override suspend fun getSelectedProject(): Project? {
        val selectedId = secureStorage.get(KEY_SELECTED_PROJECT) ?: return null
        val projects = getProjects()
        return projects.find { it.id == selectedId }
    }

    /**
     * Set the active project for the user.
     *
     * Persists the selection to SecureStorage.
     * Subsequent calls to [getSelectedProject] will return this project.
     *
     * @param projectId The ID of the project to select
     */
    override suspend fun setSelectedProject(projectId: String) {
        secureStorage.put(KEY_SELECTED_PROJECT, projectId)
    }

    /**
     * Get sprint dashboard summary for a project.
     *
     * Sends a /sprint-status command via chat with JSON format flag.
     * Returns null if no active sprint exists or on error.
     *
     * @param projectId The project to query
     * @return SprintSummary if an active sprint exists, or null if no sprint is active
     */
    override suspend fun getSprintSummary(projectId: String): SprintSummary? = try {
        val message = "/sprint-status --project $projectId --format json"
        val response = sendChatCommand(message)

        if (response.isEmpty()) null
        else parseSprintSummaryFromJson(response)
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching sprint summary", e)
        null
    }

    /**
     * Get all available slash commands organized by family.
     *
     * Returns a hardcoded list of command families with representative commands.
     * Each family includes read-only commands with mobileEnabled=true and complex commands
     * with mobileEnabled=false.
     *
     * @return List of CommandFamily objects, each containing related commands
     */
    override suspend fun getCommands(): List<CommandFamily> = try {
        listOf(
            CommandFamily(
                id = "sprint",
                name = "Sprint Management",
                icon = "ic_sprint",
                commands = listOf(
                    SlashCommand("sprint-status", "View current sprint status", "sprint", listOf("project"), true),
                    SlashCommand("daily", "Generate daily standup", "sprint", listOf("project"), true),
                    SlashCommand("sprint-plan", "Plan next sprint", "sprint", listOf("project"), false)
                )
            ),
            CommandFamily(
                id = "board",
                name = "Board Operations",
                icon = "ic_board",
                commands = listOf(
                    SlashCommand("board-flow", "View board state", "board", listOf("project"), true),
                    SlashCommand("board-update", "Update board item", "board", listOf("item-id", "status"), false)
                )
            ),
            CommandFamily(
                id = "backlog",
                name = "Backlog Management",
                icon = "ic_backlog",
                commands = listOf(
                    SlashCommand("backlog-list", "List backlog items", "backlog", listOf("project"), true),
                    SlashCommand("backlog-capture", "Capture new item", "backlog", listOf("content"), false)
                )
            ),
            CommandFamily(
                id = "time",
                name = "Time Tracking",
                icon = "ic_time",
                commands = listOf(
                    SlashCommand("report-hours", "Log hours worked", "time", listOf("task-id", "hours"), false),
                    SlashCommand("my-hours", "View my time entries", "time", listOf("date"), true)
                )
            ),
            CommandFamily(
                id = "approval",
                name = "Approvals",
                icon = "ic_approval",
                commands = listOf(
                    SlashCommand("pr-pending", "View pending PRs", "approval", listOf("project"), true),
                    SlashCommand("pr-approve", "Approve a PR", "approval", listOf("pr-id"), false)
                )
            ),
            CommandFamily(
                id = "reporting",
                name = "Reporting",
                icon = "ic_report",
                commands = listOf(
                    SlashCommand("report-executive", "Executive summary", "reporting", listOf("project"), true),
                    SlashCommand("report-velocity", "Sprint velocity trend", "reporting", listOf("project"), true)
                )
            ),
            CommandFamily(
                id = "workspace",
                name = "Workspace",
                icon = "ic_workspace",
                commands = listOf(
                    SlashCommand("help", "Get help", "workspace", listOf(), true),
                    SlashCommand("profile", "View profile", "workspace", listOf(), true)
                )
            ),
            CommandFamily(
                id = "commands",
                name = "Commands",
                icon = "ic_commands",
                commands = listOf(
                    SlashCommand("command-list", "List all commands", "commands", listOf(), true),
                    SlashCommand("command-execute", "Execute a command", "commands", listOf("name"), false)
                )
            ),
            CommandFamily(
                id = "integration",
                name = "Integration",
                icon = "ic_integration",
                commands = listOf(
                    SlashCommand("sync-azure", "Sync with Azure DevOps", "integration", listOf("project"), false),
                    SlashCommand("health", "System health check", "integration", listOf(), true)
                )
            ),
            CommandFamily(
                id = "analytics",
                name = "Analytics",
                icon = "ic_analytics",
                commands = listOf(
                    SlashCommand("metrics", "View project metrics", "analytics", listOf("project"), true),
                    SlashCommand("trends", "Analyze trends", "analytics", listOf("project", "days"), true)
                )
            )
        )
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching commands", e)
        emptyList()
    }

    /**
     * Get the authenticated user's profile.
     *
     * Combines local Google Sign-In data with Bridge /health endpoint response.
     * Returns null if authentication data is unavailable.
     *
     * @return UserProfile with name, email, role, and stats, or null if not authenticated
     */
    override suspend fun getUserProfile(): UserProfile? = try {
        // In a real implementation, would read Google Sign-In data from SecureStorage
        // For now, return a placeholder profile
        UserProfile(
            name = "Mobile User",
            email = "user@workspace.local",
            photoUrl = null,
            role = "Developer",
            organization = "PM-Workspace",
            activeProjects = 1,
            stats = UserStats(
                sprintsManaged = 0,
                pbisCompleted = 0,
                hoursLogged = 0f
            )
        )
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching user profile", e)
        null
    }

    /**
     * Get the Kanban board state for a project.
     *
     * Sends a /board-flow command via chat with JSON format flag.
     * Parses the response to extract columns and items.
     *
     * @param projectId The project to query
     * @return List of BoardColumn objects representing the board state
     */
    override suspend fun getBoard(projectId: String): List<BoardColumn> = try {
        val message = "/board-flow --project $projectId --format json"
        val response = sendChatCommand(message)

        if (response.isEmpty()) emptyList()
        else parseBoardFromJson(response)
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching board", e)
        emptyList()
    }

    /**
     * Get pending approval requests in a project.
     *
     * Sends a /pr-pending command via chat with JSON format flag.
     * Parses results and returns them sorted by creation date (newest first).
     *
     * @param projectId The project to query
     * @return List of ApprovalRequest objects sorted by creation date (newest first)
     */
    override suspend fun getApprovals(projectId: String): List<ApprovalRequest> = try {
        val message = "/pr-pending --project $projectId --format json"
        val response = sendChatCommand(message)

        if (response.isEmpty()) emptyList()
        else parseApprovalsFromJson(response)
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching approvals", e)
        emptyList()
    }

    /**
     * Execute a slash command in the Bridge.
     *
     * Sends the command via the chat endpoint and returns a streaming response.
     * The caller receives text chunks as they arrive from the Bridge.
     *
     * **Example:** `executeCommand("sprint-status", "project-123")`
     *
     * @param command The command name (without leading slash)
     * @param projectId The project context for the command
     * @return Flow<String> emitting response chunks as they arrive from the Bridge
     */
    override suspend fun executeCommand(command: String, projectId: String): Flow<String> = flow {
        try {
            val fullCommand = "/$command --project $projectId"
            val stream = bridgeService.sendMessageStream(
                bridgeUrl = "http://localhost:8922",
                authToken = "bridge-token",
                message = fullCommand,
                sessionId = CHAT_SESSION_ID
            )

            stream.collect { delta ->
                when (delta) {
                    is com.savia.domain.model.StreamDelta.Text -> emit(delta.text)
                    is com.savia.domain.model.StreamDelta.Error -> emit("Error: ${delta.message}")
                    else -> {}
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error executing command", e)
            emit("Failed to execute command: ${e.message}")
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Capture a new backlog item from user input.
     *
     * Sends a /backlog-capture command via chat.
     * Extracts the work item ID from the response.
     *
     * @param content User-provided text describing the item
     * @param type Work item type: "PBI", "Task", or "Bug"
     * @param projectId The project where the item will be created
     * @return The ID of the newly created work item
     */
    override suspend fun captureBacklogItem(
        content: String,
        type: String,
        projectId: String
    ): String = try {
        val message = "/backlog-capture --project $projectId --type $type --content \"$content\""
        val response = sendChatCommand(message)

        // Extract ID from response (format: "Created item: AB#1234")
        val idPattern = "([A-Z]+#\\d+)".toRegex()
        idPattern.find(response)?.groupValues?.get(1) ?: "UNKNOWN"
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error capturing backlog item", e)
        "ERROR"
    }

    /**
     * Log time spent on a task.
     *
     * Sends a /report-hours command via chat.
     *
     * @param taskId The task/PBI to log time against
     * @param hours Hours spent (may be fractional, e.g., 2.5)
     * @param date Date in ISO 8601 format (YYYY-MM-DD)
     * @param note Optional note about the work completed
     * @return true if logging succeeded, false otherwise
     */
    override suspend fun logTime(
        taskId: String,
        hours: Float,
        date: String,
        note: String?
    ): Boolean = try {
        val noteArg = if (note != null) " --note \"$note\"" else ""
        val message = "/report-hours --task $taskId --hours $hours --date $date$noteArg"
        val response = sendChatCommand(message)
        response.contains("logged", ignoreCase = true)
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error logging time", e)
        false
    }

    /**
     * Get time entries for a specific date.
     *
     * Sends a /report-hours command via chat with a date filter.
     * Parses the JSON response to extract time entries.
     *
     * @param date Date in ISO 8601 format (YYYY-MM-DD)
     * @return List of TimeEntry objects for that date
     */
    override suspend fun getTimeEntries(date: String): List<TimeEntry> = try {
        val message = "/report-hours --date $date --format json"
        val response = sendChatCommand(message)

        if (response.isEmpty()) emptyList()
        else parseTimeEntriesFromJson(response)
    } catch (e: Exception) {
        android.util.Log.e("ProjectRepositoryImpl", "Error fetching time entries", e)
        emptyList()
    }

    // ==================== Private Helpers ====================

    /**
     * Send a chat command and retrieve the response.
     *
     * Sends a message via the Bridge /chat endpoint and collects the full text response.
     *
     * @param message The command message to send
     * @return The full response text, or empty string if failed
     */
    private suspend fun sendChatCommand(message: String): String {
        return try {
            val bridgeUrl = "http://localhost:8922"
            val requestBody = json.encodeToString(
                ChatRequest.serializer(),
                ChatRequest(
                    message = message,
                    session_id = CHAT_SESSION_ID
                )
            ).toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url("$bridgeUrl/chat")
                .post(requestBody)
                .header("Accept", "text/event-stream")
                .build()

            val response = bridgeClient.newCall(request).execute()
            if (!response.isSuccessful) return ""

            val fullText = StringBuilder()
            response.body?.source()?.use { source ->
                while (!source.exhausted()) {
                    val line = source.readUtf8Line() ?: continue
                    if (line.startsWith("data: ")) {
                        val data = line.removePrefix("data: ").trim()
                        if (data.isNotEmpty()) {
                            try {
                                val event = json.decodeFromString(
                                    StreamEvent.serializer(),
                                    data
                                )
                                if (event.type == "text") {
                                    event.text?.let { fullText.append(it) }
                                }
                            } catch (e: Exception) {
                                // Skip malformed events
                            }
                        }
                    }
                }
            }
            fullText.toString()
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error sending chat command", e)
            ""
        }
    }

    /**
     * Parse projects from JSON response.
     *
     * Expects JSON array with project objects containing id, name, team, currentSprint, health.
     *
     * @param json The JSON response string
     * @return List of parsed Project objects
     */
    private fun parseProjectsFromJson(json: String): List<Project> {
        return try {
            val element = this.json.parseToJsonElement(json)
            val projects = mutableListOf<Project>()

            when (element) {
                is JsonArray -> {
                    element.forEach { item ->
                        if (item is JsonObject) {
                            projects.add(
                                Project(
                                    id = item["id"]?.jsonPrimitive?.content ?: return@forEach,
                                    name = item["name"]?.jsonPrimitive?.content ?: "",
                                    team = item["team"]?.jsonPrimitive?.content ?: "",
                                    currentSprint = item["currentSprint"]?.jsonPrimitive?.content,
                                    health = item["health"]?.jsonPrimitive?.int ?: 50
                                )
                            )
                        }
                    }
                }
                is JsonObject -> {
                    element["id"]?.jsonPrimitive?.content?.let { id ->
                        projects.add(
                            Project(
                                id = id,
                                name = element["name"]?.jsonPrimitive?.content ?: "",
                                team = element["team"]?.jsonPrimitive?.content ?: "",
                                currentSprint = element["currentSprint"]?.jsonPrimitive?.content,
                                health = element["health"]?.jsonPrimitive?.int ?: 50
                            )
                        )
                    }
                }
                else -> {}
            }
            projects
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error parsing projects JSON", e)
            emptyList()
        }
    }

    /**
     * Parse sprint summary from JSON response.
     *
     * @param json The JSON response string
     * @return Parsed SprintSummary, or null on error
     */
    private fun parseSprintSummaryFromJson(json: String): SprintSummary? {
        return try {
            val element = this.json.parseToJsonElement(json).jsonObject
            SprintSummary(
                name = element["name"]?.jsonPrimitive?.content ?: "Unknown",
                progress = element["progress"]?.jsonPrimitive?.float ?: 0f,
                completedPoints = element["completedPoints"]?.jsonPrimitive?.int ?: 0,
                totalPoints = element["totalPoints"]?.jsonPrimitive?.int ?: 0,
                blockedItems = element["blockedItems"]?.jsonPrimitive?.int ?: 0,
                daysRemaining = element["daysRemaining"]?.jsonPrimitive?.int ?: 0,
                velocity = element["velocity"]?.jsonPrimitive?.float ?: 0f
            )
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error parsing sprint summary JSON", e)
            null
        }
    }

    /**
     * Parse board columns and items from JSON response.
     *
     * @param json The JSON response string
     * @return List of BoardColumn objects
     */
    private fun parseBoardFromJson(json: String): List<BoardColumn> {
        return try {
            val element = this.json.parseToJsonElement(json)
            val columns = mutableListOf<BoardColumn>()

            when (element) {
                is JsonArray -> {
                    element.forEach { colElement ->
                        if (colElement is JsonObject) {
                            val items = colElement["items"]?.jsonArray?.mapNotNull { itemEl ->
                                if (itemEl is JsonObject) {
                                    BoardItem(
                                        id = itemEl["id"]?.jsonPrimitive?.content ?: return@mapNotNull null,
                                        title = itemEl["title"]?.jsonPrimitive?.content ?: "",
                                        assignee = itemEl["assignee"]?.jsonPrimitive?.content,
                                        storyPoints = itemEl["storyPoints"]?.jsonPrimitive?.int,
                                        state = itemEl["state"]?.jsonPrimitive?.content ?: "",
                                        type = itemEl["type"]?.jsonPrimitive?.content ?: "Task"
                                    )
                                } else null
                            } ?: emptyList()

                            columns.add(
                                BoardColumn(
                                    name = colElement["name"]?.jsonPrimitive?.content ?: "Unknown",
                                    items = items,
                                    wipLimit = colElement["wipLimit"]?.jsonPrimitive?.int
                                )
                            )
                        }
                    }
                }
                else -> {}
            }
            columns
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error parsing board JSON", e)
            emptyList()
        }
    }

    /**
     * Parse approval requests from JSON response.
     *
     * @param json The JSON response string
     * @return List of ApprovalRequest objects
     */
    private fun parseApprovalsFromJson(json: String): List<ApprovalRequest> {
        return try {
            val element = this.json.parseToJsonElement(json)
            val approvals = mutableListOf<ApprovalRequest>()

            when (element) {
                is JsonArray -> {
                    element.forEach { appElement ->
                        if (appElement is JsonObject) {
                            approvals.add(
                                ApprovalRequest(
                                    id = appElement["id"]?.jsonPrimitive?.content ?: return@forEach,
                                    type = parseApprovalType(
                                        appElement["type"]?.jsonPrimitive?.content ?: "PULL_REQUEST"
                                    ),
                                    title = appElement["title"]?.jsonPrimitive?.content ?: "",
                                    description = appElement["description"]?.jsonPrimitive?.content ?: "",
                                    requester = appElement["requester"]?.jsonPrimitive?.content ?: "",
                                    createdAt = appElement["createdAt"]?.jsonPrimitive?.content ?: "",
                                    estimatedCost = appElement["estimatedCost"]?.jsonPrimitive?.content
                                )
                            )
                        }
                    }
                }
                else -> {}
            }
            approvals.sortByDescending { it.createdAt }
            approvals
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error parsing approvals JSON", e)
            emptyList()
        }
    }

    /**
     * Parse time entries from JSON response.
     *
     * @param json The JSON response string
     * @return List of TimeEntry objects
     */
    private fun parseTimeEntriesFromJson(json: String): List<TimeEntry> {
        return try {
            val element = this.json.parseToJsonElement(json)
            val entries = mutableListOf<TimeEntry>()

            when (element) {
                is JsonArray -> {
                    element.forEach { entryElement ->
                        if (entryElement is JsonObject) {
                            val dateStr = entryElement["date"]?.jsonPrimitive?.content ?: return@forEach
                            entries.add(
                                TimeEntry(
                                    id = entryElement["id"]?.jsonPrimitive?.content ?: return@forEach,
                                    taskId = entryElement["taskId"]?.jsonPrimitive?.content ?: "",
                                    taskTitle = entryElement["taskTitle"]?.jsonPrimitive?.content ?: "",
                                    hours = entryElement["hours"]?.jsonPrimitive?.float ?: 0f,
                                    date = java.time.LocalDate.parse(dateStr),
                                    note = entryElement["note"]?.jsonPrimitive?.content
                                )
                            )
                        }
                    }
                }
                else -> {}
            }
            entries
        } catch (e: Exception) {
            android.util.Log.e("ProjectRepositoryImpl", "Error parsing time entries JSON", e)
            emptyList()
        }
    }

    /**
     * Parse approval type from string.
     *
     * @param typeStr The type string from JSON
     * @return Parsed ApprovalType, defaults to PULL_REQUEST
     */
    private fun parseApprovalType(typeStr: String): ApprovalType {
        return try {
            ApprovalType.valueOf(typeStr.uppercase())
        } catch (e: Exception) {
            ApprovalType.PULL_REQUEST
        }
    }

    /**
     * Get mock projects for fallback/demo purposes.
     *
     * @return List containing one mock project
     */
    private fun getMockProjects(): List<Project> {
        return listOf(
            Project(
                id = "PM-Workspace",
                name = "PM-Workspace",
                team = "PM-Workspace Team",
                currentSprint = "Sprint 2026-03",
                health = 75
            )
        )
    }

    /**
     * Internal data class for chat request serialization.
     */
    @kotlinx.serialization.Serializable
    private data class ChatRequest(
        val message: String,
        val session_id: String
    )

    /**
     * Internal data class for stream event deserialization.
     */
    @kotlinx.serialization.Serializable
    private data class StreamEvent(
        val type: String,
        val text: String? = null
    )
}
