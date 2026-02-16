package com.example.jedechai_delivery_new

import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val alarmChannelName = "jedechai/alarm_sound"
    private var merchantAlarmPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, alarmChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playMerchantAlarm" -> {
                        playMerchantAlarm()
                        result.success(null)
                    }

                    "stopMerchantAlarm" -> {
                        stopMerchantAlarm()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopMerchantAlarm()
        super.onDestroy()
    }

    private fun playMerchantAlarm() {
        try {
            if (merchantAlarmPlayer?.isPlaying == true) {
                return
            }

            merchantAlarmPlayer?.release()
            merchantAlarmPlayer = MediaPlayer.create(this, R.raw.alert_new_order)?.apply {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                } else {
                    @Suppress("DEPRECATION")
                    setAudioStreamType(AudioManager.STREAM_ALARM)
                }

                isLooping = true
                start()
            }
        } catch (_: Exception) {
            stopMerchantAlarm()
        }
    }

    private fun stopMerchantAlarm() {
        merchantAlarmPlayer?.apply {
            try {
                if (isPlaying) {
                    stop()
                }
            } catch (_: Exception) {
                // Ignore stop exceptions from invalid player state
            }

            reset()
            release()
        }
        merchantAlarmPlayer = null
    }
}
