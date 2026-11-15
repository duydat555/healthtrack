package vn.edu.vku.healthtrack.activity_sensors

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.SleepSegmentEvent
import org.json.JSONArray
import org.json.JSONObject

/**
 * Nhận giấc ngủ từ Google Sleep API (Play Services): mô hình AI trên máy dùng cảm biến ánh sáng và
 * chuyển động, gửi một đoạn ngủ mỗi sáng sau khi phát hiện người dùng thức dậy. Lưu 14 đoạn gần nhất.
 */
class SleepSegmentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!SleepSegmentEvent.hasEvents(intent)) return
        val prefs = context.getSharedPreferences("activity_sensors", Context.MODE_PRIVATE)
        val stored = JSONArray(prefs.getString(KEY, "[]"))
        val byStart = linkedMapOf<Long, JSONObject>()
        for (i in 0 until stored.length()) {
            val o = stored.getJSONObject(i)
            byStart[o.getLong("start")] = o
        }
        for (e in SleepSegmentEvent.extractEvents(intent)) {
            if (e.status != SleepSegmentEvent.STATUS_SUCCESSFUL) continue
            byStart[e.startTimeMillis] = JSONObject()
                .put("start", e.startTimeMillis)
                .put("end", e.endTimeMillis)
        }
        val kept = byStart.values.sortedBy { it.getLong("start") }.takeLast(14)
        prefs.edit().putString(KEY, JSONArray(kept).toString()).apply()
    }

    companion object {
        const val KEY = "sleep_segments"
    }
}
