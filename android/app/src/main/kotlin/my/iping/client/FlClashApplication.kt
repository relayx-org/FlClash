package my.iping.client

import android.app.Application
import android.content.Context
import my.iping.client.common.GlobalState

class FlClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
