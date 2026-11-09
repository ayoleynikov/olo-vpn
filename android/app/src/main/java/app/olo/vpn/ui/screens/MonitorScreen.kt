package app.olo.vpn.ui.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import app.olo.vpn.ui.OloViewModel
import app.olo.vpn.ui.theme.Ink
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.concurrent.TimeUnit

@Composable
fun MonitorScreen(vm: OloViewModel) {
    var ipInfo by remember { mutableStateOf("—") }
    var refresh by remember { mutableStateOf(0) }

    LaunchedEffect(refresh) {
        ipInfo = withContext(Dispatchers.IO) {
            runCatching {
                val client = OkHttpClient.Builder().connectTimeout(8, TimeUnit.SECONDS).build()
                val req = Request.Builder().url("https://ipapi.co/json/").build()
                client.newCall(req).execute().use { resp ->
                    val body = resp.body?.string().orEmpty()
                    val json = JSONObject(body)
                    "${json.optString("ip")} · ${json.optString("country_name")} · ${json.optString("org")}"
                }
            }.getOrElse { "Не удалось проверить IP: ${it.message}" }
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
    ) {
        Text("Монитор", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Ink)
        Spacer(Modifier.height(12.dp))
        Text("Статус VPN", fontWeight = FontWeight.SemiBold)
        Text(vm.status)
        Spacer(Modifier.height(16.dp))
        Text("Публичный IP", fontWeight = FontWeight.SemiBold)
        Text(ipInfo)
        TextButton(onClick = { refresh++ }) { Text("Обновить IP") }
        Spacer(Modifier.height(16.dp))
        Text("Сервер", fontWeight = FontWeight.SemiBold)
        Text(vm.selectedServer?.displayName ?: "не выбран")
        Text(vm.selectedServer?.endpoint ?: "—", color = Ink.copy(alpha = 0.6f))
        Spacer(Modifier.height(16.dp))
        Text(
            "Лог: после подключения Libbox события Clash API появятся здесь. Сейчас пишется конфиг в filesDir/sing-box-config.json.",
            color = Ink.copy(alpha = 0.65f)
        )
    }
}
