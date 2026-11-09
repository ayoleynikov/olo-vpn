package app.olo.vpn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.Timeline
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.olo.vpn.ui.screens.AddScreen
import app.olo.vpn.ui.screens.HomeScreen
import app.olo.vpn.ui.screens.MonitorScreen
import app.olo.vpn.ui.screens.ProtectScreen
import app.olo.vpn.ui.theme.Mist
import app.olo.vpn.ui.theme.Teal

@Composable
fun OloApp(vm: OloViewModel, onToggleVpn: (connected: Boolean) -> Unit) {
    val nav = rememberNavController()
    val back by nav.currentBackStackEntryAsState()
    val route = back?.destination?.route ?: "home"

    Box(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Mist, Mist.copy(alpha = 0.85f), Teal.copy(alpha = 0.12f))))
    ) {
        Scaffold(
            containerColor = androidx.compose.ui.graphics.Color.Transparent,
            bottomBar = {
                NavigationBar {
                    NavigationBarItem(
                        selected = route == "home",
                        onClick = { nav.navigate("home") { launchSingleTop = true } },
                        icon = { Icon(Icons.Default.Home, null) },
                        label = { Text("Домой") }
                    )
                    NavigationBarItem(
                        selected = route == "add",
                        onClick = { nav.navigate("add") { launchSingleTop = true } },
                        icon = { Icon(Icons.Default.Add, null) },
                        label = { Text("Добавить") }
                    )
                    NavigationBarItem(
                        selected = route == "monitor",
                        onClick = { nav.navigate("monitor") { launchSingleTop = true } },
                        icon = { Icon(Icons.Default.Timeline, null) },
                        label = { Text("Монитор") }
                    )
                    NavigationBarItem(
                        selected = route == "protect",
                        onClick = { nav.navigate("protect") { launchSingleTop = true } },
                        icon = { Icon(Icons.Default.Shield, null) },
                        label = { Text("Защита") }
                    )
                }
            }
        ) { padding ->
            NavHost(nav, startDestination = "home", Modifier.padding(padding)) {
                composable("home") { HomeScreen(vm, onToggleVpn) }
                composable("add") { AddScreen(vm) }
                composable("monitor") { MonitorScreen(vm) }
                composable("protect") { ProtectScreen(vm) }
            }
        }
    }
}
