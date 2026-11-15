package vn.edu.vku.healthtrack.activity_sensors

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Cảm biến của máy Android, không cần Google Fit hay Health Connect.
 *
 * - Bước chân: cảm biến TYPE_STEP_COUNTER chỉ cho tổng số bước từ lúc bật máy, không có lịch sử.
 *   Mỗi lần đọc, phần chênh so với lần đọc trước được cộng vào ngày hiện tại và lưu trong
 *   SharedPreferences. Bước đi lúc app không chạy được tính vào ngày mở app kế tiếp.
 * - Quãng nghỉ: các lần tắt màn hình (UsageStatsManager), cần người dùng cấp "Quyền truy cập dữ
 *   liệu sử dụng" trong Cài đặt. Dùng để ước lượng giấc ngủ.
 */
class ActivitySensorsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private lateinit var events: EventChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var sink: EventChannel.EventSink? = null
    private var liveListener: SensorEventListener? = null
    private val main = Handler(Looper.getMainLooper())
    private val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    private val sensorManager: SensorManager
        get() = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val stepSensor: Sensor?
        get() = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
    private val prefs: SharedPreferences
        get() = context.getSharedPreferences("activity_sensors", Context.MODE_PRIVATE)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "healthtrack/activity")
        channel.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "healthtrack/activity/steps")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
        stopLive()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(stepSensor != null)
            "permission" -> result.success(permissionName())
            "requestPermission" -> requestPermission(result)
            "dailySteps" -> {
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (from == null || to == null) {
                    result.error("bad_args", "Thiếu from hoặc to", null)
                } else {
                    dailySteps(from, to, result)
                }
            }
            "restIntervals" -> {
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (from == null || to == null) {
                    result.error("bad_args", "Thiếu from hoặc to", null)
                } else {
                    result.success(restIntervals(from, to))
                }
            }
            "restAccess" -> result.success(hasUsageAccess())
            "openRestAccessSettings" -> {
                val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // Quyền đếm bước

    private fun hasStepPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            context.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) ==
            PackageManager.PERMISSION_GRANTED

    private fun permissionName(): String = when {
        stepSensor == null -> "unavailable"
        hasStepPermission() -> "granted"
        prefs.getBoolean("asked", false) -> "denied"
        else -> "notDetermined"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val current = activity
        if (stepSensor == null) return result.success("unavailable")
        if (hasStepPermission()) return result.success("granted")
        if (current == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return result.success(permissionName())
        }
        pendingPermission = result
        prefs.edit().putBoolean("asked", true).apply()
        current.requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(permissionName())
        pendingPermission = null
        return true
    }

    // Bước chân

    /** Cộng phần chênh của bộ đếm vào ngày hôm nay; trả tổng bước hôm nay. */
    private fun record(counter: Long): Int {
        val today = dayFormat.format(Date())
        val last = prefs.getLong("last", -1L)
        var delta = if (last < 0) 0L else counter - last
        // Bộ đếm về 0 sau khi khởi động lại máy
        if (delta < 0) delta = counter
        val total = prefs.getInt("d:$today", 0) + delta.toInt()
        prefs.edit().putLong("last", counter).putInt("d:$today", total).apply()
        return total
    }

    private fun stepsFor(day: String): Int = prefs.getInt("d:$day", 0)

    private fun dailySteps(from: Long, to: Long, result: MethodChannel.Result) {
        val sensor = stepSensor
        if (sensor == null || !hasStepPermission()) return result.success(emptyList<Any>())
        var answered = false
        fun answer() {
            if (answered) return
            answered = true
            result.success(daysBetween(from, to))
        }
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                record(event.values[0].toLong())
                sensorManager.unregisterListener(this)
                answer()
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        // Cảm biến thường trả ngay khi đăng ký; quá 2 giây thì trả dữ liệu đã lưu
        main.postDelayed({
            sensorManager.unregisterListener(listener)
            answer()
        }, 2000)
    }

    private fun daysBetween(from: Long, to: Long): List<Map<String, Any>> {
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
            val steps = stepsFor(key)
            if (steps > 0) out.add(mapOf("day" to key, "steps" to steps))
            cal.add(Calendar.DAY_OF_MONTH, 1)
        }
        return out
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sensor = stepSensor ?: return
        if (!hasStepPermission()) return
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val total = record(event.values[0].toLong())
                sink?.success(total)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        liveListener = listener
        sensorManager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onCancel(arguments: Any?) {
        stopLive()
        sink = null
    }

    private fun stopLive() {
        liveListener?.let { sensorManager.unregisterListener(it) }
        liveListener = null
    }

    // Quãng nghỉ (tắt màn hình)

    private fun hasUsageAccess(): Boolean {
        val ops = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun restIntervals(from: Long, to: Long): List<Map<String, Long>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P || !hasUsageAccess()) return emptyList()
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(from, to)
        val event = UsageEvents.Event()
        val out = mutableListOf<Map<String, Long>>()
        var offStart: Long? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.SCREEN_NON_INTERACTIVE ->
                    if (offStart == null) offStart = event.timeStamp
                UsageEvents.Event.SCREEN_INTERACTIVE -> {
                    val start = offStart
                    if (start != null) out.add(mapOf("start" to start, "end" to event.timeStamp))
                    offStart = null
                }
            }
        }
        offStart?.let { out.add(mapOf("start" to it, "end" to to)) }
        return out
    }

    private companion object {
        const val REQUEST_CODE = 7301
    }
}
