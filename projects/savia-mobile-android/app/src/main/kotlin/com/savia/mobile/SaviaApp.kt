package com.savia.mobile

import android.app.Application
import dagger.hilt.android.HiltAndroidApp

/**
 * Savia Mobile application entry point.
 *
 * Initializes Hilt dependency injection framework and sets up global application state.
 * All repository, viewmodel, and service instances are managed by Hilt and injected
 * throughout the app via @Inject constructors and @HiltViewModel annotations.
 *
 * Application scope: singleton services (ChatRepository, SecurityRepository, databases)
 * Activity scope: ViewModels and Compose UI controllers
 *
 * @author Savia Mobile Team
 */
@HiltAndroidApp
class SaviaApp : Application()
