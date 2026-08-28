package br.com.hellenfaro.meugestorfinanceiro

import android.Manifest
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "br.com.hellenfaro.meugestorfinanceiro/android_calendar"
        private const val CALENDAR_PERMISSION_REQUEST = 4812
    }

    private var pendingCalendarResult: MethodChannel.Result? = null
    private var pendingCalendarCall: MethodCall? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listCalendars", "readAuthorizedEvents" -> withReadPermission(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun withReadPermission(call: MethodCall, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            executeReadOnlyCall(call, result)
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
            arrayOf(Manifest.permission.READ_CALENDAR),
            CALENDAR_PERMISSION_REQUEST,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST) return
        val call = pendingCalendarCall
        val result = pendingCalendarResult
        pendingCalendarCall = null
        pendingCalendarResult = null
        if (call == null || result == null) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            executeReadOnlyCall(call, result)
        } else {
            result.error("calendar_permission_denied", "Calendar permission was not granted.", null)
        }
    }

    private fun executeReadOnlyCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "listCalendars" -> result.success(listVisibleCalendars())
                "readAuthorizedEvents" -> result.success(readAuthorizedEvents(call))
                else -> result.notImplemented()
            }
        } catch (_: SecurityException) {
            result.error("calendar_permission_denied", "Calendar permission was not granted.", null)
        } catch (_: IllegalArgumentException) {
            result.error("calendar_invalid_request", "Invalid calendar read request.", null)
        }
    }

    private fun listVisibleCalendars(): List<Map<String, String>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
        )
        return contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            CalendarContract.Calendars.VISIBLE + " = 1",
            null,
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
        val selection = "${CalendarContract.Events.CALENDAR_ID} IN ($placeholders) AND " +
            "${CalendarContract.Events.DTSTART} < ? AND ${CalendarContract.Events.DTEND} > ?"
        val arguments = calendarIds.toTypedArray() + arrayOf(endsAt.toString(), startsAt.toString())
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.CALENDAR_ID,
            CalendarContract.Events.TITLE,
            CalendarContract.Events.DTSTART,
            CalendarContract.Events.DTEND,
        )
        return contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            selection,
            arguments,
            CalendarContract.Events.DTSTART + " ASC",
        )?.use { cursor ->
            buildList {
                val eventId = cursor.getColumnIndexOrThrow(CalendarContract.Events._ID)
                val calendarId = cursor.getColumnIndexOrThrow(CalendarContract.Events.CALENDAR_ID)
                val title = cursor.getColumnIndexOrThrow(CalendarContract.Events.TITLE)
                val starts = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTSTART)
                val ends = cursor.getColumnIndexOrThrow(CalendarContract.Events.DTEND)
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
}
