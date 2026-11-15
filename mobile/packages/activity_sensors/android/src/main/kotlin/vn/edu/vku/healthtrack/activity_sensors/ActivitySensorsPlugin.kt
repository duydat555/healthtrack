package vn.edu.vku.healthtrack.activity_sensors

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.AppOpsManager
import android.app.PendingIntent
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
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.SleepSegmentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONArray
import java.util.concurrent.TimeUnit

/**
 * Cảm biến của máy Android, không cần Google Fit hay Health Connect.
 *
 * - Bước chân: cảm biến TYPE_STEP_COUNTER, ghi theo ngày ở [StepStore]; tác vụ nền
 *   [StepSampleWorker] đọc khoảng 15 phút một lần để bước rơi đúng ngày cả khi app đóng.
 * - Giấc ngủ: Google Sleep API ([SleepSegmentReceiver]) nếu máy có Play Services.
 * - Dự phòng cho giấc ngủ: các lần mở màn hình (UsageStatsManager, cần người dùng cấp "Quyền truy
 *   cập dữ liệu sử dụng"), làm đầu vào cho mô hình ước lượng phía Dart.
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
            "wakeEvents" -> {
                val from = call.argument<Number>("from")?.toLong()
                val to = call.argument<Number>("to")?.toLong()
                if (from == null || to == null) {
                    result.error("bad_args", "Thiếu from hoặc to", null)
                } else {
                    result.success(wakeEvents(from, to))
                }
            }
            "stepBuckets" -> result.success(emptyList<Any>())
            "sleepSegments" -> {
                val from = call.argument<Number>("from")?.toLong() ?: 0L
                val to = call.argument<Number>("to")?.toLong() ?: Long.MAX_VALUE
                result.success(sleepSegments(from, to))
            }
            "startBackground" -> {
                startBackground()
                result.success(null)
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

    private fun dailySteps(from: Long, to: Long, result: MethodChannel.Result) {
        val sensor = stepSensor
        if (sensor == null || !hasStepPermission()) return result.success(emptyList<Any>())
        var answered = false
        fun answer() {
            if (answered) return
            answered = true
            result.success(StepStore.daysBetween(context, from, to))
        }
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                StepStore.record(context, event.values[0].toLong())
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        val sensor = stepSensor ?: return
        if (!hasStepPermission()) return
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val total = StepStore.record(context, event.values[0].toLong())
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

    /** Các lúc màn hình được mở (người dùng đang thức). */
    private fun wakeEvents(from: Long, to: Long): List<Long> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P || !hasUsageAccess()) return emptyList()
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(from, to)
        val event = UsageEvents.Event()
        val out = mutableListOf<Long>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.SCREEN_INTERACTIVE) out.add(event.timeStamp)
        }
        return out
    }

    private fun sleepSegments(from: Long, to: Long): List<Map<String, Long>> {
        val stored = JSONArray(prefs.getString(SleepSegmentReceiver.KEY, "[]"))
        val out = mutableListOf<Map<String, Long>>()
        for (i in 0 until stored.length()) {
            val o = stored.getJSONObject(i)
            val start = o.getLong("start")
            val end = o.getLong("end")
            if (end > from && start < to) out.add(mapOf("start" to start, "end" to end))
        }
        return out
    }

    // Quyền hoạt động thể chất đã được kiểm bằng hasStepPermission() ngay trước khi gọi
    @SuppressLint("MissingPermission")
    /** Bật tác vụ đọc bước định kỳ và đăng ký nhận giấc ngủ từ Sleep API (gọi lại nhiều lần không sao). */
    private fun startBackground() {
        if (stepSensor != null && hasStepPermission()) {
            val work = PeriodicWorkRequestBuilder<StepSampleWorker>(15, TimeUnit.MINUTES).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "healthtrack_step_sample",
                ExistingPeriodicWorkPolicy.KEEP,
                work,
            )
        }
        // Sleep API cần Android 10+ và quyền hoạt động thể chất; máy không có Play Services thì bỏ qua
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && hasStepPermission()) {
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
            val pending = PendingIntent.getBroadcast(
                context,
                SLEEP_REQUEST_CODE,
                Intent(context, SleepSegmentReceiver::class.java),
                flags,
            )
            try {
                ActivityRecognition.getClient(context).requestSleepSegmentUpdates(
                    pending,
                    SleepSegmentRequest(SleepSegmentRequest.SEGMENT_EVENTS_ONLY),
                )
            } catch (e: SecurityException) {
                // Chưa có quyền: lần bật sau sẽ đăng ký lại
            } catch (e: RuntimeException) {
                // Không có Play Services: dùng mô hình ước lượng phía Dart
            }
        }
    }

    private companion object {
        const val REQUEST_CODE = 7301
        const val SLEEP_REQUEST_CODE = 7302
    }
}
