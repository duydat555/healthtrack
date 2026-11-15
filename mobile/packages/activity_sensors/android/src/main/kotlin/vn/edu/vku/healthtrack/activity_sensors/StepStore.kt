package vn.edu.vku.healthtrack.activity_sensors

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Lưu bước chân theo ngày từ cảm biến TYPE_STEP_COUNTER (chỉ cho tổng từ lúc bật máy).
 * Mỗi lần đọc, phần tăng so với lần đọc trước được cộng vào ngày của lần đọc. Tác vụ nền đọc
 * khoảng 15 phút một lần nên bước đi gần nửa đêm vẫn rơi đúng ngày, sai lệch tối đa vài chục phút.
 */
internal object StepStore {
    private val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences("activity_sensors", Context.MODE_PRIVATE)

    @Synchronized
    fun record(context: Context, counter: Long, at: Date = Date()): Int {
        val p = prefs(context)
        val day = dayFormat.format(at)
        val last = p.getLong("last", -1L)
        var delta = if (last < 0) 0L else counter - last
        // Bộ đếm về 0 sau khi khởi động lại máy
        if (delta < 0) delta = counter
        val total = p.getInt("d:$day", 0) + delta.toInt()
        p.edit().putLong("last", counter).putInt("d:$day", total).apply()
        return total
    }

    fun daysBetween(context: Context, from: Long, to: Long): List<Map<String, Any>> {
        val p = prefs(context)
        val out = mutableListOf<Map<String, Any>>()
        val cal = Calendar.getInstance().apply {
            timeInMillis = from
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        while (cal.timeInMillis < to) {
            val key = dayFormat.format(cal.time)
            val steps = p.getInt("d:$key", 0)
            if (steps > 0) out.add(mapOf("day" to key, "steps" to steps))
            cal.add(Calendar.DAY_OF_MONTH, 1)
        }
        return out
    }
}
