package com.savia.mobile.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Represents an authenticated Google user.
 *
 * @property id unique identifier for the Google account
 * @property email user's Google email address
 * @property displayName user's full name (may be null)
 * @property photoUrl URL to user's Google profile picture (may be null)
 * @property idToken JWT token for backend authentication and verification
 */
data class GoogleUser(
    val id: String,
    val email: String,
    val displayName: String?,
    val photoUrl: String?,
    val idToken: String
)

/**
 * Sealed class representing the result of a Google sign-in operation.
 *
 * - Success: contains authenticated GoogleUser data
 * - Error: contains human-readable error message
 */
sealed class GoogleAuthResult {
    data class Success(val user: GoogleUser) : GoogleAuthResult()
    data class Error(val message: String) : GoogleAuthResult()
}

/**
 * Handles Google OAuth authentication via Android Credential Manager.
 *
 * Uses the modern Credential Manager API (AndroidX) instead of legacy Google Sign-In SDK.
 * Requests an ID token from Google which is passed to the backend for verification.
 *
 * Security:
 * - Web Client ID must be created in Google Cloud Console (not Android)
 * - ID token is cryptographically signed and can be verified server-side
 * - Credential Manager handles secure storage of credentials
 *
 * Features:
 * - Auto-select enabled: returns last signed-in account without user interaction
 * - Authorized accounts filter: can be adjusted for account selection UX
 *
 * @author Savia Mobile Team
 */
@Singleton
class GoogleAuthManager @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val credentialManager = CredentialManager.create(context)

    companion object {
        /**
         * Google Cloud OAuth Web Client ID for Credential Manager.
         * Configured in Google Cloud Console → APIs & Credentials → OAuth 2.0 Client IDs.
         * Must be "Web application" type (not Android) as required by Credential Manager.
         * @see <a href="https://console.cloud.google.com/apis/credentials">Google Cloud Console</a>
         */
        const val WEB_CLIENT_ID = "320745867453-6c5jmut5ug8dgsvldpjv40s8j6uca6v6.apps.googleusercontent.com"
    }

    /**
     * Initiates Google sign-in flow using Credential Manager.
     *
     * Displays the native Google sign-in UI (account selector or consent screen).
     * Auto-select is enabled to return the last used account when available.
     * Blocks until user completes authentication or cancels.
     *
     * Success returns a GoogleUser with ID token that should be sent to backend
     * for verification and JWT decoding (never trust tokens on client-side).
     *
     * @param activityContext Activity context for displaying sign-in UI
     * @return GoogleAuthResult.Success with authenticated user, or GoogleAuthResult.Error
     */
    suspend fun signIn(activityContext: Context): GoogleAuthResult {
        return try {
            val googleIdOption = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId(WEB_CLIENT_ID)
                .setAutoSelectEnabled(true)
                .build()

            val request = GetCredentialRequest.Builder()
                .addCredentialOption(googleIdOption)
                .build()

            val result = credentialManager.getCredential(
                request = request,
                context = activityContext
            )

            handleSignInResult(result)
        } catch (e: Exception) {
            GoogleAuthResult.Error(e.message ?: "Error de autenticación con Google")
        }
    }

    private fun handleSignInResult(result: GetCredentialResponse): GoogleAuthResult {
        val credential = result.credential

        return when {
            credential is CustomCredential &&
                credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL -> {
                try {
                    val googleIdTokenCredential = GoogleIdTokenCredential
                        .createFrom(credential.data)

                    GoogleAuthResult.Success(
                        GoogleUser(
                            id = googleIdTokenCredential.id,
                            email = googleIdTokenCredential.id,
                            displayName = googleIdTokenCredential.displayName,
                            photoUrl = googleIdTokenCredential.profilePictureUri?.toString(),
                            idToken = googleIdTokenCredential.idToken
                        )
                    )
                } catch (e: GoogleIdTokenParsingException) {
                    GoogleAuthResult.Error("Error al procesar credenciales de Google")
                }
            }
            else -> GoogleAuthResult.Error("Tipo de credencial no soportado")
        }
    }
}
