package com.savia.domain.model

/**
 * Kanban board column with work items.
 *
 * Represents a column in a Kanban board, containing items at that stage of work.
 *
 * @property name Name of the column (e.g., "In Progress", "Done")
 * @property items List of work items currently in this column
 * @property wipLimit Optional work-in-progress limit for this column
 */
data class BoardColumn(
    val name: String,
    val items: List<BoardItem>,
    val wipLimit: Int?
)

/**
 * A single work item on a Kanban board.
 *
 * Represents a PBI, Task, or Bug that is being tracked through the workflow.
 *
 * @property id Unique identifier of the work item
 * @property title Title or summary of the work item
 * @property assignee Email or name of the person assigned (null if unassigned)
 * @property storyPoints Story point estimate (null if not estimated)
 * @property state Current state (e.g., "Active", "Blocked")
 * @property type Work item type: "PBI", "Bug", or "Task"
 */
data class BoardItem(
    val id: String,
    val title: String,
    val assignee: String?,
    val storyPoints: Int?,
    val state: String,
    val type: String  // "PBI", "Bug", "Task"
)
