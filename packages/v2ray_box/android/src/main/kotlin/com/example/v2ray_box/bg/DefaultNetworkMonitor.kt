package com.example.v2ray_box.bg

import android.net.ConnectivityManager
import android.net.Network
import android.os.Build
import com.example.v2ray_box.V2rayBoxPlugin

object DefaultNetworkMonitor {

    var defaultNetwork: Network? = null

    suspend fun start() {
        DefaultNetworkListener.start(this) {
            defaultNetwork = it
        }
        defaultNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            V2rayBoxPlugin.connectivity?.activeNetwork
        } else {
            DefaultNetworkListener.get()
        }
    }

    suspend fun stop() {
        DefaultNetworkListener.stop(this)
    }

    suspend fun require(): Network {
        val network = defaultNetwork
        if (network != null) {
            return network
        }
        return DefaultNetworkListener.get()
    }
}
