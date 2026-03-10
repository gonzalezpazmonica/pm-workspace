package com.savia.mobile.ui.chat

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.window.PopupProperties
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.Image
import io.noties.markwon.Markwon
import io.noties.markwon.ext.strikethrough.StrikethroughPlugin
import io.noties.markwon.ext.tables.TablePlugin
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.mobile.R
import com.savia.mobile.ui.common.SaviaLogo
import com.savia.mobile.ui.common.VersionBadge
import com.savia.mobile.ui.theme.AssistantBubbleColor
import com.savia.mobile.ui.theme.AssistantBubbleTextColor
import com.savia.mobile.ui.theme.UserBubbleColor
import com.savia.mobile.ui.theme.UserBubbleTextColor
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Main chat interface for conversing with Claude via Savia Bridge or Anthropic API.
 *
 * Features:
 * - Message history display with auto-scroll to bottom
 * - Real-time message streaming (assistant responses displayed as text arrives)
 * - User and assistant message bubbles with distinct colors
 * - Markdown rendering for assistant messages (bold, italics, tables, strikethrough)
 * - Connection setup UI (Bridge or API key configuration)
 * - Slash command auto-complete menu
 * - Error handling with snackbar notifications
 * - Conversation history persistence
 * - Navigation support for loading previous conversations
 *
 * Clean Architecture Role: UI Layer (Presentation)
 * - ChatViewModel manages state and business logic
 * - ChatUiState holds reactive message list, streaming status, configuration
 * - Composable functions handle pure UI rendering
 *
 * @param viewModel ChatViewModel providing state and message sending logic
 * @param conversationIdToLoad optional conversation ID to load (from Sessions tab navigation)
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel = hiltViewModel(),
    conversationIdToLoad: String? = null,
    commandToPreFill: String? = null
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    val listState = rememberLazyListState()

    // Load conversation if navigated from sessions list
    LaunchedEffect(conversationIdToLoad) {
        conversationIdToLoad?.let { viewModel.loadConversation(it) }
    }

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(uiState.messages.size, uiState.streamingText) {
        if (uiState.messages.isNotEmpty() || uiState.streamingText.isNotEmpty()) {
            val targetIndex = uiState.messages.size + if (uiState.streamingText.isNotEmpty()) 1 else 0
            if (targetIndex > 0) {
                try {
                    listState.animateScrollToItem(targetIndex - 1)
                } catch (_: Exception) {
                    // Race condition: list size changed during scroll animation
                }
            }
        }
    }

    // Show errors
    LaunchedEffect(uiState.error) {
        uiState.error?.let {
            snackbarHostState.showSnackbar(it)
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                navigationIcon = { SaviaLogo(modifier = Modifier.padding(start = 12.dp)) },
                title = {
                    Text(
                        text = "Savia",
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                actions = {
                    VersionBadge()
                    IconButton(onClick = { viewModel.startNewConversation() }) {
                        Icon(
                            Icons.Default.Add,
                            contentDescription = stringResource(R.string.new_conversation)
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        // Permission request dialog
        uiState.pendingPermission?.let { permission ->
            PermissionRequestDialog(
                permission = permission,
                onAllow = { viewModel.respondToPermission(allow = true) },
                onDeny = { viewModel.respondToPermission(allow = false) }
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .imePadding()
        ) {
            if (!uiState.isConfigured) {
                ConnectionSetup(
                    onBridgeConfigSaved = { host, port, token ->
                        viewModel.saveBridgeConfig(host, port, token)
                    },
                    onApiKeySaved = { viewModel.saveApiKey(it) }
                )
            } else {
                // Messages list
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    state = listState,
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (uiState.messages.isEmpty() && !uiState.isStreaming) {
                        item {
                            WelcomeMessage()
                        }
                    }

                    items(uiState.messages, key = { it.id }) { message ->
                        MessageBubble(message = message)
                    }

                    // Streaming message
                    if (uiState.streamingText.isNotEmpty()) {
                        item {
                            StreamingBubble(text = uiState.streamingText)
                        }
                    }

                    // Loading indicator
                    if (uiState.isStreaming && uiState.streamingText.isEmpty()) {
                        item {
                            TypingIndicator()
                        }
                    }
                }

                // Input bar — always enabled (non-blocking chat)
                ChatInput(
                    isStreaming = uiState.isStreaming,
                    pendingMessageCount = uiState.pendingMessageCount,
                    initialText = commandToPreFill,
                    onSend = { viewModel.sendMessage(it) }
                )
            }
        }
    }
}

@Composable
private fun MessageBubble(message: Message) {
    val isUser = message.role == MessageRole.USER
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val timeText = remember(message.timestamp) { timeFormat.format(Date(message.timestamp)) }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        Card(
            modifier = Modifier.widthIn(max = screenWidth * 0.8f),
            shape = RoundedCornerShape(
                topStart = 16.dp,
                topEnd = 16.dp,
                bottomStart = if (isUser) 16.dp else 4.dp,
                bottomEnd = if (isUser) 4.dp else 16.dp
            ),
            colors = CardDefaults.cardColors(
                containerColor = if (isUser) UserBubbleColor else AssistantBubbleColor
            )
        ) {
            Column(modifier = Modifier.padding(start = 12.dp, end = 12.dp, top = 12.dp, bottom = 6.dp)) {
                if (isUser) {
                    Text(
                        text = message.content,
                        color = UserBubbleTextColor,
                        style = MaterialTheme.typography.bodyLarge
                    )
                } else {
                    MarkdownText(
                        markdown = message.content,
                        color = AssistantBubbleTextColor
                    )
                }
                Text(
                    text = timeText,
                    modifier = Modifier.align(Alignment.End),
                    color = if (isUser) UserBubbleTextColor.copy(alpha = 0.6f)
                            else AssistantBubbleTextColor.copy(alpha = 0.5f),
                    style = MaterialTheme.typography.labelSmall
                )
            }
        }
    }
}

/**
 * Streaming message bubble with inline spinner to show response in progress.
 * The spinner appears at the bottom of the bubble so users know the response
 * is still arriving — distinct from the input area which stays enabled.
 */
@Composable
private fun StreamingBubble(text: String) {
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Card(
            modifier = Modifier.widthIn(max = screenWidth * 0.8f),
            shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomEnd = 16.dp, bottomStart = 4.dp),
            colors = CardDefaults.cardColors(containerColor = AssistantBubbleColor)
        ) {
            Column(modifier = Modifier.padding(12.dp)) {
                MarkdownText(
                    markdown = text,
                    color = AssistantBubbleTextColor
                )
                Spacer(modifier = Modifier.height(6.dp))
                CircularProgressIndicator(
                    modifier = Modifier.size(14.dp),
                    color = AssistantBubbleTextColor.copy(alpha = 0.5f),
                    strokeWidth = 1.5.dp
                )
            }
        }
    }
}

@Composable
private fun TypingIndicator() {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Start
    ) {
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = AssistantBubbleColor)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                repeat(3) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f))
                    )
                }
                Spacer(modifier = Modifier.size(4.dp))
                Text(
                    text = stringResource(R.string.savia_typing),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun WelcomeMessage() {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Image(
            painter = painterResource(R.drawable.savia_logo),
            contentDescription = "Savia logo",
            modifier = Modifier.size(80.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.welcome_title),
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.welcome_subtitle),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

private data class SlashCommand(
    val command: String,
    val description: String,
    val icon: String
)

private val slashCommands = listOf(
    SlashCommand("/nueva", "Nueva conversación", "➕"),
    SlashCommand("/borrar", "Borrar conversación actual", "🗑️"),
    SlashCommand("/sesiones", "Ver sesiones activas", "📋"),
    SlashCommand("/estado", "Estado del bridge", "🔗"),
    SlashCommand("/perfil", "Ver tu perfil de usuario", "👤"),
    SlashCommand("/ayuda", "Mostrar comandos disponibles", "❓"),
    SlashCommand("/sistema", "Enviar instrucción de sistema", "⚙️"),
    SlashCommand("/exportar", "Exportar conversación", "📤"),
)

/**
 * Chat input bar — non-blocking design.
 *
 * The input field stays enabled even while Savia is streaming a response.
 * Users can type and send multiple messages without waiting; messages queue
 * and are processed sequentially (FIFO). The spinner appears on the
 * StreamingBubble, not here.
 *
 * When messages are queued, a small badge shows the pending count next to
 * the send button to provide feedback that messages are waiting.
 *
 * @param isStreaming whether a response is currently streaming
 * @param pendingMessageCount number of messages queued and waiting to be sent
 * @param onSend callback to queue a new user message
 */
@Composable
private fun ChatInput(
    isStreaming: Boolean,
    pendingMessageCount: Int = 0,
    initialText: String? = null,
    onSend: (String) -> Unit
) {
    var text by remember(initialText) { mutableStateOf(initialText ?: "") }
    val showSlashMenu = text.startsWith("/") && !text.contains(" ")
    val filteredCommands = if (showSlashMenu) {
        slashCommands.filter { it.command.startsWith(text, ignoreCase = true) }
    } else emptyList()

    // Use Box so the popup overlays above the input
    Box(modifier = Modifier.fillMaxWidth()) {
        // Input row at bottom
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier.weight(1f),
                placeholder = {
                    Text(
                        if (isStreaming && pendingMessageCount > 0)
                            stringResource(R.string.chat_input_hint) + " ($pendingMessageCount)"
                        else
                            stringResource(R.string.chat_input_hint)
                    )
                },
                shape = RoundedCornerShape(24.dp),
                maxLines = 4,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(
                    onSend = {
                        if (text.isNotBlank()) {
                            onSend(text)
                            text = ""
                        }
                    }
                ),
                enabled = true // Always enabled — non-blocking chat
            )

            // Send button with optional pending badge
            Box {
                FloatingActionButton(
                    onClick = {
                        if (text.isNotBlank()) {
                            onSend(text)
                            text = ""
                        }
                    },
                    modifier = Modifier.size(48.dp),
                    containerColor = MaterialTheme.colorScheme.primary,
                    shape = CircleShape
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = stringResource(R.string.send),
                        tint = MaterialTheme.colorScheme.onPrimary
                    )
                }
                // Pending message count badge
                if (pendingMessageCount > 0) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.TopEnd)
                            .size(18.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.error),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = pendingMessageCount.toString(),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onError
                        )
                    }
                }
            }
        }

        // Slash commands popup — anchored above the input
        DropdownMenu(
            expanded = filteredCommands.isNotEmpty(),
            onDismissRequest = { /* user types something else to dismiss */ },
            modifier = Modifier
                .fillMaxWidth(0.92f)
                .heightIn(max = 280.dp),
            properties = PopupProperties(focusable = false)
        ) {
            filteredCommands.forEach { cmd ->
                DropdownMenuItem(
                    text = {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            Text(
                                text = cmd.icon,
                                style = MaterialTheme.typography.bodyLarge
                            )
                            Column {
                                Text(
                                    text = cmd.command,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.primary
                                )
                                Text(
                                    text = cmd.description,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    },
                    onClick = {
                        text = cmd.command + " "
                    }
                )
            }
        }
    }
}

