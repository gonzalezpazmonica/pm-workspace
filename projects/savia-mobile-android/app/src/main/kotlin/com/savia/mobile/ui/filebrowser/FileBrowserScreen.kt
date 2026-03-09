package com.savia.mobile.ui.filebrowser

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.NavigateNext
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.data.api.FileEntry
import com.savia.mobile.ui.theme.AssistantBubbleColor
import com.savia.mobile.ui.theme.AssistantBubbleTextColor
import io.noties.markwon.Markwon
import io.noties.markwon.ext.strikethrough.StrikethroughPlugin
import io.noties.markwon.ext.tables.TablePlugin

/**
 * File browser screen for navigating PM-Workspace files.
 *
 * Two modes:
 * - Directory listing: shows folders and files with icons, size, modified date
 * - File viewer: displays code with monospace font or markdown with rendering
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileBrowserScreen(
    viewModel: FileBrowserViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    BackHandler {
        if (!viewModel.navigateBack()) onNavigateBack()
    }

    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = {
                    IconButton(onClick = {
                        if (!viewModel.navigateBack()) onNavigateBack()
                    }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                title = {
                    if (uiState.isViewingFile) {
                        Text(
                            text = uiState.fileContent?.name ?: "File",
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    } else {
                        Text("Files")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (uiState.isLoading) {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (uiState.isViewingFile && uiState.fileContent != null) {
                FileContentViewer(
                    content = uiState.fileContent!!.content,
                    extension = uiState.fileContent!!.extension,
                    lines = uiState.fileContent!!.lines
                )
            } else {
                // Breadcrumbs
                BreadcrumbBar(
                    breadcrumbs = uiState.breadcrumbs,
                    onNavigate = { viewModel.loadDirectory(it) }
                )
                HorizontalDivider()
                // File list
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 4.dp)
                ) {
                    items(uiState.entries, key = { it.path }) { entry ->
                        FileEntryRow(
                            entry = entry,
                            onClick = { viewModel.onEntryClick(entry) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BreadcrumbBar(
    breadcrumbs: List<String>,
    onNavigate: (String) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        breadcrumbs.forEachIndexed { index, path ->
            val label = if (path.isEmpty()) "workspace" else path.substringAfterLast("/")
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                color = if (index == breadcrumbs.lastIndex)
                    MaterialTheme.colorScheme.primary
                else
                    MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.clickable { onNavigate(path) }
            )
            if (index < breadcrumbs.lastIndex) {
                Icon(
                    Icons.Filled.NavigateNext,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun FileEntryRow(entry: FileEntry, onClick: () -> Unit) {
    val icon = when {
        entry.type == "directory" -> Icons.Filled.Folder
        entry.extension in listOf(".md", ".txt") -> Icons.Filled.Description
        entry.extension in listOf(".kt", ".java", ".py", ".js", ".ts", ".sh") -> Icons.Filled.Code
        else -> Icons.AutoMirrored.Filled.InsertDriveFile
    }
    val iconTint = when {
        entry.type == "directory" -> MaterialTheme.colorScheme.primary
        entry.extension == ".md" -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(24.dp))
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = entry.name,
                style = MaterialTheme.typography.bodyLarge,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (entry.type == "file" && entry.size > 0) {
                Text(
                    text = formatFileSize(entry.size),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        if (entry.type == "directory") {
            Icon(
                Icons.Filled.NavigateNext,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

@Composable
private fun FileContentViewer(content: String, extension: String, lines: Int) {
    val isMarkdown = extension in listOf(".md", ".mermaid")

    Column(modifier = Modifier.fillMaxSize()) {
        // File info bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "$lines lines",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = extension.uppercase().removePrefix("."),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary
            )
        }
        HorizontalDivider()

        if (isMarkdown) {
            // Render markdown
            Card(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(8.dp),
                colors = CardDefaults.cardColors(containerColor = AssistantBubbleColor),
                shape = RoundedCornerShape(12.dp)
            ) {
                val colorArgb = AssistantBubbleTextColor.toArgb()
                AndroidView(
                    modifier = Modifier.padding(16.dp),
                    factory = { context ->
                        val markwon = Markwon.builder(context)
                            .usePlugin(StrikethroughPlugin.create())
                            .usePlugin(TablePlugin.create(context))
                            .build()
                        android.widget.TextView(context).apply {
                            setTextColor(colorArgb)
                            textSize = 15f
                            setPadding(0, 0, 0, 0)
                            linksClickable = true
                            movementMethod = android.text.method.LinkMovementMethod.getInstance()
                            tag = markwon
                        }
                    },
                    update = { textView ->
                        val markwon = textView.tag as Markwon
                        markwon.setMarkdown(textView, content)
                        textView.setTextColor(colorArgb)
                    }
                )
            }
        } else {
            // Code viewer — monospace with line numbers
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(8.dp)
            ) {
                val codeLines = content.lines()
                items(codeLines.size) { index ->
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "${index + 1}",
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                fontSize = 11.sp
                            ),
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.width(40.dp)
                        )
                        Text(
                            text = codeLines[index],
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp
                            ),
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }
        }
    }
}

private fun formatFileSize(bytes: Long): String = when {
    bytes < 1024 -> "$bytes B"
    bytes < 1024 * 1024 -> "${bytes / 1024} KB"
    else -> "${"%.1f".format(bytes / (1024.0 * 1024.0))} MB"
}
