package com.savia.data.integration

import com.google.common.truth.Truth.assertThat
import com.savia.domain.repository.SecurityRepository
import kotlinx.coroutines.test.runTest
import org.junit.Before
import org.junit.Test
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Integration tests for the security flow.
 *
 * Since TinkKeyManager requires Android Keystore (unavailable in unit tests),
 * these tests verify the encryption/decryption CONTRACT that any implementation
 * must satisfy, plus the SecurityRepository flow using a JVM-compatible
 * crypto implementation that mirrors Tink's AES-256-GCM behavior.
 *
 * Covers:
 * - API key encrypt → store → retrieve → decrypt round-trip
 * - Database passphrase generation and consistency
 * - Key deletion behavior
 * - Corruption/tampering detection
 * - Multiple key isolation (different contexts)
 *
 * ADR-003 compliance: Verifies the CONTRACT even though the actual Tink
 * provider requires androidTest (instrumented tests on a device).
 */
class SecurityFlowIntegrationTest {

    private lateinit var securityRepo: TestableSecurityRepository

    @Before
    fun setup() {
        securityRepo = TestableSecurityRepository()
    }

    // --- API Key Lifecycle ---

    @Test
    fun `saveApiKey and getApiKey round-trip preserves key`() = runTest {
        val originalKey = "sk-ant-api03-AbCdEf1234567890_long_key_value"

        securityRepo.saveApiKey(originalKey)
        val retrieved = securityRepo.getApiKey()

        assertThat(retrieved).isEqualTo(originalKey)
    }

    @Test
    fun `hasApiKey returns false before saving`() = runTest {
        assertThat(securityRepo.hasApiKey()).isFalse()
    }

    @Test
    fun `hasApiKey returns true after saving`() = runTest {
        securityRepo.saveApiKey("sk-test")
        assertThat(securityRepo.hasApiKey()).isTrue()
    }

    @Test
    fun `deleteApiKey removes the key`() = runTest {
        securityRepo.saveApiKey("sk-to-delete")
        assertThat(securityRepo.hasApiKey()).isTrue()

        securityRepo.deleteApiKey()

        assertThat(securityRepo.hasApiKey()).isFalse()
        assertThat(securityRepo.getApiKey()).isNull()
    }

    @Test
    fun `getApiKey returns null when no key stored`() = runTest {
        assertThat(securityRepo.getApiKey()).isNull()
    }

    @Test
    fun `overwriting API key replaces previous value`() = runTest {
        securityRepo.saveApiKey("sk-old-key")
        securityRepo.saveApiKey("sk-new-key")

        assertThat(securityRepo.getApiKey()).isEqualTo("sk-new-key")
    }

    // --- Database Passphrase ---

    @Test
    fun `getDatabasePassphrase returns non-empty bytes`() = runTest {
        val passphrase = securityRepo.getDatabasePassphrase()

        assertThat(passphrase).isNotEmpty()
        assertThat(passphrase.size).isEqualTo(32) // 256-bit
    }

    @Test
    fun `getDatabasePassphrase returns same value on subsequent calls`() = runTest {
        val first = securityRepo.getDatabasePassphrase()
        val second = securityRepo.getDatabasePassphrase()

        assertThat(first).isEqualTo(second)
    }

    @Test
    fun `database passphrase survives API key deletion`() = runTest {
        securityRepo.saveApiKey("sk-test")
        val passphraseBefore = securityRepo.getDatabasePassphrase()

        securityRepo.deleteApiKey()
        val passphraseAfter = securityRepo.getDatabasePassphrase()

        assertThat(passphraseAfter).isEqualTo(passphraseBefore)
    }

    // --- Encryption Integrity ---

    @Test
    fun `stored API key is NOT in plaintext`() = runTest {
        val plainKey = "sk-ant-api03-this-should-be-encrypted"
        securityRepo.saveApiKey(plainKey)

        // Verify the raw stored value is not the plaintext key
        val rawStored = securityRepo.getRawStoredValue("api_key")
        assertThat(rawStored).isNotNull()
        assertThat(rawStored).isNotEqualTo(plainKey)
        assertThat(rawStored!!.toByteArray()).isNotEqualTo(plainKey.toByteArray())
    }

    @Test
    fun `tampered ciphertext fails decryption gracefully`() = runTest {
        securityRepo.saveApiKey("sk-valid-key")

        // Tamper with the stored ciphertext
        securityRepo.tamperWithStoredValue("api_key")

        // Should return null (decryption fails) instead of crashing
        val retrieved = securityRepo.getApiKey()
        assertThat(retrieved).isNull()
    }

