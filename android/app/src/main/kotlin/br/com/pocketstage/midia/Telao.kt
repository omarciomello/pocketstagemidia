package br.com.pocketstage.midia

import android.app.Activity
import android.app.Presentation
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * O telão no monitor externo: um segundo motor Flutter (função `telaoMain` em main.dart)
 * desenhado num [Presentation]. Recebe da mesa as mensagens em JSON e devolve as dele.
 */
class Telao(
    private val activity: Activity,
    display: Display,
    private val paraMesa: (String) -> Unit,
) : Presentation(activity, display) {

    private val engine = FlutterEngine(activity.applicationContext)
    private val canal: MethodChannel
    private var pronto = false
    private val fila = ArrayList<String>()
    private var view: FlutterView? = null

    init {
        val loader = FlutterInjector.instance().flutterLoader()
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "telaoMain"),
        )
        canal = MethodChannel(engine.dartExecutor.binaryMessenger, "psm/telao")
        canal.setMethodCallHandler { call, result ->
            when (call.method) {
                "enviar" -> {
                    paraMesa(call.arguments as String)
                    result.success(null)
                }
                "pronto" -> {
                    pronto = true
                    for (m in fila) canal.invokeMethod("msg", m)
                    fila.clear()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    val descricao: String
        get() = if (Build.VERSION.SDK_INT >= 23) {
            val m = display.mode
            "${m.physicalWidth}×${m.physicalHeight}"
        } else {
            "externo"
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val v = FlutterView(context)
        v.attachToFlutterEngine(engine)
        setContentView(v)
        view = v
        engine.lifecycleChannel.appIsResumed()
    }

    fun enviar(msg: String) {
        if (pronto) canal.invokeMethod("msg", msg) else fila.add(msg)
    }

    fun fechar() {
        try {
            dismiss()
        } catch (_: Exception) {
        }
        try {
            view?.detachFromFlutterEngine()
        } catch (_: Exception) {
        }
        view = null
        engine.destroy()
    }
}
