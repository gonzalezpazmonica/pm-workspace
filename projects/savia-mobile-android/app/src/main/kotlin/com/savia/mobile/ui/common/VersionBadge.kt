package com.savia.mobile.ui.common

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.savia.mobile.BuildConfig
import com.savia.mobile.R

/**
 * Displays the app version as a small label (e.g. "v0.3.17").
 *
 * Designed to be placed in TopAppBar actions so the version
 * is always visible right-aligned on every screen.
 *
 * @param modifier Optional modifier for styling
 */
@Composable
fun VersionBadge(modifier: Modifier = Modifier) {
    Text(
        text = "v${BuildConfig.VERSION_NAME}",
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier
    )
}

/**
 * Small Savia owl logo for use in TopAppBar navigationIcon.
 *
 * Renders the savia_logo PNG at 28dp — small enough for a toolbar
 * but clearly recognizable as the Savia mascot.
 *
 * @param modifier Optional modifier for sizing/padding
 */
@Composable
fun SaviaLogo(modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(id = R.drawable.savia_logo),
        contentDescription = "Savia",
        modifier = modifier.size(28.dp)
    )
}