    @Test
    fun `different keys are stored independently`() = runTest {
        securityRepo.saveApiKey("sk-api-key")
        securityRepo.saveSshKey("ssh-private-key-data")

        assertThat(securityRepo.getApiKey()).isEqualTo("sk-api-key")
        assertThat(securityRepo.getSshKey()).isEqualTo("ssh-private-key-data")

        securityRepo.deleteApiKey()
        assertThat(securityRepo.getApiKey()).isNull()
        assertThat(securityRepo.getSshKey()).isEqualTo("ssh-private-key-data") // unaffected
    }

    // --- Unicode Keys ---

    @Test
    fun `API key with special characters round-trips correctly`() = runTest {
        val key = "sk-ant-αβγ-日本語-émojis-🔑"
        securityRepo.saveApiKey(key)
        assertThat(securityRepo.getApiKey()).isEqualTo(key)
    }

    /**
     * Testable SecurityRepository that uses JVM AES-256-GCM (same algorithm as Tink)
     * but without Android Keystore dependency. Mirrors TinkKeyManager behavior.
     */
    private class TestableSecurityRepository : SecurityRepository {
        private val store = mutableMapOf<String, ByteArray>()
        private val masterKey: ByteArray

        init {
            // Generate a deterministic master key for testing
            val keyGen = KeyGenerator.getInstance("AES")
            keyGen.init(256, SecureRandom(byteArrayOf(42))) // deterministic for test reproducibility
            masterKey = keyGen.generateKey().encoded
        }

        override suspend fun saveApiKey(key: String) {
            store["api_key"] = encrypt(key.toByteArray(Charsets.UTF_8), "api_key")
        }

        override suspend fun getApiKey(): String? {
            val encrypted = store["api_key"] ?: return null
            return try {
                String(decrypt(encrypted, "api_key"), Charsets.UTF_8)
            } catch (e: Exception) {
                null // Decryption failure — corrupted or tampered
            }
        }

        override suspend fun deleteApiKey() {
            store.remove("api_key")
        }

        override suspend fun hasApiKey(): Boolean = store.containsKey("api_key")

        // Bridge config (not used in security tests but required by interface)
        override suspend fun saveBridgeConfig(host: String, port: Int, token: String) {}
        override suspend fun getBridgeHost(): String? = null
        override suspend fun getBridgePort(): Int? = null
        override suspend fun getBridgeToken(): String? = null
        override suspend fun hasBridgeConfig(): Boolean = false
        override suspend fun deleteBridgeConfig() {}

        override suspend fun saveLastConversationId(id: String) {
            store["last_conversation"] = id.toByteArray(Charsets.UTF_8)
        }
        override suspend fun getLastConversationId(): String? {
            return store["last_conversation"]?.toString(Charsets.UTF_8)
        }
        override suspend fun clearLastConversationId() {
            store.remove("last_conversation")
        }

        override suspend fun getDatabasePassphrase(): ByteArray {
            return store.getOrPut("db_passphrase") {
                val passphrase = ByteArray(32)
                SecureRandom(byteArrayOf(99)).nextBytes(passphrase)
                passphrase
            }
        }

        // --- Test helpers ---

        suspend fun saveSshKey(key: String) {
            store["ssh_key"] = encrypt(key.toByteArray(Charsets.UTF_8), "ssh_key")
        }

        suspend fun getSshKey(): String? {
            val encrypted = store["ssh_key"] ?: return null
            return try {
                String(decrypt(encrypted, "ssh_key"), Charsets.UTF_8)
            } catch (e: Exception) {
                null
            }
        }

        fun getRawStoredValue(key: String): String? {
            val bytes = store[key] ?: return null
            return java.util.Base64.getEncoder().encodeToString(bytes)
        }

        fun tamperWithStoredValue(key: String) {
            val original = store[key] ?: return
            val tampered = original.copyOf()
            if (tampered.isNotEmpty()) {
                tampered[tampered.size / 2] = (tampered[tampered.size / 2].toInt() xor 0xFF).toByte()
            }
            store[key] = tampered
        }

        // AES-256-GCM encryption (same algo as Tink AEAD)
        private fun encrypt(plaintext: ByteArray, context: String): ByteArray {
            val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(masterKey, "AES"), GCMParameterSpec(128, iv))
            cipher.updateAAD(context.toByteArray()) // Associated data for context isolation
            val ciphertext = cipher.doFinal(plaintext)
            return iv + ciphertext // prepend IV
        }

        private fun decrypt(data: ByteArray, context: String): ByteArray {
            val iv = data.copyOfRange(0, 12)
            val ciphertext = data.copyOfRange(12, data.size)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(masterKey, "AES"), GCMParameterSpec(128, iv))
            cipher.updateAAD(context.toByteArray())
            return cipher.doFinal(ciphertext)
        }
    }
}
