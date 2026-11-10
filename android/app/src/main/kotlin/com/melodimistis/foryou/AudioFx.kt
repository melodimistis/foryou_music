package com.melodimistis.foryou

import android.media.audiofx.AudioEffect
import android.media.audiofx.DynamicsProcessing
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class EqCurve(val cutoffs: FloatArray, val gains: FloatArray, val inputGain: Float) {
    val valid: Boolean
        get() = cutoffs.isNotEmpty() &&
            cutoffs.size == gains.size &&
            cutoffs.size <= AudioFx.MAX_BANDS &&
            inputGain.isFinite() &&
            cutoffs.all { it.isFinite() && it > 0f } &&
            gains.all { it.isFinite() }
}

@RequiresApi(28)
private class EqChain(session: Int, curve: EqCurve) {
    private val cutoffs = curve.cutoffs.copyOf()
    private val gains = curve.gains.copyOf()
    private var inputGain = curve.inputGain
    private val effect: DynamicsProcessing

    init {
        val eq = DynamicsProcessing.Eq(true, true, cutoffs.size)
        for (i in cutoffs.indices) {
            eq.setBand(i, DynamicsProcessing.EqBand(true, cutoffs[i], gains[i]))
        }
        val config = DynamicsProcessing.Config.Builder(
            DynamicsProcessing.VARIANT_FAVOR_FREQUENCY_RESOLUTION,
            2,
            true,
            cutoffs.size,
            false,
            0,
            false,
            0,
            false,
        )
            .setPreferredFrameDuration(AudioFx.FRAME_MS)
            .setPreEqAllChannelsTo(eq)
            .setInputGainAllChannelsTo(inputGain)
            .build()
        effect = DynamicsProcessing(0, session, config)
        try {
            if (effect.setEnabled(true) != AudioEffect.SUCCESS) {
                throw IllegalStateException("effect did not turn on")
            }
        } catch (e: Exception) {
            release()
            throw e
        }
    }

    fun fits(curve: EqCurve): Boolean = cutoffs.contentEquals(curve.cutoffs)

    fun update(curve: EqCurve) {
        val lower = curve.inputGain < inputGain
        if (lower) setInputGain(curve.inputGain)
        for (i in gains.indices) {
            if (curve.gains[i] == gains[i]) continue
            effect.setPreEqBandAllChannelsTo(
                i,
                DynamicsProcessing.EqBand(true, cutoffs[i], curve.gains[i]),
            )
            gains[i] = curve.gains[i]
        }
        if (!lower) setInputGain(curve.inputGain)
    }

    private fun setInputGain(value: Float) {
        if (value == inputGain) return
        effect.setInputGainAllChannelsTo(value)
        inputGain = value
    }

    fun release() {
        try {
            effect.release()
        } catch (e: Exception) {
            Log.w(AudioFx.TAG, "release failed", e)
        }
    }
}

object AudioFx {
    const val TAG = "ForYouAudioFx"
    const val FRAME_MS = 60f
    const val MAX_BANDS = 128
    private const val CHANNEL = "foryou/audiofx"

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val chains = HashMap<Int, Any>()
    private var sessions: Set<Int> = emptySet()
    private var curve: EqCurve? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "supported" -> submit(result) { supported() }
                "sessions" -> {
                    val ids = call.argument<List<Number>>("ids").orEmpty()
                        .map { it.toInt() }
                        .filter { it > 0 }
                        .toSet()
                    submit(result) {
                        sessions = ids
                        apply()
                    }
                }
                "eq" -> {
                    val next = curveOf(call)
                    submit(result) {
                        curve = next
                        apply() && (next == null || next.valid)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun curveOf(call: MethodCall): EqCurve? {
        if (call.argument<Boolean>("enabled") != true) return null
        val cutoffs = call.argument<List<Number>>("cutoffs").orEmpty()
        val gains = call.argument<List<Number>>("gains").orEmpty()
        val inputGain = call.argument<Number>("inputGain")?.toFloat() ?: 0f
        return EqCurve(
            FloatArray(cutoffs.size) { cutoffs[it].toFloat() },
            FloatArray(gains.size) { gains[it].toFloat() },
            inputGain,
        )
    }

    private fun submit(result: MethodChannel.Result, block: () -> Boolean) {
        worker.execute {
            val ok = try {
                block()
            } catch (e: Throwable) {
                Log.w(TAG, "request failed", e)
                false
            }
            main.post { result.success(ok) }
        }
    }

    private fun supported(): Boolean {
        if (Build.VERSION.SDK_INT < 28) return false
        return try {
            AudioEffect.queryEffects().orEmpty().any {
                it.type == AudioEffect.EFFECT_TYPE_DYNAMICS_PROCESSING
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun apply(): Boolean {
        if (Build.VERSION.SDK_INT < 28) return curve == null
        return applyChains()
    }

    @RequiresApi(28)
    private fun applyChains(): Boolean {
        val wanted = curve?.takeIf { it.valid }
        val stale = chains.keys.filter { wanted == null || it !in sessions }
        for (id in stale) {
            (chains.remove(id) as? EqChain)?.release()
        }
        if (wanted == null) return true
        var ok = true
        for (id in sessions) {
            try {
                val chain = chains[id] as? EqChain
                if (chain != null && chain.fits(wanted)) {
                    chain.update(wanted)
                } else {
                    chain?.release()
                    chains.remove(id)
                    chains[id] = EqChain(id, wanted)
                }
            } catch (e: Throwable) {
                Log.w(TAG, "equalizer failed on session $id", e)
                (chains.remove(id) as? EqChain)?.release()
                ok = false
            }
        }
        return ok
    }
}
