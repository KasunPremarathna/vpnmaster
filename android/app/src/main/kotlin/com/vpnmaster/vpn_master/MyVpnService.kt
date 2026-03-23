package com.vpnmaster.vpn_master

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.net.TrafficStats
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.Timer
import java.util.TimerTask
import libv2ray.Libv2ray
import libv2ray.CoreController
import libv2ray.CoreCallbackHandler

class MyVpnService : VpnService() {

    companion object {
        const val TAG = "MyVpnService"
        const val CHANNEL_ID = "vpn_master_channel"
        const val NOTIFICATION_ID = 1

        var uploadBytes: Long = 0L
        var downloadBytes: Long = 0L
        var uploadSpeed: Long = 0L
        var downloadSpeed: Long = 0L
        var startTime: Long = 0L

        var methodChannel: MethodChannel? = null

        fun notifyState(state: String) {
            methodChannel?.invokeMethod("onStateChanged", state)
        }
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false
    private var serverHost = ""
    private var serverPort = 0
    private var dnsServer = "1.1.1.1"
    private var xrayJson: String? = null
    private var xrayController: CoreController? = null
    private var statsTimer: Timer? = null
    
    private var lastTxBytes: Long = 0L
    private var lastRxBytes: Long = 0L

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (intent.action == "STOP_VPN") {
            stopVpnInternal()
            return START_NOT_STICKY
        }

        serverHost = intent.getStringExtra("server") ?: ""
        serverPort = intent.getIntExtra("port", 22)
        dnsServer = intent.getStringExtra("dns") ?: "1.1.1.1"
        xrayJson = intent.getStringExtra("xrayJson")

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Connecting…"))
        startVpn()
        return START_STICKY
    }

    private fun initXrayAssets() {
        val datDir = filesDir.absolutePath
        val geoip = File(datDir, "geoip.dat")
        val geosite = File(datDir, "geosite.dat")
        
        if (!geoip.exists() || !geosite.exists()) {
            val assetManager = assets
            try {
                assetManager.open("geoip.dat").use { input ->
                    FileOutputStream(geoip).use { output ->
                        input.copyTo(output)
                    }
                }
                assetManager.open("geosite.dat").use { input ->
                    FileOutputStream(geosite).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to copy Xray dat files: ${e.message}")
            }
        }
        
        try {
            Libv2ray.initCoreEnv(datDir, "")
        } catch (e: Exception) {
            Log.e(TAG, "initCoreEnv failed: ${e.message}")
        }
    }

    private fun stopVpnInternal() {
        isRunning = false
        stopStatsTimer()
        
        Thread {
            try { xrayController?.stopLoop() } catch (_: Exception) {}
            xrayController = null
            try { vpnInterface?.close() } catch (_: Exception) {}
            vpnInterface = null
        }.start()

        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
        notifyState("DISCONNECTED")
    }

    private fun startVpn() {
        try {
            Log.d(TAG, "Building VPN interface…")
            val builder = Builder()
                .setSession("VPN Master")
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer(dnsServer)
                .setMtu(1500)

            try {
                // Prevent routing loops by excluding our own app process (Xray core runs here!)
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.e(TAG, "Could not exclude package: ${e.message}")
            }

            vpnInterface = builder.establish()

            if (vpnInterface == null) {
                Log.e(TAG, "VPN interface is null — permission denied?")
                notifyState("ERROR")
                return
            }

            if (!xrayJson.isNullOrEmpty()) {
                initXrayAssets()
                xrayController = Libv2ray.newCoreController(object : CoreCallbackHandler {
                    override fun onEmitStatus(l: Long, s: String?): Long {
                        Log.d("XrayCore", s ?: "")
                        return 0
                    }
                    override fun shutdown(): Long {
                        Log.d("XrayCore", "shutdown")
                        return 0
                    }
                    override fun startup(): Long {
                        Log.d("XrayCore", "startup")
                        return 0
                    }
                })
                xrayController?.startLoop(xrayJson, vpnInterface!!.fd)
                Log.d(TAG, "Xray native core started via JNI bridged fd!")
            } else {
                Log.d(TAG, "No Xray JSON provided, running hollow VPN interface (SSH fallback).")
            }

            isRunning = true
            startTime = System.currentTimeMillis()
            uploadBytes = 0L
            downloadBytes = 0L
            lastTxBytes = TrafficStats.getUidTxBytes(android.os.Process.myUid())
            lastRxBytes = TrafficStats.getUidRxBytes(android.os.Process.myUid())
            notifyState("CONNECTED")
            updateNotification("Connected to $serverHost")
            startStatsTimer()

        } catch (e: Exception) {
            Log.e(TAG, "startVpn error: ${e.message}")
            notifyState("ERROR")
        }
    }

    private fun startStatsTimer() {
        statsTimer?.cancel()
        statsTimer = Timer()
        statsTimer?.scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                if (!isRunning) return
                val currentTx = TrafficStats.getUidTxBytes(android.os.Process.myUid())
                val currentRx = TrafficStats.getUidRxBytes(android.os.Process.myUid())

                uploadSpeed = if (currentTx > lastTxBytes) currentTx - lastTxBytes else 0L
                downloadSpeed = if (currentRx > lastRxBytes) currentRx - lastRxBytes else 0L

                uploadBytes += uploadSpeed
                downloadBytes += downloadSpeed

                lastTxBytes = currentTx
                lastRxBytes = currentRx

                val upStr = formatBytes(uploadSpeed)
                val downStr = formatBytes(downloadSpeed)
                updateNotification("▼ $downStr   ▲ $upStr")
            }
        }, 1000, 1000)
    }

    private fun stopStatsTimer() {
        statsTimer?.cancel()
        statsTimer = null
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B/s"
        if (bytes < 1024 * 1024) return String.format("%.1f KB/s", bytes / 1024f)
        return String.format("%.2f MB/s", bytes / (1024f * 1024f))
    }

    override fun onDestroy() {
        stopVpnInternal()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Master",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "VPN connection status" }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val pi = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("VPN Master")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }
}
