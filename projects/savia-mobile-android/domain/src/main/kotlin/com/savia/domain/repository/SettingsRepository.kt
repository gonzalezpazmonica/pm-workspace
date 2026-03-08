package com.savia.domain.repository

import com.savia.domain.model.AppSettings
import com.savia.domain.model.AppTheme
import com.savia.domain.model.AppLanguage
import kotlinx.coroutines.flow.Flow

/**
 * Repository for user application settings and preferences.
 *
 * This repository abstracts persistence of user preferences such as theme, language,
 * and onboarding status. The underlying data store is typically Android DataStore
 * (which replaces SharedPreferences with a modern, type-safe, coroutine-friendly API).
 *
 * ## Role in Clean Architecture
 * [SettingsRepository] lives at the domain/data layer boundary. It provides a domain-level
 * interface ([AppSettings]) while delegating actual storage/retrieval to data layer
 * implementations.
 *
 * ## Reactive Preferences
 * The [getSettings] method returns a Flow, allowing the UI to observe preference changes
 * in real-time. Any changes made via [setTheme], [setLanguage], or [setOnboardingCompleted]
 * will be reflected in the Flow.
 *
 * ## Lifecycle
 * - On app first launch: default settings are created and persisted
 * - As user changes preferences: each setter updates the DataStore and emits new AppSettings
 * - On subsequent launches: DataStore is loaded and provides the user's previous settings
 */
interface SettingsRepository {
    /**
     * Observe application settings.
     *
     * Returns a Flow that emits the current settings and any future changes.
     * The initial emission happens immediately upon subscription (with persisted or default values).
     *
     * This method is the single source of truth for app preferences. UI components should
     * collect from this Flow to stay synchronized with user preferences.
     *
     * @return Flow<AppSettings> that emits current and future settings
     */
    fun getSettings(): Flow<AppSettings>

    /**
     * Mark the onboarding flow as completed.
     *
     * Called when user finishes the initial setup (e.g., connecting to a Bridge server).
     * This prevents the onboarding screen from showing on subsequent launches.
     *
     * @throws Exception if persistence fails
     */
    suspend fun setOnboardingCompleted()

    /**
     * Update the application theme preference.
     *
     * The change is persisted immediately and emitted to all observers of [getSettings].
     *
     * @param theme New theme preference (LIGHT, DARK, or SYSTEM)
     * @throws Exception if persistence fails
     */
    suspend fun setTheme(theme: AppTheme)

    /**
     * Update the application language preference.
     *
     * The change is persisted immediately and emitted to all observers of [getSettings].
     * Triggers app string/layout re-composition in the presentation layer.
     *
     * @param language New language (ES, EN, or SYSTEM)
     * @throws Exception if persistence fails
     */
    suspend fun setLanguage(language: AppLanguage)
}
