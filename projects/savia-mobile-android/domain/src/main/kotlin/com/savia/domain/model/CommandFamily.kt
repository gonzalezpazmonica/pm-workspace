package com.savia.domain.model

/**
 * A family/category of slash commands available in the workspace.
 *
 * Groups related commands together for organizational and UI purposes.
 * Commands within a family share common functionality domain.
 *
 * @property id Unique identifier for the command family
 * @property name Display name of the family (e.g., "Sprint Management")
 * @property icon Icon identifier or asset name for UI display
 * @property commands List of slash commands in this family
 */
data class CommandFamily(
    val id: String,
    val name: String,
    val icon: String,
    val commands: List<SlashCommand>
)

/**
 * A slash command available to execute in PM-Workspace.
 *
 * Represents an individual command that can be invoked on the mobile app
 * for project management and communication.
 *
 * @property name Command name without leading slash (e.g., "sprint-status")
 * @property description Brief description of what the command does
 * @property family ID of the command family this belongs to
 * @property params List of parameter names the command accepts
 * @property mobileEnabled Whether this command is supported on mobile devices
 */
data class SlashCommand(
    val name: String,
    val description: String,
    val family: String,
    val params: List<String>,
    val mobileEnabled: Boolean
)
