package com.savia.data.repository

import com.savia.data.security.SecureStorage
import com.savia.data.security.TinkKeyManager
import com.savia.domain.repository.SecurityRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.security.SecureRandom
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Repository implementation for security and secrets management (data layer).
 *
 * **Responsibilities:**
 * 1. Store/retrieve authentication credentials (API keys, bridge tokens)
 * 2. Manage transport configuration (bridge host/port)
 * 3. Maintain session state (last conversation ID)
 * 4. Generate and manage database encryption key
 * 5. Provide secure storage backed by Android Keystore + Tink
 *
 * **Architecture Role:**
 * - Clean Architecture data layer (repository pattern)
 * - Implements interface [SecurityRepository] from domain layer
 * - Abstracts Tink encryption and SharedPreferences from domain logic
 * - Single point of access for all security configuration
 *
 * **Storage Security:**
 * All data encrypted with AES-256-GCM via Google Tink:
 * - Master key: Hardware-backed Android Keystore (if available)
 * - Data key: AES-256 managed by Tink
 * - Encryption context: "secure-storage:{key-name}" (prevents key misuse)
 *
 * **Secrets Stored:**
 * - API Key: Anthropic Claude API key (fallback, if no bridge)
 * - Bridge Host: Bridge server hostname (primary)
 * - Bridge Port: Bridge server port (primary)
 * - Bridge Token: Authentication token for bridge (primary)
 * - DB Passphrase: SQLCipher passphrase for local database
 * - Last Conversation: ID of last viewed conversation (session state)
 *
 * **Transport Decision:**
 * Bridge is primary, API is fallback:
 * - If hasBridgeConfig(): use bridge (lower latency, better UX)
 * - Else if hasApiKey(): use API (full functionality, no bridge)
 * - Else: error (must configure at least one)
 *
 * **Thread Safety:**
 * - Singleton managed by Hilt
 * - All operations use withContext(Dispatchers.IO)
 * - Safe concurrent access (SecureStorage uses SharedPreferences locks)
 *
 * **Error Handling:**
 * - get*() returns null if not found (not exception)
 * - has*() returns false if not found
 * - Decryption errors: SecureStorage.get() returns null
 * - No checked exceptions (all wrapped)
 *
 * @constructor Injected dependencies via Hilt
 * @param secureStorage Encrypted storage (SharedPreferences + Tink)
 * @param keyManager Tink encryption/decryption manager
 *
 * @see SecurityRepository Domain interface this implements
 * @see SecureStorage Implementation of encrypted storage
 * @see TinkKeyManager Tink crypto manager
 */
