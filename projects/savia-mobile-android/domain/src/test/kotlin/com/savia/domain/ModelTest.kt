package com.savia.domain

import com.google.common.truth.Truth.assertThat
import com.savia.domain.model.Conversation
import com.savia.domain.model.Message
import com.savia.domain.model.MessageRole
import com.savia.domain.model.WorkspaceHealth
import org.junit.Test

class ModelTest {

    @Test
    fun `conversation preview returns last message content truncated`() {
        val conversation = Conversation(
            id = "1",
            title = "Test",
            messages = listOf(
                Message("m1", "1", MessageRole.USER, "First message"),
                Message("m2", "1", MessageRole.ASSISTANT, "A".repeat(200))
            )
        )

        assertThat(conversation.preview).hasLength(100)
        assertThat(conversation.messageCount).isEqualTo(2)
        assertThat(conversation.lastMessage?.role).isEqualTo(MessageRole.ASSISTANT)
    }

    @Test
    fun `conversation with no messages returns empty preview`() {
        val conversation = Conversation(id = "1", title = "Empty")

        assertThat(conversation.preview).isEmpty()
        assertThat(conversation.lastMessage).isNull()
        assertThat(conversation.messageCount).isEqualTo(0)
    }

    @Test
    fun `workspace health UNAVAILABLE has negative score`() {
        val health = WorkspaceHealth.UNAVAILABLE

        assertThat(health.isAvailable).isFalse()
        assertThat(health.overallScore).isEqualTo(-1)
    }

    @Test
    fun `workspace health with valid score is available`() {
        val health = WorkspaceHealth(overallScore = 85)

        assertThat(health.isAvailable).isTrue()
    }
}
