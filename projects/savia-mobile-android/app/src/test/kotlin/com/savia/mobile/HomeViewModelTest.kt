package com.savia.mobile

import com.google.common.truth.Truth.assertThat
import com.savia.domain.model.*
import com.savia.domain.repository.ProjectRepository
import com.savia.mobile.ui.home.HomeViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {

    private val testDispatcher = StandardTestDispatcher()
    private lateinit var viewModel: HomeViewModel
    private lateinit var fakeProjectRepo: FakeProjectRepo

    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        fakeProjectRepo = FakeProjectRepo()
        viewModel = HomeViewModel(fakeProjectRepo)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `initial load populates dashboard data`() = runTest {
        advanceUntilIdle()
        val state = viewModel.uiState.value
        assertThat(state.isLoading).isFalse()
        assertThat(state.selectedProject).isEqualTo("Savia Mobile")
        assertThat(state.availableProjects).hasSize(2)
    }

    @Test
    fun `selectProject updates selected project immediately`() = runTest {
        advanceUntilIdle()
        assertThat(viewModel.uiState.value.selectedProject).isEqualTo("Savia Mobile")

        viewModel.selectProject("project-2")
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.selectedProject).isEqualTo("Savia Bridge")
        assertThat(fakeProjectRepo.selectedProjectId).isEqualTo("project-2")
    }

    @Test
    fun `selectProject persists selection across reloads`() = runTest {
        advanceUntilIdle()

        viewModel.selectProject("project-2")
        advanceUntilIdle()

        // After reload, local selection (project-2) should be respected, not Bridge default
        viewModel.refresh()
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.selectedProject).isEqualTo("Savia Bridge")
    }

    @Test
    fun `clearError resets error state`() = runTest {
        advanceUntilIdle()
        viewModel.clearError()
        assertThat(viewModel.uiState.value.error).isNull()
    }

    @Test
    fun `dashboard error sets error state`() = runTest {
        fakeProjectRepo.shouldFail = true
        viewModel = HomeViewModel(fakeProjectRepo)
        advanceUntilIdle()

        assertThat(viewModel.uiState.value.error).isNotNull()
        assertThat(viewModel.uiState.value.isLoading).isFalse()
    }
}

// --- Fake ---

private class FakeProjectRepo : ProjectRepository {
    var selectedProjectId: String? = "project-1"
    var shouldFail = false

    private val projects = listOf(
        Project(id = "project-1", name = "Savia Mobile", team = "Mobile Team", currentSprint = "Sprint 1", health = 80),
        Project(id = "project-2", name = "Savia Bridge", team = "Platform Team", currentSprint = "Sprint 1", health = 90)
    )

    override suspend fun getDashboard(): DashboardData? {
        if (shouldFail) throw RuntimeException("Connection failed")
        return DashboardData(
            greeting = "Hola, la usuaria",
            projects = projects,
            selectedProjectId = "project-1", // Bridge always returns its default
            sprint = SprintSummary(
                name = "Sprint 1", progress = 0.5f, completedPoints = 10,
                totalPoints = 20, blockedItems = 1, daysRemaining = 5, velocity = 18f
            ),
            myTasks = emptyList(),
            recentActivity = listOf("Task completed"),
            blockedItems = 1,
            hoursToday = 2.5f
        )
    }

    override suspend fun getSelectedProject(): Project? {
        return projects.find { it.id == selectedProjectId }
    }

    override suspend fun setSelectedProject(projectId: String) {
        selectedProjectId = projectId
    }

    override suspend fun getProjects() = projects
    override suspend fun getSprintSummary(projectId: String): SprintSummary? = null
    override suspend fun getCommands(): List<CommandFamily> = emptyList()
    override suspend fun getUserProfile(): UserProfile? = null
    override suspend fun getBoard(projectId: String): List<BoardColumn> = emptyList()
    override suspend fun getApprovals(projectId: String): List<ApprovalRequest> = emptyList()
    override suspend fun executeCommand(command: String, projectId: String): Flow<String> = flowOf()
    override suspend fun captureBacklogItem(content: String, type: String, projectId: String) = "WI-001"
    override suspend fun logTime(taskId: String, hours: Float, date: String, note: String?) = true
    override suspend fun getTimeEntries(date: String): List<TimeEntry> = emptyList()
    override suspend fun getGitConfig(): GitConfig? = null
    override suspend fun updateGitConfig(config: GitConfig) = true
    override suspend fun getTeamMembers(): List<TeamMember> = emptyList()
    override suspend fun addTeamMember(slug: String, identity: Map<String, String>) = true
    override suspend fun updateTeamMember(slug: String, identity: Map<String, String>) = true
    override suspend fun removeTeamMember(slug: String) = true
    override suspend fun getCompanyProfile(): CompanyProfile? = null
    override suspend fun updateCompanySection(section: String, fields: Map<String, String>, content: String) = true
}
