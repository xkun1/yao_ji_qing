package com.kunge.yaojiqing

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class DirectAudioRecorder(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val mainHandler = Handler(Looper.getMainLooper())
    private val isRecording = AtomicBoolean(false)
    private var eventSink: EventChannel.EventSink? = null
    private var audioRecord: AudioRecord? = null
    private var recorderThread: Thread? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                start(sampleRate, result)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "isRecording" -> result.success(isRecording.get())
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun start(sampleRate: Int, result: MethodChannel.Result) {
        if (isRecording.get()) {
            result.success(null)
            return
        }

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("NO_MIC_PERMISSION", "麦克风权限未授予", null)
            return
        }

        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat = AudioFormat.ENCODING_PCM_16BIT
        val minBufferSize = AudioRecord.getMinBufferSize(
            sampleRate,
            channelConfig,
            audioFormat
        )
        if (minBufferSize <= 0) {
            result.error("AUDIO_CONFIG_ERROR", "无法创建录音缓冲区", null)
            return
        }

        val bufferSize = maxOf(minBufferSize * 2, sampleRate / 5)
        val recorder = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
        } catch (e: Exception) {
            result.error("AUDIO_INIT_ERROR", "AudioRecord 创建失败: ${e.message}", null)
            return
        }

        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            result.error("AUDIO_INIT_ERROR", "AudioRecord 初始化失败", null)
            return
        }

        audioRecord = recorder
        isRecording.set(true)
        try {
            recorder.startRecording()
        } catch (e: Exception) {
            isRecording.set(false)
            recorder.release()
            audioRecord = null
            result.error("AUDIO_START_ERROR", "录音启动失败: ${e.message}", null)
            return
        }

        recorderThread = thread(start = true, name = "direct-audio-recorder") {
            val buffer = ByteArray(bufferSize)
            while (isRecording.get()) {
                val read = try {
                    recorder.read(buffer, 0, buffer.size)
                } catch (_: Exception) {
                    break
                }
                if (read > 0) {
                    val chunk = buffer.copyOf(read)
                    mainHandler.post {
                        eventSink?.success(chunk)
                    }
                } else if (read < 0) {
                    break
                }
            }
        }

        result.success(null)
    }

    fun stop() {
        if (!isRecording.getAndSet(false)) return

        try {
            audioRecord?.stop()
        } catch (_: Exception) {
        }

        try {
            recorderThread?.join(500)
        } catch (_: Exception) {
        }

        audioRecord?.release()
        audioRecord = null
        recorderThread = null
    }
}
