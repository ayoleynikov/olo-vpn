package app.olo.vpn.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.olo.vpn.model.LocalPolicy
import app.olo.vpn.model.RouteMode
import app.olo.vpn.ui.OloViewModel
import app.olo.vpn.ui.theme.Ink
import app.olo.vpn.ui.theme.Teal
import app.olo.vpn.ui.theme.TealDeep

@Composable
fun HomeScreen(vm: OloViewModel, onToggleVpn: (Boolean) -> Unit) {
    val scale by animateFloatAsState(if (vm.connected) 1.05f else 1f, label = "orb")

    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp)
    ) {
        Text("Olo", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold, color = Ink)
        Text(
            if (vm.connected) "Подключено" else "Не подключено",
            color = if (vm.connected) TealDeep else Ink.copy(alpha = 0.55f)
        )
        Spacer(Modifier.height(28.dp))

        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .size(168.dp)
                    .scale(scale)
                    .shadow(18.dp, CircleShape)
                    .background(
                        Brush.radialGradient(
                            listOf(
                                if (vm.connected) Teal else Color(0xFF9BB0BA),
                                if (vm.connected) TealDeep else Color(0xFF6B7F88)
                            )
                        ),
                        CircleShape
                    )
                    .clickable { onToggleVpn(vm.connected) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    if (vm.connected) "Стоп" else "Старт",
                    color = Color.White,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }

        Spacer(Modifier.height(12.dp))
        Text(vm.status, style = MaterialTheme.typography.bodyMedium, color = Ink.copy(alpha = 0.7f))
        Spacer(Modifier.height(20.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = vm.routeMode == RouteMode.smart,
                onClick = { vm.updateRouteMode(RouteMode.smart) },
                label = { Text("Умный") }
            )
            FilterChip(
                selected = vm.routeMode == RouteMode.global,
                onClick = { vm.updateRouteMode(RouteMode.global) },
                label = { Text("Весь трафик") }
            )
        }
        if (vm.routeMode == RouteMode.smart) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = vm.localPolicy == LocalPolicy.bypass,
                    onClick = { vm.updateLocalPolicy(LocalPolicy.bypass) },
                    label = { Text("Местное мимо") }
                )
                FilterChip(
                    selected = vm.localPolicy == LocalPolicy.throughVPN,
                    onClick = { vm.updateLocalPolicy(LocalPolicy.throughVPN) },
                    label = { Text("Местное в VPN") }
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        Text("Серверы", fontWeight = FontWeight.SemiBold, color = Ink)
        Spacer(Modifier.height(8.dp))

        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(vm.servers, key = { it.id }) { server ->
                val selected = server.id == vm.selectedServer?.id
                Row(
                    Modifier
                        .fillMaxWidth()
                        .background(
                            if (selected) Teal.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.7f),
                            RoundedCornerShape(16.dp)
                        )
                        .clickable { vm.select(server.id) }
                        .padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(server.displayName, fontWeight = FontWeight.Medium)
                        Text(
                            "${server.proto.title} · ${server.endpoint}",
                            style = MaterialTheme.typography.bodySmall,
                            color = Ink.copy(alpha = 0.55f)
                        )
                    }
                    TextButton(onClick = { vm.remove(server.id) }) { Text("Удал.") }
                }
            }
        }
    }
}
