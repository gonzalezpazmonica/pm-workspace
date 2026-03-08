package com.savia.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class GitConfig(
    val name: String = "",
    val email: String = "",
    val credentialHelper: String = "",
    val patConfigured: Boolean = false,
    val remoteUrl: String = ""
)
