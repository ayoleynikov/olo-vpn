package app.olo.vpn.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val Mist = Color(0xFFEEF3F6)
val Teal = Color(0xFF0D9488)
val TealDeep = Color(0xFF0F766E)
val Ink = Color(0xFF134E4A)
val Fog = Color(0xFFB8C5CC)

private val Light = lightColorScheme(
    primary = Teal,
    onPrimary = Color.White,
    secondary = TealDeep,
    background = Mist,
    surface = Color.White,
    onBackground = Ink,
    onSurface = Ink
)

private val Dark = darkColorScheme(
    primary = Teal,
    onPrimary = Color.White,
    secondary = Fog,
    background = Color(0xFF0B1418),
    surface = Color(0xFF122026),
    onBackground = Mist,
    onSurface = Mist
)

@Composable
fun OloTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) Dark else Light,
        content = content
    )
}
