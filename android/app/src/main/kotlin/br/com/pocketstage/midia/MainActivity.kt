package br.com.pocketstage.midia

import android.content.Intent
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Mesa do PocketStage Mídia.
 * - Telão: quando um monitor externo (HDMI) aparece, abre o [Telao] nele e repassa as mensagens
 *   entre a mesa e o telão pelo canal "psm/telao".
 * - Segundo plano: mantém o [ServicoPalco] ligado enquanto o app está aberto, para o som não parar.
 */
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var telao: Telao? = null
    private lateinit var displays: DisplayManager
    private val main = Handler(Looper.getMainLooper())

    private val ouvinte = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) = rotear()
        override fun onDisplayRemoved(displayId: Int) = rotear()
        override fun onDisplayChanged(displayId: Int) = rotear()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val c = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "psm/telao")
        c.setMethodCallHandler { call, result ->
            when (call.method) {
                "enviar" -> {
                    telao?.enviar(call.arguments as String)
                    result.success(null)
                }
                "estado" -> result.success(telao?.descricao)
                else -> result.notImplemented()
            }
        }
        canal = c
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        displays = getSystemService(DisplayManager::class.java)
        displays.registerDisplayListener(ouvinte, main)
        main.post { rotear() }
        try {
            val i = Intent(this, ServicoPalco::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        } catch (_: Exception) {
            // sem o serviço o app funciona; só fica mais sujeito a ser fechado em segundo plano
        }
    }

    override fun onDestroy() {
        displays.unregisterDisplayListener(ouvinte)
        telao?.fechar()
        telao = null
        try {
            stopService(Intent(this, ServicoPalco::class.java))
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun rotear() {
        val d = displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).firstOrNull()
        val atual = telao
        if (d == null) {
            if (atual != null) {
                telao = null
                atual.fechar()
                canal?.invokeMethod("desconectado", null)
            }
            return
        }
        if (atual != null && atual.display.displayId == d.displayId) return
        if (atual != null) {
            telao = null
            atual.fechar()
        }
        val t = Telao(this, d) { msg -> main.post { canal?.invokeMethod("msg", msg) } }
        try {
            t.show()
            telao = t
            canal?.invokeMethod("conectado", t.descricao)
        } catch (e: WindowManager.InvalidDisplayException) {
            t.fechar()
        }
    }
}
