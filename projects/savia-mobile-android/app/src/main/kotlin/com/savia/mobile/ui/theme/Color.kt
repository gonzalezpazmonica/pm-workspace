package com.savia.mobile.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Savia Mobile design system color palette.
 *
 * Theme: violet / mauve palette (#6B4C9A primary) inspired by wisdom and clarity.
 * Compliant with Material 3 color system specifications.
 * Includes both light and dark mode color definitions.
 * Chat bubble colors distinguish between user and assistant messages.
 *
 * @author Savia Mobile Design Team
 */

// Savia brand colors — mauve / violet palette inspired by wisdom and clarity
val SaviaPrimary = Color(0xFF6B4C9A)        // Deep violet
val SaviaPrimaryLight = Color(0xFF8E6FBF)   // Medium violet
val SaviaPrimaryDark = Color(0xFF4A2D7A)    // Dark violet
val SaviaSecondary = Color(0xFFA78BCA)      // Soft lavender
val SaviaAccent = Color(0xFFCDB4DB)         // Light mauve

// Neutral palette for light mode
val SaviaBackground = Color(0xFFF9F7FB)     // Very light lavender tint
val SaviaSurface = Color(0xFFFFFFFF)
val SaviaSurfaceVariant = Color(0xFFEDE7F3) // Light violet surface
val SaviaOnBackground = Color(0xFF1C1A1E)
val SaviaOnSurface = Color(0xFF1C1A1E)
val SaviaOnSurfaceVariant = Color(0xFF49454F)
val SaviaOutline = Color(0xFF79747E)

// Neutral palette for dark mode
val SaviaDarkBackground = Color(0xFF1C1A1E)
val SaviaDarkSurface = Color(0xFF211F26)
val SaviaDarkSurfaceVariant = Color(0xFF322F37)
val SaviaDarkOnBackground = Color(0xFFE6E1E5)
val SaviaDarkOnSurface = Color(0xFFE6E1E5)

// Semantic accent colors for alerts and states
val SaviaError = Color(0xFFBA1A1A)
val SaviaErrorContainer = Color(0xFFFFDAD6)
val SaviaWarning = Color(0xFFE6A817)

// Chat bubble colors — soft violet tones for message distinction
val UserBubbleColor = Color(0xFF6B4C9A)         // Deep violet for user messages
val UserBubbleTextColor = Color(0xFFFFFFFF)
val AssistantBubbleColor = Color(0xFFEDE7F3)     // Light lavender for assistant messages
val AssistantBubbleTextColor = Color(0xFF1C1A1E)
