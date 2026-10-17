package br.com.hellenfaro.meugestorfinanceiro

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.os.Bundle
import android.provider.CalendarContract
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "br.com.hellenfaro.meugestorfinanceiro/android_calendar"
        private const val SPEECH_CHANNEL = "br.com.hellenfaro.meugestorfinanceiro/assistant_speech"
        private const val SPEECH_RMS_CHANNEL = "br.com.hellenfaro.meugestorfinanceiro/assistant_speech_rms"
        private const val ASSISTANT_AUDIO_CHANNEL = "br.com.hellenfaro.meugestorfinanceiro/assistant_audio"
        private const val CALENDAR_PERMISSION_REQUEST = 4812
        private const val AUDIO_PERMISSION_REQUEST = 4813
    }

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarCall: MethodCall? = null
    private var pendingSpeechResult: MethodChannel.Result? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var waitingForAudioPermission = false
    private var rmsEventSink: EventChannel.EventSink? = null
    private var assistantAudioPlayer: MediaPlayer? = null
    private var assistantAudioResult: MethodChannel.Result? = null
    private var assistantAudioFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        clearStaleAssistantAudio()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listCalendars", "listWritableCalendars", "readAuthorizedEvents" -> withCalendarPermission(
                        call,
                        result,
                        arrayOf(Manifest.permission.READ_CALENDAR),
                    )
                    "createConfirmedEvent" -> withCalendarPermission(
                        call,
                        result,
                        arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
                    )
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(SpeechRecognizer.isRecognitionAvailable(this))
                    "hasMicrophonePermission" -> result.success(
                        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
                            PackageManager.PERMISSION_GRANTED,
                    )
                    "startListening" -> startSpeechRecognition(result)
                    "stopListening" -> {
                        stopSpeechRecognition()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_RMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    rmsEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    rmsEventSink = null
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ASSISTANT_AUDIO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playWav" -> playAssistantWav(call.arguments, result)
                    "stop" -> {
                        stopAssistantAudio()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun withCalendarPermission(
        call: MethodCall,
        result: MethodChannel.Result,
        permissions: Array<String>,
    ) {
        if (permissions.all {
                ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
            }
        ) {
            executeCalendarCall(call, result)
            return
        }
        if (pendingCalendarResult != null) {
            result.error("calendar_request_in_progress", "Calendar permission request is in progress.", null)
            return
        }
        pendingCalendarCall = call
        pendingCalendarResult = result
        ActivityCompat.requestPermissions(
            this,
            permissions,
            CALENDAR_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == AUDIO_PERMISSION_REQUEST) {
            waitingForAudioPermission = false
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                startSpeechRecognition(pendingSpeechResult)
            } else {
                finishSpeechError("permission_denied")
            }
            return
        }
        if (requestCode != CALENDAR_PERMISSION_REQUEST) return
        val call = pendingCalendarCall
        val result = pendingCalendarResult
        pendingCalendarCall = null
        pendingCalendarResult = null
        if (call == null || result == null) return
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            executeCalendarCall(call, result)
        } else {
            result.error("calendar_permission_denied", "Calendar permission was not granted.", null)
        }
    }

    override fun onPause() {
        // O diálogo de permissão pode pausar a Activity; não cancele a solicitação
        // explícita antes de o Android devolver a decisão do usuário.
        if (!waitingForAudioPermission) stopSpeechRecognition()
        stopAssistantAudio()
        super.onPause()
    }

    override fun onDestroy() {
        stopSpeechRecognition()
        stopAssistantAudio()
        super.onDestroy()
    }

    // O arquivo existe apenas no cache durante a reprodução e é removido em
    // conclusão, interrupção ou destruição da Activity.
    private fun playAssistantWav(arguments: Any?, result: MethodChannel.Result) {
        val bytes = arguments as? ByteArray
        if (bytes == null || bytes.size !in 524..4_000_044 ||
            !bytes.copyOfRange(0, 4).contentEquals("RIFF".toByteArray()) ||
            !bytes.copyOfRange(8, 12).contentEquals("WAVE".toByteArray())
        ) {
            result.error("assistant_audio_invalid", "Assistant audio is unavailable.", null)
            return
        }
        stopAssistantAudio()
        try {
            val file = File.createTempFile("assistant-voice-", ".wav", cacheDir)
            file.writeBytes(bytes)
            assistantAudioFile = file
            assistantAudioResult = result
            assistantAudioPlayer = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    finishAssistantAudio(success = true)
                }
                setOnErrorListener { _, _, _ ->
                    finishAssistantAudio(success = false)
                    true
                }
                prepare()
                start()
            }
        } catch (_: Exception) {
            finishAssistantAudio(success = false, fallbackResult = result)
        }
    }

    private fun clearStaleAssistantAudio() {
        cacheDir.listFiles { file ->
            file.name.startsWith("assistant-voice-") && file.extension == "wav"
        }?.forEach { file -> file.delete() }
    }

    private fun stopAssistantAudio() {
        val pending = assistantAudioResult
        assistantAudioResult = null
        assistantAudioPlayer?.runCatching { stop() }
        assistantAudioPlayer?.release()
        assistantAudioPlayer = null
        assistantAudioFile?.delete()
        assistantAudioFile = null
        pending?.error("assistant_audio_interrupted", "Assistant audio was stopped.", null)
    }

    private fun finishAssistantAudio(
        success: Boolean,
        fallbackResult: MethodChannel.Result? = null,
    ) {
        val pending = assistantAudioResult ?: fallbackResult
        assistantAudioResult = null
        assistantAudioPlayer?.release()
        assistantAudioPlayer = null
        assistantAudioFile?.delete()
        assistantAudioFile = null
        if (success) pending?.success(null)
        else pending?.error("assistant_audio_unavailable", "Assistant audio is unavailable.", null)
    }

    private fun startSpeechRecognition(result: MethodChannel.Result?) {
        if (result != null) {
            if (pendingSpeechResult != null || waitingForAudioPermission) {
                result.error("speech_in_progress", "Speech recognition is already active.", null)
                return
            }
            pendingSpeechResult = result
        }
        if (pendingSpeechResult == null) return
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            finishSpeechError("unavailable")
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            waitingForAudioPermission = true
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                AUDIO_PERMISSION_REQUEST,
            )
            return
        }
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) {
                rmsEventSink?.success(rmsdB.toDouble())
            }
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit

            override fun onResults(results: Bundle?) {
                val transcript = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                    ?.trim()
                if (transcript.isNullOrEmpty()) finishSpeechError("no_match")
                else finishSpeechSuccess(transcript)
            }

            override fun onError(error: Int) {
                finishSpeechError(
                    when (error) {
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "permission_denied"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "network"
                        SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "no_match"
                        else -> "unavailable"
                    },
                )
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "pt-BR")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "pt-BR")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        recognizer.startListening(intent)
    }

    private fun finishSpeechSuccess(transcript: String) {
        val result = pendingSpeechResult
        pendingSpeechResult = null
        destroySpeechRecognizer()
        result?.success(transcript)
    }

    private fun finishSpeechError(code: String) {
        val result = pendingSpeechResult
        pendingSpeechResult = null
        destroySpeechRecognizer()
        result?.error(code, "Speech recognition is unavailable.", null)
    }

    private fun stopSpeechRecognition() {
        waitingForAudioPermission = false
        val result = pendingSpeechResult
        pendingSpeechResult = null
        destroySpeechRecognizer()
        result?.error("interrupted", "Speech recognition was stopped.", null)
    }

    private fun destroySpeechRecognizer() {
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
    }

    private fun executeCalendarCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listCalendars" -> result.success(listVisibleCalendars())
                "listWritableCalendars" -> result.success(listVisibleCalendars(writableOnly = true))
                "readAuthorizedEvents" -> result.success(readAuthorizedEvents(call))
                "createConfirmedEvent" -> {
                    createConfirmedEvent(call)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: SecurityException) {
            result.error("calendar_permission_denied", "Calendar permission was not granted.", null)
        } catch (_: IllegalArgumentException) {
            result.error("calendar_invalid_request", "Invalid calendar read request.", null)
        }
    }

    private fun listVisibleCalendars(writableOnly: Boolean = false): List<Map<String, String>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
        )
        return contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            if (writableOnly) {
                "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
                    "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
            } else {
                CalendarContract.Calendars.VISIBLE + " = 1"
            },
            if (writableOnly) {
                arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
            } else {
                null
            },
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME + " ASC",
        )?.use { cursor ->
            buildList {
                val idIndex = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
                val nameIndex = cursor.getColumnIndexOrThrow(
                    CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                )
                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idIndex).toString()
                    val name = cursor.getString(nameIndex)?.trim().orEmpty()
                    if (name.isNotEmpty()) add(mapOf("id" to id, "displayName" to name))
                }
            }
        } ?: emptyList()
    }

    private fun readAuthorizedEvents(call: MethodCall): List<Map<String, Any>> {
        val calendarIds = (call.argument<List<*>>("calendarIds") ?: emptyList<Any?>())
            .map { it as? String ?: throw IllegalArgumentException() }
            .filter { it.matches(Regex("[0-9]+")) }
            .distinct()
        val startsAt = call.argument<Number>("startsAtMillis")?.toLong()
            ?: throw IllegalArgumentException()
        val endsAt = call.argument<Number>("endsAtMillis")?.toLong()
            ?: throw IllegalArgumentException()
        if (calendarIds.isEmpty() || startsAt >= endsAt) throw IllegalArgumentException()

        val placeholders = calendarIds.joinToString(",") { "?" }
        val selection = "${CalendarContract.Instances.CALENDAR_ID} IN ($placeholders)"
        val arguments = calendarIds.toTypedArray()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
        )
        // Instances expande recorrências dentro do intervalo solicitado; ler
        // Events diretamente perderia compromissos recorrentes de amanhã.
        val instancesUri = CalendarContract.Instances.CONTENT_URI.buildUpon().also { builder ->
            ContentUris.appendId(builder, startsAt)
            ContentUris.appendId(builder, endsAt)
        }.build()
        return contentResolver.query(
            instancesUri,
            projection,
            selection,
            arguments,
            CalendarContract.Instances.BEGIN + " ASC",
        )?.use { cursor ->
            buildList {
                val eventId = cursor.getColumnIndexOrThrow(CalendarContract.Instances.EVENT_ID)
                val calendarId = cursor.getColumnIndexOrThrow(CalendarContract.Instances.CALENDAR_ID)
                val title = cursor.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
                val starts = cursor.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
                val ends = cursor.getColumnIndexOrThrow(CalendarContract.Instances.END)
                while (cursor.moveToNext()) {
                    val titleValue = cursor.getString(title)?.trim().orEmpty()
                    val startValue = cursor.getLong(starts)
                    val endValue = cursor.getLong(ends)
                    if (titleValue.isNotEmpty() && startValue < endValue) {
                        add(
                            mapOf(
                                "id" to cursor.getLong(eventId).toString(),
                                "calendarId" to cursor.getLong(calendarId).toString(),
                                "title" to titleValue,
                                "startsAtMillis" to startValue,
                                "endsAtMillis" to endValue,
                            ),
                        )
                    }
                }
            }
        } ?: emptyList()
    }

    // A ponte aceita somente criação após a confirmação já validada no Dart.
    // O calendário ainda é revalidado como gravável no provedor Android.
    private fun createConfirmedEvent(call: MethodCall) {
        val calendarId = call.argument<String>("calendarId")
            ?.takeIf { it.matches(Regex("[0-9]+")) }
            ?: throw IllegalArgumentException()
        val title = call.argument<String>("title")?.trim()
            ?.takeIf { it.length in 2..120 && it.none(Char::isISOControl) }
            ?: throw IllegalArgumentException()
        val startsAt = call.argument<Number>("startsAtMillis")?.toLong()
            ?: throw IllegalArgumentException()
        val endsAt = call.argument<Number>("endsAtMillis")?.toLong()
            ?: throw IllegalArgumentException()
        if (startsAt >= endsAt || endsAt - startsAt !in 300_000L..86_400_000L) {
            throw IllegalArgumentException()
        }
        val writable = contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(CalendarContract.Calendars._ID),
            "${CalendarContract.Calendars._ID} = ? AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?",
            arrayOf(calendarId, CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()),
            null,
        )?.use { it.moveToFirst() } == true
        if (!writable) throw IllegalArgumentException()

        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId.toLong())
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DTSTART, startsAt)
            put(CalendarContract.Events.DTEND, endsAt)
            put(CalendarContract.Events.EVENT_TIMEZONE, "America/Sao_Paulo")
        }
        if (contentResolver.insert(CalendarContract.Events.CONTENT_URI, values) == null) {
            throw IllegalArgumentException()
        }
    }
}
