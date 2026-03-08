# RN-MOB-005: Play Store & Distribution Rules

## RN-MOB-005-01: Store Listing
App name: "Savia — AI Project Manager"
Short description (80 chars): "Your AI project management assistant. Sprint tracking, risk analysis, and more."
Category: Business > Project Management
Content rating: Everyone
Target age: 18+

## RN-MOB-005-02: Store Assets
Feature graphic: 1024x500px
App icon: 512x512px (adaptive icon)
Screenshots: minimum 4 per form factor (phone, tablet)
Promotional video: 30-60 seconds demo

## RN-MOB-005-03: Permissions
INTERNET — required for API and SSH
ACCESS_NETWORK_STATE — offline detection
RECORD_AUDIO — voice input (optional, runtime)
USE_BIOMETRIC — biometric lock (optional, runtime)
POST_NOTIFICATIONS — push alerts (optional, runtime)
No permission MUST be required at install time.

## RN-MOB-005-04: Release Process
Internal testing track for dev builds.
Closed beta (100 users) before open beta.
Staged rollout: 10% -> 25% -> 50% -> 100%.
Minimum 48 hours between rollout stages.

## RN-MOB-005-05: Quality Requirements
ANR rate < 0.5%
Crash rate < 1%
App startup < 3 seconds
No battery drain (background work limited to notifications)
APK size < 20MB (use App Bundle)

## RN-MOB-005-06: Legal
Terms of Service required.
Privacy Policy required (linked in app and listing).
Open source license for pm-workspace components.
Anthropic API usage compliant with their TOS.

## RN-MOB-005-07: Monetization
Free tier: 5 AI queries per day, local history only.
Pro tier ($9.99/month): Unlimited queries with own API key, cloud sync, widgets.
Google Play Billing Library v6+.
No ads. Never.
