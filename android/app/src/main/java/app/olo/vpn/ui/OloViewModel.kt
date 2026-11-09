package app.olo.vpn.ui

import android.app.Application
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.olo.vpn.core.LinkParser
import app.olo.vpn.core.SubscriptionImporter
import app.olo.vpn.data.ServerStore
import app.olo.vpn.model.LocalPolicy
import app.olo.vpn.model.LocalRegion
import app.olo.vpn.model.Protection
import app.olo.vpn.model.RouteMode
import app.olo.vpn.model.VpnServer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class OloViewModel(app: Application) : AndroidViewModel(app) {
    private val store = ServerStore(app)

    var servers by mutableStateOf(store.servers)
        private set
    var selectedId by mutableStateOf(store.selectedId)
        private set
    var routeMode by mutableStateOf(store.routeMode)
        private set
    var localPolicy by mutableStateOf(store.localPolicy)
        private set
    var localRegion by mutableStateOf(store.localRegion)
        private set
    var protection by mutableStateOf(store.protection)
        private set
    var connected by mutableStateOf(false)
        private set
    var status by mutableStateOf(
        app.getSharedPreferences("olo", Application.MODE_PRIVATE)
            .getString("vpn_status", "Готов") ?: "Готов"
    )
        private set
    var importBusy by mutableStateOf(false)
        private set
    var importError by mutableStateOf<String?>(null)
        private set

    val selectedServer: VpnServer?
        get() = servers.find { it.id == selectedId } ?: servers.firstOrNull()

    fun refresh() {
        servers = store.servers
        selectedId = store.selectedId
        routeMode = store.routeMode
        localPolicy = store.localPolicy
        localRegion = store.localRegion
        protection = store.protection
    }

    fun select(id: String) {
        store.selectedId = id
        selectedId = id
    }

    fun remove(id: String) {
        store.remove(id)
        refresh()
    }

    fun updateRouteMode(mode: RouteMode) {
        store.routeMode = mode
        routeMode = mode
    }

    fun updateLocalPolicy(policy: LocalPolicy) {
        store.localPolicy = policy
        localPolicy = policy
    }

    fun updateLocalRegion(region: LocalRegion) {
        store.localRegion = region
        localRegion = region
    }

    fun updateProtection(block: Protection.() -> Unit) {
        val p = protection.copy().apply(block)
        store.protection = p
        protection = p
    }

    fun updateConnected(value: Boolean) {
        connected = value
    }

    fun updateStatus(text: String) {
        status = text
    }

    fun importPaste(raw: String) {
        importError = null
        viewModelScope.launch {
            importBusy = true
            try {
                val text = raw.trim()
                if (SubscriptionImporter.isSubscriptionUrl(text)) {
                    val name = SubscriptionImporter.remark(text)
                    val items = withContext(Dispatchers.IO) {
                        SubscriptionImporter.fetchServers(text, name)
                    }
                    store.upsertAll(items)
                } else {
                    store.upsert(LinkParser.parse(text))
                }
                refresh()
            } catch (e: Exception) {
                importError = e.message ?: "Ошибка импорта"
            } finally {
                importBusy = false
            }
        }
    }

    fun addManual(server: VpnServer) {
        store.upsert(server)
        refresh()
    }
}
