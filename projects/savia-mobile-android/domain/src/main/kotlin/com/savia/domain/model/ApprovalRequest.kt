package com.savia.domain.model

/**
 * A pending approval request (PR, infra, deploy).
 *
 * Represents a request awaiting approval in the workflow.
 * Can be a pull request, infrastructure change, or deployment request.
 *
 * @property id Unique identifier for this approval request
 * @property type Classification of the approval request
 * @property title Title of the request
 * @property description Detailed description of what requires approval
 * @property requester Name or email of the person who requested approval
 * @property createdAt ISO 8601 timestamp when the request was created
 * @property estimatedCost Estimated cost impact if applicable (e.g., for infra changes)
 */
data class ApprovalRequest(
    val id: String,
    val type: ApprovalType,
    val title: String,
    val description: String,
    val requester: String,
    val createdAt: String,
    val estimatedCost: String?
)

/**
 * Classification of approval request types.
 *
 * Determines the approval workflow and stakeholders required.
 */
enum class ApprovalType {
    PULL_REQUEST,
    INFRASTRUCTURE,
    DEPLOYMENT
}
