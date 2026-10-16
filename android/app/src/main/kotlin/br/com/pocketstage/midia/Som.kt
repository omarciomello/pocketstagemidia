package br.com.pocketstage.midia

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File

/**
 * Players de áudio e vídeo do Android (ExoPlayer), com escolha da saída de som.
 * A mesa (Dart) manda pelo canal "psm/player"; aqui só se toca e se informa posição, fim e erro.
 * Saída 0 = alto-falante do telefone (padrão); outro número = tipo do AudioDeviceInfo escolhido.
 */
@SuppressLint("UnsafeOptInUsageError")
class Som(
    private val ctx: Context,
    private val canal: MethodChannel,
    private val texturasMesa: () -> TextureRegistry?,
    private val texturasTelao: () -> TextureRegistry?,
) {
    private class Item(
        val player: ExoPlayer,
        val inicioMs: Long,
        val reforco: Float,
        val textura: TextureRegistry.SurfaceProducer?,
    )

    private val am = ctx.getSystemService(AudioManager::class.java)
    private val main = Handler(Looper.getMainLooper())
    private val itens = HashMap<Int, Item>()
    private var saida = 0

    private val ouvinteSaidas = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = mudouSaidas(added.mapNotNull { nome(it.type) })
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = mudouSaidas(emptyList())
    }

    init {
        am.registerAudioDeviceCallback(ouvinteSaidas, main)
    }

    fun tratar(metodo: String, a: Map<*, *>?, result: MethodChannel.Result) {
        try {
            when (metodo) {
                "abrir" -> result.success(abrir(a!!))
                "play" -> { itens[id(a)]?.player?.play(); result.success(null) }
                "pause" -> { itens[id(a)]?.player?.pause(); result.success(null) }
                "ganho" -> { ganho(id(a), (a!!["g"] as Number).toFloat()); result.success(null) }
                "liberar" -> { liberar(id(a)); result.success(null) }
                "estado" -> result.success(estado())
                "saidas" -> result.success(saidas())
                "saida" -> { escolher((a!!["tipo"] as Number).toInt()); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("som", e.message, null)
        }
    }

    private fun id(a: Map<*, *>?) = (a!!["id"] as Number).toInt()

    // ---------- tocar ----------

    private fun mixer(pan: Float, reforco: Float): ChannelMixingAudioProcessor? {
        if (pan == 0f && reforco <= 1f) return null
        val l = reforco * (if (pan > 0f) 1f - pan else 1f)
        val r = reforco * (if (pan < 0f) 1f + pan else 1f)
        return ChannelMixingAudioProcessor().apply {
            putChannelMixingMatrix(ChannelMixingMatrix(1, 2, floatArrayOf(l, r)))
            putChannelMixingMatrix(ChannelMixingMatrix(2, 2, floatArrayOf(l, 0f, 0f, r)))
            for (n in 3..8) {
                val k = 2f / n
                putChannelMixingMatrix(ChannelMixingMatrix(n, 2, FloatArray(n * 2) { i -> if (i % 2 == 0) l * k else r * k }))
            }
        }
    }

    private fun novoPlayer(pan: Float, reforco: Float): ExoPlayer {
        val mix = mixer(pan, reforco)
        if (mix != null) {
            val rf = object : DefaultRenderersFactory(ctx) {
                override fun buildAudioSink(context: Context, enableFloatOutput: Boolean, enableAudioTrackPlaybackParams: Boolean): AudioSink =
                    DefaultAudioSink.Builder(context).setAudioProcessors(arrayOf<AudioProcessor>(mix)).build()
            }
            return ExoPlayer.Builder(ctx, rf).build()
        }
        return ExoPlayer.Builder(ctx).build()
    }

    private fun abrir(a: Map<*, *>): Map<String, Any?> {
        val id = id(a)
        liberar(id)
        val uri = a["uri"] as String
        val inicio = ((a["start"] as Number?)?.toDouble() ?: 0.0)
        val fim = ((a["end"] as Number?)?.toDouble() ?: 0.0)
        val loop = a["loop"] as Boolean? ?: false
        val repetir = (a["repeat"] as Number?)?.toInt() ?: 0
        val pan = ((a["pan"] as Number?)?.toFloat() ?: 0f).coerceIn(-1f, 1f)
        val reforco = ((a["boost"] as Number?)?.toFloat() ?: 1f).coerceIn(1f, 2f)
        val alvo = a["alvo"] as String?

        val p = novoPlayer(pan, reforco)
        val clip = MediaItem.ClippingConfiguration.Builder()
            .setStartPositionMs((inicio * 1000).toLong())
            .apply { if (fim > inicio) setEndPositionMs((fim * 1000).toLong()) }
            .build()
        val u = if (uri.startsWith("/")) Uri.fromFile(File(uri)) else Uri.parse(uri)
        val mi = MediaItem.Builder().setUri(u).setClippingConfiguration(clip).build()
        when {
            loop && repetir > 1 -> { p.setMediaItems(List(repetir) { mi }); p.repeatMode = Player.REPEAT_MODE_OFF }
            loop && repetir != 1 -> { p.setMediaItem(mi); p.repeatMode = Player.REPEAT_MODE_ONE }
            else -> { p.setMediaItem(mi); p.repeatMode = Player.REPEAT_MODE_OFF }
        }

        var entrada: TextureRegistry.SurfaceProducer? = null
        var onde: String? = null
        if (alvo != null) {
            val reg = if (alvo == "telao") texturasTelao() ?: texturasMesa() else texturasMesa()
            onde = if (alvo == "telao" && texturasTelao() != null) "telao" else "mesa"
            if (reg != null) {
                val prod = reg.createSurfaceProducer()
                prod.setSize(1280, 720)
                prod.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
                    override fun onSurfaceAvailable() {
                        p.setVideoSurface(prod.surface)
                    }

                    override fun onSurfaceCleanup() {
                        p.setVideoSurface(null)
                    }
                })
                p.setVideoSurface(prod.surface)
                entrada = prod
            }
        }
        val item = Item(p, (inicio * 1000).toLong(), reforco, entrada)
        itens[id] = item
        p.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_ENDED && itens[id] === item) canal.invokeMethod("fim", mapOf("id" to id))
            }

            override fun onPlayerError(error: PlaybackException) {
                if (itens[id] === item) canal.invokeMethod("erro", mapOf("id" to id, "msg" to (error.message ?: "")))
            }

            override fun onVideoSizeChanged(v: VideoSize) {
                if (v.width <= 0 || v.height <= 0) return
                entrada?.setSize(v.width, v.height)
                val w = if (v.unappliedRotationDegrees % 180 == 0) v.width else v.height
                val h = if (v.unappliedRotationDegrees % 180 == 0) v.height else v.width
                canal.invokeMethod("tamanho", mapOf("id" to id, "w" to (w * v.pixelWidthHeightRatio).toInt(), "h" to h))
            }
        })
        aplicarSaida(p)
        p.volume = 0f
        p.prepare()
        return mapOf("textura" to entrada?.id(), "onde" to onde)
    }

    private fun ganho(id: Int, g: Float) {
        val it = itens[id] ?: return
        it.player.volume = (g / it.reforco).coerceIn(0f, 1f)
    }

    private fun liberar(id: Int) {
        val it = itens.remove(id) ?: return
        try {
            it.player.release()
        } catch (_: Exception) {
        }
        try {
            it.textura?.release()
        } catch (_: Exception) {
        }
    }

    fun liberarTudo() {
        for (id in itens.keys.toList()) liberar(id)
        try {
            am.unregisterAudioDeviceCallback(ouvinteSaidas)
        } catch (_: Exception) {
        }
    }

    /** Vídeos que estavam no telão perdem a imagem quando ele sai. */
    fun telaoSaiu() {
        // os players continuam; o Dart decide parar os vídeos do telão
    }

    private fun estado(): Map<String, List<Long>> {
        val m = HashMap<String, List<Long>>()
        for ((id, it) in itens) {
            val d = it.player.duration
            m[id.toString()] = listOf(it.inicioMs + it.player.currentPosition, if (d > 0) it.inicioMs + d else -1L)
        }
        return m
    }

    // ---------- saídas de som ----------

    private fun nome(tipo: Int): String? = when (tipo) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Telefone (alto-falante)"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Fone ou cabo P2"
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Fone ou cabo P2 (com microfone)"
        AudioDeviceInfo.TYPE_LINE_ANALOG -> "Saída de linha"
        AudioDeviceInfo.TYPE_LINE_DIGITAL -> "Saída digital"
        AudioDeviceInfo.TYPE_HDMI -> "HDMI (telão)"
        AudioDeviceInfo.TYPE_HDMI_ARC -> "HDMI ARC"
        AudioDeviceInfo.TYPE_USB_DEVICE -> "USB (placa de som)"
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB (acessório)"
        AudioDeviceInfo.TYPE_DOCK -> "Adaptador / dock"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth"
        22 -> "USB (adaptador P2 / fone)" // TYPE_USB_HEADSET
        26 -> "Bluetooth LE" // TYPE_BLE_HEADSET
        27 -> "Caixa Bluetooth LE" // TYPE_BLE_SPEAKER
        29 -> "HDMI (telão)" // TYPE_HDMI_EARC
        else -> null
    }

    private fun saidas(): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        val vistos = HashSet<Int>()
        for (d in am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
            val n = nome(d.type) ?: continue
            if (!vistos.add(d.type)) continue
            val tipo = if (d.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) 0 else d.type
            val prod = d.productName?.toString()?.trim().orEmpty()
            out.add(mapOf("tipo" to tipo, "nome" to n, "produto" to prod))
        }
        out.sortBy { if ((it["tipo"] as Int) == 0) 0 else 1 }
        return out
    }

    private fun dispositivo(): AudioDeviceInfo? {
        val devs = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val alto = devs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (saida == 0) return alto
        return devs.firstOrNull { it.type == saida } ?: alto
    }

    private fun aplicarSaida(p: ExoPlayer) {
        try {
            p.setPreferredAudioDevice(dispositivo())
        } catch (_: Exception) {
        }
    }

    private fun escolher(tipo: Int) {
        saida = tipo
        for (it in itens.values) aplicarSaida(it.player)
    }

    private fun mudouSaidas(novas: List<String>) {
        for (it in itens.values) aplicarSaida(it.player)
        canal.invokeMethod("saidas", mapOf("lista" to saidas(), "novas" to novas))
    }
}