@Composable
private fun ConnectionSetup(
    onBridgeConfigSaved: (String, Int, String) -> Unit,
    onApiKeySaved: (String) -> Unit
) {
    var host by remember { mutableStateOf("") }
    var port by remember { mutableStateOf("8922") }
    var token by remember { mutableStateOf("") }
    var showApiKeyOption by remember { mutableStateOf(false) }
    var apiKey by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Image(
            painter = painterResource(R.drawable.savia_logo),
            contentDescription = "Savia logo",
            modifier = Modifier.size(96.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.setup_title),
            style = MaterialTheme.typography.headlineMedium,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.setup_bridge_description),
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.height(24.dp))

        // Bridge host
        OutlinedTextField(
            value = host,
            onValueChange = { host = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.bridge_host_label)) },
            placeholder = { Text("192.168.1.100") },
            singleLine = true,
            shape = RoundedCornerShape(12.dp)
        )
        Spacer(modifier = Modifier.height(12.dp))

        // Bridge port
        OutlinedTextField(
            value = port,
            onValueChange = { port = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.bridge_port_label)) },
            placeholder = { Text("8922") },
            singleLine = true,
            shape = RoundedCornerShape(12.dp)
        )
        Spacer(modifier = Modifier.height(12.dp))

        // Auth token
        OutlinedTextField(
            value = token,
            onValueChange = { token = it },
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.bridge_token_label)) },
            placeholder = { Text("token...") },
            singleLine = true,
            shape = RoundedCornerShape(12.dp)
        )
        Spacer(modifier = Modifier.height(20.dp))

        // Connect button
        androidx.compose.material3.Button(
            onClick = {
                val portNum = port.toIntOrNull() ?: 8922
                if (host.isNotBlank() && token.isNotBlank()) {
                    onBridgeConfigSaved(host.trim(), portNum, token.trim())
                }
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = host.isNotBlank() && token.isNotBlank()
        ) {
            Text(stringResource(R.string.connect_to_bridge))
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Divider
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(MaterialTheme.colorScheme.outlineVariant)
            )
            Text(
                text = "  o  ",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(MaterialTheme.colorScheme.outlineVariant)
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        if (!showApiKeyOption) {
            androidx.compose.material3.TextButton(
                onClick = { showApiKeyOption = true },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(R.string.use_api_key))
            }
        } else {
            AnimatedVisibility(visible = showApiKeyOption, enter = fadeIn()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    OutlinedTextField(
                        value = apiKey,
                        onValueChange = { apiKey = it },
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(stringResource(R.string.api_key_label)) },
                        placeholder = { Text("sk-ant-...") },
                        singleLine = true,
                        shape = RoundedCornerShape(12.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    androidx.compose.material3.Button(
                        onClick = {
                            if (apiKey.isNotBlank()) {
                                onApiKeySaved(apiKey)
                            }
                        },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = apiKey.isNotBlank()
                    ) {
                        Text(stringResource(R.string.save_api_key))
                    }
                }
            }
        }
    }
}

