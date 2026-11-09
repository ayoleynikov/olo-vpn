package app.olo.vpn

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.DisposableEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import app.olo.vpn.ui.OloApp
import app.olo.vpn.ui.OloViewModel
import app.olo.vpn.ui.theme.OloTheme
import app.olo.vpn.vpn.OloVpnService

class MainActivity : ComponentActivity() {
    private var pendingConnect = false
    private var onStatus: ((String) -> Unit)? = null
    private var onConnected: ((Boolean) -> Unit)? = null

    private val vpnPermission = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == RESULT_OK && pendingConnect) {
            pendingConnect = false
            onConnected?.invoke(true)
            startVpnService()
        } else {
            pendingConnect = false
            onStatus?.invoke("Разрешение VPN отклонено")
        }
    }

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.getStringExtra(OloVpnService.EXTRA_STATUS)?.let { onStatus?.invoke(it) }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val vm: OloViewModel = viewModel()
            DisposableEffect(Unit) {
                onStatus = { vm.updateStatus(it) }
                onConnected = { vm.updateConnected(it) }
                val filter = IntentFilter(OloVpnService.ACTION_STATUS)
                if (Build.VERSION.SDK_INT >= 33) {
                    registerReceiver(statusReceiver, filter, RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(statusReceiver, filter)
                }
                onDispose {
                    onStatus = null
                    onConnected = null
                    runCatching { unregisterReceiver(statusReceiver) }
                }
            }
            OloTheme {
                OloApp(
                    vm = vm,
                    onToggleVpn = { isConnected ->
                        if (isConnected) stopVpn(vm) else prepareAndStart(vm)
                    }
                )
            }
        }
    }

    private fun prepareAndStart(vm: OloViewModel) {
        if (vm.selectedServer == null) {
            vm.updateStatus("Сначала добавьте сервер")
            return
        }
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingConnect = true
            vpnPermission.launch(intent)
        } else {
            vm.updateConnected(true)
            startVpnService()
        }
    }

    private fun startVpnService() {
        val i = Intent(this, OloVpnService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
    }

    private fun stopVpn(vm: OloViewModel) {
        vm.updateConnected(false)
        startService(Intent(this, OloVpnService::class.java).setAction(OloVpnService.ACTION_STOP))
    }
}
