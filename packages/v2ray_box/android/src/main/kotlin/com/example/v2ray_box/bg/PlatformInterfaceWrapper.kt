package com.example.v2ray_box.bg

import android.os.ParcelFileDescriptor

interface PlatformInterfaceWrapper {

    fun autoDetectInterfaceControl(fd: Int): Boolean = false

    fun createTun(): ParcelFileDescriptor? = null

    fun closeTun() {}
}