@Composable
private fun MarkdownText(
    markdown: String,
    color: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier
) {
    val colorArgb = color.toArgb()

    AndroidView(
        modifier = modifier,
        factory = { context ->
            val markwon = Markwon.builder(context)
                .usePlugin(StrikethroughPlugin.create())
                .usePlugin(TablePlugin.create(context))
                .build()
            android.widget.TextView(context).apply {
                setTextColor(colorArgb)
                textSize = 16f
                // Remove extra padding from TextView
                setPadding(0, 0, 0, 0)
                // Enable link handling
                linksClickable = true
                movementMethod = android.text.method.LinkMovementMethod.getInstance()
                // Store markwon instance as tag
                tag = markwon
            }
        },
        update = { textView ->
            val markwon = textView.tag as Markwon
            markwon.setMarkdown(textView, markdown)
            textView.setTextColor(colorArgb)
        }
    )
}

/**
 * Dialog shown when Claude CLI requests permission to use a tool.
 * Displays tool name, description, and input details with Allow/Deny buttons.
 */
@Composable
private fun PermissionRequestDialog(
    permission: PendingPermission,
    onAllow: () -> Unit,
    onDeny: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDeny,
        title = {
            Text(
                text = "Permission Request",
                style = MaterialTheme.typography.titleMedium
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Claude wants to use: ${permission.toolName}",
                    style = MaterialTheme.typography.bodyLarge
                )
                if (permission.description.isNotEmpty()) {
                    Text(
                        text = permission.description,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                // Show tool input details (e.g., command to execute)
                val inputText = permission.toolInput.entries.joinToString("\n") { (k, v) ->
                    "$k: $v"
                }
                if (inputText.isNotEmpty()) {
                    Card(
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    ) {
                        Text(
                            text = inputText,
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(8.dp),
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onAllow) {
                Text("Allow")
            }
        },
        dismissButton = {
            OutlinedButton(onClick = onDeny) {
                Text("Deny")
            }
        }
    )
}
