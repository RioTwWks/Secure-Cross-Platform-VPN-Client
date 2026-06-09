package com.example.v2ray_box.bg

import android.os.RemoteCallbackList
import androidx.lifecycle.MutableLiveData
import com.example.v2ray_box.IService
import com.example.v2ray_box.IServiceCallback
import com.example.v2ray_box.constant.Status
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class ServiceBinder(private val status: MutableLiveData<Status>) : IService.Stub() {
    private val callbacks = RemoteCallbackList<IServiceCallback>()
    private val broadcastLock = Mutex()

    init {
        status.observeForever {
            broadcast { callback ->
                callback.onServiceStatusChanged(it.ordinal)
            }
        }
    }

    @Suppress("DEPRECATION")
    fun broadcast(work: (IServiceCallback) -> Unit) {
        GlobalScope.launch(Dispatchers.Main) {
            broadcastLock.withLock {
                val count = callbacks.beginBroadcast()
                try {
                    repeat(count) {
                        try {
                            work(callbacks.getBroadcastItem(it))
                        } catch (_: Exception) {
                        }
                    }
                } finally {
                    callbacks.finishBroadcast()
                }
            }
        }
    }

    override fun getStatus(): Int {
        return (status.value ?: Status.Stopped).ordinal
    }

    override fun registerCallback(callback: IServiceCallback) {
        callbacks.register(callback)
    }

    override fun unregisterCallback(callback: IServiceCallback?) {
        callbacks.unregister(callback)
    }

    fun close() {
        callbacks.kill()
    }
}