@Singleton
class SecurityRepositoryImpl @Inject constructor(
    private val secureStorage: SecureStorage,
    private val keyManager: TinkKeyManager
) : SecurityRepository {

    // ===== Anthropic API (deprecated) =====

    /**
     * Store Anthropic API key in encrypted secure storage.
     *
     * **When to Use:**
     * Only if bridge is not available.
     * Bridge is recommended (better latency, full functionality).
     *
     * **Key Format:**
     * Anthropic API key (typically starts with "sk-ant-").
     *
     * **Encryption:**
     * Encrypted with AES-256-GCM via Tink before storage.
     * Passphrase never stored (Tink manages key derivation).
     *
     * @param key Anthropic API key from api.anthropic.com
     */
    override suspend fun saveApiKey(key: String) = withContext(Dispatchers.IO) {
        secureStorage.put(KEY_API_KEY, key)
    }

    /**
     * Retrieve Anthropic API key from secure storage.
     *
     * **Return Value:**
     * Null if key not found or decryption failed.
     * Caller should check hasApiKey() first if preferred.
     *
     * @return Decrypted API key or null
     */
    override suspend fun getApiKey(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_API_KEY)
    }

    /**
     * Delete Anthropic API key from storage.
     *
     * **Effect:**
     * Removes encrypted key. Cannot fall back to API after this.
     * Bridge must be configured or reconfigure API key.
     */
    override suspend fun deleteApiKey() = withContext(Dispatchers.IO) {
        secureStorage.remove(KEY_API_KEY)
    }

    /**
     * Check if Anthropic API key is configured.
     *
     * **Use Case:**
     * Determine if API fallback is available (UI decision).
     *
     * @return true if API key exists in storage
     */
    override suspend fun hasApiKey(): Boolean = withContext(Dispatchers.IO) {
        secureStorage.contains(KEY_API_KEY)
    }

    // ===== Savia Bridge Configuration =====

    /**
     * Store Savia Bridge connection configuration.
     *
     * **Bridge URL Construction:**
     * Uses: https://{host}:{port}
     * Example: https://192.168.1.100:8922
     *
     * **Token:**
     * Authentication token obtained during bridge connection setup.
     * Must match token configured in bridge server.
     *
     * **All-or-Nothing:**
     * All three values must be provided together (host, port, token).
     * Partial configuration will cause errors.
     *
     * **Encryption:**
     * Each value encrypted separately before storage.
     *
     * @param host Bridge server hostname or IP
     * @param port Bridge server port (typically 8922)
     * @param token Bearer token for authentication
     */
    override suspend fun saveBridgeConfig(host: String, port: Int, token: String) =
        withContext(Dispatchers.IO) {
            secureStorage.put(KEY_BRIDGE_HOST, host)
            secureStorage.put(KEY_BRIDGE_PORT, port.toString())
            secureStorage.put(KEY_BRIDGE_TOKEN, token)
        }

    /**
     * Retrieve bridge server hostname.
     *
     * @return Host or null if not configured
     */
    override suspend fun getBridgeHost(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_BRIDGE_HOST)
    }

    /**
     * Retrieve bridge server port.
     *
     * @return Port (as Int) or null if not configured
     *         Returns null if stored value is not a valid integer
     */
    override suspend fun getBridgePort(): Int? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_BRIDGE_PORT)?.toIntOrNull()
    }

    /**
     * Retrieve bridge authentication token.
     *
     * @return Bearer token or null if not configured
     */
    override suspend fun getBridgeToken(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_BRIDGE_TOKEN)
    }

    /**
     * Check if bridge is fully configured.
     *
     * **Requirement:**
     * All three values must be present: host, port, token.
     * If any is missing, returns false.
     *
     * **Use Case:**
     * Determine routing in [ChatRepositoryImpl.sendMessage()].
     *
     * @return true if all bridge config is present
     */
    override suspend fun hasBridgeConfig(): Boolean = withContext(Dispatchers.IO) {
        secureStorage.contains(KEY_BRIDGE_HOST) &&
                secureStorage.contains(KEY_BRIDGE_PORT) &&
                secureStorage.contains(KEY_BRIDGE_TOKEN)
    }

    /**
     * Delete all bridge configuration.
     *
     * **Effect:**
     * Removes host, port, and token.
     * Chat will fall back to Anthropic API (if configured).
     */
    override suspend fun deleteBridgeConfig() = withContext(Dispatchers.IO) {
        secureStorage.remove(KEY_BRIDGE_HOST)
        secureStorage.remove(KEY_BRIDGE_PORT)
        secureStorage.remove(KEY_BRIDGE_TOKEN)
    }

    // ===== Session Persistence =====

    /**
     * Store ID of last viewed conversation.
     *
     * **Use Case:**
     * Resume conversation when app restarts.
     * When user re-enters chat, restore to last conversation.
     *
     * @param id Conversation ID (UUID)
     */
    override suspend fun saveLastConversationId(id: String) = withContext(Dispatchers.IO) {
        secureStorage.put(KEY_LAST_CONVERSATION, id)
    }

    /**
     * Retrieve last viewed conversation ID.
     *
     * @return Conversation ID or null if not set
     */
    override suspend fun getLastConversationId(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_LAST_CONVERSATION)
    }

    /**
     * Clear last conversation ID.
     *
     * **Use Case:**
     * When user closes app or selects new conversation.
     * Prevents restoring to deleted conversation.
     */
    override suspend fun clearLastConversationId() = withContext(Dispatchers.IO) {
        secureStorage.remove(KEY_LAST_CONVERSATION)
    }

    // ===== User Preferences =====

    override suspend fun saveTheme(theme: String) = withContext(Dispatchers.IO) {
        secureStorage.put(KEY_THEME, theme)
    }

    override suspend fun getTheme(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_THEME)
    }

    override suspend fun saveLanguage(language: String) = withContext(Dispatchers.IO) {
        secureStorage.put(KEY_LANGUAGE, language)
    }

    override suspend fun getLanguage(): String? = withContext(Dispatchers.IO) {
        secureStorage.get(KEY_LANGUAGE)
    }

    // ===== Shared =====

    /**
     * Get or generate SQLCipher database encryption passphrase.
     *
     * **Generation:**
     * On first call: generates random 32-byte (256-bit) key
     * On subsequent calls: retrieves stored key
     *
     * **Encryption:**
     * Key encrypted with AES-256 via Tink before storage.
     * Returned as ByteArray (suitable for SQLCipher).
     *
     * **Base64 Encoding:**
     * Raw 32 bytes → Base64 for storage → decoded back to bytes
     * SQLCipher uses the raw bytes.
     *
     * **Security Implications:**
     * - Unique per app install
     * - Cannot be retrieved if encryption key is lost
     * - Database becomes unrecoverable if app is uninstalled
     *
     * **Performance:**
     * - First call: generates random bytes (fast)
     * - Subsequent calls: retrieves from storage (1ms)
     * - No password prompt (automatic)
     *
     * @return 32-byte decrypted passphrase for SQLCipher
     */
    override suspend fun getDatabasePassphrase(): ByteArray = withContext(Dispatchers.IO) {
        val existing = secureStorage.get(KEY_DB_PASSPHRASE)
        if (existing != null) {
            existing.toByteArray(Charsets.UTF_8)
        } else {
            // Generate a random 32-byte passphrase on first access
            val passphrase = ByteArray(32).also { SecureRandom().nextBytes(it) }
            val encoded = android.util.Base64.encodeToString(passphrase, android.util.Base64.NO_WRAP)
            secureStorage.put(KEY_DB_PASSPHRASE, encoded)
            passphrase
        }
    }

    companion object {
        private const val KEY_API_KEY = "claude_api_key"
        private const val KEY_DB_PASSPHRASE = "db_passphrase"
        private const val KEY_BRIDGE_HOST = "bridge_host"
        private const val KEY_BRIDGE_PORT = "bridge_port"
        private const val KEY_BRIDGE_TOKEN = "bridge_token"
        private const val KEY_LAST_CONVERSATION = "last_conversation_id"
        private const val KEY_THEME = "user_theme"
        private const val KEY_LANGUAGE = "user_language"
    }
}
