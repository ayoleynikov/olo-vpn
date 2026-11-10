package app.olo.vpn.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.olo.vpn.model.ProxyProto
import app.olo.vpn.model.VpnServer
import app.olo.vpn.ui.OloViewModel
import app.olo.vpn.ui.theme.Ink

@Composable
fun AddScreen(vm: OloViewModel) {
    var paste by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var host by remember { mutableStateOf("") }
    var port by remember { mutableStateOf("443") }
    var uuid by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var sni by remember { mutableStateOf("") }
    var pbk by remember { mutableStateOf("") }
    var sid by remember { mutableStateOf("") }
    var fp by remember { mutableStateOf("chrome") }
    var flow by remember { mutableStateOf("") }
    var security by remember { mutableStateOf("reality") }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Text("Добавить", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Ink)
        Text("Любые ссылки (можно пачкой) или https-подписка", color = Ink.copy(alpha = 0.65f))
        OutlinedTextField(
            value = paste,
            onValueChange = { paste = it },
            modifier = Modifier.fillMaxWidth().height(120.dp),
            label = { Text("ss · vmess · vless · trojan · hy2 · tuic · socks · wg · https://…") }
        )
        if (vm.importBusy) CircularProgressIndicator()
        vm.importError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        Button(
            onClick = { vm.importPaste(paste) },
            enabled = paste.isNotBlank() && !vm.importBusy,
            modifier = Modifier.fillMaxWidth()
        ) { Text("Импортировать") }

        Spacer(Modifier.height(12.dp))
        Text("Вручную (VLESS / Reality)", fontWeight = FontWeight.SemiBold)
        OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), label = { Text("Имя") })
        OutlinedTextField(host, { host = it }, Modifier.fillMaxWidth(), label = { Text("Хост") })
        OutlinedTextField(port, { port = it }, Modifier.fillMaxWidth(), label = { Text("Порт") })
        OutlinedTextField(uuid, { uuid = it }, Modifier.fillMaxWidth(), label = { Text("UUID") })
        OutlinedTextField(password, { password = it }, Modifier.fillMaxWidth(), label = { Text("Пароль (Trojan/HY2)") })
        OutlinedTextField(sni, { sni = it }, Modifier.fillMaxWidth(), label = { Text("SNI") })
        OutlinedTextField(security, { security = it }, Modifier.fillMaxWidth(), label = { Text("Security") })
        OutlinedTextField(pbk, { pbk = it }, Modifier.fillMaxWidth(), label = { Text("Reality pbk") })
        OutlinedTextField(sid, { sid = it }, Modifier.fillMaxWidth(), label = { Text("Reality sid") })
        OutlinedTextField(fp, { fp = it }, Modifier.fillMaxWidth(), label = { Text("Fingerprint") })
        OutlinedTextField(flow, { flow = it }, Modifier.fillMaxWidth(), label = { Text("Flow") })
        Button(
            onClick = {
                vm.addManual(
                    VpnServer(
                        name = name.ifBlank { host },
                        proto = if (password.isNotBlank() && uuid.isBlank()) ProxyProto.trojan else ProxyProto.vless,
                        host = host.trim(),
                        port = port.toIntOrNull() ?: 443,
                        uuid = uuid.trim(),
                        password = password,
                        sni = sni.ifBlank { host },
                        security = security,
                        publicKey = pbk,
                        shortId = sid,
                        fingerprint = fp,
                        flow = flow
                    )
                )
            },
            enabled = host.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) { Text("Сохранить сервер") }
    }
}
