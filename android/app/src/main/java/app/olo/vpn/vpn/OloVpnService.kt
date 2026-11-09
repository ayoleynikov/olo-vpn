package app.olo.vpn.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import app.olo.vpn.MainActivity
import app.olo.vpn.R
import app.olo.vpn.core.SingBoxConfigBuilder
import app.olo.vpn.data.ServerStore
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * VpnService scaffold. When `libbox.aar` is present under `app/libs/`, wire Libbox PlatformInterface
 * here. Until then we establish a TUN interface and write the generated sing-box JSON for inspection.
 */
class OloVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null
    private val running = AtomicBoolean(false)

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTunnel()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            else -> startTunnel()
        }
        return START_STICKY
    }

    private fun startTunnel() {
        if (!running.compareAndSet(false, true)) return
        ensureChannel()
        startForeground(NOTIF_ID, buildNotification("Подключение…"))

        val store = ServerStore(this)
        val server = store.selected
        if (server == null) {
            updateStatus("Нет сервера")
            stopSelf()
            return
        }

        val json = SingBoxConfigBuilder.build(
            server, store.routeMode, store.localPolicy, store.localRegion, store.protection
        )
        File(filesDir, "sing-box-config.json").writeText(json)

        val builder = Builder()
            .setSession("Olo")
            .setMtu(9000)
            .addAddress("172.19.0.1", 30)
            .addDnsServer("1.1.1.1")
            .addRoute("0.0.0.0", 0)
        if (store.protection.allowLan) {
            // Local ranges stay outside full kill-switch when allowLan is on;
            // Libbox handles finer routing once linked.
        }
        try {
            tun = builder.establish()
            if (tun == null) {
                updateStatus("VpnService.establish() вернул null — проверьте разрешение VPN")
                running.set(false)
                stopSelf()
                return
            }
            // Placeholder until libbox.aar is fetched and PlatformInterface is wired.
            // See scripts/fetch_libbox_android.sh
            updateStatus("VPN интерфейс поднят · конфиг записан (ожидает Libbox)")
            startForeground(NOTIF_ID, buildNotification("Olo · ${server.displayName}"))
        } catch (e: Exception) {
            updateStatus("Ошибка VPN: ${e.message}")
            running.set(false)
            stopSelf()
        }
    }

    private fun stopTunnel() {
        running.set(false)
        tun?.close()
        tun = null
        updateStatus("Отключено")
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    private fun updateStatus(text: String) {
        getSharedPreferences("olo", MODE_PRIVATE).edit().putString(KEY_STATUS, text).apply()
        sendBroadcast(Intent(ACTION_STATUS).setPackage(packageName).putExtra(EXTRA_STATUS, text))
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL, "Olo VPN", NotificationManager.IMPORTANCE_LOW)
        )
    }

    private fun buildNotification(content: String): Notification {
        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle("Olo")
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_STOP = "app.olo.vpn.STOP"
        const val ACTION_STATUS = "app.olo.vpn.STATUS"
        const val EXTRA_STATUS = "status"
        const val KEY_STATUS = "vpn_status"
        private const val CHANNEL = "olo_vpn"
        private const val NOTIF_ID = 42
    }
}
