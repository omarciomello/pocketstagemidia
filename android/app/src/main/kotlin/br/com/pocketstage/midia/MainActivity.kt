package br.com.pocketstage.midia

import android.app.ActivityOptions
import android.content.Intent
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Mesa do PocketStage Mídia.
 * Telão: com um monitor externo, abre o palco nele e repassa as mensagens pelo canal "psm/telao".
 *  - Tela de apresentação (HDMI comum): [Telao] (Presentation).
 *  - Outra tela que não é de apresentação (ex.: Samsung DeX): [TelaoActivity] aberta naquela tela.
 * Segundo plano: mantém o [ServicoPalco] ligado enquanto o app está aberto.
 */
class MainActivity : FlutterActivity() {
    private var canal: MethodChannel? = null
    private var som: Som? = null
    private var telao: Telao? = null
    private var telaoJanela: Int? = null
    private var ultimoErro: String? = null
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
                    val m = call.arguments as String
                    telao?.enviar(m)
                    if (telaoJanela != null) Ponte.paraTelao(m)
                    result.success(null)
                }
                "estado" -> result.success(descricaoAtual())
                "diagnostico" -> result.success(diagnostico())
                "reconectar" -> {
                    rotear(forcar = true)
                    result.success(descricaoAtual())
                }
                else -> result.notImplemented()
            }
        }
        canal = c
        val cs = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "psm/player")
        val s = Som(
            applicationContext,
            cs,
            { flutterEngine.renderer },
            { telao?.texturas ?: Ponte.texturas() },
        )
        cs.setMethodCallHandler { call, result -> s.tratar(call.method, call.arguments as Map<*, *>?, result) }
        som = s
        Ponte.paraMesa = { msg -> main.post { canal?.invokeMethod("msg", msg) } }
        Ponte.aoFechar = { main.post { if (telaoJanela != null) { telaoJanela = null; avisarDesconectado() } } }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        displays = getSystemService(DisplayManager::class.java)
        displays.registerDisplayListener(ouvinte, main)
        main.postDelayed({ rotear() }, 300)
        try {
            val i = Intent(this, ServicoPalco::class.java)
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        displays.unregisterDisplayListener(ouvinte)
        telao?.fechar()
        telao = null
        Ponte.fecharTelao()
        som?.liberarTudo()
        try {
            stopService(Intent(this, ServicoPalco::class.java))
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun meuDisplay(): Int =
        if (Build.VERSION.SDK_INT >= 30) (display?.displayId ?: Display.DEFAULT_DISPLAY)
        else @Suppress("DEPRECATION") windowManager.defaultDisplay.displayId

    private fun descricaoAtual(): String? = telao?.descricao ?: telaoJanela?.let { id ->
        displays.getDisplay(id)?.let { "${tamanho(it)} · janela" }
    }

    private fun tamanho(d: Display): String =
        if (Build.VERSION.SDK_INT >= 23) "${d.mode.physicalWidth}×${d.mode.physicalHeight}" else "externo"

    private fun avisarDesconectado() = canal?.invokeMethod("desconectado", null)

    private fun rotear(forcar: Boolean = false) {
        try {
            val meu = meuDisplay()
            val externos = displays.displays.filter {
                it.displayId != meu && it.displayId != Display.DEFAULT_DISPLAY && it.state != Display.STATE_OFF &&
                    (it.flags and Display.FLAG_PRIVATE) == 0
            }
            val pres = displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION)
                .firstOrNull { it.displayId != meu && it.state != Display.STATE_OFF }
            val alvo = pres ?: externos.firstOrNull()

            if (alvo == null) {
                val tinha = telao != null || telaoJanela != null
                telao?.fechar()
                telao = null
                if (telaoJanela != null) {
                    telaoJanela = null
                    Ponte.fecharTelao()
                }
                if (tinha) avisarDesconectado()
                return
            }

            // já está no lugar certo
            if (!forcar && pres != null && telao?.display?.displayId == pres.displayId) return
            if (!forcar && pres == null && telaoJanela == alvo.displayId) return

            telao?.fechar()
            telao = null
            if (telaoJanela != null) {
                telaoJanela = null
                Ponte.fecharTelao()
            }

            if (pres != null) {
                val t = Telao(this, pres) { msg -> main.post { canal?.invokeMethod("msg", msg) } }
                t.show()
                telao = t
                canal?.invokeMethod("conectado", t.descricao)
            } else if (Build.VERSION.SDK_INT >= 26) {
                val opts = ActivityOptions.makeBasic().setLaunchDisplayId(alvo.displayId)
                val i = Intent(this, TelaoActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
                startActivity(i, opts.toBundle())
                telaoJanela = alvo.displayId
                canal?.invokeMethod("conectado", "${tamanho(alvo)} · janela")
            }
        } catch (e: Exception) {
            ultimoErro = e.toString()
            canal?.invokeMethod("erro", "Não consegui abrir o telão: ${e.javaClass.simpleName}. ${e.message ?: ""}")
        }
    }

    private fun diagnostico(): String {
        val sb = StringBuilder()
        sb.append("Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}) · ${Build.MANUFACTURER} ${Build.MODEL}\n")
        sb.append("Mesa na tela ${meuDisplay()}\n")
        val pres = displays.getDisplays(DisplayManager.DISPLAY_CATEGORY_PRESENTATION).map { it.displayId }.toSet()
        for (d in displays.displays) {
            sb.append("· tela ${d.displayId}: ${d.name} · ${tamanho(d)}")
            sb.append(" · estado ${d.state}")
            sb.append(" · flags ${d.flags}")
            if (d.displayId in pres) sb.append(" · APRESENTAÇÃO")
            sb.append('\n')
        }
        sb.append("Telão: ${descricaoAtual() ?: "nenhum"}\n")
        ultimoErro?.let { sb.append("Último erro: $it\n") }
        return sb.toString()
    }
}

/** Liga a mesa ao telão aberto como janela (TelaoActivity), que tem o próprio motor Flutter. */
object Ponte {
    var paraMesa: ((String) -> Unit)? = null
    var aoFechar: (() -> Unit)? = null
    private var telao: TelaoActivity? = null
    private val fila = ArrayList<String>()

    fun telaoPronto(a: TelaoActivity) {
        telao = a
        for (m in fila) a.receber(m)
        fila.clear()
    }

    fun telaoSaiu(a: TelaoActivity) {
        if (telao === a) {
            telao = null
            aoFechar?.invoke()
        }
    }

    fun texturas() = telao?.texturas()

    fun paraTelao(m: String) {
        val t = telao
        if (t != null) t.receber(m) else fila.add(m)
    }

    fun fecharTelao() {
        fila.clear()
        val t = telao
        telao = null
        try {
            t?.finish()
        } catch (_: Exception) {
        }
    }
}
