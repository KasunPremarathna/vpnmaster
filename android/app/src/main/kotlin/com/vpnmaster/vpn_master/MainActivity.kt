package com.vpnmaster.vpn_master

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val VPN_CHANNEL = "com.vpnmaster/vpn"
        const val VPN_PERMISSION_REQUEST = 101
        private var pendingConfig: Map<String, Any>? = null
    }

    private lateinit var channel: MethodChannel

    // Hotspot state
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL)
        MyVpnService.methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    @Suppress("UNCHECKED_CAST")
                    val config = call.arguments as? Map<String, Any> ?: emptyMap()
                    startVpnWithPermission(config, result)
                }
                "stopVpn" -> {
                    stopVpnService()
                    result.success(true)
                }
                "getStats" -> {
                    result.success(mapOf(
                        "uploadBytes" to MyVpnService.uploadBytes,
                        "downloadBytes" to MyVpnService.downloadBytes,
                        "uploadSpeed" to MyVpnService.uploadSpeed,
                        "downloadSpeed" to MyVpnService.downloadSpeed,
                        "durationSec" to if (MyVpnService.startTime > 0L)
                            (System.currentTimeMillis() - MyVpnService.startTime) / 1000L else 0L
                    ))
                }
                "pingServer" -> {
                    val pingJson = call.argument<String>("xrayJson") ?: ""
                    Thread {
                        try {
                            val datDir = filesDir.absolutePath
                            libv2ray.Libv2ray.initCoreEnv(datDir, "")
                            val pingMs = libv2ray.Libv2ray.measureOutboundDelay(pingJson, "https://www.google.com")
                            runOnUiThread { result.success(pingMs) }
                        } catch (e: Exception) {
                            runOnUiThread { result.success(-1L) }
                        }
                    }.start()
                }
                "startLocalHotspot" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startLocalHotspot(result)
                    } else {
                        result.error("UNSUPPORTED", "Requires Android 8.0+", null)
                    }
                }
                "stopLocalHotspot" -> {
                    hotspotReservation?.close()
                    hotspotReservation = null
                    result.success(true)
                }
                "openHotspotSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("HOTSPOT_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun startLocalHotspot(result: MethodChannel.Result) {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        // Stop any existing reservation first
        hotspotReservation?.close()
        hotspotReservation = null

        try {
            wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    hotspotReservation = reservation
                    val config = reservation.wifiConfiguration
                    val ssid = config?.SSID ?: "VPN-Hotspot"
                    val password = config?.preSharedKey ?: ""
                    runOnUiThread {
                        result.success(mapOf(
                            "ssid" to ssid,
                            "password" to password,
                            "gatewayIp" to "192.168.49.1",
                            "proxyPort" to 10808
                        ))
                    }
                }

                override fun onStopped() {
                    hotspotReservation = null
                    runOnUiThread {
                        channel.invokeMethod("hotspotStopped", null)
                    }
                }

                override fun onFailed(reason: Int) {
                    runOnUiThread {
                        result.error("HOTSPOT_FAILED", "Failed to start hotspot. Reason: $reason", null)
                    }
                }
            }, Handler(Looper.getMainLooper()))
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Location permission required: ${e.message}", null)
        } catch (e: Exception) {
            result.error("HOTSPOT_ERROR", e.message, null)
        }
    }

    private fun startVpnWithPermission(config: Map<String, Any>, result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingConfig = config
            @Suppress("DEPRECATION")
            startActivityForResult(intent, VPN_PERMISSION_REQUEST)
            result.success(false)
        } else {
            launchVpnService(config)
            result.success(true)
        }
    }

    @Suppress("OVERRIDE_DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST) {
            if (resultCode == RESULT_OK) {
                pendingConfig?.let { launchVpnService(it) }
            } else {
                MyVpnService.notifyState("ERROR")
            }
            pendingConfig = null
        }
    }

    private fun launchVpnService(config: Map<String, Any>) {
        val intent = Intent(this, MyVpnService::class.java).apply {
            putExtra("server", config["server"] as? String ?: "")
            putExtra("port", (config["port"] as? Int) ?: 22)
            putExtra("protocol", config["protocol"] as? String ?: "ssh")
            putExtra("username", config["username"] as? String ?: "")
            putExtra("password", config["password"] as? String ?: "")
            putExtra("dns", config["dns"] as? String ?: "1.1.1.1")
            putExtra("sni", config["sni"] as? String ?: "")
            putExtra("xrayJson", config["xrayJson"] as? String)
        }
        startForegroundService(intent)
    }

    private fun stopVpnService() {
        val intent = Intent(this, MyVpnService::class.java).apply {
            action = "STOP_VPN"
        }
        startService(intent)
    }

    override fun onDestroy() {
        hotspotReservation?.close()
        hotspotReservation = null
        super.onDestroy()
    }
}
