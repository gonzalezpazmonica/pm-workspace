package com.savia.domain.model

import kotlinx.serialization.Serializable

/**
 * Represents a saved SSH connection profile for accessing the Savia Bridge server.
 *
 * This domain model stores the essential information needed to establish an SSH connection
 * to a remote machine running the Savia Bridge. It decouples the connection configuration
 * from the actual SSH transport layer (which belongs to the data layer).
 *
 * ## Role in Clean Architecture
 * [ConnectionProfile] is a domain entity that encodes business rules about SSH connections:
 * - Exactly one profile can be marked as default
 * - Authentication is either via SSH key (preferred) or password
 * - Encrypted keys are stored separately in secure storage (Tink/Keystore)
 * - Connection history is tracked for debugging and UX (recent connections first)
 *
 * ## Usage
 * Create a connection profile when:
 * - User manually adds a Savia Bridge server
 * - User imports a saved configuration from file or QR code
 * - Auto-discovery finds a Bridge on the network
 *
 * Use a connection profile when:
 * - Establishing SSH tunnel to the Bridge
 * - Fetching workspace health or credentials
 * - Detecting Bridge availability
 *
 * @property id Unique identifier for this profile (UUID)
 * @property name User-friendly name for this connection (e.g., "Home Server", "Lab Machine")
 * @property host IP address or hostname of the Bridge server
 * @property port SSH port (usually 22)
 * @property username SSH login username (typically matches system user running Savia Bridge)
 * @property authType Authentication method: SSH key or password
 * @property encryptedKeyId Reference to encrypted SSH private key in secure storage (only if authType is KEY)
 * @property isDefault Whether this profile should be auto-selected when the app starts
 * @property lastConnectedAt Timestamp of last successful connection (for sorting and debugging)
 * @property workspacePath Remote path where Savia Bridge is installed (default: ~/savia)
 */
@Serializable
data class ConnectionProfile(
    val id: String,
    val name: String,
    val host: String,
    val port: Int = 22,
    val username: String,
    val authType: AuthType = AuthType.KEY,
    val encryptedKeyId: String? = null,
    val isDefault: Boolean = false,
    val lastConnectedAt: Long? = null,
    val workspacePath: String = "~/savia"
)

/**
 * Enumeration of SSH authentication methods supported by Savia.
 *
 * [KEY] is preferred for security and unattended operation.
 * [PASSWORD] is supported for convenience but should be encrypted in storage.
 *
 * @property KEY SSH public key authentication (private key stored in Tink secure storage)
 * @property PASSWORD SSH password authentication
 */
@Serializable
enum class AuthType {
    KEY,
    PASSWORD
}
