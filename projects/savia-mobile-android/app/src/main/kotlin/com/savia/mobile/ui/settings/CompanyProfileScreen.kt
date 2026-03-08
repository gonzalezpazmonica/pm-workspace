package com.savia.mobile.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompanyProfileScreen(
    viewModel: CompanyProfileViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var editingSection by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(uiState.message) {
        uiState.message?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearMessage()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Company Profile") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) { CircularProgressIndicator() }
        } else if (uiState.status == "not_configured") {
            Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(32.dp)
                ) {
                    Icon(Icons.Default.Business, null, modifier = Modifier.size(48.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(12.dp))
                    Text("Company not configured",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    Text("Create company profile sections in .claude/profiles/company/ or configure them here.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                val sections = listOf(
                    "identity" to "Identity",
                    "structure" to "Structure",
                    "strategy" to "Strategy",
                    "policies" to "Policies",
                    "technology" to "Technology",
                    "vertical" to "Vertical / Industry"
                )

                sections.forEach { (key, label) ->
                    val section = uiState.sections[key]
                    CompanySectionCard(
                        sectionKey = key,
                        sectionLabel = label,
                        fields = section?.fields ?: emptyMap(),
                        content = section?.content ?: "",
                        onEdit = { editingSection = key }
                    )
                }
            }
        }
    }

    // Edit section dialog
    editingSection?.let { sectionKey ->
        val section = uiState.sections[sectionKey]
        val sectionLabel = when(sectionKey) {
            "identity" -> "Identity"
            "structure" -> "Structure"
            "strategy" -> "Strategy"
            "policies" -> "Policies"
            "technology" -> "Technology"
            "vertical" -> "Vertical / Industry"
            else -> sectionKey
        }
        CompanySectionEditDialog(
            title = "Edit $sectionLabel",
            initialFields = section?.fields ?: emptyMap(),
            initialContent = section?.content ?: "",
            onDismiss = { editingSection = null },
            onSave = { fields, content ->
                viewModel.updateSection(sectionKey, fields, content)
                editingSection = null
            }
        )
    }
}

@Composable
private fun CompanySectionCard(
    sectionKey: String,
    sectionLabel: String,
    fields: Map<String, String>,
    content: String,
    onEdit: () -> Unit
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = if (fields.isNotEmpty() || content.isNotEmpty())
                MaterialTheme.colorScheme.surfaceContainerLow
            else MaterialTheme.colorScheme.surfaceContainerLowest
        )
    ) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(sectionLabel, style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold)
                IconButton(onClick = onEdit) {
                    Icon(Icons.Default.Edit, "Edit $sectionLabel",
                        tint = MaterialTheme.colorScheme.primary)
                }
            }

            if (fields.isNotEmpty()) {
                fields.forEach { (key, value) ->
                    if (key != "content") {
                        Row(modifier = Modifier.padding(vertical = 2.dp)) {
                            Text("$key: ", style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(value, style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface)
                        }
                    }
                }
            }

            if (content.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text(content.take(200) + if (content.length > 200) "..." else "",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            if (fields.isEmpty() && content.isEmpty()) {
                Text("Not configured",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun CompanySectionEditDialog(
    title: String,
    initialFields: Map<String, String>,
    initialContent: String,
    onDismiss: () -> Unit,
    onSave: (fields: Map<String, String>, content: String) -> Unit
) {
    // Common fields for company sections
    val commonKeys = listOf("name", "sector", "size", "location", "founded", "mission")
    var fieldValues by remember {
        mutableStateOf(commonKeys.associateWith { initialFields[it] ?: "" }
            .plus(initialFields.filterKeys { it !in commonKeys }))
    }
    var content by remember { mutableStateOf(initialContent) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                fieldValues.forEach { (key, value) ->
                    OutlinedTextField(
                        value = value,
                        onValueChange = { fieldValues = fieldValues.toMutableMap().apply { put(key, it) } },
                        label = { Text(key.replaceFirstChar { it.uppercase() }) },
                        modifier = Modifier.fillMaxWidth(),
                        singleLine = true
                    )
                }
                OutlinedTextField(
                    value = content,
                    onValueChange = { content = it },
                    label = { Text("Description") },
                    modifier = Modifier.fillMaxWidth().height(120.dp),
                    maxLines = 5
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val nonEmptyFields = fieldValues.filterValues { it.isNotBlank() }
                onSave(nonEmptyFields, content)
            }) { Text("Save") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        }
    )
}
