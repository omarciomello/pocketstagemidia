package br.com.pocketstage.midia

import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Telão como janela numa outra tela (ex.: Samsung DeX), com o motor Flutter `telaoMain`. */
class TelaoActivity : FlutterActivity() {
    private var canal: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "telaoMain"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val c = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "psm/telao")
        c.setMethodCallHandler { call, result ->
            when (call.method) {
                "enviar" -> {
                    Ponte.paraMesa?.invoke(call.arguments as String)
                    result.success(null)
                }
                "pronto" -> {
                    Ponte.telaoPronto(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        canal = c
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
    }

    fun texturas() = flutterEngine?.renderer

    fun receber(m: String) {
        runOnUiThread { canal?.invokeMethod("msg", m) }
    }

    override fun onDestroy() {
        Ponte.telaoSaiu(this)
        super.onDestroy()
    }
}
