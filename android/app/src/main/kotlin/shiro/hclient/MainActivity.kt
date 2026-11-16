package shiro.hclient

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import androidx.activity.BackEventCompat
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private val app get() = application as HClientApplication

    // Providing an engine without a cached-engine ID lets the first normal
    // FlutterFragment onStart execute Dart. Reattachment sees isExecutingDart.
    override fun provideFlutterEngine(context: Context): FlutterEngine = app.obtainEngine()

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun createFlutterFragment(): FlutterFragment {
        // FlutterFragment's new-engine builder explicitly sets destroy=true and
        // does not consult Activity.shouldDestroyEngineWithHost for this path.
        // Keep the embedding's normal configuration but own that final policy.
        val configuration = super.createFlutterFragment().arguments
        return MainFlutterFragment().also { it.arguments = configuration }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Plugins and channels belong to the Application's single engine.
        app.transferHost.attachActivity(this)
        // configureFlutterEngine follows ActivityAware plugin attachment. The
        // initial Fragment transaction may not attach until Activity.onStart.
        consumeIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (savedInstanceState?.getBoolean(CONSUMED_INTENT) == true) {
            intent = neutralIntent()
        }
        WindowCompat.setDecorFitsSystemWindows(window, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { it.remove() }
        }
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        // ActivityAware sharing plugins consume the new intent exactly here.
        super.onNewIntent(intent)
        consumeIntent(intent)
    }

    private fun consumeIntent(intent: Intent) {
        if (intent.action == TransferHost.OPEN_TRANSFER) {
            app.transferHost.openTransfer(intent.getStringExtra(TransferHost.TARGET))
        }
        // receive_sharing_intent handles Activity.intent again on reattachment.
        // Its first attachment/new-intent callback has already seen this value.
        if (intent.action == Intent.ACTION_VIEW || intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE || intent.action == TransferHost.OPEN_TRANSFER
        ) {
            setIntent(neutralIntent())
        }
    }

    private fun neutralIntent() = Intent(this, MainActivity::class.java).setAction(Intent.ACTION_MAIN)

    override fun onSaveInstanceState(outState: Bundle) {
        // System recreation can carry the original launch Intent after setIntent.
        outState.putBoolean(CONSUMED_INTENT, true)
        super.onSaveInstanceState(outState)
    }

    override fun onResume() {
        super.onResume()
        app.transferHost.activityResumed(this)
    }

    override fun onPause() {
        app.transferHost.activityPaused(this)
        super.onPause()
    }

    override fun onDestroy() {
        app.transferHost.detachActivity(this)
        super.onDestroy()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (app.interceptVolumeEvent && isVolumeKey(keyCode)) {
            app.volumeEvent(keyCode == KeyEvent.KEYCODE_VOLUME_UP)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        if (app.interceptVolumeEvent && isVolumeKey(keyCode)) return true
        return super.onKeyUp(keyCode, event)
    }

    private fun isVolumeKey(keyCode: Int) =
        keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN

    companion object {
        private const val CONSUMED_INTENT = "hclient.consumedIntent"
    }
}

class MainFlutterFragment : FlutterFragment() {
    private var edgeDrawer: EdgeDrawerTarget? = null
    private val edgeDrawerHost get() = (requireActivity().application as HClientApplication).edgeDrawerHost

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun startBackGesture(backEvent: BackEventCompat) {
        val flutterView = requireView()
        val location = IntArray(2)
        flutterView.getLocationOnScreen(location)
        // BackEvent uses absolute touch coordinates, including in a split-screen window.
        edgeDrawer = edgeDrawerHost.target(backEvent, location[1] + flutterView.height / 2f)
        if (edgeDrawer == null) super.startBackGesture(backEvent)
    }

    override fun updateBackGestureProgress(backEvent: BackEventCompat) {
        if (edgeDrawer == null) super.updateBackGestureProgress(backEvent)
    }

    override fun commitBackGesture() {
        val target = edgeDrawer
        edgeDrawer = null
        if (target == null) super.commitBackGesture() else edgeDrawerHost.open(target)
    }

    override fun cancelBackGesture() {
        val consumed = edgeDrawer != null
        edgeDrawer = null
        if (!consumed) super.cancelBackGesture()
    }
}
