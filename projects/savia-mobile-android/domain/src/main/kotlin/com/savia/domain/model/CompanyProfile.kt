package com.savia.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class CompanyProfile(
    val status: String = "not_configured",
    val identity: CompanySection? = null,
    val structure: CompanySection? = null,
    val strategy: CompanySection? = null,
    val policies: CompanySection? = null,
    val technology: CompanySection? = null,
    val vertical: CompanySection? = null
)

@Serializable
data class CompanySection(
    val fields: Map<String, String> = emptyMap(),
    val content: String = ""
)
