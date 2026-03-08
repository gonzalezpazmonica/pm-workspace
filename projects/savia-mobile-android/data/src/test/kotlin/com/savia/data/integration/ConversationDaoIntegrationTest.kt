package com.savia.data.integration

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.google.common.truth.Truth.assertThat
import com.savia.data.local.SaviaDatabase
import com.savia.data.local.dao.ConversationDao
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Integration tests for ConversationDao using an in-memory Room database.
 * Uses Robolectric to provide an Android Context without a device/emulator.
 *
 * Tests verify:
 * - CRUD operations for conversations and messages
 * - Foreign key cascade deletes
 * - Query ordering (updatedAt DESC for conversations, timestamp ASC for messages)
 * - Metadata updates (title, timestamp)
 * - Archived conversations filtering
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33], manifest = Config.NONE)
class ConversationDaoIntegrationTest {

    private lateinit var database: SaviaDatabase
    private lateinit var dao: ConversationDao

    @Before
    fun setup() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, SaviaDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        dao = database.conversationDao()
    }

    @After
    fun tearDown() {
        database.close()
    }

    // --- Conversation CRUD ---

    @Test
    fun `insert and retrieve conversation`() = runTest {
        val conversation = createConversation("conv_1", "Test Conversation")
        dao.insertConversation(conversation)

        val result = dao.getById("conv_1").first()

        assertThat(result).isNotNull()
        assertThat(result!!.id).isEqualTo("conv_1")
        assertThat(result.title).isEqualTo("Test Conversation")
    }

    @Test
    fun `getAll returns conversations ordered by updatedAt DESC`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Oldest", updatedAt = 1000L))
        dao.insertConversation(createConversation("conv_2", "Middle", updatedAt = 2000L))
        dao.insertConversation(createConversation("conv_3", "Newest", updatedAt = 3000L))

        val result = dao.getAll().first()

        assertThat(result).hasSize(3)
        assertThat(result[0].id).isEqualTo("conv_3") // newest first
        assertThat(result[1].id).isEqualTo("conv_2")
        assertThat(result[2].id).isEqualTo("conv_1")
    }

    @Test
    fun `getAll excludes archived conversations`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Active"))
        dao.insertConversation(createConversation("conv_2", "Archived", isArchived = true))

        val result = dao.getAll().first()

        assertThat(result).hasSize(1)
        assertThat(result[0].id).isEqualTo("conv_1")
    }

    @Test
    fun `delete conversation removes it from database`() = runTest {
        dao.insertConversation(createConversation("conv_1", "To Delete"))

        dao.deleteConversation("conv_1")

        val result = dao.getById("conv_1").first()
        assertThat(result).isNull()
    }

    @Test
    fun `getConversationCount only counts non-archived`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Active 1"))
        dao.insertConversation(createConversation("conv_2", "Active 2"))
        dao.insertConversation(createConversation("conv_3", "Archived", isArchived = true))

        val count = dao.getConversationCount()

        assertThat(count).isEqualTo(2)
    }

    // --- Message CRUD ---

    @Test
    fun `insert and retrieve messages for conversation`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Chat"))
        dao.insertMessage(createMessage("msg_1", "conv_1", "USER", "Hello", timestamp = 1000L))
        dao.insertMessage(createMessage("msg_2", "conv_1", "ASSISTANT", "Hi there!", timestamp = 2000L))

        val messages = dao.getMessages("conv_1").first()

        assertThat(messages).hasSize(2)
        assertThat(messages[0].role).isEqualTo("USER")
        assertThat(messages[1].role).isEqualTo("ASSISTANT")
    }

    @Test
    fun `messages ordered by timestamp ASC`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Chat"))
        dao.insertMessage(createMessage("msg_3", "conv_1", "ASSISTANT", "Third", timestamp = 3000L))
        dao.insertMessage(createMessage("msg_1", "conv_1", "USER", "First", timestamp = 1000L))
        dao.insertMessage(createMessage("msg_2", "conv_1", "ASSISTANT", "Second", timestamp = 2000L))

        val messages = dao.getMessages("conv_1").first()

        assertThat(messages).hasSize(3)
        assertThat(messages[0].content).isEqualTo("First")
        assertThat(messages[1].content).isEqualTo("Second")
        assertThat(messages[2].content).isEqualTo("Third")
    }

    @Test
    fun `messages from different conversations are isolated`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Chat 1"))
        dao.insertConversation(createConversation("conv_2", "Chat 2"))
        dao.insertMessage(createMessage("msg_1", "conv_1", "USER", "Hello from 1"))
        dao.insertMessage(createMessage("msg_2", "conv_2", "USER", "Hello from 2"))
        dao.insertMessage(createMessage("msg_3", "conv_1", "ASSISTANT", "Reply to 1"))

        val conv1Messages = dao.getMessages("conv_1").first()
        val conv2Messages = dao.getMessages("conv_2").first()

        assertThat(conv1Messages).hasSize(2)
        assertThat(conv2Messages).hasSize(1)
    }

    // --- Cascade Delete ---

    @Test
    fun `deleting conversation cascades to messages`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Chat"))
        dao.insertMessage(createMessage("msg_1", "conv_1", "USER", "Hello"))
        dao.insertMessage(createMessage("msg_2", "conv_1", "ASSISTANT", "Hi"))

        dao.deleteConversation("conv_1")

        val messages = dao.getMessages("conv_1").first()
        assertThat(messages).isEmpty()
    }

    // --- Metadata Updates ---

    @Test
    fun `updateTitle changes conversation title`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Old Title"))

        dao.updateTitle("conv_1", "New Title", updatedAt = 5000L)

        val result = dao.getById("conv_1").first()
        assertThat(result!!.title).isEqualTo("New Title")
        assertThat(result.updatedAt).isEqualTo(5000L)
    }

    @Test
    fun `updateTimestamp changes only updatedAt`() = runTest {
        val original = createConversation("conv_1", "Test", createdAt = 1000L, updatedAt = 1000L)
        dao.insertConversation(original)

        dao.updateTimestamp("conv_1", updatedAt = 9000L)

        val result = dao.getById("conv_1").first()
        assertThat(result!!.createdAt).isEqualTo(1000L) // unchanged
        assertThat(result.updatedAt).isEqualTo(9000L)   // updated
    }

    // --- Upsert Behavior ---

    @Test
    fun `inserting message with same ID replaces content`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Chat"))
        dao.insertMessage(createMessage("msg_1", "conv_1", "ASSISTANT", "Streaming..."))
        dao.insertMessage(createMessage("msg_1", "conv_1", "ASSISTANT", "Complete response"))

        val messages = dao.getMessages("conv_1").first()

        assertThat(messages).hasSize(1)
        assertThat(messages[0].content).isEqualTo("Complete response")
    }

    @Test
    fun `inserting conversation with same ID replaces it`() = runTest {
        dao.insertConversation(createConversation("conv_1", "Original"))
        dao.insertConversation(createConversation("conv_1", "Updated"))

        val result = dao.getById("conv_1").first()
        assertThat(result!!.title).isEqualTo("Updated")
    }

    // --- Multi-Conversation Scenario ---

    @Test
    fun `full lifecycle - create, populate, query, update, delete`() = runTest {
        // Create 3 conversations
        dao.insertConversation(createConversation("conv_1", "Project Alpha", updatedAt = 1000L))
        dao.insertConversation(createConversation("conv_2", "Sprint Review", updatedAt = 2000L))
        dao.insertConversation(createConversation("conv_3", "Bug Triage", updatedAt = 3000L))

        // Add messages to conv_1
        dao.insertMessage(createMessage("m1", "conv_1", "USER", "Status of Alpha?", timestamp = 1000L))
        dao.insertMessage(createMessage("m2", "conv_1", "ASSISTANT", "Alpha is on track.", timestamp = 1500L))
        dao.insertMessage(createMessage("m3", "conv_1", "USER", "Any blockers?", timestamp = 2000L))

        // Add messages to conv_2
        dao.insertMessage(createMessage("m4", "conv_2", "USER", "Sprint summary?", timestamp = 2000L))

        // Verify counts
        assertThat(dao.getConversationCount()).isEqualTo(3)
        assertThat(dao.getMessages("conv_1").first()).hasSize(3)
        assertThat(dao.getMessages("conv_2").first()).hasSize(1)
        assertThat(dao.getMessages("conv_3").first()).isEmpty()

        // Update conv_1 timestamp (simulates new message activity)
        dao.updateTimestamp("conv_1", updatedAt = 5000L)

        // Verify ordering changed
        val ordered = dao.getAll().first()
        assertThat(ordered[0].id).isEqualTo("conv_1") // now newest
        assertThat(ordered[1].id).isEqualTo("conv_3")
        assertThat(ordered[2].id).isEqualTo("conv_2")

        // Delete conv_2 and verify cascade
        dao.deleteConversation("conv_2")
        assertThat(dao.getConversationCount()).isEqualTo(2)
        assertThat(dao.getMessages("conv_2").first()).isEmpty()
    }

    // --- Helpers ---

    private fun createConversation(
        id: String,
        title: String,
        createdAt: Long = System.currentTimeMillis(),
        updatedAt: Long = createdAt,
        isArchived: Boolean = false
    ) = ConversationEntity(
        id = id,
        title = title,
        createdAt = createdAt,
        updatedAt = updatedAt,
        isArchived = isArchived
    )

    private fun createMessage(
        id: String,
        conversationId: String,
        role: String,
        content: String,
        timestamp: Long = System.currentTimeMillis()
    ) = MessageEntity(
        id = id,
        conversationId = conversationId,
        role = role,
        content = content,
        timestamp = timestamp
    )
}
