package com.savia.domain.model

import kotlinx.serialization.Serializable

/**
 * Represents global application settings and preferences.
 *
 * This domain model encapsulates user preferences that affect app behavior,
 * appearance, and onboarding flow. It serves as the source of truth for
 * settings that persist across sessions and are accessed throughout the app.
 *
 * ## Role in Clean Architecture
 * [AppSettings] is a domain entity that defines application preferences independent
 * of any UI framework or storage mechanism. The data layer handles persistence
 * (typically in shared preferences or datastore), while the domain layer defines
 * the structure and business rules.
 *
 * ## Lifecycle
 * - Created with defaults on first app launch
 * - Updated when user changes preferences
 * - Restored from persistent storage on subsequent launches
 * - Watched via Flow/LiveData in presentation layer for reactive updates
 *
 * @property hasApiKey Whether the user has configured an API key (for direct Claude API mode)
 * @property hasCompletedOnboarding Whether the user has completed the initial setup flow
 * @property theme UI color theme preference
 * @property language App language/localization preference
 */
@Serializable
data class AppSettings(
    val hasApiKey: Boolean = false,
    val hasCompletedOnboarding: Boolean = false,
    val theme: AppTheme = AppTheme.SYSTEM,
    val language: AppLanguage = AppLanguage.SYSTEM
)

/**
 * Enumeration of available UI themes.
 *
 * Apps using Jetpack Compose should observe [AppTheme] and apply the corresponding
 * color scheme to the CompositionLocal.
 *
 * @property LIGHT Force light theme (white background, dark text)
 * @property DARK Force dark theme (dark background, light text)
 * @property SYSTEM Follow device system theme setting
 */
@Serializable
enum class AppTheme {
    LIGHT,
    DARK,
    SYSTEM
}

/**
 * Enumeration of supported application languages.
 *
 * Used for app UI localization. [SYSTEM] delegates to device language setting.
 * If device language is not Spanish or English, defaults to English.
 *
 * @property ES Spanish (Español)
 * @property EN English
 * @property SYSTEM Auto-detect from device language
 */
@Serializable
enum class AppLanguage {
    ES,
    EN,
    SYSTEM
}
