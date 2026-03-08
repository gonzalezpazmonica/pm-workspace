package com.savia.domain.model

/**
 * A PM-Workspace project with current sprint context.
 *
 * Represents a project retrieved from PM-Workspace via the Bridge server,
 * including team structure and active sprint information.
 *
 * @property id Unique identifier for the project
 * @property name Display name of the project
 * @property team Team responsible for the project
 * @property currentSprint Name or ID of the active sprint (null if no active sprint)
 * @property health Project health score from 0 to 100
 */
data class Project(
    val id: String,
    val name: String,
    val team: String,
    val currentSprint: String?,
    val health: Int  // 0-100
)
