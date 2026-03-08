package com.savia.data.integration

import com.google.common.truth.Truth.assertThat
import com.savia.data.local.entity.ConversationEntity
import com.savia.data.local.entity.MessageEntity
import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import org.junit.Test

/**
 * Integration tests for entity ↔ domain model mapping.
 *
 * Verifies that data is preserved correctly when converting between
 * Room entities and domain models in both directions.
 */
class EntityMappingIntegrationTest {

    // --- ConversationEntity ↔ Conversation ---

    @Test
    fun `ConversationEntity to domain preserves all fields`() {
        val entity = ConversationEntity(
            id = "conv_123",
            title = "Sprint Planning",
            createdAt = 1710000000000L,
            updatedAt = 1710001000000L,
            isArchived = false
        )

        val domain = entity.toDomain()

        assertThat(domain.id).isEqualTo("conv_123")
        assertThat(domain.title).isEqualTo("Sprint Planning")
        assertThat(domain.createdAt).isEqualTo(1710000000000L)
        assertThat(domain.updatedAt).isEqualTo(1710001000000L)
        assertThat(domain.isArchived).isFalse()
        assertThat(domain.messages).isEmpty()
    }

    @Test
    fun `ConversationEntity to domain includes messages when provided`() {
        val entity = ConversationEntity(
            id = "conv_1",
            title = "Chat",
            createdAt = 1000L,
            updatedAt = 2000L
        )

        val messages = listOf(
            MessageEntity("m1", "conv_1", "USER", "Hello", 1000L),
            MessageEntity("m2", "conv_1", "ASSISTANT", "Hi there!", 1500L)
        )

        val domain = entity.toDomain(messages)

        assertThat(domain.messages).hasSize(2)
        assertThat(domain.messages[0].role).isEqualTo(MessageRole.USER)
        assertThat(domain.messages[1].role).isEqualTo(MessageRole.ASSISTANT)
        assertThat(domain.messageCount).isEqualTo(2)
        assertThat(domain.lastMessage!!.content).isEqualTo("Hi there!")
    }

    @Test
    fun `Conversation to entity round-trip preserves data`() {
        val original = Conversation(
            id = "conv_round",
            title = "Round Trip Test",
            createdAt = 999L,
            updatedAt = 1999L,
            isArchived = true
        )

        val entity = ConversationEntity.fromDomain(original)
        val restored = entity.toDomain()

        assertThat(restored.id).isEqualTo(original.id)
        assertThat(restored.title).isEqualTo(original.title)
        assertThat(restored.createdAt).isEqualTo(original.createdAt)
        assertThat(restored.updatedAt).isEqualTo(original.updatedAt)
        assertThat(restored.isArchived).isEqualTo(original.isArchived)
    }

    // --- MessageEntity ↔ Message ---

    @Test
    fun `MessageEntity to domain preserves all fields`() {
        val entity = MessageEntity(
            id = "msg_456",
            conversationId = "conv_123",
            role = "USER",
            content = "What's the sprint velocity?",
            timestamp = 1710000000000L,
            tokenCount = 42
        )

        val domain = entity.toDomain()

        assertThat(domain.id).isEqualTo("msg_456")
        assertThat(domain.conversationId).isEqualTo("conv_123")
        assertThat(domain.role).isEqualTo(MessageRole.USER)
        assertThat(domain.content).isEqualTo("What's the sprint velocity?")
        assertThat(domain.timestamp).isEqualTo(1710000000000L)
        assertThat(domain.tokenCount).isEqualTo(42)
    }

    @Test
    fun `Message to entity round-trip preserves data`() {
        val original = Message(
            id = "msg_round",
            conversationId = "conv_1",
            role = MessageRole.ASSISTANT,
            content = "The sprint is on track with 80% completion.",
            timestamp = 5000L,
            tokenCount = 150
        )

        val entity = MessageEntity.fromDomain(original)
        val restored = entity.toDomain()

        assertThat(restored.id).isEqualTo(original.id)
        assertThat(restored.conversationId).isEqualTo(original.conversationId)
        assertThat(restored.role).isEqualTo(original.role)
        assertThat(restored.content).isEqualTo(original.content)
        assertThat(restored.timestamp).isEqualTo(original.timestamp)
        assertThat(restored.tokenCount).isEqualTo(original.tokenCount)
    }

    @Test
    fun `Message with null tokenCount round-trips correctly`() {
        val original = Message(
            id = "msg_null_tc",
            conversationId = "conv_1",
            role = MessageRole.USER,
            content = "Hello",
            tokenCount = null
        )

        val entity = MessageEntity.fromDomain(original)
        val restored = entity.toDomain()

        assertThat(restored.tokenCount).isNull()
    }

    // --- Role Mapping ---

    @Test
    fun `all MessageRole values map correctly through entity`() {
        MessageRole.entries.forEach { role ->
            val message = Message(
                id = "msg_${role.name}",
                conversationId = "conv_1",
                role = role,
                content = "Test"
            )

            val entity = MessageEntity.fromDomain(message)
            assertThat(entity.role).isEqualTo(role.name)

            val restored = entity.toDomain()
            assertThat(restored.role).isEqualTo(role)
        }
    }

    // --- Conversation Computed Properties with Entities ---

    @Test
    fun `conversation preview from entity messages is truncated at 100 chars`() {
        val entity = ConversationEntity("c1", "Test", 0, 0)
        val longMessage = MessageEntity(
            "m1", "c1", "ASSISTANT",
            "A".repeat(500), 1000L
        )

        val domain = entity.toDomain(listOf(longMessage))

        assertThat(domain.preview).hasLength(100)
    }

    @Test
    fun `conversation with empty messages has empty preview`() {
        val entity = ConversationEntity("c1", "Empty", 0, 0)

        val domain = entity.toDomain(emptyList())

        assertThat(domain.preview).isEmpty()
        assertThat(domain.lastMessage).isNull()
    }

    // --- Unicode Content ---

    @Test
    fun `entity mapping preserves unicode content`() {
        val message = Message(
            id = "msg_unicode",
            conversationId = "conv_1",
            role = MessageRole.ASSISTANT,
            content = "¡Hola! El sprint está al 80%. Los bloqueantes son: análisis de rendimiento 🚀"
        )

        val entity = MessageEntity.fromDomain(message)
        val restored = entity.toDomain()

        assertThat(restored.content).isEqualTo(message.content)
        assertThat(restored.content).contains("¡Hola!")
        assertThat(restored.content).contains("🚀")
    }
}
