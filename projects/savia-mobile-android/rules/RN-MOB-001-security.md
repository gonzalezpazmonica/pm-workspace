# RN-MOB-001: Security Rules

## RN-MOB-001-01: API Key Storage
All API keys MUST be stored in Android Keystore using EncryptedSharedPreferences.
Never store keys in plain SharedPreferences, SQLite, or files.

## RN-MOB-001-02: SSH Key Protection
SSH private keys MUST be encrypted at rest using AES-256-GCM.
Keys MUST require biometric or PIN authentication to decrypt.

## RN-MOB-001-03: Certificate Pinning
All HTTPS connections to api.anthropic.com MUST use certificate pinning.
Pin both leaf and intermediate certificates for rotation resilience.

## RN-MOB-001-04: No Logging Secrets
Log statements MUST NOT contain: API keys, SSH keys, passwords, tokens.
Use ProGuard/R8 to strip debug logs from release builds.

## RN-MOB-001-05: Biometric Lock
App MUST support optional biometric lock (fingerprint/face).
After 5 minutes background, require re-authentication.

## RN-MOB-001-06: Clipboard Protection
API keys and SSH keys MUST NOT be copyable to clipboard.
Clear clipboard after 60 seconds if user copies sensitive data.

## RN-MOB-001-07: Network Security
Reject cleartext HTTP traffic (usesCleartextTraffic=false).
Minimum TLS 1.2 for all connections.
No trust of user-installed CA certificates for API calls.

## RN-MOB-001-08: Data at Rest
Room database MUST use SQLCipher encryption.
Conversation cache MUST be encrypted.
