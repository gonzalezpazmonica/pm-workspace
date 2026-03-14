package com.savia.domain.repository

/**
 * Repository for managing sensitive and security-critical data.
 *
 * This repository abstracts all secure storage operations using Tink (Google's encryption library)
 * combined with Android Keystore for key storage. The implementation ensures that:
 * - All sensitive data is encrypted at rest
 * - Encryption keys are stored in hardware-backed secure enclave (when available)
 * - No plaintext credentials appear in logs or shared preferences
 *
 * ## Architecture
 * The repository operates at the domain layer and delegates to data layer implementations
 * that handle the actual Tink AEAD encryption, key management, and Android platform
 * integration.
 *
 * ## Supported Modes
 * Savia supports two connection modes, each with separate credential storage:
 *
 * ### 1. Anthropic API (Direct Mode)
 * Deprecated but kept for backward compatibility. Stores an API key to call Claude
 * directly from the mobile app (not recommended due to credential exposure).
 *
 * ### 2. Savia Bridge (Preferred Mode)
 * The primary mode. Stores connection parameters to a self-hosted Savia Bridge server:
 * - Bridge host/port for network location
 * - Authentication token for API requests
 *
 * ## Data Encryption
 * Database passphrase is auto-generated on first launch and used to encrypt the Room database.
 * The passphrase itself is stored in Android Keystore (encrypted by OS).
 */
interface SecurityRepository {
    // ===== Anthropic API (deprecated, kept for backward compatibility) =====

    /**
     * Store the Claude API key securely.
     *
     * Encrypts the key using Tink AEAD before storage.
     * Intended for direct API mode (not recommended in production).
     *
     * @param key API key from Anthropic
     * @throws Exception if encryption or storage fails
     */
    suspend fun saveApiKey(key: String)

    /**
     * Retrieve the stored Claude API key.
     *
     * Automatically decrypts the key from secure storage.
     *
     * @return The API key, or null if not set
     * @throws Exception if decryption fails
     */
    suspend fun getApiKey(): String?

    /**
     * Delete the stored API key.
     *
     * Use this when user switches from API mode to Bridge mode.
     *
     * @throws Exception if deletion fails
     */
    suspend fun deleteApiKey()

    /**
     * Check if an API key has been configured.
     *
     * Faster than calling [getApiKey] when you only need to know if a key exists.
     *
     * @return true if key is set, false otherwise
     */
    suspend fun hasApiKey(): Boolean

    // ===== Savia Bridge Configuration =====

    /**
     * Store Savia Bridge server connection parameters.
     *
     * Encrypts each parameter separately. Called during onboarding or when user
     * adds a new Bridge server. The username is registered with the bridge to
     * obtain a per-user token.
     *
     * @param host IP address or hostname of the Bridge
     * @param port Port number (typically 8922 or 8923)
     * @param token Authentication token issued by Bridge (user token after registration)
     * @param username Bridge username slug (alphanumeric, dash, underscore)
     * @throws Exception if encryption or storage fails
     */
    suspend fun saveBridgeConfig(host: String, port: Int, token: String, username: String = "")

    /**
     * Get the Bridge server hostname/IP.
     *
     * Automatically decrypts from secure storage.
     *
     * @return Host (e.g., "192.168.1.100" or "savia.example.com"), or null if not configured
     * @throws Exception if decryption fails
     */
    suspend fun getBridgeHost(): String?

    /**
     * Get the Bridge server port number.
     *
     * Automatically decrypts from secure storage.
     *
     * @return Port number, or null if not configured
     * @throws Exception if decryption fails
     */
    suspend fun getBridgePort(): Int?

    /**
     * Get the Bridge authentication token.
     *
     * Automatically decrypts from secure storage. This token is sent with every
     * request to the Bridge API. After registration this is the per-user token.
     *
     * @return Authentication token, or null if not configured
     * @throws Exception if decryption fails
     */
    suspend fun getBridgeToken(): String?

    /**
     * Get the Bridge username.
     *
     * The username slug used to register with the bridge and obtain a per-user token.
     *
     * @return Username slug, or null if not configured
     * @throws Exception if decryption fails
     */
    suspend fun getBridgeUsername(): String?

    /**
     * Construct the complete Bridge URL from host and port.
     *
     * Convenience method that calls [getBridgeHost] and [getBridgePort] internally.
     * Returns null if either component is missing.
     *
     * @return Complete URL like "https://192.168.1.100:8922", or null if not configured
     */
    suspend fun getBridgeUrl(): String? {
        val host = getBridgeHost() ?: return null
        val port = getBridgePort() ?: return null
        return "https://$host:$port"
    }

    /**
     * Check if Bridge configuration is complete and ready to use.
     *
     * Returns true only if host, port, and token are all set.
     *
     * @return true if Bridge is configured, false otherwise
     */
    suspend fun hasBridgeConfig(): Boolean

    /**
     * Delete all stored Bridge configuration including username.
     *
     * Use this when user wants to disconnect from a Bridge server or during
     * account logout.
     *
     * @throws Exception if deletion fails
     */
    suspend fun deleteBridgeConfig()

    // ===== Session Persistence =====

    /**
     * Save the last active conversation ID for session restoration.
     *
     * Called when user switches conversations. Used to restore the user to
     * the correct conversation when the app is relaunched.
     *
     * @param id Conversation ID to save
     * @throws Exception if storage fails
     */
    suspend fun saveLastConversationId(id: String)

    /**
     * Get the last active conversation ID.
     *
     * Called on app launch to restore the user's previous context.
     *
     * @return Last conversation ID, or null if no history exists
     * @throws Exception if retrieval fails
     */
    suspend fun getLastConversationId(): String?

    /**
     * Clear the saved last conversation ID.
     *
     * Use this if a conversation is deleted or when resetting app state.
     *
     * @throws Exception if deletion fails
     */
    suspend fun clearLastConversationId()

    // ===== User Preferences =====

    /**
     * Save the user's preferred theme.
     * @param theme Theme name ("SYSTEM", "LIGHT", "DARK")
     */
    suspend fun saveTheme(theme: String)

    /**
     * Get the user's preferred theme.
     * @return Theme name, or null for system default
     */
    suspend fun getTheme(): String?

    /**
     * Save the user's preferred language.
     * @param language Language code ("SYSTEM", "ES", "EN")
     */
    suspend fun saveLanguage(language: String)

    /**
     * Get the user's preferred language.
     * @return Language code, or null for system default
     */
    suspend fun getLanguage(): String?

    // ===== Shared =====

    /**
     * Get the database encryption passphrase.
     *
     * Auto-generates a random passphrase on first call and stores it in
     * Android Keystore. Subsequent calls return the same passphrase.
     *
     * Used by Room database for encrypted database implementation.
     *
     * @return 32-byte encryption key
     * @throws Exception if key generation or retrieval fails
     */
    suspend fun getDatabasePassphrase(): ByteArray
}
