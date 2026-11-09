package app.olo.vpn.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.olo.vpn.model.LocalRegion
import app.olo.vpn.ui.OloViewModel
import app.olo.vpn.ui.theme.Ink

@Composable
fun ProtectScreen(vm: OloViewModel) {
    Column(Modifier.fillMaxSize().padding(20.dp)) {
        Text("Защита", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Ink)
        Spacer(Modifier.height(16.dp))
        ToggleRow("Kill switch", vm.protection.killSwitch) {
            vm.updateProtection { killSwitch = it }
        }
        ToggleRow("DNS через VPN", vm.protection.dnsThroughVpn) {
            vm.updateProtection { dnsThroughVpn = it }
        }
        ToggleRow("Блок IPv6", vm.protection.blockIpv6) {
            vm.updateProtection { blockIpv6 = it }
        }
        ToggleRow("Разрешить LAN", vm.protection.allowLan) {
            vm.updateProtection { allowLan = it }
        }
        Spacer(Modifier.height(20.dp))
        Text("Регион для умного маршрута", fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))
        Row {
            listOf(LocalRegion.auto to "Авто", LocalRegion.ru to "RU", LocalRegion.cn to "CN", LocalRegion.other to "Другой")
                .forEach { (region, label) ->
                    FilterChip(
                        selected = vm.localRegion == region,
                        onClick = { vm.updateLocalRegion(region) },
                        label = { Text(label) },
                        modifier = Modifier.padding(end = 6.dp)
                    )
                }
        }
    }
}

@Composable
private fun ToggleRow(title: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
