package com.savia.mobile.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

/**
 * Light color scheme for Savia Mobile.
 *
 * Uses the violet/mauve palette for primary and secondary colors.
 * Provides light backgrounds for readability in bright environments.
 * Follows Material 3 guidelines for color role mappings.
 */
private val LightColorScheme = lightColorScheme(
    primary = SaviaPrimary,
    onPrimary = SaviaSurface,
    primaryContainer = SaviaAccent,
    onPrimaryContainer = SaviaPrimaryDark,
    secondary = SaviaPrimaryLight,
    onSecondary = SaviaSurface,
    secondaryContainer = SaviaSurfaceVariant,
    onSecondaryContainer = SaviaPrimaryDark,
    tertiary = SaviaSecondary,
    background = SaviaBackground,
    onBackground = SaviaOnBackground,
    surface = SaviaSurface,
    onSurface = SaviaOnSurface,
    surfaceVariant = SaviaSurfaceVariant,
    onSurfaceVariant = SaviaOnSurfaceVariant,
    outline = SaviaOutline,
    error = SaviaError,
    errorContainer = SaviaErrorContainer,
    onError = SaviaSurface,
    onErrorContainer = SaviaError
)

/**
 * Dark color scheme for Savia Mobile.
 *
 * Uses inverted colors from light scheme for dark mode.
 * Light text on dark backgrounds for readability in low-light environments.
 * Follows Material 3 dark mode guidelines.
 */
private val DarkColorScheme = darkColorScheme(
    primary = SaviaSecondary,
    onPrimary = SaviaPrimaryDark,
    primaryContainer = SaviaPrimary,
    onPrimaryContainer = SaviaAccent,
    secondary = SaviaPrimaryLight,
    onSecondary = SaviaPrimaryDark,
    secondaryContainer = SaviaDarkSurfaceVariant,
    onSecondaryContainer = SaviaAccent,
    tertiary = SaviaAccent,
    background = SaviaDarkBackground,
    onBackground = SaviaDarkOnBackground,
    surface = SaviaDarkSurface,
    onSurface = SaviaDarkOnSurface,
    surfaceVariant = SaviaDarkSurfaceVariant,
    onSurfaceVariant = SaviaDarkOnBackground,
    outline = SaviaOutline,
    error = SaviaErrorContainer,
    errorContainer = SaviaError,
    onError = SaviaError,
    onErrorContainer = SaviaErrorContainer
)

/**
 * Savia Mobile theme composable applying Material 3 design system.
 *
 * Features:
 * - Automatic dark/light mode based on system settings (isSystemInDarkTheme)
 * - Material You dynamic colors on Android 12+ when enabled (Material Color Extraction)
 * - Violet/mauve color palette with semantic colors for errors and warnings
 * - Typography system following Material 3 specifications
 * - Consistent color mappings across primary, secondary, tertiary, and neutral roles
 *
 * Usage: Wrap application content with SaviaTheme to apply colors and typography.
 *
 * @param darkTheme whether to use dark color scheme (defaults to system preference)
 * @param dynamicColor whether to use Material You dynamic colors (Android 12+)
 * @param content composable content to be themed
 */
@Composable
fun SaviaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        // Material You dynamic colors on Android 12+
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context)
            else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = SaviaTypography,
        content = content
    )
}
