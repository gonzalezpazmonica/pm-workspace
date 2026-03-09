package com.savia.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class TeamMember(
    val slug: String,
    val name: String = "",
    val role: String = "",
    val email: String = "",
    val hasWorkflow: Boolean = false,
    val hasTools: Boolean = false,
    val hasProjects: Boolean = false
)
