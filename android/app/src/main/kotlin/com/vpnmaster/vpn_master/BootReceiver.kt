package com.vpnmaster.vpn_master

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Receives BOOT_COMPLETED broadcast and auto-starts the VPN service
 * if auto-start is enabled in preferences.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("vpn_master_prefs", Context.MODE_PRIVATE)
        val autoStart = prefs.getBoolean("auto_start", false)
        val server = prefs.getString("last_server", null)

        if (autoStart && !server.isNullOrEmpty()) {
            val vpnIntent = Intent(context, MyVpnService::class.java).apply {
                putExtra("server", server)
                putExtra("port", prefs.getInt("last_port", 22))
                putExtra("dns", prefs.getString("custom_dns", "1.1.1.1"))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(vpnIntent)
            } else {
                context.startService(vpnIntent)
            }
        }
    }
}
